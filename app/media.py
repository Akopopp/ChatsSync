import json
import os
import re
import shutil
import statistics
import subprocess
from pathlib import Path

from . import edits

THREADS = os.environ.get('CPU_THREADS', '2')
FONTS = Path(__file__).resolve().parent.parent / 'fonts'
MODELS = Path(__file__).resolve().parent / 'models'
EMOJI_DIR = Path(__file__).resolve().parent / 'emoji'
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
# Clip parts are short, so take the sharpest version (up to 4K): the 9:16 crop keeps only a third of the width.
PART_FORMAT = 'bv*[height<=2160]+ba/b[height<=2160]/b'


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
        '-f', PART_FORMAT, '--merge-output-format', 'mkv', '--download-sections', f'*{start:.2f}-{end:.2f}',
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
    for side in video.get('side_data_list') or []:
        rotate = rotate or abs(int(side.get('rotation', 0) or 0))
    w, h = int(video['width']), int(video['height'])
    if rotate in (90, 270):
        w, h = h, w
    return {'width': w, 'height': h, 'duration': float(out['format'].get('duration', 0)),
            'audio': any(s['codec_type'] == 'audio' for s in out['streams'])}


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
    # Loudness of every second (RMS), used to find high-energy moments without AI.
    loud = [round(float(np.sqrt(np.mean(np.square(samples[i:i + 16000], dtype=np.float64)))), 4)
            for i in range(0, len(samples), 16000)]
    del samples
    audio.unlink(missing_ok=True)
    return words, info.language, loud


# ---------- faces ----------

SAMPLE_FPS = 2.5


def _detector(w, h):
    import cv2
    model = MODELS / 'yunet.onnx'
    if model.exists():
        net = cv2.FaceDetectorYN.create(str(model), '', (w, h), 0.75)

        def find(frame):
            _, faces = net.detect(frame)
            return [] if faces is None else [tuple(float(v) for v in f[:4]) for f in faces]
        return find
    cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')

    def find(frame):
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        return [tuple(float(v) for v in f) for f in cascade.detectMultiScale(gray, 1.15, 6, minSize=(40, 40))]
    return find


def face_samples(path: Path, t0, t1, src, offset=0.0):
    """Faces 2.5 times a second between t0 and t1 (seconds in the file).
    Returns [[time, [[cx, cy, w, h], ...]], ...] with time = file time + offset and sizes in source pixels."""
    import numpy as np
    sw = 640
    sh = int(round(src['height'] * sw / src['width'] / 2)) * 2
    proc = subprocess.Popen(['nice', '-n', '15', 'ffmpeg', '-v', 'error', '-ss', f'{t0:.2f}', '-to', f'{t1:.2f}',
                             '-i', str(path), '-vf', f'fps={SAMPLE_FPS},scale={sw}:{sh}', '-f', 'rawvideo',
                             '-pix_fmt', 'bgr24', '-'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    find = _detector(sw, sh)
    k = src['width'] / sw
    size, out, i = sw * sh * 3, [], 0
    while True:
        buf = proc.stdout.read(size)
        if len(buf) < size:
            break
        frame = np.frombuffer(buf, np.uint8).reshape(sh, sw, 3)
        faces = [[round((x + w / 2) * k), round((y + h / 2) * k), round(w * k), round(h * k)]
                 for x, y, w, h in find(frame) if w >= sw * 0.035]
        out.append([round(offset + t0 + i / SAMPLE_FPS, 2), faces])
        i += 1
    proc.wait()
    return out


def _area(f):
    return f[2] * f[3]


def camera_keys(samples, cw, width, start, end):
    """Keyframes [(t from clip start, crop left x)] following the main face, or None without a steady face.
    The camera holds still until the face leaves the middle of the frame, then glides there."""
    pts, prev = [], None
    for t, faces in samples:
        if not faces or t < start - 0.5 or t > end + 0.5:
            continue
        big = max(faces, key=_area)
        if prev is None:
            face = big
        else:
            near = min(faces, key=lambda f: abs(f[0] - prev))
            face = near if _area(near) >= 0.55 * _area(big) else big
        prev = face[0]
        pts.append((t - start, face[0]))
    inside = sum(1 for t, _ in samples if start <= t <= end) or 1
    if len(pts) < max(3, 0.3 * inside):
        return None
    xs = [x for _, x in pts]
    smooth = [statistics.median(xs[max(0, i - 2):i + 3]) for i in range(len(xs))]
    cam = smooth[0]
    keys = [(0.0, cam)]
    for (t, _), x in zip(pts, smooth):
        if abs(x - cam) > cw * 0.12:
            t = max(t, keys[-1][0])
            keys += [(t, cam), (t + 0.45, x)]
            cam = x
    keys.append((max(end - start, keys[-1][0]) + 1, cam))
    left = [(round(t, 2), int(min(max(x - cw / 2, 0), width - cw)) // 2 * 2) for t, x in keys]
    out = [left[0]]
    for i, key in enumerate(left[1:], 1):  # drop points in the middle of a still stretch
        if not (key[1] == out[-1][1] and i + 1 < len(left) and left[i + 1][1] == key[1]):
            out.append(key)
    return out


def path_expr(keys):
    """ffmpeg expression of t that eases (smoothstep) between keyframes."""
    terms = []
    for (ta, xa), (tb, xb) in zip(keys, keys[1:]):
        if tb - ta < 0.01:
            continue
        if xa == xb:
            seg = f'{xa}'
        else:
            p = f'((t-{ta})/{tb - ta:.2f})'
            seg = f'({xa}+({xb - xa})*(3*{p}*{p}-2*{p}*{p}*{p}))'
        terms.append(f'gte(t,{ta})*lt(t,{tb})*{seg}')
    terms.append(f'gte(t,{keys[-1][0]})*{keys[-1][1]}')
    return '+'.join(terms)


def two_speakers(samples, width, start, end):
    """((cx, cy, face size) left, right) when two people sit side by side most of the clip, else None."""
    window = [faces for t, faces in samples if start <= t <= end]
    xs = sorted(f[0] for faces in window for f in faces)
    if len(window) < 4 or len(xs) < 4:
        return None
    gap, i = max((xs[i + 1] - xs[i], i) for i in range(len(xs) - 1))
    if gap < width * 0.2:
        return None
    cut = (xs[i] + xs[i + 1]) / 2
    sides = ([f for faces in window for f in faces if f[0] < cut], [f for faces in window for f in faces if f[0] >= cut])
    seen = [sum(1 for faces in window if any((f[0] < cut) == (n == 0) for f in faces)) for n in (0, 1)]
    if min(seen) < 0.35 * len(window):
        return None
    return tuple((statistics.median(f[0] for f in g), statistics.median(f[1] for f in g), statistics.median(f[3] for f in g))
                 for g in sides)


# ---------- framing ----------

def _sharpen(scale):
    """Light sharpening when the picture is blown up, so upscaled crops look less soft."""
    if scale <= 1.15:
        return ''
    amount = min(0.4 + (scale - 1) * 0.35, 1.0)
    return f',unsharp=5:5:{amount:.2f}:5:5:0'


def _split(pair, w, h):
    """Two speakers stacked: each gets a 1080x960 panel cropped around their face."""
    chains = []
    for i, (cx, cy, size) in enumerate(pair):
        ch = min(h, max(size * 2.8, h * 0.5))
        cw = min(w, ch * W / (H / 2))
        ch = cw * (H / 2) / W
        x = min(max(cx - cw / 2, 0), w - cw)
        y = min(max(cy - ch * 0.42, 0), h - ch)
        chains.append(f'[s{i}]crop={int(cw) // 2 * 2}:{int(ch) // 2 * 2}:{int(x) // 2 * 2}:{int(y) // 2 * 2},'
                      f'scale={W}:{H // 2}:flags=lanczos{_sharpen(H / 2 / ch)}[p{i}]')
    return 'split[s0][s1];' + ';'.join(chains) + ';[p0][p1]vstack,setsar=1'


def framing(src, layout, samples, start, end):
    """Filter chain that turns the footage into 1080x1920, and the layout it ended up using."""
    w, h = src['width'], src['height']
    if h >= w * 1.5:
        return (f'scale={W}:{H}:force_original_aspect_ratio=increase:flags=lanczos,crop={W}:{H}{_sharpen(H / h)},setsar=1',
                'vertical')
    sharp = h >= 1000
    if samples and (layout == 'split' or (layout == 'auto' and sharp)):
        pair = two_speakers(samples, w, start, end)
        if pair:
            return _split(pair, w, h), 'split'
    if samples and (layout in ('face', 'split') or (layout == 'auto' and sharp)):
        cw = int(h * 9 / 16) // 2 * 2
        keys = camera_keys(samples, cw, w, start, end)
        if keys:
            x = path_expr(keys) if len({k[1] for k in keys}) > 1 else str(keys[0][1])
            return f"crop=w={cw}:h={h}:x='{x}':y=0,scale={W}:{H}:flags=lanczos{_sharpen(H / h)},setsar=1", 'face'
    return (f'split[a][b];[a]scale={W // 4}:{H // 4}:force_original_aspect_ratio=increase,crop={W // 4}:{H // 4},'
            f'boxblur=8:2,scale={W}:{H}[bg];[b]scale={W}:-2:flags=lanczos{_sharpen(W / w)}[fg];'
            f'[bg][fg]overlay=0:(H-h)/2,setsar=1', 'fit')


# ---------- captions ----------

def ass_time(t):
    t = max(t, 0)
    h, rem = divmod(t, 3600)
    m, s = divmod(rem, 60)
    return f'{int(h)}:{int(m):02d}:{s:05.2f}'


def ass_escape(text):
    return text.replace('\\', '').replace('{', '(').replace('}', ')').replace('\n', ' ')


def bgr(hex6):
    return f'&H{hex6[4:6]}{hex6[2:4]}{hex6[0:2]}&'


# font, size, outline, shadow, border style, most words on screen, most characters on screen
STYLE_SPEC = {
    'bold': ('Montserrat Black', 90, 7, 3, 1, 3, 20),
    'pop': ('Montserrat Black', 124, 8, 4, 1, 1, 14),
    'boxed': ('Montserrat ExtraBold', 74, 16, 0, 3, 4, 24),
    'clean': ('Montserrat ExtraBold', 68, 4, 2, 1, 6, 32),
}


def caption_place(edit):
    """ASS alignment, vertical margin, and where emojis go (top y) for the caption position."""
    hook_on = bool(edit.get('hook')) and edit.get('hook_show') != 'off'
    if edit.get('seam'):  # split screen: captions sit on the line between the two people
        return 5, 0, 700
    return {'bottom': (2, 560, 990), 'middle': (2, 780, 760),
            'top': (8, 400 if hook_on else 220, 680 if hook_on else 500)}[edit.get('position', 'bottom')]


def _groups(words, per_line, chars, sentences):
    groups, cur = [], []
    for w in words:
        text = ' '.join(x['w'] for x in cur + [w])
        if cur and (len(cur) >= per_line or w['s'] - cur[-1]['e'] > 0.6 or len(text) > chars
                    or (sentences and re.search(r'[.!?]$', cur[-1]['w']))):
            groups.append(cur)
            cur = []
        cur.append(w)
    return groups + ([cur] if cur else [])


def build_ass(words, dur, edit):
    """Subtitles for the finished clip. words are in output time."""
    style = edit.get('style', 'bold')
    font, size, outline, shadow, border, per_line, chars = STYLE_SPEC.get(style, STYLE_SPEC['bold'])
    hi = bgr(edits.COLORS.get(edit.get('color'), 'FFE500'))
    align, margin, _ = caption_place(edit)
    upper = edit.get('uppercase')
    box = border == 3
    header = f'''[Script Info]
ScriptType: v4.00+
PlayResX: {W}
PlayResY: {H}
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Cap,{font},{size},&H00FFFFFF,&H00FFFFFF,{'&H5A000000' if box else '&H00000000'},&H80000000,-1,0,0,0,100,100,0,0,{border},{outline},{shadow},{align},70,70,{margin},1
Style: Title,Montserrat ExtraBold,62,&H00111111,&H00111111,&H00FFFFFF,&H00FFFFFF,-1,0,0,0,100,100,0,0,3,18,0,8,90,90,170,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
'''
    lines = []
    hook = (edit.get('hook') or '').strip()
    if hook and edit.get('hook_show') != 'off':
        until = dur if edit.get('hook_show') == 'full' else min(3.2, dur)
        lines.append(f'Dialogue: 1,{ass_time(0)},{ass_time(until)},Title,,0,0,0,,{ass_escape(hook)}')
    if style == 'off':
        return header + '\n'.join(lines) + '\n'

    def txt(w):
        return ass_escape(w['w'].upper() if upper else w['w'])

    groups = _groups(words, per_line, chars, style == 'clean')
    for gi, group in enumerate(groups):
        g_end = groups[gi + 1][0]['s'] if gi + 1 < len(groups) else group[-1]['e'] + 0.4
        g_end = min(g_end, group[-1]['e'] + 0.6, dur)
        if style == 'clean':
            lines.append(f'Dialogue: 0,{ass_time(group[0]["s"])},{ass_time(max(g_end, group[0]["s"] + 0.1))},Cap,,0,0,0,,'
                         '{\\fad(80,0)}' + ' '.join(txt(w) for w in group))
            continue
        for i, w in enumerate(group):
            s = w['s']
            e = max(group[i + 1]['s'] if i + 1 < len(group) else g_end, s + 0.05)
            if style == 'pop':
                strong = len(re.sub(r'[^\w]', '', w['w'])) >= 6 or edits.emoji_for(w['w'])
                color = '{\\c' + hi + '}' if strong else ''
                lines.append(f'Dialogue: 0,{ass_time(s)},{ass_time(min(e, s + 1.4))},Cap,,0,0,0,,'
                             '{\\fscx128\\fscy128\\t(0,110,\\fscx100\\fscy100)}' + color + txt(w))
                continue
            parts = [('{\\c' + hi + '}' + txt(x) + '{\\c&HFFFFFF&}') if j == i else txt(x) for j, x in enumerate(group)]
            pop = '{\\fscx108\\fscy108\\t(0,90,\\fscx100\\fscy100)}' if i == 0 else ''
            lines.append(f'Dialogue: 0,{ass_time(s)},{ass_time(e)},Cap,,0,0,0,,{pop}{" ".join(parts)}')
    return header + '\n'.join(lines) + '\n'


# ---------- render ----------

def render(raw: Path, out: Path, edit, words, offset, src, samples=None, music=None):
    """Edit one clip. raw is footage whose first frame is at `offset` seconds of the original video;
    edit, words and face samples all use original-video seconds. Returns (thumbnail, layout used, output length)."""
    start, end = edit['start'], edit['end']
    t0, dur = max(start - offset, 0), end - start
    rel = [{'s': round(w['s'] - start, 2), 'e': round(w['e'] - start, 2), 'w': w['w']} for w in words]
    cuts = [(a - start, b - start) for a, b in edit.get('cuts') or []]
    keep = edits.keep_ranges(rel, {**edit, 'cuts': cuts}, dur)
    to_out, kept = edits.timeline(keep)
    length = round(sum(b - a for a, b in keep), 2)
    cap = [{'s': round(to_out(w['s']), 2), 'e': round(to_out(w['e']), 2), 'w': w['w']}
           for w in rel if kept((w['s'] + w['e']) / 2)]
    chain, layout = framing(src, edit.get('layout', 'auto'), samples, start, end)
    if layout == 'split' and edit.get('position', 'bottom') != 'top':
        edit = {**edit, 'seam': True}
    graph, v, n = [f'[0:v]fps=30,{chain}[base]'], 'base', 1
    inputs = ['-ss', f'{t0:.3f}', '-to', f'{t0 + dur:.3f}', '-i', str(raw)]
    trimmed = len(keep) > 1 or keep[0][0] > 0.01 or keep[0][1] < dur - 0.01
    select = '+'.join(f'between(t,{a},{b})' for a, b in keep)
    if trimmed:
        graph.append(f"[{v}]select='{select}',setpts=N/30/TB[cut]")
        v = 'cut'
    if edit.get('zoom'):
        zoomed = edits.zoom_ranges(cap, keep, length)
        if zoomed:
            when = '+'.join(f'between(on/30,{a},{b - 0.02:.2f})' for a, b in zoomed)
            graph.append(f"[{v}]zoompan=z='if({when},1.12,1)':x='iw/2-iw/zoom/2':y='(ih-ih/zoom)*0.4':d=1:"
                         f"s={W}x{H}:fps=30[zoom]")
            v = 'zoom'
    ass = out.with_suffix('.ass')
    if edit.get('style') != 'off' or (edit.get('hook') and edit.get('hook_show') != 'off'):
        ass.write_text(build_ass(cap, length, edit), encoding='utf-8')
        graph.append(f"[{v}]subtitles=filename='{ass}':fontsdir='{FONTS}'[subs]")
        v = 'subs'
    if edit.get('emoji') and edit.get('style') != 'off':
        events = edits.emoji_events(cap, length)
        top = caption_place(edit)[2]
        for code in dict.fromkeys(c for c, _, _ in events):
            spans = [(a, b) for c, a, b in events if c == code]
            inputs += ['-i', str(EMOJI_DIR / f'{code}.png')]
            show = '+'.join(f'between(t,{a},{b})' for a, b in spans)
            drop = '+'.join(f'between(t,{a},{b})*36*max(0,1-(t-{a})*7)' for a, b in spans)
            graph.append(f"[{n}:v]scale=170:170[e{n}];[{v}][e{n}]overlay=x=(W-w)/2:y='{top}-{drop}':enable='{show}'[o{n}]")
            v, n = f'o{n}', n + 1
    if edit.get('progress'):
        color = edits.COLORS.get(edit.get('color'), 'FFE500')
        graph.append(f"color=c=0x{color}:s={W}x10:r=30:d={length}[bar];[{v}][bar]overlay=x='-w+w*t/{length}':y=0[prog]")
        v = 'prog'
    amap = []
    if src.get('audio', True):
        voice = '[0:a]aresample=48000'
        if trimmed:
            voice += f",asetnsamples=n=1600:p=1,aselect='{select}',asetpts=N/SR/TB"
        graph.append(voice + '[voice]')
        amap = ['-map', '[voice]']
        if music and Path(music).exists():
            inputs += ['-stream_loop', '-1', '-i', str(music)]
            vol = max(0, min(int(edit.get('music_volume', 12)), 60)) / 100
            graph.append(f'[{n}:a]aresample=48000,volume={vol},atrim=0:{length}[m];[voice]asplit[v1][v2];'
                         f'[m][v1]sidechaincompress=threshold=0.02:ratio=8:attack=15:release=350[duck];'
                         f'[v2][duck]amix=inputs=2:duration=first:normalize=0[mix]')
            amap = ['-map', '[mix]']
    sh(['nice', '-n', '15', 'ffmpeg', '-y', '-v', 'error', *inputs, '-filter_complex', ';'.join(graph), '-map', f'[{v}]',
        *amap, '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '18', '-r', '30', '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '160k', '-ar', '48000', '-t', f'{length}', '-threads', THREADS,
        '-movflags', '+faststart', str(out)], timeout=2400)
    ass.unlink(missing_ok=True)
    thumb = out.with_suffix('.jpg')
    sh(['ffmpeg', '-y', '-v', 'error', '-ss', str(min(1, length / 2)), '-i', str(out), '-frames:v', '1',
        '-vf', 'scale=360:-2', str(thumb)])
    return thumb, layout, length


def cut_raw(src: Path, out: Path, start, end):
    """A clip's footage (with some extra on both sides) cut from a full video, so the clip can be edited later."""
    sh(['nice', '-n', '15', 'ffmpeg', '-y', '-v', 'error', '-ss', f'{start:.3f}', '-to', f'{end:.3f}', '-i', str(src),
        '-map', '0:v:0', '-map', '0:a:0?', '-vf', "scale='min(iw,2560)':-2", '-c:v', 'libx264', '-preset', 'ultrafast',
        '-crf', '16', '-c:a', 'aac', '-b:a', '192k', '-threads', THREADS, str(out)], timeout=1800)
    return out
