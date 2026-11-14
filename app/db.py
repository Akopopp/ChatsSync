import json
import os
import sqlite3
import threading
import time
from pathlib import Path

DATA = Path(os.environ.get('DATA_DIR', '/data'))
DB_PATH = DATA / 'clipper.db'
_lock = threading.RLock()

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
}

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
create index if not exists posts_due on posts(status, due_at);
create index if not exists jobs_user on jobs(user_id, created_at);
create index if not exists clips_job on clips(job_id);
'''


def conn():
    c = sqlite3.connect(DB_PATH, timeout=30, check_same_thread=False)
    c.row_factory = sqlite3.Row
    return c


def init():
    DATA.mkdir(parents=True, exist_ok=True)
    with conn() as c:
        c.executescript(SCHEMA)
        c.execute('pragma journal_mode=wal')


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
