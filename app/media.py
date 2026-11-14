import json
import os
import re
import shutil
import statistics
import subprocess
from pathlib import Path

THREADS = os.environ.get('CPU_THREADS', '2')
FONTS = Path(__file__).resolve().parent.parent / 'fonts'
W, H = 1080, 1920
_model = None


class JobError(Exception):
    pass


def sh(cmd, timeout=None):
    res = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if res.returncode != 0:
        tail = (res.stderr or res.stdout).strip().splitlines()[-6:]
        raise JobError(' '.join(tail)[-600:] or f'{cmd[0]} failed')
    return res.stdout


def free_gb():
    return shutil.disk_usage(os.environ.get('DATA_DIR', '/data')).free / 1e9


# ---------- download ----------

def source_type(url):
    if re.search(r'drive\.google\.com|docs\.google\.com', url):
        return 'drive'
    return 'link'


BLOCKED = ('YouTube asked the server to sign in, so this link could not be downloaded right now. Upload the video file '
           'instead, or try the link again later.')
VIDEO_FORMAT = 'bv*[height<=1080][ext=mp4]+ba[ext=m4a]/bv*[height<=1080]+ba/b[height<=1080]/b'


def ytdlp_base(session=''):
    """yt-dlp with the proxy (sticky per job when PROXY_URL has {session}) and saved cookies."""
    cmd = ['yt-dlp', '--no-playlist', '--no-warnings', '--no-progress', '--retries', '5', '--socket-timeout', '30']
    proxy = os.environ.get('PROXY_URL', '').strip()
    if proxy:
        cmd += ['--proxy', proxy.replace('{session}', session or 'clipper')]
    cookies = Path(os.environ.get('DATA_DIR', '/data')) / 'cookies.txt'
    if cookies.exists():
        cmd += ['--cookies', str(cookies)]
    return cmd


def _ytdlp(args, timeout):
    from . import db
    try:
        out = sh(args, timeout=timeout)
    except JobError as err:
        if 'Sign in to confirm' in str(err) or 'not a bot' in str(err):
            db.set_stat('yt_blocked_at', __import__('time').time())
            raise JobError(BLOCKED)
        raise
    if db.stat('yt_blocked_at'):
        db.set_stat('yt_blocked_at', 0)
    return out


def metadata(url, session=''):
    """Title and length of a linked video without downloading it (best effort)."""
    out = _ytdlp(ytdlp_base(session) + ['--skip-download', '--print', '%(duration)s\t%(title)s', url], timeout=90)
    duration, _, title = out.strip().splitlines()[-1].partition('\t')
    return title, float(duration) if duration not in ('', 'NA', 'None') else 0


def download_audio(url, folder: Path, max_minutes, session=''):
    """Only the sound track: enough to write the transcript and pick clips, ~1 MB a minute."""
    folder.mkdir(parents=True, exist_ok=True)
    out = _ytdlp(ytdlp_base(session) + [
        '-f', 'bestaudio[ext=m4a]/bestaudio/best',
        '-o', str(folder / 'audio-src.%(ext)s'), '--print', 'after_move:%(title)s', url], timeout=3600)
    files = sorted(folder.glob('audio-src.*'))
    if not files:
        raise JobError('Video was not downloaded (too long or not available).')
    lines = out.strip().splitlines()
    return files[0], (lines[-1] if lines else '')


def download_section(url, out_base: Path, start, end, session=''):
    """Just one clip's part of the video in up to 1080p, cut exactly at start and end."""
    _ytdlp(ytdlp_base(session) + [
        '-f', VIDEO_FORMAT, '--merge-output-format', 'mp4', '--download-sections', f'*{start:.2f}-{end:.2f}',
        '--force-keyframes-at-cuts', '-o', f'{out_base}.%(ext)s', url], timeout=1800)
    files = sorted(out_base.parent.glob(out_base.name + '.*'))
    if not files:
        raise JobError('Clip part was not downloaded.')
    return files[0]


def download(url, kind, folder: Path, max_minutes, session=''):
    """The whole video (Google Drive, or links where downloading parts is not possible)."""
    folder.mkdir(parents=True, exist_ok=True)
    if kind == 'drive':
        import gdown
        out = gdown.download(url, str(folder / 'source.mp4'), quiet=True, fuzzy=True)
        if not out:
            raise JobError('Google Drive file could not be downloaded. Make sure sharing is "Anyone with the link".')
        return Path(out), ''
    out = _ytdlp(ytdlp_base(session) + [
        '-f', VIDEO_FORMAT, '--merge-output-format', 'mp4',
        '-o', str(folder / 'source.%(ext)s'), '--print', 'after_move:%(title)s', url], timeout=3 * 3600)
    files = sorted(folder.glob('source.*'))
    if not files:
        raise JobError('Video was not downloaded (too long or not available).')
    lines = out.strip().splitlines()
    return files[0], (lines[-1] if lines else '')


def media_duration(path):
    out = sh(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(path)])
    return float(out.strip() or 0)


def probe(path):
    out = json.loads(sh(['ffprobe', '-v', 'error', '-print_format', 'json', '-show_streams', '-show_format', str(path)]))
    video = next((s for s in out['streams'] if s['codec_type'] == 'video'), None)
    if not video:
        raise JobError('File has no video track.')
    rotate = int((video.get('tags') or {}).get('rotate', 0) or 0)
    w, h = int(video['width']), int(video['height'])
    if rotate in (90, 270):
        w, h = h, w
    return {'width': w, 'height': h, 'duration': float(out['format'].get('duration', 0))}


# ---------- transcription ----------

def transcribe(path: Path, language='', on_progress=None, duration=0):
    global _model
    import numpy as np
    from faster_whisper import WhisperModel
    # Decode with ffmpeg ourselves (16 kHz mono float) instead of faster-whisper's PyAV reader,
    # which breaks on newer PyAV releases. Memory-mapped, so long videos don't fill the RAM.
    audio = path.with_name('audio.f32')
    sh(['ffmpeg', '-y', '-v', 'error', '-i', str(path), '-vn', '-ac', '1', '-ar', '16000', '-f', 'f32le', str(audio)])
    samples = np.memmap(audio, dtype=np.float32, mode='r')
    if not len(samples):
        raise JobError('This video has no sound.')
    if _model is None:
        _model = WhisperModel(os.environ.get('WHISPER_MODEL', 'small'), device='cpu',
                              compute_type='int8', cpu_threads=int(THREADS))
    segments, info = _model.transcribe(samples, language=language or None, word_timestamps=True,
                                       vad_filter=True, beam_size=1)
    words = []
    for seg in segments:
        if on_progress and duration:
            on_progress(min(seg.end / duration, 0.99))
        for w in seg.words or []:
            text = w.word.strip()
            if text:
                words.append({'s': round(w.start, 2), 'e': round(w.end, 2), 'w': text})
    audio.unlink(missing_ok=True)
    return words, info.language


# ---------- framing ----------

def face_center(path: Path, start, end, src):
    """Median x of the largest face across the clip, or None."""
    import cv2
    cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    cap = cv2.VideoCapture(str(path))
    xs = []
    t = start + 0.3
    step = max(0.7, (end - start) / 24)
    while t < end:
        cap.set(cv2.CAP_PROP_POS_MSEC, t * 1000)
        ok, frame = cap.read()
        t += step
        if not ok:
            continue
        small = cv2.resize(frame, (640, int(640 * frame.shape[0] / frame.shape[1])))
        gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
        faces = cascade.detectMultiScale(gray, scaleFactor=1.15, minNeighbors=6, minSize=(40, 40))
        if len(faces):
            x, y, fw, fh = max(faces, key=lambda f: f[2] * f[3])
            xs.append((x + fw / 2) / small.shape[1] * src['width'])
    cap.release()
    if len(xs) < 3:
        return None
    return statistics.median(xs)


def video_filter(path, start, end, src, crop_mode):
    w, h = src['width'], src['height']
    if h >= w * 1.5:  # already vertical
        return f'scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},setsar=1'
    cx = face_center(path, start, end, src) if crop_mode == 'face' else None
    if cx is not None:
        cw = int(h * 9 / 16) // 2 * 2
        x = int(min(max(cx - cw / 2, 0), w - cw))
        return f'crop={cw}:{h}:{x}:0,scale={W}:{H},setsar=1'
    return (f'split[a][b];[a]scale={W // 4}:{H // 4}:force_original_aspect_ratio=increase,crop={W // 4}:{H // 4},'
            f'boxblur=8:2,scale={W}:{H}[bg];[b]scale={W}:-2[fg];[bg][fg]overlay=0:(H-h)/2,setsar=1')


# ---------- captions ----------

def ass_time(t):
    t = max(t, 0)
    h, rem = divmod(t, 3600)
    m, s = divmod(rem, 60)
    return f'{int(h)}:{int(m):02d}:{s:05.2f}'


def ass_escape(text):
    return text.replace('\\', '').replace('{', '(').replace('}', ')').replace('\n', ' ')


def build_ass(words, start, end, title, settings):
    upper = settings.get('caption_uppercase') == '1'
    header = f'''[Script Info]
ScriptType: v4.00+
PlayResX: {W}
PlayResY: {H}
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Cap,Montserrat Black,92,&H00FFFFFF,&H00FFFFFF,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,7,3,2,70,70,560,1
Style: Title,Montserrat ExtraBold,62,&H00111111,&H00111111,&H00FFFFFF,&H00FFFFFF,-1,0,0,0,100,100,0,0,3,18,0,8,90,90,170,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
'''
    lines = []
    dur = end - start
    if title and settings.get('show_title') == '1':
        lines.append(f'Dialogue: 1,{ass_time(0)},{ass_time(dur)},Title,,0,0,0,,{ass_escape(title)}')
    clip_words = [w for w in words if w['s'] >= start - 0.05 and w['e'] <= end + 0.3]
    groups, cur = [], []
    for w in clip_words:
        if cur and (len(cur) >= 3 or w['s'] - cur[-1]['e'] > 0.6 or len(' '.join(x['w'] for x in cur + [w])) > 22):
            groups.append(cur)
            cur = []
        cur.append(w)
    if cur:
        groups.append(cur)
    for gi, group in enumerate(groups):
        g_end = groups[gi + 1][0]['s'] if gi + 1 < len(groups) else group[-1]['e'] + 0.4
        g_end = min(g_end, group[-1]['e'] + 0.6)
        for i, w in enumerate(group):
            s = w['s'] - start
            e = (group[i + 1]['s'] if i + 1 < len(group) else g_end) - start
            parts = []
            for j, x in enumerate(group):
                txt = ass_escape(x['w'].upper() if upper else x['w'])
                parts.append('{\\c&H00E5FF&}' + txt + '{\\c&HFFFFFF&}' if j == i else txt)
            pop = '{\\fscx108\\fscy108\\t(0,90,\\fscx100\\fscy100)}' if i == 0 else ''
            lines.append(f'Dialogue: 0,{ass_time(s)},{ass_time(max(e, s + 0.05))},Cap,,0,0,0,,{pop}{" ".join(parts)}')
    return header + '\n'.join(lines) + '\n'


# ---------- render ----------

def render(path: Path, out: Path, start, end, words, title, src, settings):
    ass = out.with_suffix('.ass')
    ass.write_text(build_ass(words, start, end, title, settings), encoding='utf-8')
    vf = video_filter(path, start, end, src, settings.get('crop_mode', 'face'))
    sub = f"subtitles=filename='{ass}':fontsdir='{FONTS}'"
    graph = f'[0:v]{vf}[v0];[v0]{sub}[v]'
    sh(['nice', '-n', '15', 'ffmpeg', '-y', '-v', 'error', '-ss', f'{start:.2f}', '-to', f'{end:.2f}', '-i', str(path),
        '-filter_complex', graph, '-map', '[v]', '-map', '0:a:0?', '-c:v', 'libx264', '-preset', 'veryfast',
        '-crf', '21', '-r', '30', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '128k', '-ar', '44100',
        '-threads', THREADS, '-movflags', '+faststart', str(out)], timeout=1800)
    ass.unlink(missing_ok=True)
    thumb = out.with_suffix('.jpg')
    sh(['ffmpeg', '-y', '-v', 'error', '-ss', '1', '-i', str(out), '-frames:v', '1', '-vf', 'scale=360:-2', str(thumb)])
    return thumb
