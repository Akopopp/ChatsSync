"""Everything the AI writes: which moments to clip, the post text, translations, channel profiles."""
import json
import os
import re
import time
from collections import Counter

import requests

from . import geo

MISTRAL_URL = 'https://api.mistral.ai/v1/chat/completions'
MODEL = os.environ.get('MISTRAL_MODEL', 'mistral-small-latest')
GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent'


class AIError(Exception):
    pass


def ai_ready():
    return bool(os.environ.get('GEMINI_API_KEY') or os.environ.get('MISTRAL_API_KEY'))


def gemini_models():
    # Tested on this key: 3.5-flash and the lite models answer in seconds; flash-latest and 3.8-flash often hang.
    return [m for m in (os.environ.get('GEMINI_MODEL'), 'gemini-3.5-flash', 'gemini-flash-lite-latest',
                        'gemini-3.5-flash-lite', 'gemini-flash-latest') if m]


_resting = {}  # model -> time until which it is skipped (busy, timing out or retired)


def _gemini(body, timeout=150):
    """Gemini call. A model that is busy, too slow or retired is skipped for a while and the next one is used."""
    key = os.environ['GEMINI_API_KEY']
    now = time.time()
    models = list(dict.fromkeys(gemini_models()))
    ready = [m for m in models if _resting.get(m, 0) < now] or models
    last = ''
    for model in ready:
        for attempt in range(2):
            try:
                res = requests.post(GEMINI_URL.format(model=model), json=body, timeout=timeout,
                                    headers={'x-goog-api-key': key})
            except requests.Timeout:
                last = f'{model}: no answer in {timeout} s'
                _resting[model] = time.time() + 1800
                break
            except requests.RequestException as err:
                last = f'{model}: {str(err)[:150]}'
                time.sleep(2)
                continue
            if res.status_code == 200:
                data = res.json()
                cands = data.get('candidates') or []
                if cands and (cands[0].get('content') or {}).get('parts'):
                    _resting.pop(model, None)
                    return cands[0]['content']
                last = f'{model}: empty answer ({(cands[0].get("finishReason") if cands else data.get("promptFeedback"))})'
                break
            try:
                msg = res.json().get('error', {}).get('message', res.text[:200])
            except ValueError:
                msg = res.text[:200]
            last = f'{model}: HTTP {res.status_code} {msg[:220]}'
            if res.status_code in (400, 401, 403) and 'API key' in msg:
                raise AIError('The Gemini API key is not valid. Check GEMINI_API_KEY.')
            if res.status_code == 404:
                _resting[model] = time.time() + 86400
                break
            if res.status_code == 429 or res.status_code >= 500:
                if attempt == 0:
                    time.sleep(3)
                    continue
                _resting[model] = time.time() + 600
            break
    raise AIError(last or 'AI did not answer.')


def _mistral(prompt, json_out=True):
    body = {'model': MODEL, 'temperature': 0.4, 'messages': [{'role': 'user', 'content': prompt}]}
    if json_out:
        body['response_format'] = {'type': 'json_object'}
    res = requests.post(MISTRAL_URL, json=body, timeout=180,
                        headers={'Authorization': f'Bearer {os.environ["MISTRAL_API_KEY"]}'})
    if res.status_code != 200:
        raise AIError(f'Mistral: HTTP {res.status_code} {res.text[:200]}')
    return res.json()['choices'][0]['message']['content']


def ask_json(prompt, temperature=0.4, images=None):
    """Send a prompt (and optional JPEG images), get parsed JSON back. Raises AIError with a readable reason."""
    if not ai_ready():
        raise AIError('No AI key is set (GEMINI_API_KEY).')
    if os.environ.get('GEMINI_API_KEY'):
        import base64
        parts = [{'text': prompt}] + [{'inlineData': {'mimeType': 'image/jpeg', 'data': base64.b64encode(img).decode()}}
                                      for img in images or []]
        content = _gemini({'contents': [{'role': 'user', 'parts': parts}],
                           'generationConfig': {'temperature': temperature, 'responseMimeType': 'application/json'}})
        text = ''.join(p.get('text', '') for p in content['parts'] if not p.get('thought'))
    elif images:
        raise AIError('Looking at video frames needs GEMINI_API_KEY.')
    else:
        text = _mistral(prompt)
    text = text.strip().removeprefix('```json').removeprefix('```').removesuffix('```').strip()
    try:
        return json.loads(text)
    except ValueError:
        match = re.search(r'\{.*\}', text, re.S)
        if match:
            try:
                return json.loads(match.group(0))
            except ValueError:
                pass
    raise AIError('AI sent an answer that could not be read.')


def chat_with_tools(contents, system, tools):
    """One Gemini turn with function calling (used by the helper). Returns the model's content."""
    if not os.environ.get('GEMINI_API_KEY'):
        raise AIError('The AI helper needs GEMINI_API_KEY.')
    return _gemini({'systemInstruction': {'parts': [{'text': system}]}, 'contents': contents,
                    'tools': [{'functionDeclarations': tools}], 'generationConfig': {'temperature': 0.3}}, timeout=60)


# ---------- choosing the moments ----------

PICK_PROMPT = '''You pick the best short clips from a long video transcript for YouTube Shorts, TikTok and Reels.
The creator pays for clips that get views, so each clip must make sense on its own and hook viewers in the first 2 seconds.
{brief}Pick moments that are funny, surprising, emotional, controversial, very skillful, or give one clear valuable idea or story.
For sports or gaming, pick the big plays and the commentary peaks.
Rules:
- Each clip is between {min_s} and {max_s} seconds long.
- Start where a sentence starts and end where a thought ends (never mid-sentence).
- Clips must not overlap.
- Return up to {count} clips, best first.
- "hook": 2 to 6 words shown on screen, in {lang}.
- "score": 0-100, how likely it is to go viral.
Reply with JSON only: {{"clips": [{{"start": 12.3, "end": 55.0, "hook": "...", "reason": "...", "score": 80}}]}}

Transcript (each line starts with the time in seconds):
{transcript}'''


def lines_from_words(words, gap=0.8, max_len=160):
    lines, cur = [], []
    for w in words:
        text = ' '.join(x['w'] for x in cur)
        if cur and (w['s'] - cur[-1]['e'] > gap or len(text) > max_len or re.search(r'[.!?]$', cur[-1]['w'])):
            lines.append(cur)
            cur = []
        cur.append(w)
    if cur:
        lines.append(cur)
    return lines


def _brief(brief):
    brief = (brief or '').strip()
    return f'The campaign owner says (follow this): """{brief[:2500]}"""\n' if brief else ''


def heuristic(lines, s, count):
    min_s, max_s = float(s['clip_min']), float(s['clip_max'])
    target = (min_s + max_s) / 2
    picks = []
    for i, first in enumerate(lines):
        words, j = [], i
        while j < len(lines) and lines[j][-1]['e'] - first[0]['s'] <= max_s:
            words += lines[j]
            j += 1
        if not words:
            continue
        dur = words[-1]['e'] - first[0]['s']
        if dur < min_s:
            continue
        text = ' '.join(w['w'] for w in words)
        score = len(words) / dur * 10 + text.count('!') * 4 + text.count('?') * 3 - abs(dur - target) / 3
        picks.append({'start': first[0]['s'], 'end': words[-1]['e'], 'score': score, 'hook': '', 'reason': 'Fast, dense talking'})
    picks.sort(key=lambda p: -p['score'])
    return picks[: count * 4]


def clean_list(value, limit, hashtag):
    if isinstance(value, str):
        value = re.split(r'[,\n]', value)
    out = []
    for item in value or []:
        item = re.sub(r'\s+', ' ', str(item)).strip().strip('#').strip()
        if not item:
            continue
        item = '#' + re.sub(r'[^\w]', '', item) if hashtag else item[:60]
        if len(item) > 1 and item.lower() not in [o.lower() for o in out]:
            out.append(item)
    return out[:limit]


def snap(clip, words, min_s, max_s):
    start = next((w['s'] for w in words if w['s'] >= float(clip['start']) - 0.4), None)
    if start is None:
        return None
    end_words = [w for w in words if w['e'] <= float(clip['end']) + 0.4 and w['s'] >= start]
    if not end_words:
        return None
    end = end_words[-1]['e'] + 0.25
    if end - start > max_s + 3:
        end = max(w['e'] for w in end_words if w['e'] - start <= max_s) + 0.25
    if end - start < min_s - 3:
        return None
    return round(max(start - 0.1, 0), 2), round(end, 2)


def pick_clips(words, s, brief=''):
    """Best moments. Returns (clips, used_ai, problem) where problem says why the AI was not used."""
    count = int(s['clips_per_video'])
    min_s, max_s = float(s['clip_min']), float(s['clip_max'])
    lines = lines_from_words(words)
    transcript = '\n'.join(f'[{ln[0]["s"]:.1f}] ' + ' '.join(w['w'] for w in ln) for ln in lines)
    raw, problem = None, ''
    if ai_ready():
        try:
            data = ask_json(PICK_PROMPT.format(min_s=min_s, max_s=max_s, count=count, transcript=transcript[:400000],
                                               brief=_brief(brief), lang=geo.lang_name(s.get('target_language'))), 0.3)
            raw = data.get('clips', []) if isinstance(data, dict) else data
        except AIError as err:
            problem = str(err)
        except Exception as err:  # never let the AI stop the clips
            problem = f'AI error: {err}'
    else:
        problem = 'No AI key is set.'
    used_ai = bool(raw)
    if not raw:
        raw = heuristic(lines, s, count)
    chosen = []
    for clip in sorted(raw, key=lambda c: -float(c.get('score', 0) or 0)):
        try:
            span = snap(clip, words, min_s, max_s)
        except (TypeError, ValueError):
            continue
        if not span or any(span[0] < c['end'] and span[1] > c['start'] for c in chosen):
            continue
        chosen.append({'start': span[0], 'end': span[1], 'title': '', 'hook': (clip.get('hook') or '').strip()[:60],
                       'reason': (clip.get('reason') or '')[:300], 'score': float(clip.get('score', 0) or 0), 'meta': {}})
        if len(chosen) >= count:
            break
    return chosen, used_ai, problem


# ---------- the post text, captions and edit plan for each clip ----------

def phrases(words, max_words=7):
    """Caption phrases (for translated captions): split at pauses, sentence ends or every few words."""
    out, cur = [], []
    for w in words:
        if cur and (len(cur) >= max_words or w['s'] - cur[-1]['e'] > 0.45 or re.search(r'[.!?,;:]$', cur[-1]['w'])):
            out.append(cur)
            cur = []
        cur.append(w)
    if cur:
        out.append(cur)
    return out


WRITE_PROMPT = '''You are a YouTube Shorts growth expert. Write the post and the edit plan for each clip below.
{brief}Audience: viewers in {country}. Write every title, hook, description, tag and comment in {lang}, using {style}.
Use the exact words people in {country} type into YouTube search for this topic.
{examples}For every clip return:
- "titles": 3 different titles under 70 characters. Curiosity and emotion, specific, true to the clip (no clickbait lies), no hashtags, no emoji at the start.
- "best": the index (0, 1 or 2) of the title most likely to get clicks.
- "hook": 2 to 6 words shown big on screen in the first seconds.
- "description": 70 to 150 words. Line 1: one strong sentence with the main search keyword. Then a short paragraph about what happens and why it matters. Then one line asking viewers a question. Plain text: no hashtags, no links, no "subscribe" (added separately).
- "tags": 15 to 25 search keywords and phrases, most specific first, mix short and long-tail, no # sign.
- "hashtags": 3 to 5 hashtags, the most relevant niche one first. Do not include #shorts.
- "first_comment": one short question or hot take that makes people reply.
- "keywords": 3 to 8 important single words copied exactly from the {kw_source} (shown in color in the captions).
- "emojis": up to 4 items {{"word": a word copied exactly from the clip text, "emoji": one fitting emoji}}.
- "zoom_words": 2 to 4 words copied exactly from the clip text where the speaker stresses something.
- "broll": up to 2 items {{"word": a word copied exactly from the clip text, "query": 2 to 4 English words to search stock video}} only for concrete visual things.
{extra}Reply with JSON only: {{"clips": [{{"id": 1, "titles": [], "best": 0, "hook": "", "description": "", "tags": [], "hashtags": [], "first_comment": "", "keywords": [], "emojis": [], "zoom_words": [], "broll": []{extra_keys}}}]}}

{clips}'''


def _examples(top_titles):
    if not top_titles:
        return ''
    lines = '\n'.join(f'- {t}' for t in top_titles[:6])
    return f'These titles already did well for this campaign. Learn from their style (do not copy them):\n{lines}\n'


def write_texts(items, s, brief='', spoken='', top_titles=None):
    """items: [{'id', 'words'}]. Returns ({id: meta}, problem). meta holds the post text and the edit plan."""
    if not items:
        return {}, ''
    if not ai_ready():
        return {it['id']: fallback_text(it['words'], s) for it in items}, 'No AI key is set.'
    target = s.get('target_language') or 'en'
    spoken = (spoken or s.get('spoken_language') or '').split('-')[0]
    translate = s.get('translate_captions') == '1' and spoken and spoken != target.split('-')[0]
    loc_langs = [x.strip() for x in s.get('localize_langs', '').split(',') if x.strip() and x.strip() != target] \
        if s.get('localize') == '1' else []
    code = s.get('country', 'US')
    style = geo.COUNTRIES.get(code, geo.COUNTRIES['WW'])[2]
    extra, extra_keys = '', ''
    if translate:
        extra += (f'- "subs": an object mapping every phrase number to a natural, short {geo.lang_name(target)} '
                  f'subtitle for that phrase (keep the meaning, keep it short).\n')
        extra_keys += ', "subs": {"0": ""}'
    if loc_langs:
        extra += ('- "loc": an object mapping each of these language codes ' + ', '.join(loc_langs) +
                  ' to {"title": "", "description": ""} with the best title and the description translated.\n')
        extra_keys += ', "loc": {}'
    out, problem = {}, ''
    for start in range(0, len(items), 4):
        batch = items[start:start + 4]
        blocks = []
        for it in batch:
            text = ' '.join(w['w'] for w in it['words'])
            block = f'### Clip {it["id"]}\nText: {text[:6000]}'
            if translate:
                ph = phrases(it['words'])
                it['phrases'] = ph
                block += '\nPhrases:\n' + '\n'.join(f'{i}: ' + ' '.join(w['w'] for w in p) for i, p in enumerate(ph))
            blocks.append(block)
        prompt = WRITE_PROMPT.format(
            brief=_brief(brief), country=geo.country_name(code), lang=geo.lang_name(target), style=style,
            examples=_examples(top_titles), extra=extra, extra_keys=extra_keys, clips='\n\n'.join(blocks),
            kw_source=f'{geo.lang_name(target)} subtitles' if translate else 'clip text')
        try:
            data = ask_json(prompt, 0.6)
            got = {str(c.get('id')): c for c in (data.get('clips', []) if isinstance(data, dict) else data)}
        except Exception as err:
            problem = str(err)
            got = {}
        for it in batch:
            c = got.get(str(it['id']))
            out[it['id']] = _clean_meta(c, it, s, translate) if c else fallback_text(it['words'], s)
    return out, problem


def _clean_meta(c, it, s, translate):
    titles = [re.sub(r'\s+', ' ', str(t)).strip().strip('"')[:100] for t in (c.get('titles') or []) if str(t).strip()]
    try:
        best = min(max(int(c.get('best', 0)), 0), len(titles) - 1) if titles else 0
    except (TypeError, ValueError):
        best = 0
    if titles and s.get('best_title') != '1':
        best = 0
    meta = {
        'ai': True, 'titles': titles[:3], 'title': titles[best] if titles else '',
        'hook': str(c.get('hook') or '').strip()[:60],
        'description': str(c.get('description') or '').strip()[:3000],
        'tags': clean_list(c.get('tags'), 30, hashtag=False),
        'hashtags': [h for h in clean_list(c.get('hashtags'), 6, hashtag=True) if h.lower() != '#shorts'],
        'first_comment': str(c.get('first_comment') or '').strip()[:500],
        'keywords': [str(k).strip() for k in (c.get('keywords') or []) if str(k).strip()][:8],
        'emojis': [e for e in (c.get('emojis') or []) if isinstance(e, dict) and e.get('word') and e.get('emoji')][:4],
        'zoom_words': [str(k).strip() for k in (c.get('zoom_words') or []) if str(k).strip()][:4],
        'broll': [b for b in (c.get('broll') or []) if isinstance(b, dict) and b.get('word') and b.get('query')][:2],
    }
    if translate and isinstance(c.get('subs'), dict) and it.get('phrases'):
        subs = []
        for i, p in enumerate(it['phrases']):
            txt = str(c['subs'].get(str(i)) or c['subs'].get(i) or '').strip()
            if txt:
                subs.append({'s': p[0]['s'], 'e': p[-1]['e'], 't': txt[:120]})
        if len(subs) >= len(it['phrases']) * 0.6:
            meta['subs'] = subs
    if isinstance(c.get('loc'), dict):
        meta['loc'] = {k: {'title': str(v.get('title', ''))[:100], 'description': str(v.get('description', ''))[:3000]}
                       for k, v in c['loc'].items() if isinstance(v, dict) and v.get('title')}
    return meta


STOP = set('the a an and or but so to of in on at for with is are was were be been it this that i you he she we they my your '
           'me him her them our their not no yes do did does have has had just like what when where who how why if then '
           'there here very really can will would could should get got go going all one about from up out into over'.split())


def fallback_text(words, s):
    """Post text without AI: built from what is said in the clip."""
    text = ' '.join(w['w'] for w in words).strip()
    sentences = re.split(r'(?<=[.!?])\s+', text)
    title = sentences[0][:90] if sentences else text[:90]
    common = [w for w, _ in Counter(re.sub(r'[^\w\s]', '', text.lower()).split()).most_common(40)
              if w not in STOP and len(w) > 3][:12]
    return {'ai': False, 'titles': [title], 'title': title, 'hook': '', 'description': ' '.join(sentences[:3])[:600],
            'tags': common, 'hashtags': ['#' + w for w in common[:3]], 'first_comment': '', 'keywords': common[:4],
            'emojis': [], 'zoom_words': [], 'broll': []}


# ---------- channel profile ----------

CHANNEL_PROMPT = '''You are a YouTube channel growth expert. Write the profile for a Shorts channel.
Channel name: {name}
{brief}Audience: viewers in {country}. Write in {lang} using {style}.
Return JSON only:
{{"description": "a channel description of 600 to 900 characters: what the channel posts, why people should subscribe, how often new clips come, the main search keywords used naturally. No links.",
  "keywords": ["10 to 15 channel keywords or short phrases"],
  "tagline": "a banner tagline under 40 characters",
  "playlist": "a playlist name under 50 characters",
  "colors": ["#hex main color", "#hex second color"]}}'''


def channel_profile(name, s, brief=''):
    code = s.get('country', 'US')
    data = ask_json(CHANNEL_PROMPT.format(name=name, brief=_brief(brief), country=geo.country_name(code),
                                          lang=geo.lang_name(s.get('target_language')),
                                          style=geo.COUNTRIES.get(code, geo.COUNTRIES['WW'])[2]), 0.7)
    kws = clean_list(data.get('keywords'), 15, hashtag=False)
    return {'description': str(data.get('description', '')).strip()[:1000],
            'keywords': ' '.join(f'"{k}"' if ' ' in k else k for k in kws)[:480],
            'tagline': str(data.get('tagline', '')).strip()[:40], 'playlist': str(data.get('playlist', '')).strip()[:60],
            'colors': [c for c in (data.get('colors') or []) if re.fullmatch(r'#[0-9a-fA-F]{6}', str(c))][:2]}


# ---------- looking at the video: layout and a check of the finished edit ----------

LAYOUT_PROMPT = '''You are a professional Shorts editor. A horizontal video clip must become a vertical 9:16 Short (1080x1920).
The images are frames from the clip, in order. {brief}Face finder says: a face is seen in {faces:.0%} of frames, main face
width is {size:.0%} of the frame, two people too far apart for one crop in {apart:.0%} of frames.
Pick the layout that looks best and loses nothing important:
- "crop": a 9:16 window (about 32% of the frame width) that follows the main subject. Best when one person or one
  subject fills the frame: talking head, interview close-up, one player, one object.
- "full": the whole horizontal picture in the middle of the vertical frame, blurred background, title above and
  captions below. Best for gameplay, sports, wide shots, two or more people talking, screens, slides, text on screen,
  or anything where a crop would cut off what matters.
- "split": the streamer's webcam box on top, a tall crop of the gameplay below it (about 47% of the frame width).
  Best for a streamer playing a game with a clear webcam overlay, when the action sits in the middle of the screen
  and the streamer's face and reaction matter. Not for wide cinematic shots or action spread across the whole screen.
Also give:
- "focus": for every frame, where the most important subject is across the width (0 = left edge, 1 = right edge).
  For "split" this is the gameplay action, not the webcam.
- "cam": for "split" only, the webcam overlay box as [x, y, width, height], shares of the frame (0 to 1), tight
  around the webcam picture.
- "captions": the best caption spot that covers nothing important. For "full": "below" or "above" the picture.
  For "crop": "low", "middle" or "high" (avoid faces, scoreboards, game HUD and any text already on screen).
  For "split": "seam" (between webcam and gameplay) or "low".
- "burned_subtitles": true only if the video already shows spoken-word subtitles in the picture.
- "reason": one short sentence a user understands.
Reply with JSON only: {{"layout": "full", "focus": [0.5], "cam": [], "captions": "below", "burned_subtitles": false, "reason": ""}}'''


def layout_advice(images, stats, brief=''):
    data = ask_json(LAYOUT_PROMPT.format(brief=_brief(brief), faces=stats.get('faces', 0), size=stats.get('size', 0),
                                         apart=stats.get('apart', 0)), 0.2, images=images)
    layout = data.get('layout') if data.get('layout') in ('crop', 'full', 'split') else 'full'
    cam = []
    try:
        x, y, w, h = [min(max(float(v), 0.0), 1.0) for v in data.get('cam') or []]
        pad = 0.01  # a little room so a slightly tight box never cuts the face
        x, y = max(x - pad, 0.0), max(y - pad, 0.0)
        cam = [x, y, min(w + 2 * pad, 1 - x), min(h + 2 * pad, 1 - y)]
    except (TypeError, ValueError):
        pass
    if layout == 'split' and (len(cam) != 4 or cam[2] < 0.08 or cam[3] < 0.08 or cam[2] * cam[3] > 0.4):
        layout = 'full'
    focus = []
    for i in range(len(images)):
        try:
            focus.append(min(max(float((data.get('focus') or [])[i]), 0.0), 1.0))
        except (IndexError, TypeError, ValueError):
            focus.append(focus[-1] if focus else 0.5)
    return {'layout': layout, 'focus': focus, 'captions': str(data.get('captions', '')).lower(),
            'burned_subtitles': bool(data.get('burned_subtitles')), 'reason': str(data.get('reason', ''))[:200], 'cam': cam}


REVIEW_PROMPT = '''You are checking a finished vertical Short before it is posted. The images are frames from it.
Layout used: {layout} ({what}); captions are {captions}. {brief}
Look for real problems only: captions or titles covering faces, the main action, a scoreboard or text already in the
video; the main subject cut off or out of the frame; an empty or useless picture; text running off the screen.
Also check safety: "unsafe" is true if any frame shows nudity, underwear or lingerie, sexual content, a strip
club, drug use or gambling.
Reply with JSON only: {{"ok": true, "fix": "none", "unsafe": false, "reason": "one short sentence"}}
"fix" is one of: "none", "switch_to_full", "switch_to_crop", "captions_below", "captions_above", "captions_low",
"captions_middle", "captions_high".'''


def review_edit(images, plan, brief=''):
    if not images:
        return None
    what = {'full': 'whole picture in the middle, text above and below',
            'split': "streamer's webcam on top, gameplay crop below"}.get(plan.get('layout'), '9:16 crop of the subject')
    data = ask_json(REVIEW_PROMPT.format(layout=plan.get('layout'), what=what, captions=plan.get('captions'),
                                         brief=_brief(brief)), 0.1, images=images)
    fix = str(data.get('fix', 'none'))
    ok = bool(data.get('ok', True)) or fix == 'none'
    return {'ok': ok, 'fix': fix, 'reason': str(data.get('reason', ''))[:200], 'unsafe': data.get('unsafe') is True}
