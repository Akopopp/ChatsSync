import json
import os
import shutil
import threading
import time
import traceback
from datetime import datetime, timedelta, timezone
from pathlib import Path

from . import ai, db, media, platforms

JOBS = db.DATA / 'jobs'
MIN_FREE_GB = float(os.environ.get('MIN_FREE_GB', '8'))
YT_DAILY_LIMIT = int(os.environ.get('YT_DAILY_LIMIT', '95'))
DEFAULT_MINUTES = 20  # assumed length while a linked video's length is still unknown
_wake = threading.Event()


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


def estimate(job, settings=None):
    """Seconds of work for each stage of a job."""
    rate = db.rates()
    settings = settings or db.settings(job['user_id'])
    length = job['duration'] or DEFAULT_MINUTES * 60
    clips = int(settings['clips_per_video'])
    clip_len = (float(settings['clip_min']) + float(settings['clip_max'])) / 2
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
    db.run('update jobs set status="queued", stage="", step="Waiting" where status="working"')
    db.run('update posts set status="waiting" where status="posting"')
    for target in (_job_loop, _post_loop, _cleanup_loop):
        threading.Thread(target=target, daemon=True).start()


def wake():
    _wake.set()


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
        title, duration = media.metadata(job['source'])
        user = db.one('select max_minutes from users where id=?', (job['user_id'],))
        db.update_job(job_id, title=title[:200] or job['title'], duration=duration)
        if duration and user['max_minutes'] and duration > user['max_minutes'] * 60:
            db.update_job(job_id, status='failed', error=f'Video is longer than your limit of {user["max_minutes"]} minutes.')
    except Exception as err:
        if 'Sign in to confirm' in str(err) and db.one('select status from jobs where id=?', (job_id,))['status'] == 'queued':
            db.update_job(job_id, status='failed', finished_at=time.time(), error=(
                'YouTube blocked the server from downloading this video. Download it on your phone or PC and upload '
                'the file here instead, or use the Google Drive link from the campaign.'))


def _stage(job_id, stage, step):
    db.update_job(job_id, stage=stage, step=step, stage_started=time.time(), progress=0)


def process(job_id):
    job = db.one('select * from jobs where id=?', (job_id,))
    user = db.one('select * from users where id=?', (job['user_id'],))
    settings = db.settings(job['user_id'])
    folder = job_dir(job_id)
    folder.mkdir(parents=True, exist_ok=True)
    db.update_job(job_id, status='working', started_at=time.time(), error='')
    try:
        if media.free_gb() < MIN_FREE_GB:
            raise media.JobError('The server is busy with storage right now. Please try again in a while.')
        for old in db.q('select file from clips where job_id=?', (job_id,)):
            if old['file']:
                Path(old['file']).unlink(missing_ok=True)
        db.run('delete from clips where job_id=?', (job_id,))
        limit = user['max_minutes'] or 300
        src = next(folder.glob('upload.*'), None) or next(folder.glob('source.mp4'), None)
        if src is None:
            _stage(job_id, 'download', 'Downloading the video')
            t0 = time.time()
            src, title = media.download(job['source'], job['source_type'], folder, limit)
            if title:
                db.update_job(job_id, title=title[:200])
        else:
            t0 = None
        info = media.probe(src)
        if t0:
            learn('download', time.time() - t0, info['duration'])
        db.update_job(job_id, duration=info['duration'])
        if info['duration'] > limit * 60:
            raise media.JobError(f'Video is longer than your limit of {limit} minutes.')

        _stage(job_id, 'transcribe', 'Listening to the video and writing captions')
        words_file = folder / 'words.json'
        if words_file.exists():
            words = json.loads(words_file.read_text())
        else:
            t0 = time.time()
            words, _ = media.transcribe(src, settings['language'], duration=info['duration'],
                                        on_progress=lambda p: db.update_job(job_id, progress=round(p, 3)))
            learn('transcribe', time.time() - t0, info['duration'])
            words_file.write_text(json.dumps(words))
        if len(words) < 30:
            raise media.JobError('Not enough speech in this video to make clips.')

        _stage(job_id, 'pick', 'Finding the best moments')
        t0 = time.time()
        picks, used_ai = ai.pick_clips(words, settings)
        learn('pick', time.time() - t0, 1)
        if not picks:
            raise media.JobError('No good clips found. Try different clip lengths in Settings.')
        job = db.one('select * from jobs where id=?', (job_id,))
        clip_ids = [db.run(
            'insert into clips(job_id, user_id, start, end, title, hook, reason, score, meta, status, created_at) '
            'values(?,?,?,?,?,?,?,?,?,?,?)',
            (job_id, job['user_id'], p['start'], p['end'], p['title'] or job['title'][:90], p['hook'], p['reason'],
             p['score'], json.dumps(p.get('meta', {})), 'rendering', time.time())) for p in picks]

        _stage(job_id, 'render', 'Editing clips')
        db.update_job(job_id, clips_total=len(clip_ids), clips_done=0)
        rendered = 0
        t0 = time.time()
        for n, clip_id in enumerate(clip_ids, 1):
            db.update_job(job_id, step=f'Editing clip {n} of {len(clip_ids)}', clips_done=n - 1)
            clip = db.one('select * from clips where id=?', (clip_id,))
            out = folder / f'clip-{clip_id}.mp4'
            try:
                thumb = media.render(src, out, clip['start'], clip['end'], words, clip['hook'], info, settings)
                db.update_clip(clip_id, file=str(out), thumb=str(thumb), status='ready')
                rendered += clip['end'] - clip['start']
            except Exception as err:
                db.update_clip(clip_id, status='failed', error=str(err)[:500])
        learn('render', time.time() - t0, rendered)
        src.unlink(missing_ok=True)
        note = '' if used_ai else 'Clips were picked without AI.'
        db.update_job(job_id, status='done', stage='', step=note, finished_at=time.time(), clips_done=len(clip_ids))
        if settings['upload_mode'] == 'auto':
            for clip_id in clip_ids:
                if db.one('select status from clips where id=?', (clip_id,))['status'] == 'ready':
                    approve(clip_id)
    except Exception as err:
        db.update_job(job_id, status='failed', stage='', step='', error=str(err)[:600], finished_at=time.time())
        for leftover in list(folder.glob('source.*')) + list(folder.glob('upload.*')) + list(folder.glob('*.part')):
            leftover.unlink(missing_ok=True)


# ---------- posting ----------

def next_slot(user_id, platform, gap_hours):
    last = db.one('select max(due_at) as t from posts where user_id=? and platform=? and status != "failed"',
                  (user_id, platform))
    soonest = time.time() + 60
    if gap_hours > 0 and last and last['t']:
        return max(soonest, last['t'] + gap_hours * 3600)
    return soonest


def approve(clip_id):
    clip = db.one('select * from clips where id=?', (clip_id,))
    settings = db.settings(clip['user_id'])
    gap = float(settings['schedule_gap_hours'] or 0)
    linked = platforms.connected(clip['user_id'])
    targets = [p for p in platforms.NAMES if settings.get(f'post_{p}') == '1' and linked[p]]
    if not targets:
        db.update_clip(clip_id, error='Connect at least one account in Settings first.')
        return False
    for platform in targets:
        if not db.one('select id from posts where clip_id=? and platform=? and status != "failed"', (clip_id, platform)):
            db.run('insert into posts(clip_id, user_id, platform, due_at) values(?,?,?,?)',
                   (clip_id, clip['user_id'], platform, next_slot(clip['user_id'], platform, gap)))
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


def _post_loop():
    while True:
        due = db.one('select * from posts where status="waiting" and due_at<=? order by due_at limit 1', (time.time(),))
        if not due:
            time.sleep(20)
            continue
        clip = db.one('select * from clips where id=?', (due['clip_id'],))
        if not clip or not clip['file'] or not Path(clip['file']).exists():
            db.run('update posts set status="failed", error="Clip file is gone." where id=?', (due['id'],))
            continue
        if due['platform'] == 'youtube':
            date, count = yt_today()
            if count >= YT_DAILY_LIMIT:
                db.run('update posts set due_at=?, error=? where id=?', (time.time() + 3600,
                       'YouTube daily upload limit reached. It will post automatically later.', due['id']))
                continue
        db.run('update posts set status="posting", tries=tries+1 where id=?', (due['id'],))
        try:
            ext_id, url = platforms.post(due['platform'], due['user_id'], clip, db.settings(due['user_id']),
                                         platforms.public_link(clip['id']))
            db.run('update posts set status="posted", external_id=?, url=?, error="", posted_at=? where id=?',
                   (ext_id, url, time.time(), due['id']))
            if due['platform'] == 'youtube':
                date, count = yt_today()
                db.set_stat('yt_day', {'date': date, 'count': count + 1})
        except Exception as err:
            tries = due['tries'] + 1
            if tries < 3:
                db.run('update posts set status="waiting", due_at=?, error=? where id=?',
                       (time.time() + 600 * tries, f'Retrying: {str(err)[:300]}', due['id']))
            else:
                db.run('update posts set status="failed", error=? where id=?', (str(err)[:400], due['id']))
        _finish_clip(clip['id'])


def _finish_clip(clip_id):
    posts = db.q('select status from posts where clip_id=?', (clip_id,))
    if any(p['status'] in ('waiting', 'posting') for p in posts):
        return
    clip = db.one('select * from clips where id=?', (clip_id,))
    if all(p['status'] == 'posted' for p in posts):
        Path(clip['file']).unlink(missing_ok=True)
        db.update_clip(clip_id, status='posted', file='')
    else:
        db.update_clip(clip_id, status='ready', error='Some posts failed. Check below and try again.')


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
        for clip in db.q('select id, file from clips where created_at<? and file != ""', (cutoff,)):
            if not db.one('select id from posts where clip_id=? and status in ("waiting","posting")', (clip['id'],)):
                Path(clip['file']).unlink(missing_ok=True)
                db.update_clip(clip['id'], file='', status='expired')
        time.sleep(3600)
