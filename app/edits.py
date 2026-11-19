"""How a clip is edited (trim, captions, layout, effects) and the helpers that turn an edit into cuts and timings."""
import difflib
import json
import re

STYLES = {'bold': 'Bold, word by word', 'pop': 'One big word at a time', 'boxed': 'Boxed', 'clean': 'Clean subtitles',
          'off': 'No captions'}
COLORS = {'yellow': 'FFE500', 'green': '39FF14', 'cyan': '38D9F5', 'pink': 'FF3EA5', 'orange': 'FF8A00', 'white': 'FFFFFF'}
POSITIONS = {'bottom': 'Bottom', 'middle': 'Middle', 'top': 'Top'}
LAYOUTS = {'auto': 'Automatic', 'face': 'Follow the speaker', 'split': 'Two speakers, one above the other',
           'fit': 'Full frame with blurred background'}
HOOK_SHOW = {'full': 'Whole clip', 'start': 'First 3 seconds', 'off': 'Hidden'}
FILLERS = {'um', 'umm', 'uh', 'uhh', 'uhm', 'erm', 'er', 'ah', 'hmm', 'mm', 'mhm'}
FLAGS = ('jumpcuts', 'fillers', 'zoom', 'emoji', 'progress', 'uppercase')

# Word -> emoji (Noto images in app/emoji). Matched on the start of a word, so "money" also hits "moneys".
EMOJI = {
    '1f4b0': 'money cash dollar dollars rich paid salary million millions billion billions profit',
    '1f525': 'fire hot lit viral',
    '2764': 'love loved loving heart',
    '1f602': 'laugh laughing funny lol haha hilarious joke',
    '1f92f': 'crazy insane mind unbelievable shocking shocked wild',
    '1f9e0': 'brain smart genius intelligent',
    '1f4a1': 'idea ideas tip tips trick hack',
    '1f3c6': 'win won winner winning champion best',
    '274c': 'mistake mistakes wrong fail failed failure',
    '2705': 'correct exactly',
    '23f0': 'time clock hours minutes deadline',
    '1f4bc': 'business job company boss career office',
    '1f4f1': 'phone iphone app apps',
    '1f697': 'car cars driving',
    '1f354': 'food eat eating hungry burger',
    '1f622': 'sad cry crying tears',
    '1f631': 'scared scary fear afraid terrifying',
    '1f621': 'angry mad hate furious',
    '1f92b': 'secret secrets hidden nobody',
    '1f440': 'look watch eyes',
    '1f30d': 'world global planet earth',
    '1f4c8': 'growth grow growing increase double',
    '1f4c9': 'crash dropped decline',
    '1f680': 'rocket launch fast faster speed',
    '1f4aa': 'strong strength muscle gym workout',
    '1f6d1': 'stop quit',
    '1f451': 'king queen boss',
    '1f3ae': 'game games gaming gamer',
    '1f3b5': 'music song songs sing',
    '1f381': 'free gift bonus',
    '1f3af': 'goal goals target focus',
    '1f389': 'party celebrate congratulations',
    '1f60e': 'cool confident',
    '1f62e': 'wow amazing incredible',
    '1f480': 'dead died death dying',
    '1f4da': 'book books read reading learn learning study',
    '1f393': 'school college university degree',
    '1f3e0': 'house home',
    '1f476': 'baby kids children child',
    '1f436': 'dog dogs puppy',
    '1f431': 'cat cats kitten',
    '2615': 'coffee',
    '1f634': 'sleep sleeping tired',
    '2708': 'travel flight plane airport',
    '1f3a5': 'video videos camera youtube film',
    '1f914': 'think thinking wonder',
    '1f4af': 'hundred percent perfect',
    '1f64f': 'thank thanks grateful pray',
    '1f91d': 'deal partner partnership agree',
    '26a0': 'warning careful danger dangerous',
}
_EMOJI_WORDS = {w: code for code, words in EMOJI.items() for w in words.split()}


def defaults(clip, settings):
    hook_show = settings.get('hook_show', 'full') if settings.get('show_title', '1') == '1' else 'off'
    return {
        'start': clip['start'], 'end': clip['end'], 'hook': clip.get('hook') or '', 'hook_show': hook_show,
        'style': settings.get('caption_style', 'bold'), 'color': settings.get('caption_color', 'yellow'),
        'position': settings.get('caption_position', 'bottom'), 'uppercase': settings.get('caption_uppercase') == '1',
        'layout': settings.get('crop_mode', 'auto'),
        'jumpcuts': settings.get('fx_jumpcuts', '0') == '1', 'fillers': settings.get('fx_fillers', '1') == '1',
        'zoom': settings.get('fx_zoom', '1') == '1', 'emoji': settings.get('fx_emoji', '1') == '1',
        'progress': settings.get('fx_progress', '1') == '1',
        'music': settings.get('music_default', ''), 'music_volume': int(settings.get('music_volume') or 12),
        'cuts': [], 'words': None, 'words_range': None,
    }


def meta_of(clip):
    return clip['meta'] if isinstance(clip['meta'], dict) else json.loads(clip['meta'] or '{}')


def get(clip, settings):
    return {**defaults(clip, settings), **meta_of(clip).get('edit', {})}


def caption_words(all_words, edit):
    """Caption words (absolute times) inside the trimmed clip: the user's edited text where there is one."""
    words = all_words
    if edit.get('words'):
        lo, hi = edit['words_range']
        words = sorted([w for w in all_words if w['e'] <= lo or w['s'] >= hi] + edit['words'], key=lambda w: w['s'])
    return [w for w in words if w['s'] >= edit['start'] - 0.05 and w['e'] <= edit['end'] + 0.3]


def realign(old, text):
    """Put new caption text on the old word timings: unchanged words keep their time, changed words share it."""
    new = text.split()
    if not old:
        return []
    ops = difflib.SequenceMatcher(a=[w['w'].lower() for w in old], b=[t.lower() for t in new], autojunk=False)
    out = []
    for tag, i1, i2, j1, j2 in ops.get_opcodes():
        if tag == 'equal':
            out += [{**old[i1 + k], 'w': new[j1 + k]} for k in range(i2 - i1)]
        elif tag in ('replace', 'insert'):
            if i2 > i1:
                s, e = old[i1]['s'], old[i2 - 1]['e']
            else:
                prev = old[i1 - 1] if i1 > 0 else None
                nxt = old[i1] if i1 < len(old) else None
                s = prev['e'] if prev else max(nxt['s'] - 0.3, 0)
                e = nxt['s'] if nxt else prev['e'] + 0.3
                if e - s < 0.15:
                    base = prev or nxt
                    s, e = base['s'], base['e']
            sizes = [len(t) + 1 for t in new[j1:j2]]
            t = s
            for word, size in zip(new[j1:j2], sizes):
                step = (e - s) * size / sum(sizes)
                out.append({'s': round(t, 2), 'e': round(t + step, 2), 'w': word})
                t += step
    return sorted(out, key=lambda w: w['s'])


def _merge(ranges):
    out = []
    for a, b in sorted(ranges):
        if out and a <= out[-1][1] + 0.05:
            out[-1][1] = max(out[-1][1], b)
        else:
            out.append([a, b])
    return out


def keep_ranges(words, edit, dur):
    """Parts of the clip (seconds from its start) that stay after cut words, fillers and jump cuts."""
    removed = [(a, b) for a, b in edit.get('cuts') or []]
    if edit.get('fillers'):
        removed += [(w['s'] - 0.03, w['e'] + 0.03) for w in words if re.sub(r'[^\w]', '', w['w'].lower()) in FILLERS]
    if edit.get('jumpcuts'):
        last = 0.0
        for w in words + [{'s': dur, 'e': dur}]:
            if w['s'] - last > 0.55:  # a pause: keep a short breath on both sides
                removed.append((last + 0.15, w['s'] - 0.1))
            last = max(last, w['e'])
    keep, t = [], 0.0
    for a, b in _merge((max(a, 0), min(b, dur)) for a, b in removed if b - a > 0.05):
        if a - t > 0.12:
            keep.append((round(t, 3), round(a, 3)))
        t = max(t, b)
    if dur - t > 0.12:
        keep.append((round(t, 3), round(dur, 3)))
    return keep or [(0.0, round(dur, 3))]


def timeline(keep):
    """Function mapping clip time to output time after cuts, and whether a moment survives the cuts."""
    def to_out(t):
        out = 0.0
        for a, b in keep:
            if t < a:
                return out
            if t <= b:
                return out + t - a
            out += b - a
        return out

    def kept(t):
        return any(a <= t <= b for a, b in keep)
    return to_out, kept


def emoji_for(word):
    clean = re.sub(r'[^\w]', '', word.lower())
    if len(clean) < 3:
        return None
    return _EMOJI_WORDS.get(clean) or next((c for w, c in _EMOJI_WORDS.items() if len(w) >= 5 and clean.startswith(w)), None)


def emoji_events(words, dur, every=3.0, limit=8):
    """[(code, start, end)] in output time: one emoji at a time, never more often than every 3 seconds."""
    events, last = [], -every
    for w in words:
        code = emoji_for(w['w'])
        if code and w['s'] - last >= every and len(events) < limit:
            events.append((code, round(w['s'], 2), round(min(max(w['s'] + 1.3, w['e'] + 0.5), dur), 2)))
            last = w['s']
    return events


def zoom_ranges(words, keep, dur):
    """Output-time ranges shown punched in: the picture changes size at every cut, at new sentences
    (at most every 2.5 s) and at least every 5 s, alternating between normal and close."""
    starts = []
    t = 0.0
    for a, b in keep:
        starts.append(t)
        t += b - a
    prev, last = None, 0.0
    for w in words:
        sentence = prev is not None and (re.search(r'[.!?,]$', prev['w']) or w['s'] - prev['e'] > 0.35)
        if (sentence and w['s'] - last >= 2.5) or w['s'] - last >= 5:
            starts.append(w['s'])
            last = w['s']
        prev = w
    spaced = []
    for s in sorted(set(round(s, 2) for s in starts if s < dur - 0.5)):
        if not spaced or s - spaced[-1] >= 1.2:
            spaced.append(s)
    starts, bounds = spaced, spaced + [dur]
    return [(bounds[i], bounds[i + 1]) for i in range(1, len(starts), 2)]
