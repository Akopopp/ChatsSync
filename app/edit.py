"""Pro editing for one clip: silence and filler cuts, punch-in zooms, styled captions with colored keywords and emojis,
hook and outro text, background music that ducks under the voice, sound effects, stock B-roll and a progress bar."""
import os
import random
import re
import statistics
from pathlib import Path

import requests

from . import db, media
from .media import FONTS, H, THREADS, W, JobError, sh

FPS = 30
ASSETS = db.DATA / 'assets'
MUSIC = db.DATA / 'music'
FILLERS = {'um', 'umm', 'uh', 'uhh', 'uhm', 'erm', 'er', 'hmm', 'hm', 'ah', 'aah', 'eh', 'mm', 'mmm'}
EMOJI_FONTS = ['/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf', '/usr/share/fonts/noto/NotoColorEmoji.ttf']


def norm(word):
    return re.sub(r'[^\w]', '', str(word).lower())


def grid(t):
    return round(round(t * FPS) / FPS, 4)


# ---------- what to keep (silence and filler cuts) ----------

def plan_segments(words, dur, s):
    """Parts of the clip to keep, in clip seconds. Talking clips lose long pauses and "um"s; others stay whole."""
    cut_silence, cut_fillers = s.get('cut_silence') == '1', s.get('cut_fillers') == '1'
    speech = sum(max(w['e'] - w['s'], 0) for w in words)
    if not words or not (cut_silence or cut_fillers) or speech < dur * 0.45:
        return [(0.0, grid(dur))]
    kept = [w for w in words if not (cut_fillers and norm(w['w']) in FILLERS)]
    if not kept:
        return [(0.0, grid(dur))]
    segs = []
    start = max(0.0, kept[0]['s'] - 0.12) if cut_silence else 0.0
    end = kept[0]['e']
    for prev, w in zip(kept, kept[1:]):
        gap = w['s'] - prev['e']
        dropped = any(prev['e'] <= x['s'] < w['s'] and norm(x['w']) in FILLERS for x in words) if cut_fillers else False
        if (cut_silence and gap > 0.45) or (dropped and gap > 0.2):
            segs.append((start, end + 0.12))
            start = w['s'] - 0.08
        end = max(end, w['e'])
    segs.append((start, min(dur, end + 0.35) if cut_silence else dur))
    out = []
    for a, b in segs:
        a, b = grid(max(a, 0)), grid(min(b, dur))
        if out and a <= out[-1][1] + 0.05:
            out[-1] = (out[-1][0], max(out[-1][1], b))
        elif b - a >= 0.25:
            out.append((a, b))
    if not out or dur - sum(b - a for a, b in out) < 0.3:
        return [(0.0, grid(dur))]
    return out


def mapper(segs):
    """Clip time -> edited time (removed parts collapse to the next kept moment)."""
    def to_new(t):
        acc = 0.0
        for a, b in segs:
            if t < a:
                return acc
            if t <= b:
                return acc + (t - a)
            acc += b - a
        return acc
    return to_new


# ---------- zoom plan ----------

def zoom_pieces(segs, words, s, meta):
    """Split kept parts into pieces with their own zoom: alternate 100%/110% between phrases, 120% punch on stressed words."""
    if s.get('zoom') != '1':
        return [(a, b, 1.0) for a, b in segs]
    stress = {norm(x) for x in meta.get('zoom_words', [])} - {''}
    punches = []
    for w in words:
        if norm(w['w']) in stress and len(punches) < 4 and (not punches or w['s'] - punches[-1][1] > 2):
            punches.append((grid(w['s'] - 0.05), grid(w['e'] + 0.35)))
            stress.discard(norm(w['w']))
    toggles, last = [], 0.0
    for prev, w in zip(words, words[1:]):
        pause = w['s'] - prev['e'] > 0.35 or re.search(r'[.!?]$', prev['w'])
        if (pause and w['s'] - last >= 1.8) or w['s'] - last >= 4.0:
            toggles.append(grid(w['s'] - 0.04))
            last = w['s']
    cuts = sorted({t for t in toggles} | {t for p in punches for t in p})

    def level(t):
        if any(a <= t < b for a, b in punches):
            return 1.2
        return 1.1 if sum(1 for x in toggles if x <= t) % 2 else 1.0

    pieces = []
    for a, b in segs:
        points = [a] + [c for c in cuts if a + 0.2 < c < b - 0.2] + [b]
        for x, y in zip(points, points[1:]):
            z = level((x + y) / 2)
            if pieces and pieces[-1][1] == x and pieces[-1][2] == z:
                pieces[-1] = (pieces[-1][0], y, z)
            else:
                pieces.append((x, y, z))
    return pieces


# ---------- framing ----------

def face_track(path, start, end, src):
    """Smooth camera path [(t, x_center)] that follows the main face, or None when there is no face."""
    import cv2
    cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    cap = cv2.VideoCapture(str(path))
    step = max(0.5, (end - start) / 120)
    samples, t = [], start + 0.2
    while t < end:
        cap.set(cv2.CAP_PROP_POS_MSEC, t * 1000)
        ok, frame = cap.read()
        x = None
        if ok:
            small = cv2.resize(frame, (640, int(640 * frame.shape[0] / frame.shape[1])))
            faces = cascade.detectMultiScale(cv2.cvtColor(small, cv2.COLOR_BGR2GRAY), scaleFactor=1.15,
                                             minNeighbors=6, minSize=(40, 40))
            if len(faces):
                fx, fy, fw, fh = max(faces, key=lambda f: f[2] * f[3])
                x = (fx + fw / 2) / small.shape[1] * src['width']
        samples.append((t - start, x))
        t += step
    cap.release()
    found = [x for _, x in samples if x is not None]
    if len(found) < max(3, len(samples) * 0.3):
        return None
    filled, cur = [], found[0]
    for t, x in samples:
        cur = x if x is not None else cur
        filled.append((t, cur))
    smooth = []
    for i, (t, _) in enumerate(filled):
        window = [x for _, x in filled[max(0, i - 2):i + 3]]
        smooth.append((t, statistics.median(window)))
    keys, cam = [(0.0, smooth[0][1])], smooth[0][1]
    for t, x in smooth:
        if abs(x - cam) > src['width'] * 0.07 and t - keys[-1][0] > 0.6:
            keys += [(t, cam), (t + 0.5, x)]
            cam = x
    return keys[:60]


def _path_expr(keys, cw, w):
    def clamp(x):
        return int(min(max(x - cw / 2, 0), w - cw))
    if len(keys) == 1:
        return str(clamp(keys[0][1]))
    expr = str(clamp(keys[-1][1]))
    for (t0, x0), (t1, x1) in reversed(list(zip(keys, keys[1:]))):
        a, b = clamp(x0), clamp(x1)
        seg = str(a) if a == b else f'{a}+({b - a})*(t-{t0:.2f})/{max(t1 - t0, 0.01):.2f}'
        expr = f'if(lt(t,{t1:.2f}),{seg},{expr})'
    return expr


def framing(path, start, end, src, s):
    """Filter that turns the source into a 1080x1920 picture (on the clip's own timeline)."""
    w, h = src['width'], src['height']
    boost = ',eq=saturation=1.12:contrast=1.04' if s.get('color_boost') == '1' else ''
    if h >= w * 1.5:  # already vertical
        return f'fps={FPS},scale={W}:{H}:force_original_aspect_ratio=increase:flags=lanczos,crop={W}:{H}{media._sharpen(H / h)},setsar=1{boost}'
    mode = s.get('crop_mode', 'auto')
    cw = int(h * 9 / 16) // 2 * 2
    if mode == 'center':
        return f'fps={FPS},crop={cw}:{h}:{(w - cw) // 2}:0,scale={W}:{H}:flags=lanczos{media._sharpen(H / h)},setsar=1{boost}'
    want_face = mode == 'face' or (mode == 'auto' and h >= 1000)
    try:
        keys = face_track(path, start, end, src) if want_face else None
    except Exception as err:  # never let face finding stop the edit
        print('face tracking failed:', err)
        keys = None
    if keys:
        return (f"fps={FPS},crop={cw}:{h}:'{_path_expr(keys, cw, w)}':0,scale={W}:{H}:flags=lanczos"
                f'{media._sharpen(H / h)},setsar=1{boost}')
    return (f'fps={FPS},split[fa][fb];[fa]scale={W // 4}:{H // 4}:force_original_aspect_ratio=increase,crop={W // 4}:{H // 4},'
            f'boxblur=8:2,scale={W}:{H}[fbg];[fb]scale={W}:-2:flags=lanczos{media._sharpen(W / w)}[ffg];'
            f'[fbg][ffg]overlay=0:(H-h)/2,setsar=1{boost}')


# ---------- captions ----------

YELLOW, GREEN, RED, WHITE, BLACK = '&H00E5FF&', '&H5AFF3C&', '&H3B3BFF&', '&HFFFFFF&', '&H111111&'
STYLES = {
    #        font               size  primary      outline     back        border outline shadow
    'bold': ('Montserrat Black', 92, '&H00FFFFFF', '&H00000000', '&H80000000', 1, 7, 3),
    'beast': ('Montserrat Black', 104, '&H00FFFFFF', '&H00000000', '&H00000000', 1, 10, 0),
    'boxed': ('Montserrat ExtraBold', 78, '&H00111111', '&H00FFFFFF', '&H00FFFFFF', 3, 14, 0),
    'karaoke': ('Montserrat Black', 84, '&H00FFFFFF', '&H00000000', '&H80000000', 1, 7, 2),
    'minimal': ('Montserrat ExtraBold', 70, '&H00FFFFFF', '&H00000000', '&H90000000', 1, 4, 2),
}
GROUP_WORDS = {'bold': 3, 'beast': 2, 'boxed': 3, 'karaoke': 5, 'minimal': 5}


def caption_margin(s):
    return 330 if s.get('caption_position') == 'low' else 620


def ass_time(t):
    t = max(t, 0)
    h, rem = divmod(t, 3600)
    m, sec = divmod(rem, 60)
    return f'{int(h)}:{int(m):02d}:{sec:05.2f}'


def esc(text):
    return str(text).replace('\\', '').replace('{', '(').replace('}', ')').replace('\n', ' ')


def build_ass(words, subs, dur, meta, s):
    style = s.get('caption_style', 'bold')
    if style not in STYLES and style != 'off':
        style = 'bold'
    font, size, prim, outl, back, border, outline, shadow = STYLES.get(style, STYLES['bold'])
    margin = caption_margin(s)
    upper = s.get('caption_uppercase') == '1' and style != 'minimal'
    keys = {norm(k) for k in meta.get('keywords', [])} - {''} if s.get('highlight_keywords') == '1' else set()
    accent = RED if style == 'boxed' else GREEN
    active = RED if style == 'boxed' else YELLOW
    head = f'''[Script Info]
ScriptType: v4.00+
PlayResX: {W}
PlayResY: {H}
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Cap,{font},{size},{prim},{prim},{outl},{back},-1,0,0,0,100,100,0,0,{border},{outline},{shadow},2,70,70,{margin},1
Style: Title,Montserrat ExtraBold,62,&H00111111,&H00111111,&H00FFFFFF,&H00FFFFFF,-1,0,0,0,100,100,0,0,3,18,0,8,90,90,170,1
Style: Hook,Montserrat Black,110,&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,-1,0,0,0,100,100,0,0,1,10,4,5,80,80,0,1
Style: Outro,Montserrat Black,86,&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,-1,0,0,0,100,100,0,0,1,9,3,5,80,80,0,1
Style: Mark,Montserrat ExtraBold,40,&H66FFFFFF,&H66FFFFFF,&H99000000,&H00000000,-1,0,0,0,100,100,0,0,1,2,0,9,40,40,60,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
'''
    lines = []
    hook = (meta.get('hook') or '').strip()
    if hook and s.get('hook') == 'top':
        lines.append(f'Dialogue: 1,{ass_time(0)},{ass_time(dur)},Title,,0,0,0,,{esc(hook)}')
    elif hook and s.get('hook') == 'intro':
        lines.append(f'Dialogue: 2,{ass_time(0)},{ass_time(min(2.4, dur))},Hook,,0,0,0,,'
                     '{\\fscx70\\fscy70\\t(0,160,\\fscx100\\fscy100)\\fad(0,250)}' + esc(hook.upper()))
    if s.get('watermark') == '1' and s.get('watermark_text'):
        lines.append(f'Dialogue: 1,{ass_time(0)},{ass_time(dur)},Mark,,0,0,0,,{esc(s["watermark_text"])}')
    outro_at = dur - 1.8 if s.get('outro') == '1' and s.get('outro_text') and dur > 8 else None
    if outro_at:
        lines.append(f'Dialogue: 2,{ass_time(outro_at)},{ass_time(dur)},Outro,,0,0,0,,'
                     '{\\fad(200,0)\\fscx80\\fscy80\\t(0,180,\\fscx100\\fscy100)}' + esc(s['outro_text'].upper()))
    cap_end = outro_at if outro_at else dur + 1

    def word_txt(w):
        return esc(w.upper() if upper else w)

    if style != 'off' and subs:
        for sub in subs:
            if sub['s'] >= cap_end:
                break
            parts = []
            for word in sub['t'].split():
                txt = word_txt(word)
                parts.append('{\\c' + accent + '}' + txt + '{\\c' + WHITE + '}' if norm(word) in keys and style != 'boxed'
                             else txt)
            pop = '{\\fscx106\\fscy106\\t(0,90,\\fscx100\\fscy100)}'
            lines.append(f'Dialogue: 0,{ass_time(sub["s"])},{ass_time(min(sub["e"] + 0.15, cap_end))},Cap,,0,0,0,,{pop}{" ".join(parts)}')
    elif style != 'off':
        size_cap = GROUP_WORDS.get(style, 3)
        groups, cur = [], []
        for w in words:
            if cur and (len(cur) >= size_cap or w['s'] - cur[-1]['e'] > 0.6 or len(' '.join(x['w'] for x in cur + [w])) > 22 + size_cap * 3):
                groups.append(cur)
                cur = []
            cur.append(w)
        if cur:
            groups.append(cur)
        for gi, group in enumerate(groups):
            if group[0]['s'] >= cap_end:
                break
            g_end = groups[gi + 1][0]['s'] if gi + 1 < len(groups) else group[-1]['e'] + 0.4
            g_end = min(g_end, group[-1]['e'] + 0.6, cap_end)
            if style == 'minimal':
                lines.append(f'Dialogue: 0,{ass_time(group[0]["s"])},{ass_time(g_end)},Cap,,0,0,0,,'
                             + ' '.join(('{\\c' + accent + '}' + word_txt(x['w']) + '{\\c' + WHITE + '}')
                                        if norm(x['w']) in keys else word_txt(x['w']) for x in group))
                continue
            for i, w in enumerate(group):
                st = w['s']
                en = group[i + 1]['s'] if i + 1 < len(group) else g_end
                parts = []
                for j, x in enumerate(group):
                    txt = word_txt(x['w'])
                    base = BLACK if style == 'boxed' else WHITE
                    if style == 'karaoke':
                        color = active if j <= i else (accent if norm(x['w']) in keys else base)
                    else:
                        color = active if j == i else (accent if norm(x['w']) in keys else base)
                    if style == 'beast' and j == i:
                        txt = '{\\fscx112\\fscy112}' + txt + '{\\fscx100\\fscy100}'
                    parts.append('{\\c' + color + '}' + txt + '{\\c' + base + '}' if color != base else txt)
                pop = '{\\fscx108\\fscy108\\t(0,90,\\fscx100\\fscy100)}' if i == 0 else ''
                if style == 'beast':
                    pop = '{\\fscx115\\fscy115\\t(0,110,\\fscx100\\fscy100)}' if i == 0 else ''
                lines.append(f'Dialogue: 0,{ass_time(st)},{ass_time(max(min(en, cap_end), st + 0.05))},Cap,,0,0,0,,{pop}{" ".join(parts)}')
    return head + '\n'.join(lines) + '\n'


# ---------- emojis, sound effects, music, B-roll ----------

def emoji_png(char):
    """PNG of one color emoji (cached)."""
    folder = ASSETS / 'emoji'
    folder.mkdir(parents=True, exist_ok=True)
    out = folder / ('-'.join(f'{ord(c):x}' for c in char) + '.png')
    if out.exists():
        return out
    font_path = next((p for p in EMOJI_FONTS if Path(p).exists()), None)
    if not font_path:
        return None
    from PIL import Image, ImageDraw, ImageFont
    font = ImageFont.truetype(font_path, 109)
    img = Image.new('RGBA', (160, 160), (0, 0, 0, 0))
    ImageDraw.Draw(img).text((10, 10), char, font=font, embedded_color=True)
    box = img.getbbox()
    if not box:
        return None
    img = img.crop(box).resize((190, int(190 * (box[3] - box[1]) / max(box[2] - box[0], 1))), Image.LANCZOS)
    img.save(out)
    return out


def sfx(name):
    folder = ASSETS / 'sfx'
    folder.mkdir(parents=True, exist_ok=True)
    out = folder / f'{name}.wav'
    if not out.exists():
        src = {'whoosh': 'anoisesrc=d=0.45:c=pink:a=0.6:r=44100,highpass=f=400,lowpass=f=5000,'
                         'afade=t=in:st=0:d=0.2,afade=t=out:st=0.2:d=0.25',
               'pop': 'sine=f=900:d=0.09:sample_rate=44100,afade=t=out:st=0.01:d=0.08'}[name]
        sh(['ffmpeg', '-y', '-v', 'error', '-f', 'lavfi', '-i', src, '-ac', '2', '-ar', '44100', str(out)])
    return out


def music_file(campaign_id):
    files = []
    for folder in (MUSIC / f'c{campaign_id}', MUSIC / 'all'):
        if folder.exists():
            files = [p for p in folder.iterdir() if p.suffix.lower() in ('.mp3', '.m4a', '.wav', '.aac', '.ogg')]
            if files:
                break
    return random.choice(files) if files else None


def pexels_clip(query, folder: Path, n):
    key = os.environ.get('PEXELS_API_KEY', '').strip()
    if not key:
        return None
    res = requests.get('https://api.pexels.com/videos/search', headers={'Authorization': key}, timeout=20,
                       params={'query': query, 'orientation': 'portrait', 'per_page': 6, 'size': 'medium'})
    if res.status_code != 200:
        return None
    for video in res.json().get('videos', []):
        files = [f for f in video.get('video_files', []) if f.get('link') and (f.get('height') or 0) >= 1000
                 and (f.get('width') or 0) < (f.get('height') or 0)]
        if not files:
            continue
        best = min(files, key=lambda f: abs((f.get('height') or 0) - 1920))
        out = folder / f'broll-{n}.mp4'
        with requests.get(best['link'], stream=True, timeout=60) as dl:
            if dl.status_code != 200:
                continue
            size = 0
            with out.open('wb') as fh:
                for chunk in dl.iter_content(1 << 20):
                    size += len(chunk)
                    if size > 40 << 20:
                        break
                    fh.write(chunk)
        return out
    return None


def _first_time(words, target, after=0.0):
    t = norm(target)
    for w in words:
        if norm(w['w']) == t and w['s'] >= after:
            return w
    return None


# ---------- the whole edit ----------

def render(path: Path, out: Path, start, end, words, meta, src, s, campaign_id=0, simple=False, has_audio=True):
    """Edit one clip. words are in the source's time; start/end cut the clip. Returns the thumbnail path."""
    folder = out.parent
    dur = round(end - start, 3)
    clip_words = [{'s': round(w['s'] - start, 3), 'e': round(w['e'] - start, 3), 'w': w['w']}
                  for w in words if w['s'] >= start - 0.05 and w['e'] <= end + 0.3]
    if simple:
        s = {**s, 'cut_silence': '0', 'cut_fillers': '0', 'zoom': '0', 'emojis': '0', 'broll': '0', 'music': '0', 'sfx': '0'}
    segs = plan_segments(clip_words, dur, s)
    to_new = mapper(segs)
    new_dur = round(sum(b - a for a, b in segs), 3)
    kept_words = []
    for w in clip_words:
        if s.get('cut_fillers') == '1' and norm(w['w']) in FILLERS and len(segs) > 1:
            continue
        ns, ne = to_new(w['s']), to_new(w['e'])
        if ne > ns:
            kept_words.append({'s': round(ns, 3), 'e': round(ne, 3), 'w': w['w']})
    subs = [{'s': round(to_new(x['s']), 3), 'e': round(to_new(x['e']), 3), 't': x['t']}
            for x in (meta.get('subs') or []) if x['e'] > 0 and x['s'] < dur]  # clip seconds
    pieces = zoom_pieces(segs, clip_words, s, meta)

    inputs = ['-ss', f'{start:.3f}', '-to', f'{end:.3f}', '-i', str(path)]
    n_in = 1
    graph = [f'[0:v]{framing(path, start, end, src, s)}[base]']
    if len(pieces) == 1 and pieces[0][2] == 1.0 and len(segs) == 1:
        graph.append(f'[base]trim=start=0:end={new_dur},setpts=PTS-STARTPTS[vc]')
    else:
        labels = ''.join(f'[s{i}]' for i in range(len(pieces)))
        graph.append(f'[base]split={len(pieces)}{labels}' if len(pieces) > 1 else '[base]null[s0]')
        for i, (a, b, z) in enumerate(pieces):
            zoom = ''
            if z > 1.0:
                zw, zh = int(W * z) // 2 * 2, int(H * z) // 2 * 2
                zoom = f',scale={zw}:{zh}:flags=bicubic,crop={W}:{H}:{(zw - W) // 2}:{int((zh - H) * 0.35)}'
            graph.append(f'[s{i}]trim=start={a}:end={b},setpts=PTS-STARTPTS{zoom}[p{i}]')
        graph.append(''.join(f'[p{i}]' for i in range(len(pieces))) + f'concat=n={len(pieces)}:v=1:a=0[vc]')

    # sound: kept parts of the voice, glued with tiny fades so cuts don't click
    if has_audio:
        if len(segs) == 1:
            graph.append(f'[0:a]aresample=44100,aformat=channel_layouts=stereo,atrim=start=0:end={new_dur},asetpts=PTS-STARTPTS[ac]')
        else:
            labels = ''.join(f'[x{i}]' for i in range(len(segs)))
            graph.append(f'[0:a]aresample=44100,aformat=channel_layouts=stereo,asplit={len(segs)}{labels}')
            for i, (a, b) in enumerate(segs):
                fade = min(0.015, (b - a) / 4)
                graph.append(f'[x{i}]atrim=start={a}:end={b},asetpts=PTS-STARTPTS,'
                             f'afade=t=in:d={fade:.3f},afade=t=out:st={b - a - fade:.3f}:d={fade:.3f}[y{i}]')
            graph.append(''.join(f'[y{i}]' for i in range(len(segs))) + f'concat=n={len(segs)}:v=0:a=1[ac]')
    else:
        graph.append(f'anullsrc=r=44100:cl=stereo,atrim=0:{new_dur}[ac]')

    video = 'vc'
    # B-roll from Pexels over the picture for ~2 s (never in the first 2 s or the outro)
    events = []  # (time, sfx name)
    if s.get('broll') == '1' and not simple:
        used = 0
        for item in meta.get('broll', [])[:2]:
            w = _first_time(kept_words, item.get('word', ''), after=2.0)
            if not w or w['s'] > new_dur - 3.5:
                continue
            try:
                clip = pexels_clip(str(item['query'])[:60], folder, used)
            except Exception:
                clip = None
            if not clip:
                continue
            a, b = round(w['s'] - 0.1, 2), round(min(w['s'] + 1.9, new_dur - 2), 2)
            inputs += ['-ss', '0', '-t', f'{b - a + 0.2:.2f}', '-i', str(clip)]
            graph.append(f'[{n_in}:v]scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},fps={FPS},'
                         f'setpts=PTS-STARTPTS+{a}/TB[br{used}]')
            graph.append(f"[{video}][br{used}]overlay=0:0:enable='between(t,{a},{b})':eof_action=pass[vb{used}]")
            video = f'vb{used}'
            events.append((a, 'whoosh'))
            n_in += 1
            used += 1

    ass = out.with_suffix('.ass')
    ass.write_text(build_ass(kept_words, subs, new_dur, meta, s), encoding='utf-8')
    graph.append(f"[{video}]subtitles=filename='{ass}':fontsdir='{FONTS}'[vs]")
    video = 'vs'

    if s.get('emojis') == '1' and not simple:
        y = H - caption_margin(s) - (560 if subs else 360)
        shown = 0
        for item in meta.get('emojis', [])[:4]:
            w = _first_time(kept_words, item.get('word', ''), after=2.5 if s.get('hook') == 'intro' else 0.0)
            png = emoji_png(str(item.get('emoji', ''))[:4]) if w else None
            if not png:
                continue
            a, b = round(w['s'], 2), round(min(w['e'] + 1.0, new_dur), 2)
            inputs += ['-i', str(png)]
            graph.append(f"[{video}][{n_in}:v]overlay=(W-w)/2:{y}:enable='between(t,{a},{b})'[ve{shown}]")
            video = f've{shown}'
            events.append((a, 'pop'))
            n_in += 1
            shown += 1

    if s.get('progress_bar') == '1':
        graph.append(f'color=c=0xFFD400:s={W}x12:r={FPS}:d={new_dur}[pb]')
        graph.append(f"[{video}][pb]overlay=x='-w+w*t/{new_dur}':y=H-12[vp]")
        video = 'vp'

    # whoosh where the zoom jumps (spaced out), pop when an emoji appears
    if s.get('sfx') == '1' and not simple:
        to_new_piece, acc, last = [], 0.0, -9
        for a, b, z in pieces:
            to_new_piece.append((acc, z))
            acc += b - a
        prev_z = 1.0
        for t, z in to_new_piece:
            if z != prev_z and t - last >= 3 and 1 < t < new_dur - 2 and len([e for e in events if e[1] == 'whoosh']) < 5:
                events.append((round(t, 2), 'whoosh'))
                last = t
            prev_z = z
    mix = ['[ac]']
    if s.get('music') == '1' and not simple:
        track = music_file(campaign_id)
        if track:
            level = max(min(float(s.get('music_volume') or 14), 60), 1) / 100
            inputs += ['-stream_loop', '-1', '-i', str(track)]
            graph.append('[ac]asplit=2[voice][key]')
            graph.append(f'[{n_in}:a]aresample=44100,aformat=channel_layouts=stereo,atrim=0:{new_dur},asetpts=PTS-STARTPTS,volume={level:.2f},'
                         f'afade=t=in:d=0.6,afade=t=out:st={max(new_dur - 1.2, 0):.2f}:d=1.2[mus]')
            graph.append('[mus][key]sidechaincompress=threshold=0.02:ratio=9:attack=20:release=400[duck]')
            mix = ['[voice]', '[duck]']
            n_in += 1
    for i, (t, name) in enumerate(sorted(events)[:10]):
        inputs += ['-i', str(sfx(name))]
        gain = 0.35 if name == 'whoosh' else 0.5
        ms = int(t * 1000)
        graph.append(f'[{n_in}:a]aresample=44100,aformat=channel_layouts=stereo,volume={gain},adelay={ms}|{ms},apad=whole_dur={new_dur},atrim=0:{new_dur}[fx{i}]')
        mix.append(f'[fx{i}]')
        n_in += 1
    tail = ',loudnorm=I=-14:TP=-1.5:LRA=11,aresample=44100' if s.get('loudnorm') == '1' else ''
    if len(mix) > 1:
        graph.append(''.join(mix) + f'amix=inputs={len(mix)}:duration=first:dropout_transition=0,volume={len(mix)}{tail}[aout]')
    else:
        graph.append(f'[ac]anull{tail}[aout]')

    cmd = ['nice', '-n', '15', 'ffmpeg', '-y', '-v', 'error'] + inputs + [
        '-filter_complex', ';'.join(graph), '-map', f'[{video}]', '-map', '[aout]', '-t', f'{new_dur:.3f}',
        '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '18', '-r', str(FPS), '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '160k', '-ar', '44100', '-threads', THREADS, '-movflags', '+faststart', str(out)]
    try:
        sh(cmd, timeout=2400)
    finally:
        ass.unlink(missing_ok=True)
        for leftover in folder.glob('broll-*.mp4'):
            leftover.unlink(missing_ok=True)
    thumb = out.with_suffix('.jpg')
    sh(['ffmpeg', '-y', '-v', 'error', '-ss', '1', '-i', str(out), '-frames:v', '1', '-vf', 'scale=360:-2', str(thumb)])
    return thumb, {'duration': new_dur, 'cuts': len(segs) - 1, 'zooms': sum(1 for p in pieces if p[2] > 1)}


def has_audio(path):
    try:
        out = sh(['ffprobe', '-v', 'error', '-select_streams', 'a', '-show_entries', 'stream=index', '-of', 'csv=p=0', str(path)])
        return bool(out.strip())
    except JobError:
        return False
