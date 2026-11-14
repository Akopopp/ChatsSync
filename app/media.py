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


def ytdlp_base():
    cmd = ['yt-dlp', '--no-playlist', '--no-warnings']
    cookies = Path(os.environ.get('DATA_DIR', '/data')) / 'cookies.txt'
    if cookies.exists():
        cmd += ['--cookies', str(cookies)]
    return cmd


def metadata(url):
    """Title and length of a linked video without downloading it (best effort)."""
    out = sh(ytdlp_base() + ['--skip-download', '--print', '%(duration)s\t%(title)s', url], timeout=60)
    duration, _, title = out.strip().splitlines()[-1].partition('\t')
    return title, float(duration) if duration not in ('', 'NA', 'None') else 0


def download(url, kind, folder: Path, max_minutes):
    folder.mkdir(parents=True, exist_ok=True)
    if kind == 'drive':
        import gdown
        out = gdown.download(url, str(folder / 'source.mp4'), quiet=True, fuzzy=True)
        if not out:
            raise JobError('Google Drive file could not be downloaded. Make sure sharing is "Anyone with the link".')
        return Path(out), ''
    cmd = ytdlp_base() + [
        '--no-progress', '-f', 'bv*[height<=1080][ext=mp4]+ba[ext=m4a]/bv*[height<=1080]+ba/b[height<=1080]/b',
        '--merge-output-format', 'mp4', '--match-filter', f'duration < {int(max_minutes) * 60} | !duration',
        '-o', str(folder / 'source.%(ext)s'), '--print', 'after_move:%(title)s', url,
    ]
    try:
        title = sh(cmd, timeout=3 * 3600).strip().splitlines()
    except JobError as err:
        msg = str(err)
        if 'Sign in to confirm' in msg or 'bot' in msg.lower():
            raise JobError('YouTube blocked the server from downloading this video. Download it on your phone or PC and '
                           'upload the file here instead, or use the Google Drive link from the campaign.')
        raise
    files = sorted(folder.glob('source.*'))
    if not files:
        raise JobError('Video was not downloaded (too long or not available).')
    return files[0], (title[-1] if title else '')


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
    from faster_whisper import WhisperModel
    audio = path.with_name('audio.wav')
    sh(['ffmpeg', '-y', '-v', 'error', '-i', str(path), '-vn', '-ac', '1', '-ar', '16000', str(audio)])
    if _model is None:
        _model = WhisperModel(os.environ.get('WHISPER_MODEL', 'small'), device='cpu',
                              compute_type='int8', cpu_threads=int(THREADS))
    segments, info = _model.transcribe(str(audio), language=language or None, word_timestamps=True,
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
