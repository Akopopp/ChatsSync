"""Every campaign setting with a plain-language explanation. The campaign page and the AI helper both read this."""
from . import geo

COUNTRY_OPTS = [(k, v[0]) for k, v in geo.COUNTRIES.items()]
LANG_OPTS = list(geo.LANGS.items())

# (key, label, kind, options, help). kind: switch | select | number | text | textarea
SECTIONS = [
    ('Who it is for', 'The AI writes titles, keywords and captions for these viewers, and posts at their busiest hours.', [
        ('country', 'Target country', 'select', COUNTRY_OPTS,
         'Titles, search keywords, spelling and posting times are made for viewers in this country.'),
        ('target_language', 'Language of titles and captions', 'select', LANG_OPTS,
         'Titles, descriptions and translated captions are written in this language.'),
        ('spoken_language', 'Language spoken in the videos', 'select', [('', 'Detect automatically')] + LANG_OPTS,
         'Leave on automatic. Change it only if captions come out in the wrong language.'),
        ('category_id', 'YouTube category', 'select', list(geo.CATEGORIES.items()),
         'Helps YouTube show the clips to the right people (Gaming for game clips, Sports for matches, and so on).'),
    ]),
    ('Posting', 'Where and when finished clips go. Pick the channels above.', [
        ('auto_post', 'Post automatically', 'switch', None,
         'On: every finished clip is scheduled on the channels of this campaign. Off: you check each clip and press Post.'),
        ('schedule_mode', 'When to post', 'select',
         [('peak', 'At the busiest hours in the target country'), ('gap', 'Every few hours'), ('now', 'As soon as possible')],
         'Busiest hours spreads the posts of each day over the times most people in that country watch Shorts.'),
        ('posts_per_day', 'Posts per day on each channel', 'number', (1, 30),
         'New or unverified YouTube channels can post only about 10 to 15 a day. 3 to 6 a day is a healthy pace.'),
        ('gap_hours', 'Hours between posts', 'number', (0, 48), 'Only for "Every few hours".'),
        ('privacy', 'Who can see new posts', 'select',
         [('public', 'Everyone (public)'), ('unlisted', 'Only people with the link'), ('private', 'Only me (private)')],
         'Use private to test a new campaign first.'),
        ('first_comment', 'Post a first comment', 'switch', None,
         'The AI writes a question under each video so people start replying. Pin it in YouTube Studio for even more replies.'),
        ('playlist', 'Add every clip to a playlist', 'switch', None,
         'Each channel gets a playlist named after this campaign. Playlists keep viewers watching longer.'),
        ('localize', 'Titles in more languages', 'switch', None,
         'Adds translated titles and descriptions, so YouTube shows them to people who speak those languages.'),
        ('localize_langs', 'Extra languages', 'text', None, 'Language codes separated by commas, e.g. es,pt,fr,de,hi'),
    ]),
    ('Post text', 'The AI writes a title, description, tags, hashtags and a first comment for every clip. These are added to it.', [
        ('best_title', 'Pick the best of 3 titles', 'switch', None,
         'The AI writes 3 titles and keeps the one most likely to get clicks. You can switch to another on the clip.'),
        ('hashtags', 'Hashtags on every post', 'text', None, 'Separated by spaces, e.g. #shorts #pubg. Keep it to 1 to 3.'),
        ('credit', 'Credit line', 'text', None, 'Shown under the description, e.g. Credit: @creator'),
        ('cta', 'Call to action', 'text', None, 'Shown under the description, e.g. Follow for daily clips!'),
        ('links', 'Links', 'textarea', None, 'Any links to add to every description (one per line).'),
        ('title_suffix', 'Add to the end of every title', 'text', None, 'Optional, e.g. #shorts'),
        ('description_template', 'Description layout', 'textarea', None,
         'Use {description} {cta} {credit} {links} {hashtags} {title}. The AI fills {description}.'),
    ]),
    ('Clips', 'How long each clip is and how many are made from one video.', [
        ('clip_min', 'Shortest clip (seconds)', 'number', (10, 170), 'Shorts work best between 25 and 60 seconds.'),
        ('clip_max', 'Longest clip (seconds)', 'number', (15, 180), 'YouTube Shorts allow up to 3 minutes; Facebook Reels 90 seconds.'),
        ('clips_per_video', 'Clips per video', 'number', (1, 15), 'More clips = more posts, but the weaker moments get in too.'),
    ]),
    ('Editing', 'How each clip is edited so people keep watching.', [
        ('crop_mode', 'Framing', 'select',
         [('ai', 'AI decides for every clip (recommended)'), ('fit', 'Always the whole picture, text above and below'),
          ('face', 'Always a 9:16 crop that follows the face'), ('center', 'Always cut out the middle')],
         'AI looks at each clip: close-ups become a 9:16 crop that follows the person; games, sports, groups and wide '
         'shots keep the whole horizontal picture with the title above and captions below, so nothing is covered.'),
        ('ai_check', 'AI checks every finished clip', 'switch', None,
         'After editing, the AI looks at the clip. If captions cover a face or the subject is cut off, it fixes the '
         'layout and edits the clip again.'),
        ('cut_silence', 'Cut out pauses', 'switch', None,
         'Removes silent gaps while people talk, so the clip feels fast. Videos with little talking are left whole.'),
        ('cut_fillers', 'Cut "um" and "uh"', 'switch', None, 'Removes filler sounds.'),
        ('zoom', 'Zoom cuts', 'switch', None, 'Zooms in and out between sentences and punches in on the words that matter.'),
        ('caption_style', 'Caption style', 'select',
         [('bold', 'Bold: big white words, the spoken word turns yellow'), ('beast', 'Beast: huge words, 2 at a time, bouncing'),
          ('boxed', 'Boxed: black words on a white box'), ('karaoke', 'Karaoke: words light up as they are said'),
          ('minimal', 'Minimal: small, clean, normal case'), ('off', 'No captions')],
         'Captions are written word by word from what is said.'),
        ('caption_position', 'Caption position', 'select',
         [('auto', 'AI picks a spot that covers nothing'), ('low', 'Low'), ('middle', 'Middle')],
         'With the whole picture, captions always go under (or above) the video, never on it.'),
        ('caption_uppercase', 'Captions in CAPITAL letters', 'switch', None, ''),
        ('censor_captions', 'Hide swear words in text', 'switch', None, 'Strong swear words show as F*CK in captions and hook text.'),
        ('highlight_keywords', 'Color the important words', 'switch', None, 'The AI picks the key words and colors them green.'),
        ('emojis', 'Emojis', 'switch', None, 'A fitting emoji pops up above the captions on a few key words.'),
        ('hook', 'Hook text', 'select',
         [('top', 'Box at the top for the whole clip'), ('intro', 'Big text for the first 2 seconds'), ('off', 'No hook text')],
         'A short line that tells viewers why to keep watching.'),
        ('translate_captions', 'Translate captions', 'switch', None,
         'When the video is in another language (e.g. Hindi), captions are shown in the campaign language (e.g. English).'),
        ('progress_bar', 'Progress bar', 'switch', None, 'A thin bar at the bottom shows how much is left; people stay till the end.'),
        ('sfx', 'Sound effects', 'switch', None, 'A soft whoosh on zoom cuts and a pop when an emoji appears.'),
        ('music', 'Background music', 'switch', None,
         'Plays one of your uploaded tracks under the voice. It gets quieter whenever someone talks. Upload only music you may use.'),
        ('music_volume', 'Music volume (%)', 'number', (1, 60), '10 to 18 is usually right.'),
        ('broll', 'B-roll (stock clips)', 'switch', None,
         'Shows a matching stock video for 2 seconds on things that are mentioned (needs a free Pexels key on the server).'),
        ('loudnorm', 'Even, loud sound', 'switch', None, 'Makes every clip as loud as normal Shorts.'),
        ('color_boost', 'Richer colors', 'switch', None, 'A little more color and contrast.'),
        ('outro', 'Ending text', 'switch', None, 'Shows a short message for the last 2 seconds.'),
        ('outro_text', 'Ending text', 'text', None, 'e.g. Follow for more'),
        ('watermark', 'Channel name on the video', 'switch', None, 'Small text in the top corner.'),
        ('watermark_text', 'Channel name text', 'text', None, 'e.g. @yourchannel'),
        ('logo_url', 'Logo on every clip (image link)', 'text', None,
         'Some campaigns require their logo or overlay on the whole clip. Paste the link to the image (PNG or WebP).'),
        ('logo_position', 'Logo position', 'select',
         [('top_right', 'Top right'), ('top_left', 'Top left'), ('bottom_right', 'Bottom right'), ('bottom_left', 'Bottom left')],
         'Pick a corner where the logo covers nothing important.'),
        ('logo_size', 'Logo size (% of the width)', 'number', (8, 45), '20 to 30 is usually right.'),
    ]),
    ('Auto-pilot', 'Watch the creators you clip. When they upload, clips are made (and posted, if posting is automatic) on their own.', [
        ('autopilot', 'Auto-pilot', 'switch', None, 'Checks the channels below every 20 minutes. Only new uploads are clipped.'),
        ('sources', 'Channels or playlists to watch', 'textarea', None,
         'One link per line, e.g. https://www.youtube.com/@creator. Only clip creators who allowed it.'),
    ]),
]

FIELDS = {key: (label, kind, opts, help_) for _, _, items in SECTIONS for key, label, kind, opts, help_ in items}


def describe():
    """Plain list of every setting for the AI helper."""
    lines = []
    for title, _, items in SECTIONS:
        lines.append(f'[{title}]')
        for key, label, kind, opts, help_ in items:
            if kind == 'select':
                values = ', '.join(f'{v}={t}' for v, t in opts[:25])
                lines.append(f'- {key} ({label}): one of {values}. {help_}')
            elif kind == 'switch':
                lines.append(f'- {key} ({label}): "1" on or "0" off. {help_}')
            elif kind == 'number':
                lines.append(f'- {key} ({label}): number {opts[0]}-{opts[1]}. {help_}')
            else:
                lines.append(f'- {key} ({label}): text. {help_}')
    return '\n'.join(lines)


def clean(key, value):
    """Check one value from a form or the AI helper. Returns the string to store, or None if it is not allowed."""
    if key == 'channels':
        return ','.join(x for x in str(value).replace(' ', '').split(',') if x.isdigit())
    if key not in FIELDS:
        return None
    label, kind, opts, _ = FIELDS[key]
    value = '' if value is None else str(value).strip()
    if kind == 'switch':
        return '1' if value.lower() in ('1', 'true', 'on', 'yes') else '0'
    if kind == 'select':
        allowed = [v for v, _ in opts]
        return value if value in allowed else None
    if kind == 'number':
        try:
            num = float(value)
        except ValueError:
            return None
        num = min(max(num, opts[0]), opts[1])
        return str(int(num)) if key != 'gap_hours' else str(round(num, 1))
    return value[:3000]
