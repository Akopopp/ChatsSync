"""The clipping agent without AI: scores moments with rules, writes titles and tags, reads campaign rules,
checks clips before posting and times posts for the target country."""
import bisect
import math
import re
import statistics
import time
from collections import Counter
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

STOP = set('''a about above after again against all am an and any are aren't as at be because been before being below between both
but by can can't cannot could couldn't did didn't do does doesn't doing don't down during each few for from further had hadn't has
hasn't have haven't having he he'd he'll he's her here here's hers herself him himself his how how's i i'd i'll i'm i've if in into is
isn't it it's its itself let's me more most mustn't my myself no nor not of off on once only or other ought our ours ourselves out
over own same shan't she she'd she'll she's should shouldn't so some such than that that's the their theirs them themselves then
there there's these they they'd they'll they're they've this those through to too under until up very was wasn't we we'd we'll
we're we've were weren't what what's when when's where where's which while who who's whom why why's with won't would wouldn't you
you'd you'll you're you've your yours yourself yourselves yeah yes okay ok oh like just really gonna wanna gotta um uh uhm erm hmm
know mean thing things stuff kind sort get got go going went come came say said says see saw make made take took want look lot
lots actually basically literally right well also even still back way one two three much many every something anything nothing
everything someone anyone everyone people guy guys good great little big new old first last time times day days year years
think thought tell told need needs let put give gave
best better worse worst crazy love loved hate tells telling knows knew learned learn ignore ignored changed change simple easy
hard real really true sure able whole entire pretty quite enough long short high low huge small large maybe probably
definitely exactly totally completely absolutely start started stop stopped keep kept try tried trying feel felt seem seems
call called work working worked happen happened happens talk talking talked lose afford nobody somebody everybody
cannot whatever whenever another doing done'''.split())
HOOK_WORDS = set('''secret secrets nobody never always mistake mistakes truth stop why how worst best biggest crazy insane shocking
real reason warning don't dont imagine listen money million millions free hack trick lesson learned regret wish problem fail failed
lost quit fired rich broke dangerous wrong hate love died dead illegal banned hidden exposed'''.split())
VALUE_MARKERS = ('the reason', "here's", 'here is', 'how to', 'the secret', 'the key', 'the trick', 'the problem', 'i learned',
                 'i realized', 'when i', 'so i', 'then i', 'because', 'the truth', 'step one', 'number one', 'first thing',
                 'the lesson', 'what happened', 'turns out', 'the difference', 'the mistake', 'you need to', 'you have to',
                 'if you want', 'most people', 'the best way', 'the only way', 'what i did', 'my advice')
ADS = ('sponsor', 'sponsored', 'promo code', 'discount code', 'link in the description', 'link below', 'use code', 'patreon',
       'brought to you by', 'nordvpn', 'squarespace', 'skillshare', 'audible', 'betterhelp', 'hellofresh', 'expressvpn',
       'manscaped', 'athletic greens', 'raid shadow legends', 'smash that like', 'hit subscribe', 'subscribe to the channel')
WEAK_START = {'and', 'but', 'so', 'um', 'uh', 'like', 'yeah', 'or', 'because', 'cause', "'cause", 'which', 'that'}
LAUGH = re.compile(r'\b(ha){2,}\b|\[laugh|\(laugh|\blol\b', re.I)
NUMBER = re.compile(r'\d|\b(one|two|three|four|five|six|seven|eight|nine|ten|hundred|thousand|million|billion)\b', re.I)
ENDS = re.compile(r'[.!?]["\')\]]*$')

# Country targeting: time zone for peak posting hours, Google Trends region, and main language.
COUNTRIES = {
    'US': ('United States', 'America/New_York', 'en'), 'GB': ('United Kingdom', 'Europe/London', 'en'),
    'CA': ('Canada', 'America/Toronto', 'en'), 'AU': ('Australia', 'Australia/Sydney', 'en'),
    'IN': ('India', 'Asia/Kolkata', 'hi'), 'PK': ('Pakistan', 'Asia/Karachi', 'ur'), 'AE': ('United Arab Emirates', 'Asia/Dubai', 'ar'),
    'SA': ('Saudi Arabia', 'Asia/Riyadh', 'ar'), 'DE': ('Germany', 'Europe/Berlin', 'de'), 'FR': ('France', 'Europe/Paris', 'fr'),
    'ES': ('Spain', 'Europe/Madrid', 'es'), 'IT': ('Italy', 'Europe/Rome', 'it'), 'NL': ('Netherlands', 'Europe/Amsterdam', 'nl'),
    'BR': ('Brazil', 'America/Sao_Paulo', 'pt'), 'MX': ('Mexico', 'America/Mexico_City', 'es'), 'PH': ('Philippines', 'Asia/Manila', 'en'),
    'NG': ('Nigeria', 'Africa/Lagos', 'en'), 'ID': ('Indonesia', 'Asia/Jakarta', 'id'), 'TR': ('Turkey', 'Europe/Istanbul', 'tr'),
    'BD': ('Bangladesh', 'Asia/Dhaka', 'bn'), 'EG': ('Egypt', 'Africa/Cairo', 'ar'), 'ZA': ('South Africa', 'Africa/Johannesburg', 'en'),
}
COUNTRY_ALIASES = {'US': ['usa', 'u.s.', 'america', 'american'], 'GB': ['uk', 'u.k.', 'britain', 'england', 'british'],
                   'AE': ['uae', 'emirates', 'dubai'], 'SA': ['ksa', 'saudi'], 'AU': ['aussie'], 'CA': ['canadian'],
                   'IN': ['indian'], 'PK': ['pakistani']}
# Local hours when Shorts and Reels audiences are most active.
PEAKS = {'weekday': [(12, 15), (18, 22)], 'weekend': [(10, 13), (18, 22)]}
LANGUAGES = {'': 'Detect automatically', 'en': 'English', 'hi': 'Hindi', 'ur': 'Urdu', 'ar': 'Arabic', 'es': 'Spanish',
             'pt': 'Portuguese', 'fr': 'French', 'de': 'German', 'it': 'Italian', 'nl': 'Dutch', 'tr': 'Turkish',
             'id': 'Indonesian', 'bn': 'Bengali'}


def _clean(word):
    return re.sub(r"[^\w']", '', word.lower())


# ---------- sentences and keywords ----------

def sentences(words):
    out, cur = [], []
    for w in words:
        if cur and (w['s'] - cur[-1]['e'] > 0.8 or ENDS.search(cur[-1]['w'])):
            out.append(cur)
            cur = []
        cur.append(w)
    return out + ([cur] if cur else [])


def keywords(clip_words, all_words=None, limit=10):
    """Words that stand out in this clip compared with the whole video (single words and two-word phrases)."""
    def terms(ws):
        clean = [_clean(w['w']) for w in ws]
        singles = [c for c in clean if len(c) >= 4 and c not in STOP and not c.isdigit()]
        pairs = [f'{a} {b}' for a, b in zip(clean, clean[1:]) if a not in STOP and b not in STOP and len(a) >= 3 and len(b) >= 3]
        return Counter(singles), Counter(pairs)
    s1, p1 = terms(clip_words)
    s_all, p_all = terms(all_words or clip_words)
    total = max(len(all_words or clip_words), 1)
    scored = {}
    for counter, every, bonus in ((s1, s_all, 1.0), (p1, p_all, 1.6)):
        for term, n in counter.items():
            if n < 2 and bonus == 1.6:
                continue
            rarity = math.log(1 + total / (every.get(term, n) + 1))
            scored[term] = n * rarity * bonus
    best = sorted(scored, key=lambda t: -scored[t])
    out = []
    for term in best:
        if any(term in o or o in term for o in out):
            continue
        out.append(term)
        if len(out) >= limit:
            break
    return out


# ---------- scoring ----------

def _loud_ratio(loud, start, end, base):
    if not loud or not base:
        return 1.0
    part = loud[int(start):max(int(math.ceil(end)), int(start) + 1)]
    return (sum(part) / len(part) / base) if part else 1.0


def _scale(value, low, high):
    return max(0.0, min(100.0, (value - low) / (high - low) * 100))


def score(words, start, end, ctx):
    """Viral score 0-100 for one stretch of the video, with the parts and plain-language notes behind it.
    ctx: loud (per-second loudness), base (median loudness), rate (average words a second), topic (main keywords),
    focus (campaign keywords), trends (trending searches), country (name)."""
    starts = ctx.get('starts') or [w['s'] for w in words]
    i0 = bisect.bisect_left(starts, start - 0.05)
    clip = [w for w in words[i0:bisect.bisect_right(starts, end + 0.3)] if w['e'] <= end + 0.3]
    if len(clip) < 5:
        return {'total': 0, 'parts': [], 'notes': ['Too little speech.']}
    before = words[i0 - 1] if i0 > 0 else None
    text = ' '.join(w['w'] for w in clip)
    low = ' ' + re.sub(r'\s+', ' ', re.sub(r"[^\w' ]", ' ', text.lower())) + ' '
    sents = sentences(clip)
    first = sents[0]
    first_text = ' '.join(w['w'] for w in first)
    opening = [_clean(w['w']) for w in clip if w['s'] < start + 3.5]
    notes = []

    hook = 30
    if '?' in first_text:
        hook += 20
        notes.append('Opens with a question.')
    if {'you', 'your', "you're"} & set(opening[:10]):
        hook += 10
    found = [w for w in dict.fromkeys(opening) if w in HOOK_WORDS]
    if found:
        hook += min(len(found) * 12, 30)
        notes.append(f'Strong opening words: {", ".join(found[:3])}.')
    if NUMBER.search(first_text):
        hook += 10
    if len(first) <= 12:
        hook += 10
    elif len(first) > 25:
        hook -= 15
    if opening and opening[0] in WEAK_START:
        hook -= 10
        notes.append(f'Starts with "{opening[0]}", a weak first word.')

    dur = max(end - start, 1)
    loud = _loud_ratio(ctx.get('loud'), start, end, ctx.get('base'))
    pace = len(clip) / dur / max(ctx.get('rate') or 2.5, 0.5)
    laughs = len(LAUGH.findall(text))
    energy = 0.6 * _scale(loud, 0.75, 1.35) + 0.4 * _scale(pace, 0.75, 1.3) + min(text.count('!') * 6 + laughs * 12, 25)
    if loud >= 1.15:
        notes.append(f'Louder and more energetic than the rest of the video (+{round((loud - 1) * 100)}%).')
    if laughs:
        notes.append('Has laughter.')

    markers = [m for m in VALUE_MARKERS if f' {m} ' in low]
    value = 30 + min(len(markers) * 15, 50) + (10 if NUMBER.search(text) else 0) + (10 if re.search(r'\b(i|my|me)\b', low) else 0)
    if markers:
        notes.append(f'Tells a story or gives a clear point ("{markers[0]}").')

    starts_clean = before is None or ENDS.search(before['w']) or clip[0]['s'] - before['e'] > 0.6
    complete = (50 if starts_clean else 20) + (50 if ENDS.search(clip[-1]['w']) else 10)
    if ENDS.search(clip[-1]['w']):
        notes.append('Ends on a finished sentence.')

    topic = ctx.get('topic') or []
    focus = ctx.get('focus') or []
    trends = ctx.get('trends') or []
    on_topic = sum(1 for t in topic if f' {t} ' in low)
    hits = [k for k in focus if f' {k.lower()} ' in low]
    trend_hits = [t for t in trends if len(t) > 3 and f' {t.lower()} ' in low]
    keys = 25 + min(on_topic * 10, 35) + min(len(hits) * 20, 40) + min(len(trend_hits) * 25, 50)
    if hits:
        notes.append(f'Mentions campaign topics: {", ".join(hits[:3])}.')
    if trend_hits:
        notes.append(f'Mentions {", ".join(trend_hits[:2])}, trending in {ctx.get("country") or "your country"} right now.')

    penalty = 0
    ads = [a for a in ADS if f' {a} ' in low]
    if ads:
        penalty += 40
        notes.append(f'Sounds like an ad or a call to subscribe ("{ads[0]}"). Campaigns usually don\'t pay for these.')
    fillers = sum(1 for w in clip if _clean(w['w']) in ('um', 'uh', 'uhm', 'erm'))
    if fillers / len(clip) > 0.05:
        penalty += 8
    pauses = sum(1 for a, b in zip(clip, clip[1:]) if b['s'] - a['e'] > 1.5)
    if pauses:
        penalty += min(pauses * 3, 15)
        notes.append(f'{pauses} long pause{"s" if pauses > 1 else ""}. Turn on jump cuts to remove {"them" if pauses > 1 else "it"}.')
    target = ctx.get('target')
    fit = 5 if target and abs(dur - target) <= target * 0.25 else 0

    parts = [('Hook', hook), ('Energy', energy), ('Value', value), ('Complete', complete), ('Keywords', keys)]
    parts = [{'name': n, 'value': int(round(max(0, min(100, v))))} for n, v in parts]
    weights = (0.30, 0.20, 0.20, 0.15, 0.15)
    total = sum(p['value'] * wt for p, wt in zip(parts, weights)) - penalty + fit
    return {'total': int(round(max(0, min(100, total)))), 'parts': parts, 'notes': notes[:5]}


def context(words, loud, settings, campaign=None, trends=None):
    rest = [x for x in (loud or []) if x > 0.002]
    dur = (words[-1]['e'] - words[0]['s']) if words else 1
    lo, hi = float(settings['clip_min']), float(settings['clip_max'])
    country = COUNTRIES.get((campaign or {}).get('country', ''), ('',))[0]
    return {'loud': loud, 'base': statistics.median(rest) if rest else 0, 'rate': len(words) / max(dur, 1),
            'topic': keywords(words, words, 20), 'focus': split_list((campaign or {}).get('keywords', '')),
            'trends': trends or [], 'country': country, 'target': (lo + hi) / 2, 'starts': [w['s'] for w in words]}


def candidates(words, min_s, max_s):
    """Stretches that start where a sentence starts and end where one ends, between min_s and max_s long."""
    sents = sentences(words)
    out = []
    for i, first in enumerate(sents):
        start = first[0]['s']
        for last in sents[i:]:
            dur = last[-1]['e'] - start
            if dur > max_s:
                break
            if dur >= min_s:
                out.append((round(max(start - 0.1, 0), 2), round(last[-1]['e'] + 0.25, 2)))
    return out


def pick(words, ctx, count, min_s, max_s, extra=()):
    """Best non-overlapping stretches. extra: (start, end, outside score 0-100) picks from AI to blend in."""
    scored = []
    for start, end in candidates(words, min_s, max_s):
        scored.append((score(words, start, end, ctx), start, end, None))
    for start, end, outside in extra:
        result = score(words, start, end, ctx)
        result['total'] = int(round(result['total'] * 0.5 + float(outside or 0) * 0.5))
        scored.append((result, start, end, 'ai'))
    scored.sort(key=lambda r: (-r[0]['total'], r[3] is None))
    chosen = []
    for result, start, end, source in scored:
        if any(start < c['end'] + 3 and end > c['start'] - 3 for c in chosen):
            continue
        chosen.append({'start': start, 'end': end, 'why': result, 'source': source})
        if len(chosen) >= count:
            break
    return chosen


# ---------- titles and tags without AI ----------

def _tidy(text):
    text = re.sub(r'\b(um+|uh+|uhm|erm)\b[,.]?\s*', '', text, flags=re.I)
    text = re.sub(r'^(and|but|so|like|yeah|okay|ok|well|now)\b[, ]*', '', text.strip(), flags=re.I)
    text = re.sub(r'\s+', ' ', text).strip(' ,')
    return text[:1].upper() + text[1:]


def _cut(text, limit):
    if len(text) <= limit:
        return text
    return text[:limit].rsplit(' ', 1)[0].rstrip(',;:-')


def write_text(words, start, end, all_words, campaign=None, trends=None):
    """Title, hook, description, tags and hashtags for a clip, written from its own words."""
    clip = [w for w in words if w['s'] >= start - 0.05 and w['e'] <= end + 0.3]
    sents = [' '.join(w['w'] for w in s) for s in sentences(clip)] or ['']

    def punch(sentence):
        low = [_clean(w) for w in sentence.split()]
        return (sum(1 for w in low if w in HOOK_WORDS) * 3 + ('?' in sentence) * 3 + bool(NUMBER.search(sentence))
                + ({'you', 'your'} & set(low) != set()) - (len(low) > 18) * 3 - (len(low) < 4) * 3)
    early = sents[:4]
    best = max(early, key=lambda s: (punch(s), -early.index(s)))
    title = _cut(_tidy(best).rstrip('.'), 70)
    short = re.sub(r"^(here is|here's|you know|i think|i mean|let me tell you|the thing is)\b[, ]*", '', _tidy(best), flags=re.I)
    short = _tidy(short).rstrip('.!?,')
    hook = _cut(short, 46).split()
    while len(hook) > 2 and _clean(hook[-1]) in STOP:
        hook.pop()
    hook = ' '.join(hook) if len(hook) > 1 else title[:40]
    description = _cut(' '.join(_tidy(s) for s in sents[:2]), 280)
    tags = keywords(clip, all_words, 10)
    tags += [k for k in split_list((campaign or {}).get('keywords', '')) if k.lower() not in [t.lower() for t in tags]]
    low = ' '.join(w['w'].lower() for w in clip)
    tags += [t for t in (trends or []) if t.lower() in low and t.lower() not in [x.lower() for x in tags]]
    hashtags = ['#' + ''.join(p.capitalize() for p in re.findall(r'\w+', t)) for t in tags[:4]]
    return {'title': title, 'hook': hook, 'description': description, 'tags': tags[:15], 'hashtags': hashtags}


# ---------- campaigns ----------

def split_list(value):
    return [v.strip() for v in re.split(r'[,\n]', value or '') if v.strip()]


PLATFORM_WORDS = {'youtube': r'youtube|\bshorts?\b|\byt\b', 'instagram': r'instagram|\breels?\b|\big\b', 'facebook': r'facebook|\bfb\b',
                  'tiktok': r'tiktok|tik tok', 'x': r'twitter|\bx\.com\b'}


def parse_rules(text):
    """Read a campaign's rules (pasted from its page) into settings. Returns (fields, findings)."""
    text = text or ''
    low = text.lower()
    fields, found = {}, []
    tags = list(dict.fromkeys(re.findall(r'(?<![\w&])#\w+', text)))
    if tags:
        fields['hashtags'] = ' '.join(tags[:15])
        found.append(f'Required hashtags: {" ".join(tags[:15])}')
    handles = list(dict.fromkeys(m for m in re.findall(r'(?<![\w.])@[A-Za-z0-9_.]{2,30}', text) if not m.endswith('.')))
    if handles:
        fields['mentions'] = ' '.join(handles[:6])
        found.append(f'Accounts to tag: {" ".join(handles[:6])}')
        if re.search(r'credit|tag|mention', low):
            fields['credit'] = f'Credit: {handles[0]}'
    sec = r'(?:s|sec|secs|second|seconds)\b'
    mins = r'(?:m|min|mins|minute|minutes)\b'

    def secs(n, unit):
        return float(n) * (60 if unit and re.match(r'm', unit) else 1)
    m = re.search(rf'(\d{{1,3}})\s*(?:-|–|to)\s*(\d{{1,3}})\s*({sec}|{mins})', low)
    if m:
        fields['min_len'], fields['max_len'] = secs(m.group(1), m.group(3)), secs(m.group(2), m.group(3))
    else:
        m = re.search(rf'(?:at least|minimum|min\.?|longer than|over)\s*(\d{{1,3}})\s*({sec}|{mins})', low)
        if m:
            fields['min_len'] = secs(m.group(1), m.group(2))
        m = re.search(rf'(?:at most|maximum|max\.?|under|shorter than|no longer than|up to|less than)\s*(\d{{1,3}})\s*({sec}|{mins})', low)
        if m:
            fields['max_len'] = secs(m.group(1), m.group(2))
    if 'min_len' in fields or 'max_len' in fields:
        found.append(f'Clip length: {int(fields.get("min_len", 0)) or "any"} to {int(fields.get("max_len", 0)) or "any"} seconds')
    plats = [p for p, rx in PLATFORM_WORDS.items() if re.search(rx, low)]
    if plats:
        fields['platforms'] = [p for p in plats if p in ('youtube', 'instagram', 'facebook')]
        names = {'youtube': 'YouTube', 'instagram': 'Instagram', 'facebook': 'Facebook', 'tiktok': 'TikTok', 'x': 'X'}
        found.append(f'Platforms named: {", ".join(names[p] for p in plats)}')
    phrases = [q for q in re.findall(r'["“]([^"”]{3,80})["”]', text)
               if re.search(r'(include|caption|description|title|say|write|add)', low)]
    if phrases:
        fields['phrases'] = '\n'.join(dict.fromkeys(phrases[:5]))
        found.append(f'Text that must be in the post: {"; ".join(phrases[:5])}')
    for code, (name, _, _) in COUNTRIES.items():
        aliases = [name.lower()] + COUNTRY_ALIASES.get(code, [])
        if any(re.search(rf'(?<![\w.]){re.escape(a)}(?![\w])', low) for a in aliases) or (code == 'US' and re.search(r'\bUS\b', text)):
            fields['country'] = code
            found.append(f'Target country: {name}')
            break
    if re.search(r'\benglish\b', low):
        fields['language'] = 'en'
    banned = re.findall(r'\bno (watermarks?|swearing|cursing|profanity|music|nsfw|politics|reuploads?|other creators?)\b', low)
    if banned:
        found.append(f'Not allowed: {", ".join(dict.fromkeys(banned))}')
        if any(b in ('swearing', 'cursing', 'profanity') for b in banned):
            fields['banned'] = 'fuck, shit, bitch, damn, ass'
    links = re.findall(r'https?://\S+', text)
    if links:
        fields['link'] = links[0].rstrip(').,')
    if not found:
        found.append('No clear rules found. Fill in the fields yourself.')
    return fields, found


def effective(settings, campaign):
    """User settings with the campaign's post rules on top."""
    if not campaign:
        return dict(settings)
    out = dict(settings)
    credit = campaign.get('credit', '')
    mentions = ' '.join(m for m in (campaign.get('mentions') or '').split() if m.lower() not in credit.lower())
    extra = [x for x in (credit, mentions, campaign.get('phrases', '')) if x.strip()]
    if extra:
        out['creator_credit'] = '\n'.join(extra)
    tags = (campaign.get('hashtags') or '').split()
    if tags:
        out['hashtags'] = ' '.join(dict.fromkeys(tags + settings['hashtags'].split()))
    if campaign.get('title_suffix'):
        out['title_suffix'] = campaign['title_suffix']
    out['campaign_name'] = campaign.get('name', '')
    if campaign.get('min_len'):
        out['clip_min'] = str(int(float(campaign['min_len'])))
    if campaign.get('max_len'):
        out['clip_max'] = str(int(min(float(campaign['max_len']), 180)))
    if float(out['clip_max']) - float(out['clip_min']) < 5:
        out['clip_max'] = str(int(float(out['clip_min']) + 5))
    if campaign.get('language'):
        out['language'] = campaign['language']
    if campaign.get('platforms'):
        for p in ('youtube', 'instagram', 'facebook'):
            out[f'post_{p}'] = '1' if p in campaign['platforms'] and settings.get(f'post_{p}') == '1' else '0'
    return out


PLATFORM_MAX = {'youtube': 180, 'instagram': 180, 'facebook': 90}


def checks(clip, text, campaign, length, targets):
    """Checks before posting: [(passed, must_pass, message)]."""
    campaign = campaign or {}
    body = f'{text["title"]}\n{text["body"]}'.lower()
    out = []
    lo, hi = float(campaign.get('min_len') or 0), float(campaign.get('max_len') or 0)
    if lo or hi:
        ok = (not lo or length >= lo - 0.5) and (not hi or length <= hi + 0.5)
        out.append((ok, True, f'Length {round(length)} s ' + ('fits' if ok else 'is outside') +
                     f' the campaign rule ({int(lo) or "any"} to {int(hi) or "any"} s).'))
    for p in targets:
        if length > PLATFORM_MAX[p] + 0.5:
            out.append((False, True, f'Too long for {p.capitalize()} ({PLATFORM_MAX[p]} s at most).'))
    for tag in (campaign.get('hashtags') or '').split():
        out.append((tag.lower() in body, True, f'Hashtag {tag} is in the post.' if tag.lower() in body else f'Hashtag {tag} is missing.'))
    for handle in (campaign.get('mentions') or '').split():
        ok = handle.lower() in body
        out.append((ok, True, f'Tags {handle}.' if ok else f'{handle} is not tagged.'))
    for phrase in split_list(campaign.get('phrases', '').replace('\n', ',')):
        ok = phrase.lower() in body
        out.append((ok, True, f'Includes "{phrase}".' if ok else f'Missing required text "{phrase}".'))
    banned = [b for b in split_list(campaign.get('banned', '')) if re.search(rf'\b{re.escape(b.lower())}\b', body)]
    if campaign.get('banned'):
        out.append((not banned, True, 'No banned words in the post.' if not banned else f'Banned words in the post: {", ".join(banned)}.'))
    out.append((True, False, 'Vertical 1080x1920 video with captions burned in.'))
    if len(text['title']) > 100:
        out.append((False, False, 'Title is longer than 100 characters, it will be shortened.'))
    return out


# ---------- country timing and trends ----------

def next_peak(after, country):
    """Earliest time at or after `after` (unix seconds) inside the country's busy hours."""
    if country not in COUNTRIES:
        return after
    zone = ZoneInfo(COUNTRIES[country][1])
    here = datetime.fromtimestamp(after, zone)
    for add in range(8):
        day = (here + timedelta(days=add)).date()
        for a, b in PEAKS['weekend' if day.weekday() >= 5 else 'weekday']:
            begin = datetime(day.year, day.month, day.day, a, tzinfo=zone).timestamp()
            stop = datetime(day.year, day.month, day.day, b, tzinfo=zone).timestamp()
            if stop > after + 600:
                return max(after, begin)
    return after


def peak_text(country):
    if country not in COUNTRIES:
        return ''
    return (f'Posts go out at busy times in {COUNTRIES[country][0]}: weekdays 12 to 3 pm and 6 to 10 pm, '
            f'weekends 10 am to 1 pm and 6 to 10 pm (their time).')


def trends(country, db=None):
    """Searches trending right now in a country (Google Trends feed), cached for 3 hours. Empty when unavailable."""
    if country not in COUNTRIES:
        return []
    key = f'trends_{country}'
    cached = db.stat(key) if db else None
    if cached and time.time() - cached.get('at', 0) < 3 * 3600:
        return cached.get('items', [])
    items = []
    try:
        import requests
        import xml.etree.ElementTree as ET
        res = requests.get(f'https://trends.google.com/trending/rss?geo={country}', timeout=15,
                           headers={'User-Agent': 'Mozilla/5.0'})
        if res.ok:
            items = [i.findtext('title', '').strip() for i in ET.fromstring(res.content).iter('item')][:25]
    except Exception as err:
        print('trends failed', country, err)
    if db:
        db.set_stat(key, {'at': time.time(), 'items': [i for i in items if i]})
    return [i for i in items if i]
