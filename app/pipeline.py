import json
import os
import shutil
import threading
import time
import traceback
from datetime import datetime, timedelta, timezone
from pathlib import Path

from . import agent, ai, db, edits, media, platforms

JOBS = db.DATA / 'jobs'
MIN_FREE_GB = float(os.environ.get('MIN_FREE_GB', '8'))
YT_DAILY_LIMIT = int(os.environ.get('YT_DAILY_LIMIT', '95'))
DEFAULT_MINUTES = 20  # assumed length while a linked video's length is still unknown
PAD = 12  # seconds of footage kept on both sides of a clip, so it can be trimmed longer later
RAW_KEEP_HOURS = 48  # footage kept this long for edits (links can always be fetched again)
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
    db.run('update clips set status="reedit" where status="rendering" and job_id in (select id from jobs where status="done")')
    db.run('update posts set status="waiting" where status="posting"')
    for target in (_job_loop, _post_loop, _cleanup_loop):
        threading.Thread(target=target, daemon=True).start()


def wake():
    _wake.set()


def _job_loop():
    while True:
        waiting = db.one('select id from clips where status="reedit" order by edit_at limit 1')
        if waiting:  # people wait on the editor page, and one clip is quick, so edits go first
            try:
                rerender(waiting['id'])
            except Exception:
                traceback.print_exc()
            continue
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


def job_settings(job):
    """The user's settings with the job's campaign rules on top, and the campaign."""
    campaign = db.campaign(job.get('campaign_id'), job['user_id'])
    return agent.effective(db.settings(job['user_id']), campaign), campaign


def clip_settings(clip):
    job = db.one('select * from jobs where id=?', (clip['job_id'],))
    settings, campaign = job_settings(job)
    settings['post_language'] = (campaign or {}).get('language') or job.get('language') or ''
    return settings, campaign


def choose_clips(words, loud, settings, campaign):
    """Pick clips with the built-in rules; when AI is on and a key is set, its picks compete in the same ranking."""
    trend_list = agent.trends((campaign or {}).get('country', ''), db)
    ctx = agent.context(words, loud, settings, campaign, trend_list)
    from_ai, used_ai = [], False
    if db.site().get('picker') != 'rules':
        try:
            from_ai = ai.candidates(words, settings) or []
            used_ai = bool(from_ai)
        except Exception as err:  # the rules still work without AI
            print('AI pick failed:', err)
    by_span = {(c['start'], c['end']): c for c in from_ai}
    chosen = agent.pick(words, ctx, int(settings['clips_per_video']), float(settings['clip_min']),
                        float(settings['clip_max']), [(c['start'], c['end'], c['score']) for c in from_ai])
    picks = []
    for c in chosen:
        why = c['why']
        found = by_span.get((c['start'], c['end'])) if c['source'] == 'ai' else None
        if found:
            pick = {**found, 'score': why['total'], 'meta': {**found['meta'], 'why': why}}
        else:
            text = agent.write_text(words, c['start'], c['end'], words, campaign, trend_list)
            pick = {'start': c['start'], 'end': c['end'], 'title': text['title'], 'hook': text['hook'],
                    'reason': ' '.join(why['notes'][:2]) or 'High score on hook, energy and value.', 'score': why['total'],
                    'meta': {'description': text['description'], 'tags': text['tags'], 'hashtags': text['hashtags'], 'why': why}}
        picks.append(pick)
    return picks, used_ai


def process(job_id):
    job = db.one('select * from jobs where id=?', (job_id,))
    user = db.one('select * from users where id=?', (job['user_id'],))
    settings, campaign = job_settings(job)
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

        _stage(job_id, 'transcribe', 'Listening to the video and writing captions')
        words_file = folder / 'words.json'
        if words_file.exists():
            words = json.loads(words_file.read_text())
        else:
            t0 = time.time()
            words, language, loud = media.transcribe(listen, settings['language'], duration=duration,
                                                     on_progress=lambda p: db.update_job(job_id, progress=round(p, 3)))
            learn('transcribe', time.time() - t0, duration)
            words_file.write_text(json.dumps(words))
            (folder / 'loud.json').write_text(json.dumps(loud))
            db.update_job(job_id, language=language or '')
        if len(words) < 30:
            raise media.JobError('Not enough speech in this video to make clips.')

        _stage(job_id, 'pick', 'Finding the best moments')
        t0 = time.time()
        loud_file = folder / 'loud.json'
        picks, used_ai = choose_clips(words, json.loads(loud_file.read_text()) if loud_file.exists() else [], settings, campaign)
        learn('pick', time.time() - t0, 1)
        if not picks:
            raise media.JobError('No good clips found. Try different clip lengths in Settings.')
        job = db.one('select * from jobs where id=?', (job_id,))
        clip_ids = [db.run(
            'insert into clips(job_id, user_id, start, end, title, hook, reason, score, meta, status, created_at) '
            'values(?,?,?,?,?,?,?,?,?,?,?)',
            (job_id, job['user_id'], p['start'], p['end'], p['title'] or job['title'][:90], p['hook'], p['reason'],
             p['score'], json.dumps({**p.get('meta', {}), 'edit': edits.defaults(p, settings)}), 'rendering',
             time.time())) for p in picks]

        _stage(job_id, 'render', 'Editing clips')
        db.update_job(job_id, clips_total=len(clip_ids), clips_done=0)
        rendered = 0
        t0 = time.time()
        for n, clip_id in enumerate(clip_ids, 1):
            db.update_job(job_id, step=f'Editing clip {n} of {len(clip_ids)}', clips_done=n - 1)
            clip = db.one('select * from clips where id=?', (clip_id,))
            try:
                if parts:
                    try:
                        raw = raw_from_link(job, clip_id, clip['start'], clip['end'], session)
                    except media.JobError as err:
                        if str(err) == media.BLOCKED:
                            raise
                        # this site can't send parts: fetch the whole video once and cut locally
                        db.update_job(job_id, step='Downloading the full video')
                        src, _ = media.download(job['source'], job['source_type'], folder, limit, session)
                        parts = False
                if not parts:
                    raw = raw_from_file(src, folder, clip_id, clip['start'], clip['end'], duration)
                meta = edits.meta_of(clip)
                meta['raw'] = raw
                db.update_clip(clip_id, meta=json.dumps(meta))
                render_clip(clip_id, words)
                rendered += clip['end'] - clip['start']
            except Exception as err:
                db.update_clip(clip_id, status='failed', error=str(err)[:500])
        learn('render', time.time() - t0, rendered)
        for leftover in [src, listen] + list(folder.glob('part-*')):
            if leftover:
                Path(leftover).unlink(missing_ok=True)  # each clip keeps its own footage (raw-*) for edits
        if not any(db.one('select status from clips where id=?', (c,))['status'] == 'ready' for c in clip_ids):
            failed = db.one('select error from clips where job_id=? and error != "" limit 1', (job_id,))
            raise media.JobError(failed['error'] if failed else 'Clips could not be edited.')
        db.update_job(job_id, status='done', stage='', step='', finished_at=time.time(), clips_done=len(clip_ids))
        if settings['upload_mode'] == 'auto':
            for clip_id in clip_ids:
                if db.one('select status from clips where id=?', (clip_id,))['status'] == 'ready':
                    approve(clip_id)
    except Exception as err:
        db.update_job(job_id, status='failed', stage='', step='', error=str(err)[:600], finished_at=time.time())
        for pattern in ('source.*', 'upload.*', 'audio-src.*', 'audio.f32', 'part-*', 'raw-*', '*.part'):
            for leftover in folder.glob(pattern):
                leftover.unlink(missing_ok=True)


# ---------- clip footage, rendering and edits ----------

def raw_from_link(job, clip_id, start, end, session):
    """Download just this clip's part of the video (plus some extra on both sides)."""
    folder = job_dir(job['id'])
    for old in folder.glob(f'raw-{clip_id}.*'):
        old.unlink(missing_ok=True)
    a = max(start - PAD, 0)
    b = min(end + PAD, job['duration']) if job['duration'] else end + PAD
    path = media.download_section(job['source'], folder / f'raw-{clip_id}', a, b, session)
    return {'file': str(path), 'offset': round(a, 2), 'end': round(b, 2), 'at': time.time()}


def raw_from_file(src, folder, clip_id, start, end, duration):
    a, b = max(start - PAD, 0), min(end + PAD, duration or end + PAD)
    path = media.cut_raw(src, folder / f'raw-{clip_id}.mp4', a, b)
    return {'file': str(path), 'offset': round(a, 2), 'end': round(b, 2), 'at': time.time()}


def music_path(user_id, name):
    if not name:
        return None
    path = db.DATA / 'music' / str(user_id) / Path(name).name
    return path if path.exists() else None


def render_clip(clip_id, words):
    """Render a clip from its saved footage with its current edit, replacing the old file."""
    clip = db.one('select * from clips where id=?', (clip_id,))
    meta = edits.meta_of(clip)
    edit = edits.get(clip, clip_settings(clip)[0])
    raw = meta['raw']
    info = media.probe(raw['file'])
    faces = meta.get('faces')
    if edit['layout'] != 'fit' and info['height'] < info['width'] * 1.5 and not (
            faces and faces['from'] <= edit['start'] + 0.5 and faces['to'] >= edit['end'] - 0.5):
        a, b = max(edit['start'] - 3, raw['offset']), min(edit['end'] + 3, raw['end'])
        faces = {'from': a, 'to': b, 'samples': media.face_samples(
            Path(raw['file']), a - raw['offset'], b - raw['offset'], info, raw['offset'])}
    out = job_dir(clip['job_id']) / f'clip-{clip_id}-{int(time.time())}.mp4'
    thumb, layout, length = media.render(
        Path(raw['file']), out, edit, edits.caption_words(words, edit), raw['offset'], info,
        faces['samples'] if faces else None, music_path(clip['user_id'], edit.get('music')))
    meta.update(edit=edit, faces=faces, layout=layout, length=length)
    db.update_clip(clip_id, file=str(out), thumb=str(thumb), status='ready', error='', meta=json.dumps(meta),
                   start=edit['start'], end=edit['end'], hook=edit['hook'])
    for old in (clip['file'], clip['thumb']):
        if old and old not in (str(out), str(thumb)):
            Path(old).unlink(missing_ok=True)


def request_edit(clip_id, edit):
    clip = db.one('select * from clips where id=?', (clip_id,))
    meta = edits.meta_of(clip)
    meta['edit'] = edit
    db.update_clip(clip_id, meta=json.dumps(meta), status='reedit', error='', edit_at=time.time())
    wake()


def can_edit_video(clip, job):
    raw = edits.meta_of(clip).get('raw') or {}
    return job['source_type'] == 'link' or bool(raw.get('file') and Path(raw['file']).exists())


def rerender(clip_id):
    clip = db.one('select * from clips where id=?', (clip_id,))
    job = db.one('select * from jobs where id=?', (clip['job_id'],))
    db.update_clip(clip_id, status='rendering')
    try:
        words = json.loads((job_dir(job['id']) / 'words.json').read_text())
        meta = edits.meta_of(clip)
        edit, raw = meta['edit'], meta.get('raw') or {}
        covered = raw.get('file') and Path(raw['file']).exists() and raw['offset'] <= edit['start'] + 0.05 \
            and raw['end'] >= edit['end'] - 0.05
        if not covered:
            if job['source_type'] != 'link':
                raise media.JobError('The original footage of this clip was removed from the server, so the video '
                                     'can no longer be changed. The title and post text can still be edited.')
            meta['raw'] = raw_from_link(job, clip_id, edit['start'], edit['end'], f'c{clip_id}t{int(time.time())}')
            db.update_clip(clip_id, meta=json.dumps(meta))
        render_clip(clip_id, words)
    except Exception as err:
        traceback.print_exc()
        fresh = db.one('select file from clips where id=?', (clip_id,))
        has_file = fresh['file'] and Path(fresh['file']).exists()
        db.update_clip(clip_id, status='ready' if has_file else 'failed', error=f'Changes not applied: {err}'[:500])


def drop_raw(clip_id):
    clip = db.one('select meta from clips where id=?', (clip_id,))
    meta = edits.meta_of(clip)
    raw = meta.get('raw')
    if raw and raw.get('file'):
        Path(raw['file']).unlink(missing_ok=True)
        meta['raw'] = {**raw, 'file': ''}
        db.update_clip(clip_id, meta=json.dumps(meta))


# ---------- posting ----------

def next_slot(user_id, platform, gap_hours, country=''):
    last = db.one('select max(due_at) as t from posts where user_id=? and platform=? and status != "failed"',
                  (user_id, platform))
    soonest = time.time() + 60
    if gap_hours > 0 and last and last['t']:
        soonest = max(soonest, last['t'] + gap_hours * 3600)
    return agent.next_peak(soonest, country) if country else soonest


def post_targets(clip, settings):
    linked = platforms.connected(clip['user_id'])
    return [p for p in platforms.NAMES if settings.get(f'post_{p}') == '1' and linked[p]]


def clip_checks(clip, settings, campaign, targets=None):
    text = platforms.post_text(clip, settings)
    meta = edits.meta_of(clip)
    length = meta.get('length') or (clip['end'] - clip['start'])
    return agent.checks(clip, text, campaign, length, targets if targets is not None else post_targets(clip, settings))


def approve(clip_id):
    clip = db.one('select * from clips where id=?', (clip_id,))
    settings, campaign = clip_settings(clip)
    gap = float(settings['schedule_gap_hours'] or 0)
    targets = post_targets(clip, settings)
    if not targets:
        db.update_clip(clip_id, error='Connect at least one account in Settings first.')
        return False
    problems = [msg for ok, must, msg in clip_checks(clip, settings, campaign, targets) if must and not ok]
    if problems:
        db.update_clip(clip_id, error='Fix before posting: ' + ' '.join(problems))
        return False
    for platform in targets:
        if not db.one('select id from posts where clip_id=? and platform=? and status != "failed"', (clip_id, platform)):
            db.run('insert into posts(clip_id, user_id, platform, due_at) values(?,?,?,?)',
                   (clip_id, clip['user_id'], platform, next_slot(clip['user_id'], platform, gap,
                                                                  (campaign or {}).get('country', ''))))
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
            ext_id, url = platforms.post(due['platform'], due['user_id'], clip, clip_settings(clip)[0],
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
        drop_raw(clip_id)
    else:
        db.update_clip(clip_id, status='ready', error='Some posts failed. Check below and try again.')


# ---------- cleanup ----------

def delete_job(job_id):
    db.run('delete from posts where clip_id in (select id from clips where job_id=?)', (job_id,))
    db.run('delete from clips where job_id=?', (job_id,))
    db.run('delete from jobs where id=?', (job_id,))
    shutil.rmtree(job_dir(job_id), ignore_errors=True)


def _cleanup_loop():
    """Delete clip footage after 2 days and clip files nobody posted within 7 days, to keep the disk free."""
    while True:
        stale = time.time() - RAW_KEEP_HOURS * 3600
        for clip in db.q('select id, meta, edit_at from clips where meta like \'%"raw"%\' and status not in ("reedit", "rendering")'):
            raw = edits.meta_of(clip).get('raw') or {}
            if raw.get('file') and max(raw.get('at', 0), clip['edit_at'] or 0) < stale:
                drop_raw(clip['id'])
        cutoff = time.time() - 7 * 86400
        for clip in db.q('select id, file from clips where created_at<? and file != ""', (cutoff,)):
            if not db.one('select id from posts where clip_id=? and status in ("waiting","posting")', (clip['id'],)):
                Path(clip['file']).unlink(missing_ok=True)
                db.update_clip(clip['id'], file='', status='expired')
        time.sleep(3600)
