import json
import os
import re

import requests

MISTRAL_URL = 'https://api.mistral.ai/v1/chat/completions'
MODEL = os.environ.get('MISTRAL_MODEL', 'mistral-small-latest')

PROMPT = '''You pick the best short clips from a long video transcript for YouTube Shorts.
The creator pays for clips that get views, so each clip must stand on its own and hook viewers in the first 2 seconds.
Pick moments that are funny, surprising, emotional, controversial, or give one clear valuable idea or story.
Rules:
- Each clip is between {min_s} and {max_s} seconds long.
- Start where a sentence starts and end where a thought ends (never mid-sentence).
- Clips must not overlap.
- Return up to {count} clips, best first.
- "title": a punchy YouTube Shorts title under 70 characters, no hashtags, no clickbait lies, in the same language as the transcript.
- "hook": 2 to 6 words shown on screen, in the same language as the transcript.
- "description": 2 or 3 short sentences for the post, naturally using the search keywords people would type to find this moment.
- "tags": 8 to 15 search keywords or short phrases (no # sign), most specific first.
- "hashtags": 3 to 6 relevant hashtags (with # sign), no spaces inside a hashtag.
Reply with JSON only: {{"clips": [{{"start": 12.3, "end": 55.0, "title": "...", "hook": "...", "description": "...", "tags": ["..."], "hashtags": ["#..."], "reason": "...", "score": 0-100}}]}}

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


GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent'


def ai_ready():
    return bool(os.environ.get('GEMINI_API_KEY') or os.environ.get('MISTRAL_API_KEY'))


def _ask_gemini(prompt):
    key = os.environ['GEMINI_API_KEY']
    body = {'contents': [{'role': 'user', 'parts': [{'text': prompt}]}],
            'generationConfig': {'temperature': 0.3, 'responseMimeType': 'application/json'}}
    models = [m for m in (os.environ.get('GEMINI_MODEL'), 'gemini-flash-latest', 'gemini-2.5-flash') if m]
    last = None
    for model in models:
        res = requests.post(GEMINI_URL.format(model=model), json=body, timeout=240, headers={'x-goog-api-key': key})
        if res.status_code == 404:  # model name retired: try the next one
            last = res
            continue
        res.raise_for_status()
        parts = res.json()['candidates'][0]['content']['parts']
        return ''.join(p.get('text', '') for p in parts)
    last.raise_for_status()


def _ask_mistral(prompt):
    body = {'model': MODEL, 'temperature': 0.3, 'response_format': {'type': 'json_object'},
            'messages': [{'role': 'user', 'content': prompt}]}
    res = requests.post(MISTRAL_URL, json=body, timeout=180,
                        headers={'Authorization': f'Bearer {os.environ["MISTRAL_API_KEY"]}'})
    res.raise_for_status()
    return res.json()['choices'][0]['message']['content']


def ask_ai(transcript, settings, count):
    """Clip picks from Gemini (free key) or Mistral, whichever key is set. None when no key."""
    if not ai_ready():
        return None
    prompt = PROMPT.format(min_s=settings['clip_min'], max_s=settings['clip_max'], count=count, transcript=transcript)
    text = _ask_gemini(prompt) if os.environ.get('GEMINI_API_KEY') else _ask_mistral(prompt)
    text = text.strip().removeprefix('```json').removeprefix('```').removesuffix('```')
    data = json.loads(text)
    return data.get('clips', []) if isinstance(data, dict) else data


def heuristic(lines, settings, count):
    min_s, max_s = float(settings['clip_min']), float(settings['clip_max'])
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
        picks.append({'start': first[0]['s'], 'end': words[-1]['e'], 'score': score,
                      'title': ' '.join(w['w'] for w in first)[:70], 'hook': '', 'reason': 'Fast, dense talking'})
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
        item = '#' + re.sub(r'[^\w]', '', item) if hashtag else item[:40]
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


def pick_clips(words, settings):
    count = int(settings['clips_per_video'])
    min_s, max_s = float(settings['clip_min']), float(settings['clip_max'])
    lines = lines_from_words(words)
    transcript = '\n'.join(f'[{ln[0]["s"]:.1f}] ' + ' '.join(w['w'] for w in ln) for ln in lines)
    raw, used_ai = None, False
    try:
        raw = ask_ai(transcript[:400000], settings, count)
        used_ai = raw is not None
    except Exception as err:  # fall back to the heuristic when the AI call fails
        print('AI pick failed:', err)
    if not raw:
        raw = heuristic(lines, settings, count)
    chosen = []
    for clip in sorted(raw, key=lambda c: -float(c.get('score', 0))):
        span = snap(clip, words, min_s, max_s)
        if not span or any(span[0] < c['end'] and span[1] > c['start'] for c in chosen):
            continue
        chosen.append({'start': span[0], 'end': span[1], 'title': (clip.get('title') or '').strip()[:90],
                       'hook': (clip.get('hook') or '').strip()[:60], 'reason': (clip.get('reason') or '')[:300],
                       'score': float(clip.get('score', 0)), 'meta': {
                           'description': str(clip.get('description') or '').strip()[:1500],
                           'tags': clean_list(clip.get('tags'), 15, hashtag=False),
                           'hashtags': clean_list(clip.get('hashtags'), 6, hashtag=True)}})
        if len(chosen) >= count:
            break
    return chosen, used_ai
