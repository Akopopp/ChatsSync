import json
import os
import shutil
import threading
import time
import traceback
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

from . import ai, db, edit, geo, media, notify, platforms

JOBS = db.DATA / 'jobs'
MIN_FREE_GB = float(os.environ.get('MIN_FREE_GB', '8'))
YT_DAILY_LIMIT = int(os.environ.get('YT_DAILY_LIMIT', '95'))
DEFAULT_MINUTES = 20  # assumed length while a linked video's length is still unknown
MAX_TRIES = int(os.environ.get('MAX_TRIES', '3'))  # restarts allowed in the middle of one video before giving up on it
CRASHED = ('The server restarted several times while making clips from this video, so it was stopped to keep the '
           'queue moving. Try a shorter video, or upload the file instead.')
_wake = threading.Event()
_stop = set()  # job ids the user stopped while they were being worked on
_current = {}  # {'job': id, 'thread': id} of the job being worked on right now


def job_dir(job_id):
    return JOBS / str(job_id)


# ---------- queue order and timers ----------

def queue_order():
    """Queued jobs, taking turns between users so one user can't block everyone."""
    jobs = db.q('select * from jobs where status="queued" order by created_at')
    seen, ranked = {}, []
    for job in jobs:
        n = seen.get(job['user_id'], 0)
        seen[job['user_id']] = n + 1
        ranked.append((n, job['created_at'], job))
    return [j for _, _, j in sorted(ranked, key=lambda r: (r[0], r[1]))]


_camp_cache = {}


def _settings_for(job):
    key = (job['id'], job.get('campaign_id'))
    hit = _camp_cache.get(key)
    if hit and hit[0] > time.time() - 30:
        return hit[1]
    s = db.job_campaign(job)['s']
    _camp_cache[key] = (time.time(), s)
    return s


def estimate(job, s=None):
    """Seconds of work for each stage of a job."""
    rate = db.rates()
    s = s or _settings_for(job)
    length = job['duration'] or DEFAULT_MINUTES * 60
    clips = int(s['clips_per_video'])
    clip_len = (float(s['clip_min']) + float(s['clip_max'])) / 2
    return {
        'download': 0 if job['source_type'] == 'upload' else length * rate['download'] + 10,
        'transcribe': length * rate['transcribe'] + 15,
        'pick': rate['pick'],
        'render': clips * clip_len * rate['render'],
    }


STAGES = ['download', 'transcribe', 'pick', 'render']


def remaining(job):
    est = estimate(job)
    if job['status'] == 'queued' or job['stage'] not in STAGES:
        return sum(est.values())
    i = STAGES.index(job['stage'])
    elapsed = time.time() - (job['stage_started'] or time.time())
    stage_est = est[job['stage']]
    if job['stage'] == 'transcribe' and job['progress'] > 0.05:
        left = elapsed / job['progress'] - elapsed
    elif job['stage'] == 'render' and job['clips_total']:
        per_clip = stage_est / job['clips_total']
        left = max(per_clip * (job['clips_total'] - job['clips_done']) - min(elapsed, per_clip * 0.9), 5)
    else:
        left = max(stage_est - elapsed, stage_est * 0.1)
    return left + sum(est[s] for s in STAGES[i + 1:])


def timers():
    """{job_id: {'starts_in': secs, 'left': secs, 'ahead': n, 'total': secs}} for unfinished jobs."""
    out, clock = {}, 0
    for job in db.q('select * from jobs where status="working"'):
        left = remaining(job)
        out[job['id']] = {'starts_in': 0, 'left': left, 'ahead': 0, 'total': sum(estimate(job).values())}
        clock += left
    working = len(out)
    for n, job in enumerate(queue_order()):
        total = sum(estimate(job).values())
        out[job['id']] = {'starts_in': clock, 'left': clock + total, 'ahead': working + n, 'total': total}
        clock += total
    return out


def learn(stage, seconds, media_seconds):
    if media_seconds <= 0:
        return
    rate = db.rates()
    value = seconds if stage == 'pick' else seconds / media_seconds
    rate[stage] = round(rate[stage] * 0.6 + value * 0.4, 4)
    db.set_stat('rates', rate)


# ---------- workers ----------

def start():
    # A job still "working" here was cut off by a restart. If it keeps doing that (e.g. it crashes the server),
    # stop retrying it instead of looping forever and blocking every video behind it.
    db.run('update jobs set status="failed", stage="", step="", error=?, finished_at=? where status="working" and attempts>=?',
           (CRASHED, time.time(), MAX_TRIES))
    db.run('update jobs set status="queued", stage="", step="Waiting" where status="working"')
    db.run('update posts set status="waiting" where status="posting"')
    for target in (_job_loop, _post_loop, _cleanup_loop, _autopilot_loop, _stats_loop):
        threading.Thread(target=target, daemon=True).start()


def wake():
    _wake.set()


def stop(job_id):
    """Stop a job that is being worked on: end its running command and make the worker give it up."""
    _stop.add(job_id)
    if _current.get('job') == job_id:
        media.kill(_current['thread'])


def _check(job_id):
    if job_id in _stop:
        raise media.JobError(media.STOPPED)


def _job_loop():
    while True:
        order = queue_order()
        if not order:
            _wake.wait(15)
            _wake.clear()
            continue
        try:
            process(order[0]['id'])
        except Exception:
            traceback.print_exc()


def prefetch(job_id):
    """Look up title and length of a linked video so the queue timer is accurate."""
    job = db.one('select * from jobs where id=?', (job_id,))
    try:
        title, duration = media.metadata(job['source'], f'j{job_id}')
        user = db.one('select max_minutes from users where id=?', (job['user_id'],))
        db.update_job(job_id, title=title[:200] or job['title'], duration=duration)
        if duration and user['max_minutes'] and duration > user['max_minutes'] * 60:
            db.update_job(job_id, status='failed', error=f'Video is longer than your limit of {user["max_minutes"]} minutes.')
    except Exception as err:
        if str(err) == media.BLOCKED and db.one('select status from jobs where id=?', (job_id,))['status'] == 'queued':
            db.update_job(job_id, status='failed', finished_at=time.time(), error=media.BLOCKED)


def _shift(words, start, end):
    return [{'s': round(w['s'] - start, 2), 'e': round(w['e'] - start, 2), 'w': w['w']}
            for w in words if w['s'] >= start - 0.05 and w['e'] <= end + 0.3]


def _stage(job_id, stage, step):
    db.update_job(job_id, stage=stage, step=step, stage_started=time.time(), progress=0)


def top_titles(campaign_id):
    rows = db.q('select c.title from posts p join clips c on c.id=p.clip_id join jobs j on j.id=c.job_id '
                'where j.campaign_id=? and p.views>0 order by p.views desc limit 6', (campaign_id,))
    return list(dict.fromkeys(r['title'] for r in rows if r['title']))


def _render(path, out, start, end, words, meta, src, s, camp):
    """Full edit; if that fails, a simpler edit; if that fails too, the basic edit. The clip always gets made.
    Returns (thumbnail, how the layout was chosen)."""
    audio = edit.has_audio(path)
    try:
        thumb, info = edit.render(path, out, start, end, words, meta, src, s, camp['id'], has_audio=audio,
                                  brief=camp['brief'])
        return thumb, info['plan']
    except Exception as err:
        print('full edit failed, trying simple edit:', str(err)[:400])
    try:
        thumb, info = edit.render(path, out, start, end, words, meta, src, s, camp['id'], simple=True,
                                  has_audio=audio, brief=camp['brief'], review=False)
        return thumb, info['plan']
    except Exception as err:
        print('simple edit failed, using basic edit:', str(err)[:400])
    basic = {'show_title': '1' if s.get('hook') != 'off' else '0', 'caption_uppercase': s.get('caption_uppercase', '1'),
             'crop_mode': s.get('crop_mode') if s.get('crop_mode') in ('face', 'fit') else 'auto'}
    return media.render(path, out, start, end, words, meta.get('hook', ''), src, basic), {}


def process(job_id):
    job = db.one('select * from jobs where id=?', (job_id,))
    user = db.one('select * from users where id=?', (job['user_id'],))
    camp = db.job_campaign(job)
    if not job.get('campaign_id'):
        db.update_job(job_id, campaign_id=camp['id'])
    s = camp['s']
    folder = job_dir(job_id)
    folder.mkdir(parents=True, exist_ok=True)
    db.update_job(job_id, status='working', started_at=time.time(), error='')
    db.run('update jobs set attempts=attempts+1 where id=?', (job_id,))
    _current.update(job=job_id, thread=threading.get_ident())
    try:
        if media.free_gb() < MIN_FREE_GB:
            raise media.JobError('The server is busy with storage right now. Please try again in a while.')
        for old in db.q('select file from clips where job_id=?', (job_id,)):
            if old['file']:
                Path(old['file']).unlink(missing_ok=True)
        db.run('delete from clips where job_id=?', (job_id,))
        limit = user['max_minutes'] or 300
        session = f'j{job_id}t{int(time.time())}'
        src = next(folder.glob('upload.*'), None) or next(folder.glob('source.mp4'), None)
        parts = src is None and job['source_type'] == 'link'  # download only the sound now, clip parts later
        t0 = time.time()
        if parts:
            _stage(job_id, 'download', 'Getting the sound of the video')
            listen, title = media.download_audio(job['source'], folder, limit, session)
            duration = media.media_duration(listen)
        else:
            if src is None:
                _stage(job_id, 'download', 'Downloading the video')
                src, title = media.download(job['source'], job['source_type'], folder, limit, session)
            else:
                title, t0 = '', None
            info = media.probe(src)
            listen, duration = src, info['duration']
        if title:
            db.update_job(job_id, title=title[:200])
        if t0:
            learn('download', time.time() - t0, duration)
        db.update_job(job_id, duration=duration)
        if duration > limit * 60:
            raise media.JobError(f'Video is longer than your limit of {limit} minutes.')

        _check(job_id)
        _stage(job_id, 'transcribe', 'Listening to the video and writing captions')
        words_file, lang_file = folder / 'words.json', folder / 'lang.txt'
        if words_file.exists():
            words = json.loads(words_file.read_text())
            lang = lang_file.read_text().strip() if lang_file.exists() else s['spoken_language']
        else:
            t0 = time.time()
            words, lang = media.transcribe(listen, s['spoken_language'], duration=duration,
                                           on_progress=lambda p: db.update_job(job_id, progress=round(p, 3)),
                                           should_stop=lambda: job_id in _stop)
            learn('transcribe', time.time() - t0, duration)
            words_file.write_text(json.dumps(words))
            lang_file.write_text(lang or '')
        # short sources (stream clips) are often reactions with few words; long videos need real talking
        whole = bool(duration) and duration <= 90  # a stream clip someone already cut: keep the whole moment
        if not whole and len(words) < 30:
            raise media.JobError('Not enough speech in this video to make clips.')

        _check(job_id)
        _stage(job_id, 'pick', 'Finding the best moments')
        t0 = time.time()
        if whole:
            picks, used_ai, problem = [{'start': 0.0, 'end': round(duration, 2), 'hook': '', 'score': 80,
                                        'reason': 'The whole stream clip, so the moment keeps its setup and payoff.'}], False, None
        else:
            picks, used_ai, problem = ai.pick_clips(words, s, camp['brief'])
        if not picks:
            raise media.JobError('No good clips found. Try different clip lengths in the campaign.')
        _check(job_id)
        db.update_job(job_id, step='Writing titles, descriptions and the edit plan')
        items = [{'id': i, 'words': _shift(words, p['start'], p['end'])} for i, p in enumerate(picks)]
        metas, write_problem = ai.write_texts(items, s, camp['brief'], lang, top_titles(camp['id']))
        learn('pick', time.time() - t0, 1)
        job = db.one('select * from jobs where id=?', (job_id,))
        clip_ids = []
        for i, p in enumerate(picks):
            meta = metas.get(i) or ai.fallback_text(items[i]['words'], s)
            meta['hook'] = meta.get('hook') or p['hook']
            meta['lang'] = lang
            title = meta.get('title') or job['title'][:90]
            clip_ids.append(db.run(
                'insert into clips(job_id, user_id, start, end, title, hook, reason, score, meta, status, created_at) '
                'values(?,?,?,?,?,?,?,?,?,?,?)',
                (job_id, job['user_id'], p['start'], p['end'], title[:100], meta['hook'], p['reason'], p['score'],
                 json.dumps(meta), 'rendering', time.time())))

        _stage(job_id, 'render', 'Editing clips')
        db.update_job(job_id, clips_total=len(clip_ids), clips_done=0)
        rendered = 0
        t0 = time.time()
        for n, clip_id in enumerate(clip_ids, 1):
            _check(job_id)
            db.update_job(job_id, step=f'Editing clip {n} of {len(clip_ids)}', clips_done=n - 1)
            clip = db.one('select * from clips where id=?', (clip_id,))
            meta = json.loads(clip['meta'] or '{}')
            out = folder / f'clip-{clip_id}.mp4'
            try:
                if parts:
                    try:
                        part = media.download_section(job['source'], folder / f'part-{clip_id}', clip['start'], clip['end'], session)
                    except media.JobError as err:
                        if str(err) == media.BLOCKED:
                            raise
                        # this site can't send parts: fetch the whole video once and cut locally
                        db.update_job(job_id, step='Downloading the full video')
                        src, _ = media.download(job['source'], job['source_type'], folder, limit, session)
                        info, parts = media.probe(src), False
                if parts:
                    length = clip['end'] - clip['start']
                    thumb, layout = _render(part, out, 0, length, _shift(words, clip['start'], clip['end']), meta,
                                            media.probe(part), s, camp)
                    part.unlink(missing_ok=True)
                else:
                    thumb, layout = _render(src, out, clip['start'], clip['end'], words, meta, info, s, camp)
                meta['layout'] = layout
                if layout.get('unsafe'):  # the AI check saw nudity, a strip club, drugs or gambling: never post it
                    out.unlink(missing_ok=True)
                    db.update_clip(clip_id, thumb=str(thumb), status='rejected', meta=json.dumps(meta),
                                   error=f'AI safety check: {layout["unsafe"]}'[:500])
                    continue
                db.update_clip(clip_id, file=str(out), thumb=str(thumb), status='ready', meta=json.dumps(meta))
                threading.Thread(target=platforms.drop_clip, args=(clip_id, str(out)), daemon=True).start()
                rendered += clip['end'] - clip['start']
            except Exception as err:
                db.update_clip(clip_id, status='failed', error=str(err)[:500])
        learn('render', time.time() - t0, rendered)
        for leftover in [src, listen] + list(folder.glob('part-*')):
            if leftover:
                Path(leftover).unlink(missing_ok=True)
        ready = [c for c in clip_ids if db.one('select status from clips where id=?', (c,))['status'] == 'ready']
        if not ready:
            failed = db.one('select error from clips where job_id=? and error != "" limit 1', (job_id,))
            raise media.JobError(failed['error'] if failed else 'Clips could not be edited.')
        _check(job_id)
        notes = []
        if not used_ai:
            notes.append(f'Clips were picked without AI ({problem or "AI not available"}).')
        if write_problem:
            notes.append(f'Some post text was written without AI ({write_problem[:160]}). Use "Rewrite with AI" on a clip.')
        db.update_job(job_id, status='done', stage='', step=' '.join(notes)[:600], finished_at=time.time(),
                      clips_done=len(clip_ids))
        notify.send(job['user_id'], 'done', f'{len(ready)} clips ready: {job["title"] or job["source"]}\n'
                                            f'{platforms.PUBLIC_URL}/jobs/{job_id}')
        if s['auto_post'] == '1':
            for clip_id in ready:
                approve(clip_id)
    except Exception as err:
        stopped = job_id in _stop
        if not stopped:  # a stopped job was already marked (cancelled) or removed (deleted) by whoever stopped it
            db.update_job(job_id, status='failed', stage='', step='', error=str(err)[:600], finished_at=time.time())
            notify.send(job['user_id'], 'failed', f'Could not make clips: {str(err)[:300]}\n{platforms.PUBLIC_URL}/jobs/{job_id}')
        for pattern in ('source.*', 'upload.*', 'audio-src.*', 'audio.f32', 'part-*', '*.part', 'broll-*'):
            for leftover in folder.glob(pattern):
                leftover.unlink(missing_ok=True)
        if stopped and db.one('select id from jobs where id=?', (job_id,)):
            db.update_job(job_id, stage='', step='')
        elif stopped:
            # the user deleted it while it was running: clear anything written after the delete
            db.run('delete from clips where job_id=?', (job_id,))
            shutil.rmtree(folder, ignore_errors=True)
    finally:
        _current.clear()
        _stop.discard(job_id)


def rewrite_text(clip_id):
    """Ask the AI again for one clip's title, description, tags and comment. Returns '' or the problem."""
    clip = db.one('select * from clips where id=?', (clip_id,))
    job = db.one('select * from jobs where id=?', (clip['job_id'],))
    camp = db.job_campaign(job)
    words_file = job_dir(job['id']) / 'words.json'
    if not words_file.exists():
        return 'The transcript of this video is gone, so the text cannot be rewritten.'
    words = _shift(json.loads(words_file.read_text()), clip['start'], clip['end'])
    meta = json.loads(clip['meta'] or '{}')
    s = {**camp['s'], 'translate_captions': '0'}
    metas, problem = ai.write_texts([{'id': 0, 'words': words}], s, camp['brief'], meta.get('lang', ''),
                                    top_titles(camp['id']))
    new = metas.get(0)
    if not new or not new.get('ai'):
        return problem or 'The AI did not answer. Try again in a minute.'
    for key in ('subs', 'keywords', 'emojis', 'zoom_words', 'broll', 'hook'):  # already burned into the video
        if key in meta:
            new[key] = meta[key]
    new['lang'] = meta.get('lang', '')
    db.update_clip(clip_id, title=new['title'][:100] or clip['title'], meta=json.dumps(new))
    return ''


# ---------- scheduling ----------

def _taken(channel_id):
    return [r['due_at'] for r in db.q('select due_at from posts where channel_id=? and status != "failed" and due_at>?',
                                      (channel_id, time.time() - 3 * 86400)) if r['due_at']]


def next_slot(ch, s):
    """When this channel should post next: at the campaign country's peak hours, after a gap, or right away,
    never more than the campaign's posts per day or the channel's daily limit."""
    now = time.time()
    tz = ZoneInfo(geo.tz_name(s.get('country', 'US')))
    mode = s.get('schedule_mode', 'peak')
    per_day = max(1, int(float(s.get('posts_per_day') or 1)))
    limit = int(ch.get('daily_limit') or 0) or 999
    cap = min(per_day, limit) if mode == 'peak' else limit
    taken = _taken(ch['id'])
    earliest = max(now + 60, ch.get('blocked_until') or 0)

    def count(day_start):
        return sum(1 for t in taken if day_start <= t < day_start + 86400)

    def midnight(ts):
        local = datetime.fromtimestamp(ts, tz)
        return datetime(local.year, local.month, local.day, tzinfo=tz)

    if mode == 'peak':
        jitter = 5 + (ch['id'] * 7) % 17
        base = midnight(earliest)
        for d in range(90):
            day = base + timedelta(days=d)
            day = datetime(day.year, day.month, day.day, tzinfo=tz)
            if count(day.timestamp()) >= cap:
                continue
            for hour in geo.peak_hours(per_day):
                slot = (day + timedelta(hours=hour, minutes=jitter)).timestamp()
                if slot >= earliest and not any(abs(t - slot) < 20 * 60 for t in taken):
                    return slot
        return earliest
    gap = float(s.get('gap_hours') or 0) * 3600 if mode == 'gap' else 0
    last = max(taken, default=0)
    slot = max(earliest, last + gap) if last else earliest
    for _ in range(90):
        day = midnight(slot)
        if count(day.timestamp()) < cap:
            return slot
        slot = (day + timedelta(days=1, hours=8)).timestamp()
    return slot


def approve(clip_id, channel_ids=None):
    """Queue a clip for posting on the campaign's channels (or the given ones)."""
    clip = db.one('select * from clips where id=?', (clip_id,))
    job = db.one('select * from jobs where id=?', (clip['job_id'],))
    camp = db.job_campaign(job)
    ids = channel_ids or camp['channel_ids']
    chans = [c for c in (db.channel(i) for i in ids) if c and c['user_id'] == clip['user_id']]
    if not chans:
        db.update_clip(clip_id, error='Choose at least one channel for this campaign first (Campaigns page).')
        return False
    for ch in chans:
        if not db.one('select id from posts where clip_id=? and channel_id=? and status != "failed"', (clip_id, ch['id'])):
            db.run('insert into posts(clip_id, user_id, platform, channel_id, due_at) values(?,?,?,?,?)',
                   (clip_id, clip['user_id'], ch['platform'], ch['id'], next_slot(ch, camp['s'])))
    db.update_clip(clip_id, status='approved', error='')
    return True


def retry_post(post_id):
    db.run('update posts set status="waiting", error="", due_at=? where id=?', (time.time(), post_id))
    clip = db.one('select clip_id from posts where id=?', (post_id,))
    db.update_clip(clip['clip_id'], status='approved')


def yt_today():
    pacific = datetime.now(timezone(timedelta(hours=-8))).strftime('%Y-%m-%d')
    day = db.stat('yt_day', {})
    return pacific, (day.get('count', 0) if day.get('date') == pacific else 0)


def _pacific_midnight():
    now = datetime.now(ZoneInfo('America/Los_Angeles'))
    nxt = datetime(now.year, now.month, now.day, tzinfo=ZoneInfo('America/Los_Angeles')) + timedelta(days=1, minutes=10)
    return nxt.timestamp()


def _post_channel(post):
    if post.get('channel_id'):
        return db.channel(post['channel_id'])
    chans = db.channels(post['user_id'], post['platform'])  # posts made before channels existed
    return chans[0] if chans else None


def _when(ts, s):
    return datetime.fromtimestamp(ts, ZoneInfo(geo.tz_name(s.get('country', 'US')))).strftime('%d %b %I:%M %p')


def _post_loop():
    while True:
        try:
            _post_one()
        except Exception:
            traceback.print_exc()
            time.sleep(20)


def _post_one():
    due = db.one('select * from posts where status="waiting" and due_at<=? order by due_at limit 1', (time.time(),))
    if not due:
        time.sleep(20)
        return
    clip = db.one('select * from clips where id=?', (due['clip_id'],))
    if not clip or not clip['file'] or not Path(clip['file']).exists():
        db.run('update posts set status="failed", error="Clip file is gone." where id=?', (due['id'],))
        return
    ch = _post_channel(due)
    if not ch:
        db.run('update posts set status="failed", error="This channel is not connected any more." where id=?', (due['id'],))
        _finish_clip(clip['id'])
        return
    job = db.one('select * from jobs where id=?', (clip['job_id'],))
    camp = db.job_campaign(job)
    s = {**camp['s'], '_campaign_id': camp['id'], '_campaign_name': camp['name']}
    if ch['platform'] == 'youtube':
        date, count = yt_today()
        if count >= YT_DAILY_LIMIT:
            db.run('update posts set due_at=?, error=? where id=?', (_pacific_midnight(),
                   'The app reached its YouTube uploads for today. It will post automatically after the daily reset.', due['id']))
            return
        if (ch.get('blocked_until') or 0) > time.time():
            slot = next_slot(ch, s)
            db.run('update posts set due_at=?, error=? where id=?', (slot, f'Channel limit reached today. Posting at {_when(slot, s)}.', due['id']))
            return
    db.run('update posts set status="posting", tries=tries+1 where id=?', (due['id'],))
    try:
        ext_id, url, notes = platforms.post(ch, clip, s, platforms.public_link(clip['id']))
        db.run('update posts set status="posted", external_id=?, url=?, error=?, posted_at=? where id=?',
               (ext_id, url, notes or '', time.time(), due['id']))
        if ch['platform'] == 'youtube':
            date, count = yt_today()
            db.set_stat('yt_day', {'date': date, 'count': count + 1})
        notify.send(due['user_id'], 'posted', f'Posted on {ch["name"]}: {clip["title"]}\n{url}')
    except Exception as err:
        reason, message = platforms._yt_error(err) if ch['platform'] == 'youtube' else ('', str(err))
        text = f'{reason} {message}'
        if 'uploadLimitExceeded' in text or 'exceeded the number of videos' in text:
            db.run('update channels set blocked_until=?, note=? where id=?', (time.time() + 16 * 3600,
                   'YouTube says this channel reached its daily upload limit. Verify it at youtube.com/verify to post more each day.', ch['id']))
            slot = next_slot(db.channel(ch['id']), s)
            db.run('update posts set status="waiting", tries=tries-1, due_at=?, error=? where id=?', (slot,
                   f'YouTube daily limit for this channel reached. Moved to {_when(slot, s)}.', due['id']))
            notify.send(due['user_id'], 'failed', f'{ch["name"]}: YouTube upload limit reached for today. '
                                                  f'Posts moved to tomorrow. Verify the channel at youtube.com/verify for a higher limit.')
            return
        if 'quotaExceeded' in text or 'quota' in reason.lower():
            db.run('update posts set status="waiting", tries=tries-1, due_at=?, error=? where id=?', (_pacific_midnight(),
                   'YouTube API quota used up for today. It will post after the daily reset.', due['id']))
            return
        if 'invalid_grant' in text or 'expired or revoked' in text or 'unauthorized' in text.lower():
            db.run('update channels set note=? where id=?', ('Login expired. Reconnect this channel.', ch['id']))
            db.run('update posts set status="failed", error=? where id=?',
                   (f'{ch["name"]} needs to be reconnected (Channels page), then press Retry.', due['id']))
            notify.send(due['user_id'], 'failed', f'{ch["name"]} needs to be reconnected in Clipper.')
            _finish_clip(clip['id'])
            return
        tries = due['tries'] + 1
        if tries < 3:
            db.run('update posts set status="waiting", due_at=?, error=? where id=?',
                   (time.time() + 600 * tries, f'Retrying: {message[:300]}', due['id']))
        else:
            db.run('update posts set status="failed", error=? where id=?', (message[:400], due['id']))
            notify.send(due['user_id'], 'failed', f'Post failed on {ch["name"]}: {message[:200]}')
    _finish_clip(clip['id'])


def _finish_clip(clip_id):
    posts = db.q('select status from posts where clip_id=?', (clip_id,))
    if any(p['status'] in ('waiting', 'posting') for p in posts):
        return
    clip = db.one('select * from clips where id=?', (clip_id,))
    if all(p['status'] == 'posted' for p in posts):
        db.update_clip(clip_id, status='posted')  # the file stays a week so it can be posted elsewhere by hand
    else:
        db.update_clip(clip_id, status='ready', error='Some posts failed. Check below and try again.')


# ---------- auto-pilot: new videos from the campaign's sources become clips on their own ----------

def _source_key(campaign_id, url):
    import hashlib
    return f'seen_{campaign_id}_{hashlib.md5(url.encode()).hexdigest()[:10]}'


def check_sources(camp, first_run_takes=0):
    """Look for new uploads on the campaign's source channels. Returns the number of videos added."""
    from . import auth
    user = db.one('select * from users where id=?', (camp['user_id'],))
    if not user or auth.access_problem(user):
        return 0
    added = 0
    for url in [u.strip() for u in camp['s']['sources'].splitlines() if u.strip().startswith('http')][:10]:
        try:
            latest = media.latest_videos(url, 5)
        except Exception as err:
            print('auto-pilot source failed', url, str(err)[:200])
            continue
        key = _source_key(camp['id'], url)
        seen = db.stat(key)
        if seen is None:  # first look: remember what is there now, only clip what comes after
            db.set_stat(key, [v['id'] for v in latest])
            fresh = latest[:first_run_takes]
        else:
            fresh = [v for v in latest if v['id'] not in seen]
        for video in reversed(fresh):
            if auth.access_problem(db.one('select * from users where id=?', (camp['user_id'],))):
                break
            now = time.time()
            job_id = db.run('insert into jobs(user_id, source, source_type, title, step, created_at, updated_at, campaign_id) '
                            'values(?,?,?,?,?,?,?,?)', (camp['user_id'], video['url'], 'link', video['title'][:200],
                                                        'Waiting', now, now, camp['id']))
            threading.Thread(target=prefetch, args=(job_id,), daemon=True).start()
            added += 1
        if fresh or seen is None:
            db.set_stat(key, list(dict.fromkeys([v['id'] for v in latest] + list(seen or [])))[:200])
    if added:
        wake()
    return added


def _autopilot_loop():
    time.sleep(60)
    while True:
        for row in db.q('select id from campaigns'):
            camp = db.campaign(row['id'])
            if camp and camp['s']['autopilot'] == '1' and camp['s']['sources'].strip():
                try:
                    check_sources(camp)
                except Exception:
                    traceback.print_exc()
        time.sleep(int(os.environ.get('AUTOPILOT_MINUTES', '20')) * 60)


# ---------- views and likes ----------

def refresh_stats(user_id=None):
    since = time.time() - 30 * 86400
    sql = ('select * from posts where status="posted" and platform="youtube" and posted_at>? and stats_at<? '
           + ('and user_id=? ' if user_id else '') + 'order by posted_at desc limit 500')
    args = (since, time.time() - 2 * 3600) + ((user_id,) if user_id else ())
    by_channel = {}
    for p in db.q(sql, args):
        ch = _post_channel(p)
        if ch and p['external_id']:
            by_channel.setdefault(ch['id'], (ch, []))[1].append(p)
    for ch, posts in by_channel.values():
        for i in range(0, len(posts), 50):
            batch = posts[i:i + 50]
            try:
                got = platforms.yt_stats(ch, [p['external_id'] for p in batch])
            except Exception as err:
                print('stats failed', ch['name'], str(err)[:200])
                break
            for p in batch:
                st = got.get(p['external_id'], {})
                db.run('update posts set views=?, likes=?, comments=?, stats_at=? where id=?',
                       (st.get('views', p['views']), st.get('likes', p['likes']), st.get('comments', p['comments']),
                        time.time(), p['id']))


def _stats_loop():
    time.sleep(120)
    while True:
        try:
            refresh_stats()
        except Exception:
            traceback.print_exc()
        time.sleep(3 * 3600)


# ---------- cleanup ----------

def delete_job(job_id):
    db.run('delete from posts where clip_id in (select id from clips where job_id=?)', (job_id,))
    db.run('delete from clips where job_id=?', (job_id,))
    db.run('delete from jobs where id=?', (job_id,))
    shutil.rmtree(job_dir(job_id), ignore_errors=True)


def _cleanup_loop():
    """Delete clip files nobody posted within 7 days, to keep the disk free."""
    while True:
        cutoff = time.time() - 7 * 86400
        for clip in db.q('select id, file, status from clips where created_at<? and file != ""', (cutoff,)):
            if not db.one('select id from posts where clip_id=? and status in ("waiting","posting")', (clip['id'],)):
                Path(clip['file']).unlink(missing_ok=True)
                db.update_clip(clip['id'], file='', status='posted' if clip['status'] == 'posted' else 'expired')
        time.sleep(3600)
