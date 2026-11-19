import json
import os
import sqlite3
import threading
import time
from pathlib import Path

DATA = Path(os.environ.get('DATA_DIR', '/data'))
DB_PATH = DATA / 'clipper.db'
_lock = threading.RLock()

# Per-user settings (account level). Campaign settings live in CAMPAIGN_DEFAULTS below.
DEFAULT_SETTINGS = {
    'campaign_name': '',
    'creator_credit': '',
    'hashtags': '#shorts',
    'title_suffix': '',
    'description_template': '{title}\n\n{description}\n\n{credit}\n\n{hashtags}',
    'clip_min': '25',
    'clip_max': '60',
    'clips_per_video': '5',
    'upload_mode': 'approve',
    'post_youtube': '1',
    'post_instagram': '1',
    'post_facebook': '1',
    'schedule_gap_hours': '3',
    'crop_mode': 'auto',
    'show_title': '1',
    'caption_uppercase': '1',
    'language': '',
    'telegram_token': '',
    'telegram_chat': '',
    'alert_posted': '1',
    'alert_failed': '1',
    'alert_done': '1',
}

DEFAULT_TEMPLATE = '{description}\n\n{cta}\n\n{credit}\n\n{links}\n\n{hashtags}'

# Every switch and value a campaign can have. Stored as JSON in campaigns.settings; anything missing uses these.
CAMPAIGN_DEFAULTS = {
    # who it is for
    'country': 'US',
    'target_language': 'en',
    'spoken_language': '',
    'category_id': '24',
    # clips
    'clip_min': '25',
    'clip_max': '60',
    'clips_per_video': '5',
    # posting
    'channels': '',
    'auto_post': '0',
    'schedule_mode': 'peak',
    'posts_per_day': '4',
    'gap_hours': '3',
    'privacy': 'public',
    'first_comment': '1',
    'playlist': '0',
    'localize': '0',
    'localize_langs': 'es,pt,fr,de',
    # post text
    'hashtags': '#shorts',
    'credit': '',
    'title_suffix': '',
    'cta': 'Follow for more!',
    'links': '',
    'description_template': DEFAULT_TEMPLATE,
    'best_title': '1',
    # editing
    'crop_mode': 'ai',
    'ai_check': '1',
    'cut_silence': '1',
    'cut_fillers': '1',
    'zoom': '1',
    'caption_style': 'bold',
    'caption_uppercase': '1',
    'caption_position': 'auto',
    'highlight_keywords': '1',
    'emojis': '1',
    'hook': 'top',
    'progress_bar': '1',
    'music': '0',
    'music_volume': '14',
    'sfx': '1',
    'broll': '0',
    'loudnorm': '1',
    'color_boost': '1',
    'outro': '1',
    'outro_text': 'Follow for more',
    'watermark': '0',
    'watermark_text': '',
    'logo_url': '',
    'logo_position': 'top_right',
    'logo_size': '24',
    'translate_captions': '1',
    # auto-pilot
    'autopilot': '0',
    'sources': '',
}

# Switches (stored as '1' / '0'); the campaign form sends only the ones that are on.
CAMPAIGN_SWITCHES = ('auto_post', 'ai_check', 'first_comment', 'playlist', 'localize', 'best_title', 'cut_silence', 'cut_fillers',
                     'zoom', 'caption_uppercase', 'highlight_keywords', 'emojis', 'progress_bar', 'music', 'sfx',
                     'broll', 'loudnorm', 'color_boost', 'outro', 'watermark', 'translate_captions', 'autopilot')

# Seconds of work per second of video, learned from real jobs (see pipeline.learn).
DEFAULT_RATES = {'download': 0.05, 'transcribe': 0.45, 'pick': 45.0, 'render': 1.6}

SCHEMA = '''
create table if not exists users (
  id integer primary key autoincrement,
  email text unique, name text, password text, role text default 'user',
  active integer default 1, expires_at real default 0,
  videos_per_month integer default 30, max_minutes integer default 90,
  notes text default '', created_at real, last_login real default 0
);
create table if not exists settings (user_id integer, key text, value text, primary key (user_id, key));
create table if not exists stats (key text primary key, value text);
create table if not exists jobs (
  id integer primary key autoincrement, user_id integer,
  source text, source_type text, title text default '',
  status text default 'queued', step text default '', stage text default '', stage_started real default 0,
  progress real default 0, error text default '', duration real default 0,
  clips_total integer default 0, clips_done integer default 0,
  created_at real, started_at real default 0, finished_at real default 0, updated_at real
);
create table if not exists clips (
  id integer primary key autoincrement, job_id integer, user_id integer,
  start real, end real, title text, hook text, reason text,
  score real default 0, file text default '', thumb text default '',
  status text default 'rendering',
  error text default '', created_at real, meta text default '{}'
);
create table if not exists posts (
  id integer primary key autoincrement, clip_id integer, user_id integer, platform text,
  status text default 'waiting', due_at real, external_id text default '', url text default '',
  error text default '', posted_at real default 0, tries integer default 0
);
create table if not exists campaigns (
  id integer primary key autoincrement, user_id integer, name text, brief text default '',
  settings text default '{}', created_at real, updated_at real
);
create table if not exists channels (
  id integer primary key autoincrement, user_id integer, platform text, ext_id text default '', name text default '',
  data text default '{}', daily_limit integer default 10, note text default '', blocked_until real default 0,
  created_at real
);
create index if not exists posts_due on posts(status, due_at);
create index if not exists jobs_user on jobs(user_id, created_at);
create index if not exists clips_job on clips(job_id);
create index if not exists campaigns_user on campaigns(user_id);
create index if not exists channels_user on channels(user_id);
'''


def conn():
    c = sqlite3.connect(DB_PATH, timeout=30, check_same_thread=False)
    c.row_factory = sqlite3.Row
    return c


MIGRATIONS = {
    'users': {'approved': 'integer default 1', 'google_sub': "text default ''", 'avatar': "text default ''"},
    'jobs': {'attempts': 'integer default 0', 'campaign_id': 'integer default 0'},
    'posts': {'channel_id': 'integer default 0', 'views': 'integer default 0', 'likes': 'integer default 0',
              'comments': 'integer default 0', 'stats_at': 'real default 0', 'extra': "text default ''"},
}

SITE_DEFAULTS = {'signup_mode': 'approval', 'trial_days': '3', 'trial_videos': '5', 'trial_minutes': '60'}


def init():
    DATA.mkdir(parents=True, exist_ok=True)
    with conn() as c:
        c.executescript(SCHEMA)
        c.execute('pragma journal_mode=wal')
        for table, cols in MIGRATIONS.items():
            have = {r['name'] for r in c.execute(f'pragma table_info({table})')}
            for col, kind in cols.items():
                if col not in have:
                    c.execute(f'alter table {table} add column {col} {kind}')
    migrate_campaigns()
    migrate_layout()


def site():
    """Admin-wide settings (stored under user 0)."""
    stored = {r['key']: r['value'] for r in q('select key, value from settings where user_id=0')}
    return {**SITE_DEFAULTS, **stored}


def q(sql, args=()):
    with _lock, conn() as c:
        return [dict(r) for r in c.execute(sql, args).fetchall()]


def one(sql, args=()):
    rows = q(sql, args)
    return rows[0] if rows else None


def run(sql, args=()):
    with _lock, conn() as c:
        return c.execute(sql, args).lastrowid


def settings(user_id):
    stored = {r['key']: r['value'] for r in q('select key, value from settings where user_id=?', (user_id,))}
    return {**DEFAULT_SETTINGS, **stored}


def set_setting(user_id, key, value):
    run('insert into settings(user_id, key, value) values(?, ?, ?) '
        'on conflict(user_id, key) do update set value=excluded.value', (user_id, key, value))


def get_json(user_id, key):
    row = one('select value from settings where user_id=? and key=?', (user_id, key))
    return json.loads(row['value']) if row and row['value'] else None


def set_json(user_id, key, value):
    set_setting(user_id, key, json.dumps(value) if value is not None else '')


def stat(key, default=None):
    row = one('select value from stats where key=?', (key,))
    return json.loads(row['value']) if row else default


def set_stat(key, value):
    run('insert into stats(key, value) values(?, ?) on conflict(key) do update set value=excluded.value',
        (key, json.dumps(value)))


def rates():
    return {**DEFAULT_RATES, **(stat('rates') or {})}


def update_job(job_id, **fields):
    fields['updated_at'] = time.time()
    cols = ', '.join(f'{k}=?' for k in fields)
    run(f'update jobs set {cols} where id=?', (*fields.values(), job_id))


def update_clip(clip_id, **fields):
    cols = ', '.join(f'{k}=?' for k in fields)
    run(f'update clips set {cols} where id=?', (*fields.values(), clip_id))


# ---------- campaigns ----------

def _campaign_row(row):
    if not row:
        return None
    stored = json.loads(row.get('settings') or '{}')
    row['s'] = {**CAMPAIGN_DEFAULTS, **{k: str(v) for k, v in stored.items() if k in CAMPAIGN_DEFAULTS}}
    row['channel_ids'] = [int(x) for x in row['s']['channels'].split(',') if x.strip().isdigit()]
    return row


def campaign(campaign_id):
    return _campaign_row(one('select * from campaigns where id=?', (campaign_id,)))


def campaigns(user_id):
    return [_campaign_row(r) for r in q('select * from campaigns where user_id=? order by id', (user_id,))]


def create_campaign(user_id, name, brief='', values=None):
    now = time.time()
    clean = {k: str(v) for k, v in (values or {}).items() if k in CAMPAIGN_DEFAULTS}
    return run('insert into campaigns(user_id, name, brief, settings, created_at, updated_at) values(?,?,?,?,?,?)',
               (user_id, (name or 'New campaign').strip()[:80], (brief or '').strip()[:4000], json.dumps(clean), now, now))


def update_campaign(campaign_id, name=None, brief=None, values=None):
    row = one('select * from campaigns where id=?', (campaign_id,))
    if not row:
        return
    stored = json.loads(row['settings'] or '{}')
    for k, v in (values or {}).items():
        if k in CAMPAIGN_DEFAULTS:
            stored[k] = str(v)
    run('update campaigns set name=?, brief=?, settings=?, updated_at=? where id=?',
        ((name if name is not None else row['name']).strip()[:80] or row['name'],
         (brief if brief is not None else row['brief'] or '').strip()[:4000], json.dumps(stored), time.time(), campaign_id))


def default_campaign(user_id):
    """The user's first campaign; made on the spot if they have none."""
    row = one('select id from campaigns where user_id=? order by id limit 1', (user_id,))
    if row:
        return campaign(row['id'])
    chans = ','.join(str(c['id']) for c in channels(user_id))
    return campaign(create_campaign(user_id, 'Main campaign', '', {'channels': chans}))


def job_campaign(job):
    c = campaign(job.get('campaign_id') or 0) if job.get('campaign_id') else None
    if not c or c['user_id'] != job['user_id']:
        c = default_campaign(job['user_id'])
    return c


# ---------- channels (connected accounts, any number per platform) ----------

def _channel_row(row):
    if row:
        row['d'] = json.loads(row.get('data') or '{}')
    return row


def channel(channel_id):
    return _channel_row(one('select * from channels where id=?', (channel_id,)))


def channels(user_id, platform=None):
    if platform:
        rows = q('select * from channels where user_id=? and platform=? order by id', (user_id, platform))
    else:
        rows = q('select * from channels where user_id=? order by platform desc, id', (user_id,))
    return [_channel_row(r) for r in rows]


def save_channel(user_id, platform, ext_id, name, data):
    """Add a channel, or refresh the login of one that is already connected."""
    row = one('select id, data from channels where user_id=? and platform=? and ext_id=?', (user_id, platform, ext_id))
    if row:
        merged = {**json.loads(row['data'] or '{}'), **data}
        run('update channels set name=?, data=?, note="" where id=?', (name, json.dumps(merged), row['id']))
        return row['id']
    return run('insert into channels(user_id, platform, ext_id, name, data, created_at) values(?,?,?,?,?,?)',
               (user_id, platform, ext_id, name, json.dumps(data), time.time()))


def set_channel_data(channel_id, **fields):
    row = channel(channel_id)
    if row:
        run('update channels set data=? where id=?', (json.dumps({**row['d'], **fields}), channel_id))


def migrate_campaigns():
    """One time: old single-account settings become a channel list and a "Main campaign" per user."""
    if stat('campaigns_v1'):
        return
    for user in q('select id from users'):
        uid = user['id']
        old = settings(uid)
        ids = []
        for platform in ('youtube', 'instagram', 'facebook'):
            acct = get_json(uid, f'acct_{platform}')
            if not acct:
                continue
            if platform == 'facebook':
                for page in acct.get('pages', []):
                    cid = save_channel(uid, 'facebook', page['id'], page['name'], {'page': page})
                    if page['id'] == acct.get('page_id') and old.get('post_facebook') == '1':
                        ids.append(cid)
                continue
            ext = acct.get('channel_id') or acct.get('ig_id') or acct.get('name', platform)
            cid = save_channel(uid, platform, str(ext), acct.get('name', platform), acct)
            if old.get(f'post_{platform}') == '1':
                ids.append(cid)
        for platform in ('youtube', 'instagram', 'facebook'):  # posts made before channels existed
            first = one('select id from channels where user_id=? and platform=? order by id limit 1', (uid, platform))
            if first:
                run('update posts set channel_id=? where user_id=? and platform=? and (channel_id is null or channel_id=0)',
                    (first['id'], uid, platform))
        if one('select id from campaigns where user_id=?', (uid,)):
            continue
        template = old['description_template']
        if template == DEFAULT_SETTINGS['description_template']:
            template = DEFAULT_TEMPLATE
        values = {
            'channels': ','.join(map(str, ids)), 'auto_post': '1' if old['upload_mode'] == 'auto' else '0',
            'schedule_mode': 'peak', 'posts_per_day': '6', 'gap_hours': old['schedule_gap_hours'] or '3',
            'credit': old['creator_credit'], 'hashtags': old['hashtags'], 'title_suffix': old['title_suffix'],
            'description_template': template, 'clip_min': old['clip_min'], 'clip_max': old['clip_max'],
            'clips_per_video': old['clips_per_video'], 'spoken_language': old['language'], 'crop_mode': old['crop_mode'],
            'hook': 'top' if old['show_title'] == '1' else 'off', 'caption_uppercase': old['caption_uppercase'],
        }
        cid = create_campaign(uid, old['campaign_name'] or 'Main campaign', '', values)
        run('update jobs set campaign_id=? where user_id=? and (campaign_id is null or campaign_id=0)', (cid, uid))
    set_stat('campaigns_v1', time.time())


def migrate_layout():
    """One time: campaigns that cropped every video now let the AI pick the layout per clip."""
    if stat('layout_v2'):
        return
    for row in q('select id, settings from campaigns'):
        stored = json.loads(row['settings'] or '{}')
        if stored.get('crop_mode', 'auto') in ('auto', 'face'):
            stored['crop_mode'] = 'ai'
        if stored.get('caption_position') == 'middle':
            stored['caption_position'] = 'auto'
        run('update campaigns set settings=? where id=?', (json.dumps(stored), row['id']))
    set_stat('layout_v2', time.time())
