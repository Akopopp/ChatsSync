import asyncio
import json
import os
import threading
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse, HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.middleware.sessions import SessionMiddleware

from . import agent, ai, auth, brand, db, edit, fields, geo, media, notify, pipeline, platforms

ROOT = Path(__file__).resolve().parent
PKT = timezone(timedelta(hours=5))
APP_NAME = os.environ.get('APP_NAME', 'ChatsSync Clips')

db.init()
auth.bootstrap_admin()
app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
app.add_middleware(SessionMiddleware, secret_key=platforms.secret_key(), max_age=30 * 86400, same_site='lax')
app.mount('/static', StaticFiles(directory=ROOT / 'static'), name='static')
templates = Jinja2Templates(directory=ROOT / 'templates')


def when(ts):
    return datetime.fromtimestamp(ts, PKT).strftime('%d %b, %I:%M %p') if ts else ''


def day(ts):
    return datetime.fromtimestamp(ts, PKT).strftime('%d %b %Y') if ts else 'Never'


def dur(sec):
    sec = int(sec or 0)
    return f'{sec // 3600}:{sec % 3600 // 60:02d}:{sec % 60:02d}' if sec >= 3600 else f'{sec // 60}:{sec % 60:02d}'


def eta(sec):
    sec = int(max(sec or 0, 0))
    if sec < 60:
        return 'under a minute'
    if sec < 3600:
        return f'{round(sec / 60)} min'
    return f'{sec // 3600} h {sec % 3600 // 60} min'


templates.env.filters.update(when=when, day=day, dur=dur, eta=eta)
templates.env.globals.update(APP_NAME=APP_NAME, NAMES=platforms.NAMES, COUNTRIES=geo.COUNTRIES, LANGS=geo.LANGS,
                             CATEGORIES=geo.CATEGORIES, SECTIONS=fields.SECTIONS, HAS_AI=ai.ai_ready)


@app.on_event('startup')
def boot():
    pipeline.start()


# ---------- helpers ----------

def current_user(request: Request):
    user_id = request.session.get('uid')
    return db.one('select * from users where id=?', (user_id,)) if user_id else None


def need_user(request: Request, admin=False):
    user = current_user(request)
    if not user or not user['active'] and user['role'] != 'admin':
        raise HTTPException(status_code=401)
    if admin and user['role'] != 'admin':
        raise HTTPException(status_code=403)
    return user


def page(request, name, admin=False, **ctx):
    user = current_user(request)
    if not user:
        return RedirectResponse('/login', status_code=303)
    if admin and user['role'] != 'admin':
        return RedirectResponse('/', status_code=303)
    ctx.update(request=request, user=user, settings=db.settings(user['id']), linked=platforms.connected(user['id']),
               free_gb=media.free_gb(), now=time.time(), yt_blocked=db.stat('yt_blocked_at', 0))
    return templates.TemplateResponse(request, name, ctx)


def own_job(user, job_id):
    job = db.one('select * from jobs where id=?', (job_id,))
    if not job or (job['user_id'] != user['id'] and user['role'] != 'admin'):
        raise HTTPException(status_code=404)
    return job


def own_clip(user, clip_id):
    clip = db.one('select * from clips where id=?', (clip_id,))
    if not clip or (clip['user_id'] != user['id'] and user['role'] != 'admin'):
        raise HTTPException(status_code=404)
    return clip


@app.exception_handler(401)
def to_login(request, exc):
    return RedirectResponse('/login', status_code=303)


# ---------- login ----------

@app.get('/login', response_class=HTMLResponse)
def login_form(request: Request):
    error = 'Google sign-in was cancelled. Please try again.' if request.query_params.get('error') == 'google' else ''
    if current_user(request):
        return RedirectResponse('/', status_code=303)
    return templates.TemplateResponse(request, 'login.html', {'request': request, 'error': error,
                                                              'google': auth.google_ready()})


@app.post('/login')
def login(request: Request, email: str = Form(...), password: str = Form(...)):
    user = auth.login(email, password)
    if not user:
        time.sleep(1)
        return templates.TemplateResponse(request, 'login.html', {'request': request, 'error': 'Wrong email or password.',
                                                                  'google': auth.google_ready()}, status_code=401)
    request.session['uid'] = user['id']
    return RedirectResponse('/', status_code=303)


@app.get('/logout')
def logout(request: Request):
    request.session.clear()
    return RedirectResponse('/login', status_code=303)


@app.get('/auth/google/start')
def google_start(request: Request):
    if not auth.google_ready():
        return RedirectResponse('/login', status_code=303)
    import secrets
    state = secrets.token_urlsafe(16)
    request.session['google_state'] = state
    return RedirectResponse(auth.google_url(state), status_code=303)


@app.get('/auth/google/callback')
def google_callback(request: Request, code: str = '', state: str = ''):
    if not code or state != request.session.pop('google_state', None):
        return RedirectResponse('/login?error=google', status_code=303)
    try:
        user, problem = auth.google_login(auth.google_profile(code))
    except Exception as err:
        print('google login failed', err)
        user, problem = None, 'Google sign-in failed. Please try again.'
    if not user:
        return templates.TemplateResponse(request, 'login.html', {'request': request, 'error': problem,
                                                                  'google': auth.google_ready()}, status_code=403)
    request.session['uid'] = user['id']
    return RedirectResponse('/', status_code=303)


# ---------- videos ----------

def user_jobs(user_id, limit):
    return db.q("""select j.*, (select count(*) from clips c where c.job_id=j.id and c.status not in ('failed','rejected')) as clip_count,
                   (select count(*) from posts p join clips c on c.id=p.clip_id where c.job_id=j.id and p.status='posted') as posted,
                   (select name from campaigns m where m.id=j.campaign_id) as campaign_name
                   from jobs j where j.user_id=? order by j.id desc limit ?""", (user_id, limit))


@app.get('/', response_class=HTMLResponse)
def home(request: Request):
    user = current_user(request)
    if not user:
        return RedirectResponse('/welcome', status_code=303)
    if not user.get('approved', 1):
        return page(request, 'pending.html')
    camps = db.campaigns(user['id']) or [db.default_campaign(user['id'])]
    return page(request, 'home.html', jobs=user_jobs(user['id'], 5), timers=pipeline.timers(),
                problem=auth.access_problem(user), used=auth.videos_this_month(user['id']),
                error=request.query_params.get('error', ''), camps=camps,
                pick=int(request.query_params.get('campaign') or camps[0]['id']))


@app.get('/videos', response_class=HTMLResponse)
def videos(request: Request):
    user = current_user(request)
    if not user:
        return RedirectResponse('/login', status_code=303)
    return page(request, 'videos.html', jobs=user_jobs(user['id'], 200), timers=pipeline.timers(),
                msg=request.query_params.get('msg', ''))


def _campaign_for(user, campaign_id):
    camp = db.campaign(int(campaign_id or 0)) if str(campaign_id or '').isdigit() else None
    if not camp or camp['user_id'] != user['id']:
        camp = db.default_campaign(user['id'])
    return camp


@app.post('/jobs')
async def new_job(request: Request, url: str = Form(''), campaign_id: str = Form(''), file: UploadFile | None = File(None)):
    user = need_user(request)
    problem = auth.access_problem(user)
    if problem:
        return RedirectResponse('/?error=limit', status_code=303)
    camp = _campaign_for(user, campaign_id)
    now = time.time()
    if file is not None and file.filename:
        job_id = db.run('insert into jobs(user_id, source, source_type, title, status, step, created_at, updated_at, campaign_id) '
                        'values(?,?,?,?,?,?,?,?,?)', (user['id'], file.filename, 'upload', Path(file.filename).stem[:150],
                                                      'uploading', 'Uploading', now, now, camp['id']))
        folder = pipeline.job_dir(job_id)
        folder.mkdir(parents=True, exist_ok=True)
        dest = folder / f'upload{Path(file.filename).suffix.lower()[:6] or ".mp4"}'
        with dest.open('wb') as fh:
            while chunk := await file.read(8 * 1024 * 1024):
                fh.write(chunk)
        try:
            info = media.probe(dest)
            db.update_job(job_id, duration=info['duration'], status='queued', step='Waiting')
        except Exception:
            dest.unlink(missing_ok=True)
            db.update_job(job_id, status='failed', error='This file is not a video we can read.')
        pipeline.wake()
        return RedirectResponse(f'/jobs/{job_id}', status_code=303)
    links = [x.strip() for x in url.replace(',', '\n').split() if x.strip().startswith('http')][:30]
    if not links:
        return RedirectResponse('/?error=link', status_code=303)
    made = []
    for link in links:
        if made and auth.access_problem(db.one('select * from users where id=?', (user['id'],))):
            break
        made.append(agent.add_link(user['id'], link, camp['id']))
    pipeline.wake()
    if len(made) == 1:
        return RedirectResponse(f'/jobs/{made[0]}', status_code=303)
    return RedirectResponse(f'/videos?msg=added_{len(made)}', status_code=303)


def clip_rows(job_id):
    clips = db.q('select * from clips where job_id=? and status != "rejected" order by score desc, id', (job_id,))
    for clip in clips:
        clip['posts'] = db.q('select * from posts where clip_id=? order by id', (clip['id'],))
        for p in clip['posts']:
            ch = db.channel(p['channel_id']) if p.get('channel_id') else None
            p['where'] = ch['name'] if ch else platforms.NAMES.get(p['platform'], p['platform'])
        clip['meta'] = json.loads(clip['meta'] or '{}')
    return clips


@app.get('/jobs/{job_id}', response_class=HTMLResponse)
def job_page(request: Request, job_id: int):
    user = current_user(request)
    if not user:
        return RedirectResponse('/login', status_code=303)
    job = own_job(user, job_id)
    camp = db.job_campaign(job)
    clips = clip_rows(job_id)
    for clip in clips:
        clip['text'] = platforms.post_text(clip, camp['s'])
    chans = [c for c in (db.channel(i) for i in camp['channel_ids']) if c]
    return page(request, 'job.html', job=job, clips=clips, timer=pipeline.timers().get(job_id), camp=camp, chans=chans,
                msg=request.query_params.get('msg', ''))


@app.get('/jobs/{job_id}/status')
def job_status(request: Request, job_id: int):
    user = need_user(request)
    job = own_job(user, job_id)
    clips = db.q('select id, status from clips where job_id=?', (job_id,))
    posts = db.q('select p.id, p.status from posts p join clips c on c.id=p.clip_id where c.job_id=?', (job_id,))
    return {'status': job['status'], 'step': job['step'], 'timer': pipeline.timers().get(job_id),
            'sig': job['status'] + ','.join(c['status'] for c in clips) + ','.join(p['status'] for p in posts)}


@app.post('/jobs/{job_id}/retry')
def retry_job(request: Request, job_id: int):
    user = need_user(request)
    own_job(user, job_id)
    db.update_job(job_id, status='queued', step='Waiting', error='', created_at=time.time(), attempts=0)
    pipeline.wake()
    return RedirectResponse(f'/jobs/{job_id}', status_code=303)


@app.post('/jobs/{job_id}/delete')
def remove_job(request: Request, job_id: int):
    user = need_user(request)
    job = own_job(user, job_id)
    if job['status'] == 'working':
        pipeline.stop(job_id)  # stuck or not, end the work on it so the next video can start
    pipeline.delete_job(job_id)
    return RedirectResponse(request.query_params.get('back', '/'), status_code=303)


@app.post('/jobs/{job_id}/post-all')
def post_all(request: Request, job_id: int):
    user = need_user(request)
    own_job(user, job_id)
    for clip in db.q('select id from clips where job_id=? and status="ready"', (job_id,)):
        if not pipeline.approve(clip['id']):
            return RedirectResponse(f'/jobs/{job_id}?msg=nochannel', status_code=303)
    return RedirectResponse(f'/jobs/{job_id}', status_code=303)


# ---------- clips ----------

@app.post('/clips/{clip_id}/save')
async def save_clip(request: Request, clip_id: int):
    user = need_user(request)
    clip = own_clip(user, clip_id)
    form = await request.form()
    meta = json.loads(clip['meta'] or '{}')
    meta['description'] = str(form.get('description', meta.get('description', ''))).strip()[:3000]
    if 'tags' in form:
        meta['tags'] = ai.clean_list(str(form.get('tags', '')), 30, hashtag=False)
    if 'hashtags' in form:
        meta['hashtags'] = ai.clean_list(str(form.get('hashtags', '')).replace(' ', ','), 6, hashtag=True)
    if 'first_comment' in form:
        meta['first_comment'] = str(form.get('first_comment', '')).strip()[:500]
    title = str(form.get('title', clip['title'])).strip()[:100] or clip['title']
    db.update_clip(clip_id, title=title, meta=json.dumps(meta))
    if form.get('post'):
        if not pipeline.approve(clip_id):
            return RedirectResponse(f'/jobs/{clip["job_id"]}?msg=nochannel#clip-{clip_id}', status_code=303)
    return RedirectResponse(f'/jobs/{clip["job_id"]}#clip-{clip_id}', status_code=303)


@app.post('/clips/{clip_id}/rewrite')
def rewrite_clip(request: Request, clip_id: int):
    user = need_user(request)
    clip = own_clip(user, clip_id)
    problem = pipeline.rewrite_text(clip_id)
    msg = 'rewrite_bad' if problem else 'rewrite_ok'
    if problem:
        db.update_clip(clip_id, error=problem[:300])
    return RedirectResponse(f'/jobs/{clip["job_id"]}?msg={msg}#clip-{clip_id}', status_code=303)


@app.post('/clips/{clip_id}/reject')
def reject_clip(request: Request, clip_id: int):
    user = need_user(request)
    clip = own_clip(user, clip_id)
    if clip['file']:
        Path(clip['file']).unlink(missing_ok=True)
    db.run('delete from posts where clip_id=? and status="waiting"', (clip_id,))
    db.update_clip(clip_id, status='rejected', file='')
    return RedirectResponse(f'/jobs/{clip["job_id"]}', status_code=303)


@app.post('/posts/{post_id}/retry')
def retry_post(request: Request, post_id: int):
    user = need_user(request)
    post = db.one('select * from posts where id=?', (post_id,))
    clip = own_clip(user, post['clip_id'])
    if clip['file']:
        pipeline.retry_post(post_id)
    return RedirectResponse(f'/jobs/{clip["job_id"]}#clip-{clip["id"]}', status_code=303)


@app.post('/posts/{post_id}/now')
def post_now(request: Request, post_id: int):
    user = need_user(request)
    post = db.one('select * from posts where id=?', (post_id,))
    clip = own_clip(user, post['clip_id'])
    db.run('update posts set due_at=? where id=? and status="waiting"', (time.time(), post_id))
    return RedirectResponse(f'/jobs/{clip["job_id"]}#clip-{clip["id"]}', status_code=303)


@app.post('/posts/{post_id}/cancel')
def cancel_post(request: Request, post_id: int):
    user = need_user(request)
    post = db.one('select * from posts where id=?', (post_id,))
    clip = own_clip(user, post['clip_id'])
    db.run('delete from posts where id=? and status="waiting"', (post_id,))
    if not db.one('select id from posts where clip_id=? and status in ("waiting","posting")', (clip['id'],)) and clip['status'] == 'approved':
        db.update_clip(clip['id'], status='ready')
    return RedirectResponse(f'/jobs/{clip["job_id"]}#clip-{clip["id"]}', status_code=303)


@app.get('/media/{clip_id}.{ext}')
def clip_media(request: Request, clip_id: int, ext: str):
    user = need_user(request)
    clip = own_clip(user, clip_id)
    path = clip['file'] if ext == 'mp4' else clip['thumb']
    if not path or not Path(path).exists():
        raise HTTPException(status_code=404)
    name = f'clip-{clip_id}.{ext}' if request.query_params.get('dl') else None
    return FileResponse(path, media_type='video/mp4' if ext == 'mp4' else 'image/jpeg', filename=name)


@app.get('/clips/{clip_id}/sheet.jpg')
def clip_sheet(request: Request, clip_id: int):
    """Eight small frames of the clip side by side, for a quick look without loading the video."""
    user = need_user(request)
    clip = own_clip(user, clip_id)
    if not clip['file'] or not Path(clip['file']).exists():
        raise HTTPException(status_code=404)
    out = Path(clip['file']).with_suffix('.sheet.jpg')
    if not out.exists() or out.stat().st_mtime < Path(clip['file']).stat().st_mtime:
        dur = media.media_duration(Path(clip['file'])) or 1
        media.sh(['ffmpeg', '-y', '-v', 'error', '-i', clip['file'], '-vf', f'fps=8/{dur:.2f},scale=200:-2,tile=8x1',
                  '-frames:v', '1', '-q:v', '4', str(out)])
    return FileResponse(out, media_type='image/jpeg', headers={'Cache-Control': 'no-store'})


@app.get('/p/{token}.mp4')
def public_clip(token: str):
    try:
        clip_id = platforms.check_public(token)
    except Exception:
        raise HTTPException(status_code=404)
    clip = db.one('select file from clips where id=?', (clip_id,))
    if not clip or not clip['file'] or not Path(clip['file']).exists():
        raise HTTPException(status_code=404)
    return FileResponse(clip['file'], media_type='video/mp4', headers={'Access-Control-Allow-Origin': '*'})


@app.get('/clips/{clip_id}/public-link')
def clip_public_link(request: Request, clip_id: int):
    """Short-lived link to the clip file, for uploading it by hand on TikTok or Instagram."""
    user = need_user(request)
    clip = own_clip(user, clip_id)
    if not clip['file'] or not Path(clip['file']).exists():
        raise HTTPException(status_code=404)
    return {'url': platforms.public_link(clip_id)}


# ---------- campaigns ----------

def own_campaign(user, campaign_id):
    camp = db.campaign(campaign_id)
    if not camp or (camp['user_id'] != user['id'] and user['role'] != 'admin'):
        raise HTTPException(status_code=404)
    return camp


@app.get('/campaigns', response_class=HTMLResponse)
def campaigns_page(request: Request):
    user = current_user(request)
    if not user:
        return RedirectResponse('/login', status_code=303)
    camps = db.campaigns(user['id']) or [db.default_campaign(user['id'])]
    chans = {c['id']: c for c in db.channels(user['id'])}
    for c in camps:
        c['jobs'] = db.one('select count(*) as n from jobs where campaign_id=?', (c['id'],))['n']
        c['posted'] = db.one('select count(*) as n from posts p join clips k on k.id=p.clip_id join jobs j on j.id=k.job_id '
                             'where j.campaign_id=? and p.status="posted"', (c['id'],))['n']
    return page(request, 'campaigns.html', camps=camps, chans=chans, msg=request.query_params.get('msg', ''))


@app.post('/campaigns/new')
async def campaign_new(request: Request):
    user = need_user(request)
    form = await request.form()
    copy_of = str(form.get('copy', ''))
    if copy_of.isdigit():
        src = own_campaign(user, int(copy_of))
        cid = db.create_campaign(user['id'], f'{src["name"]} (copy)', src['brief'], {**src['s'], 'autopilot': '0'})
    else:
        cid = db.create_campaign(user['id'], str(form.get('name') or 'New campaign'), '', {})
    return RedirectResponse(f'/campaigns/{cid}?msg=new', status_code=303)


@app.get('/campaigns/{campaign_id}', response_class=HTMLResponse)
def campaign_page(request: Request, campaign_id: int):
    user = current_user(request)
    if not user:
        return RedirectResponse('/login', status_code=303)
    camp = own_campaign(user, campaign_id)
    folder = edit.MUSIC / f'c{campaign_id}'
    tracks = sorted(p.name for p in folder.iterdir()) if folder.exists() else []
    return page(request, 'campaign.html', camp=camp, chans=db.channels(camp['user_id']), tracks=tracks,
                msg=request.query_params.get('msg', ''), has_pexels=bool(os.environ.get('PEXELS_API_KEY')),
                emoji_ok=any(Path(p).exists() for p in edit.EMOJI_FONTS))


@app.post('/campaigns/{campaign_id}')
async def campaign_save(request: Request, campaign_id: int):
    user = need_user(request)
    camp = own_campaign(user, campaign_id)
    form = await request.form()
    values = {}
    for key, (label, kind, opts, _) in fields.FIELDS.items():
        if kind == 'switch':
            values[key] = '1' if form.get(key) else '0'
        elif key in form:
            cleaned = fields.clean(key, form.get(key))
            if cleaned is not None:
                values[key] = cleaned
    own = {c['id'] for c in db.channels(camp['user_id'])}
    values['channels'] = ','.join(str(i) for i in form.getlist('channel') if str(i).isdigit() and int(i) in own)
    if float(values.get('clip_max', 60)) < float(values.get('clip_min', 25)) + 5:
        values['clip_max'] = str(int(float(values.get('clip_min', 25)) + 5))
    db.update_campaign(campaign_id, name=str(form.get('name', camp['name'])), brief=str(form.get('brief', '')), values=values)
    return RedirectResponse(f'/campaigns/{campaign_id}?msg=saved', status_code=303)


@app.post('/campaigns/{campaign_id}/delete')
def campaign_delete(request: Request, campaign_id: int):
    user = need_user(request)
    camp = own_campaign(user, campaign_id)
    if len(db.campaigns(camp['user_id'])) <= 1:
        return RedirectResponse(f'/campaigns/{campaign_id}?msg=last', status_code=303)
    db.run('delete from campaigns where id=?', (campaign_id,))
    keep = db.default_campaign(camp['user_id'])
    db.run('update jobs set campaign_id=? where campaign_id=?', (keep['id'], campaign_id))
    return RedirectResponse('/campaigns?msg=deleted', status_code=303)


@app.post('/campaigns/{campaign_id}/music')
async def campaign_music(request: Request, campaign_id: int):
    user = need_user(request)
    own_campaign(user, campaign_id)
    form = await request.form()
    folder = edit.MUSIC / f'c{campaign_id}'
    folder.mkdir(parents=True, exist_ok=True)
    remove = str(form.get('remove', ''))
    if remove:
        target = folder / Path(remove).name
        target.unlink(missing_ok=True)
        return RedirectResponse(f'/campaigns/{campaign_id}?msg=music_removed#music', status_code=303)
    added = 0
    for up in form.getlist('tracks'):
        name = Path(getattr(up, 'filename', '') or '').name
        if not name or Path(name).suffix.lower() not in ('.mp3', '.m4a', '.wav', '.aac', '.ogg'):
            continue
        data = await up.read()
        if len(data) > 30 * 1024 * 1024:
            continue
        (folder / name).write_bytes(data)
        added += 1
    return RedirectResponse(f'/campaigns/{campaign_id}?msg=music_{added}#music', status_code=303)


@app.post('/campaigns/{campaign_id}/check')
def campaign_check(request: Request, campaign_id: int):
    user = need_user(request)
    camp = own_campaign(user, campaign_id)
    added = pipeline.check_sources(camp, first_run_takes=1)
    return RedirectResponse(f'/campaigns/{campaign_id}?msg=checked_{added}#autopilot', status_code=303)


# ---------- channels ----------

def own_channel(user, channel_id):
    ch = db.channel(channel_id)
    if not ch or (ch['user_id'] != user['id'] and user['role'] != 'admin'):
        raise HTTPException(status_code=404)
    return ch


@app.get('/channels', response_class=HTMLResponse)
def channels_page(request: Request):
    user = current_user(request)
    if not user:
        return RedirectResponse('/login', status_code=303)
    chans = db.channels(user['id'])
    day = time.time() - 86400
    for c in chans:
        c['today'] = db.one('select count(*) as n from posts where channel_id=? and status="posted" and posted_at>?', (c['id'], day))['n']
        c['waiting'] = db.one('select count(*) as n from posts where channel_id=? and status="waiting"', (c['id'],))['n']
        c['full'] = platforms.full_access(c) if c['platform'] == 'youtube' else True
        c['camps'] = [m['name'] for m in db.campaigns(user['id']) if c['id'] in m['channel_ids']]
    return page(request, 'channels.html', chans=chans, msg=request.query_params.get('msg', ''),
                ready={p: platforms.configured(p) for p in platforms.NAMES})


@app.post('/channels/{channel_id}/limit')
def channel_limit(request: Request, channel_id: int, per_day: int = Form(10)):
    user = need_user(request)
    ch = own_channel(user, channel_id)
    db.run('update channels set daily_limit=?, blocked_until=0, note="" where id=?', (min(max(per_day, 1), 100), ch['id']))
    return RedirectResponse('/channels?msg=saved', status_code=303)


@app.post('/channels/{channel_id}/disconnect')
def channel_disconnect(request: Request, channel_id: int):
    user = need_user(request)
    ch = own_channel(user, channel_id)
    db.run('delete from posts where channel_id=? and status="waiting"', (ch['id'],))
    db.run('delete from channels where id=?', (ch['id'],))
    for camp in db.campaigns(ch['user_id']):
        if ch['id'] in camp['channel_ids']:
            db.update_campaign(camp['id'], values={'channels': ','.join(str(i) for i in camp['channel_ids'] if i != ch['id'])})
    return RedirectResponse('/channels?msg=removed', status_code=303)


@app.get('/channels/{channel_id}/setup', response_class=HTMLResponse)
def channel_setup(request: Request, channel_id: int):
    user = current_user(request)
    if not user:
        return RedirectResponse('/login', status_code=303)
    ch = own_channel(user, channel_id)
    camps = db.campaigns(ch['user_id'])
    pick = request.query_params.get('campaign', '')
    camp = next((c for c in camps if str(c['id']) == pick), None) or \
        next((c for c in camps if ch['id'] in c['channel_ids']), None) or (camps[0] if camps else None)
    current = {}
    if ch['platform'] == 'youtube':
        try:
            item = platforms.yt_branding(ch)
            current = (item.get('brandingSettings') or {}).get('channel') or {}
            current['banner'] = ((item.get('brandingSettings') or {}).get('image') or {}).get('bannerExternalUrl', '')
        except Exception as err:
            current = {'error': str(err)[:200]}
    return page(request, 'channel_setup.html', ch=ch, camps=camps, camp=camp, profile=ch['d'].get('profile') or {},
                current=current, full=platforms.full_access(ch) if ch['platform'] == 'youtube' else False,
                msg=request.query_params.get('msg', ''), err=request.query_params.get('err', ''),
                themes=brand.THEMES, theme=ch['d'].get('theme', 'blue'))


def _setup_back(ch_id, camp_id, msg, err=''):
    from urllib.parse import quote
    extra = f'&err={quote(err[:200])}' if err else ''
    return RedirectResponse(f'/channels/{ch_id}/setup?campaign={camp_id}&msg={msg}{extra}', status_code=303)


@app.post('/channels/{channel_id}/setup/write')
def channel_write(request: Request, channel_id: int, campaign_id: int = Form(0)):
    user = need_user(request)
    ch = own_channel(user, channel_id)
    camp = db.campaign(campaign_id) or db.default_campaign(ch['user_id'])
    try:
        profile = ai.channel_profile(ch['name'], camp['s'], camp['brief'])
    except Exception as err:
        return _setup_back(ch['id'], camp['id'], 'write_bad', str(err))
    db.set_channel_data(ch['id'], profile=profile, theme='ai' if profile.get('colors') else ch['d'].get('theme', 'blue'))
    return _setup_back(ch['id'], camp['id'], 'written')


def _art(ch, kind, theme=None, tagline=None):
    folder = db.DATA / 'assets' / 'channels' / str(ch['id'])
    folder.mkdir(parents=True, exist_ok=True)
    profile = ch['d'].get('profile') or {}
    c1, c2 = brand.colors(theme or ch['d'].get('theme', 'blue'), profile.get('colors'))
    out = folder / f'{kind}.png'
    if kind == 'banner':
        return brand.banner(ch['name'], tagline if tagline is not None else profile.get('tagline', ''), c1, c2, out)
    if kind == 'logo':
        return brand.logo(ch['name'], c1, c2, out)
    return brand.watermark(out)


@app.get('/channels/{channel_id}/art/{kind}.png')
def channel_art(request: Request, channel_id: int, kind: str):
    user = need_user(request)
    ch = own_channel(user, channel_id)
    if kind not in ('banner', 'logo', 'watermark'):
        raise HTTPException(status_code=404)
    path = _art(ch, kind)
    name = f'{kind}.png' if request.query_params.get('dl') else None
    return FileResponse(path, media_type='image/png', filename=name, headers={'Cache-Control': 'no-store'})


@app.post('/channels/{channel_id}/setup/apply')
async def channel_apply(request: Request, channel_id: int):
    user = need_user(request)
    ch = own_channel(user, channel_id)
    form = await request.form()
    camp_id = int(form.get('campaign_id') or 0)
    action = str(form.get('action', ''))
    profile = dict(ch['d'].get('profile') or {})
    for key in ('description', 'keywords', 'tagline'):
        if key in form:
            profile[key] = str(form.get(key, '')).strip()[:1000 if key == 'description' else 480]
    theme = str(form.get('theme') or ch['d'].get('theme', 'blue'))
    db.set_channel_data(ch['id'], profile=profile, theme=theme)
    ch = db.channel(ch['id'])
    if action == 'preview':
        return _setup_back(ch['id'], camp_id, 'preview')
    if ch['platform'] != 'youtube' or not platforms.full_access(ch):
        return _setup_back(ch['id'], camp_id, 'reconnect')
    try:
        if action == 'profile':
            platforms.yt_apply_branding(ch, description=profile.get('description', ''), keywords=profile.get('keywords', ''),
                                        country=str(form.get('country') or '') or None,
                                        language=str(form.get('language') or '') or None)
        elif action == 'banner':
            platforms.yt_upload_banner(ch, _art(ch, 'banner'))
        elif action == 'watermark':
            platforms.yt_set_watermark(ch, _art(ch, 'watermark'))
        elif action == 'playlist':
            camp = db.campaign(camp_id) or db.default_campaign(ch['user_id'])
            platforms.ensure_playlist(ch, camp['id'], profile.get('playlist') or camp['name'])
    except Exception as err:
        reason, message = platforms._yt_error(err)
        return _setup_back(ch['id'], camp_id, 'apply_bad', message or str(err))
    return _setup_back(ch['id'], camp_id, f'done_{action}')


# ---------- stats ----------

@app.get('/stats', response_class=HTMLResponse)
def stats_page(request: Request):
    user = current_user(request)
    if not user:
        return RedirectResponse('/login', status_code=303)
    uid = user['id']
    rows = db.q('select p.*, c.title, c.job_id, j.campaign_id from posts p join clips c on c.id=p.clip_id '
                'join jobs j on j.id=c.job_id where p.user_id=? and p.status="posted" order by p.posted_at desc limit 1000', (uid,))
    camps = {c['id']: c['name'] for c in db.campaigns(uid)}
    chans = {c['id']: c['name'] for c in db.channels(uid)}
    by_camp, by_chan = {}, {}
    for r in rows:
        r['where'] = chans.get(r['channel_id'], platforms.NAMES.get(r['platform']))
        for bucket, key, label in ((by_camp, r['campaign_id'], camps.get(r['campaign_id'], 'Old videos')),
                                   (by_chan, r['channel_id'], r['where'])):
            b = bucket.setdefault(key, {'name': label, 'posts': 0, 'views': 0, 'likes': 0, 'comments': 0})
            b['posts'] += 1
            b['views'] += r['views'] or 0
            b['likes'] += r['likes'] or 0
            b['comments'] += r['comments'] or 0
    week = time.time() - 7 * 86400
    totals = {'posts': len(rows), 'views': sum(r['views'] or 0 for r in rows), 'likes': sum(r['likes'] or 0 for r in rows),
              'week': sum(1 for r in rows if r['posted_at'] > week),
              'waiting': db.one('select count(*) as n from posts where user_id=? and status="waiting"', (uid,))['n']}
    top = sorted(rows, key=lambda r: -(r['views'] or 0))[:15]
    return page(request, 'stats.html', totals=totals, by_camp=sorted(by_camp.values(), key=lambda b: -b['views']),
                by_chan=sorted(by_chan.values(), key=lambda b: -b['views']), top=top,
                updated=max([r['stats_at'] for r in rows] or [0]))


@app.post('/stats/refresh')
def stats_refresh(request: Request):
    user = need_user(request)
    threading.Thread(target=pipeline.refresh_stats, args=(user['id'],), daemon=True).start()
    return RedirectResponse('/stats?msg=refreshing', status_code=303)


# ---------- AI helper ----------

@app.post('/helper/chat')
async def helper_chat(request: Request):
    user = need_user(request)
    body = await request.json()
    try:
        result = await asyncio.to_thread(agent.chat, user, body.get('messages') or [], APP_NAME)
    except Exception as err:
        return {'reply': f'Sorry, the AI could not answer right now ({str(err)[:160]}). Try again in a minute.', 'pending': []}
    return result


@app.post('/helper/confirm')
async def helper_confirm(request: Request):
    user = need_user(request)
    body = await request.json()
    return {'reply': await asyncio.to_thread(agent.confirm, user, str(body.get('token', '')))}


# ---------- settings and accounts ----------

@app.get('/settings', response_class=HTMLResponse)
def settings_page(request: Request):
    return page(request, 'settings.html', msg=request.query_params.get('msg', ''), has_ai=ai.ai_ready())


@app.post('/settings')
async def save_settings(request: Request):
    user = need_user(request)
    form = await request.form()
    for key in ('telegram_token', 'telegram_chat'):
        if key in form:
            db.set_setting(user['id'], key, str(form.get(key, '')).strip()[:200])
    for key in ('alert_posted', 'alert_failed', 'alert_done'):
        db.set_setting(user['id'], key, '1' if form.get(key) else '0')
    if form.get('test'):
        problem = notify.test(user['id'])
        return RedirectResponse('/settings?msg=' + ('test_ok' if not problem else 'test_bad'), status_code=303)
    return RedirectResponse('/settings?msg=saved', status_code=303)


@app.post('/admin/server')
async def admin_server(request: Request):
    need_user(request, admin=True)
    form = await request.form()
    cookies = form.get('cookies')
    if cookies is not None and getattr(cookies, 'filename', ''):
        (db.DATA / 'cookies.txt').write_bytes(await cookies.read())
        db.set_stat('yt_blocked_at', 0)
    if form.get('remove_cookies'):
        (db.DATA / 'cookies.txt').unlink(missing_ok=True)
    return RedirectResponse('/admin?msg=server_ok#server', status_code=303)


@app.post('/password')
def change_password(request: Request, current: str = Form(...), new: str = Form(...)):
    user = need_user(request)
    if not auth.check_password(current, user['password']) or len(new) < 8:
        return RedirectResponse('/settings?msg=pw_bad#password', status_code=303)
    db.run('update users set password=? where id=?', (auth.hash_password(new), user['id']))
    return RedirectResponse('/settings?msg=pw_ok#password', status_code=303)


@app.get('/oauth/{platform}/start')
def oauth_start(request: Request, platform: str):
    need_user(request)
    if platform not in platforms.NAMES or not platforms.configured(platform):
        return RedirectResponse('/channels', status_code=303)
    return RedirectResponse(platforms.start_auth(platform, request.session), status_code=303)


@app.get('/oauth/{platform}/callback')
def oauth_callback(request: Request, platform: str, code: str = '', state: str = ''):
    user = need_user(request)
    if platform not in platforms.NAMES or not code or state != request.session.get('oauth_state'):
        return RedirectResponse(f'/channels?msg=link_fail_{platform}', status_code=303)
    try:
        ids = platforms.finish_auth(platform, user['id'], code, state, request.session)
    except Exception as err:
        print('oauth failed', platform, err)
        return RedirectResponse(f'/channels?msg=link_fail_{platform}', status_code=303)
    camps = db.campaigns(user['id'])
    if len(camps) == 1 and not camps[0]['channel_ids']:  # first channel: use it in the only campaign
        db.update_campaign(camps[0]['id'], values={'channels': ','.join(map(str, ids))})
    return RedirectResponse(f'/channels?msg=linked_{platform}', status_code=303)


# ---------- admin ----------

@app.get('/admin', response_class=HTMLResponse)
def admin_home(request: Request):
    users = db.q('select * from users where approved=1 order by id desc')
    pending = db.q('select * from users where approved=0 order by created_at')
    for u in users:
        u['used'] = auth.videos_this_month(u['id'])
        u['linked'] = platforms.connected(u['id'])
    names = {u['id']: u['name'] or u['email'] for u in db.q('select id, name, email from users')}
    live = db.q('select * from jobs where status in ("working", "queued", "uploading") order by created_at')
    recent = db.q('select j.*, (select count(*) from clips c where c.job_id=j.id) as clip_count from jobs j '
                  'where status in ("done", "failed") order by finished_at desc limit 40')
    date, yt_count = pipeline.yt_today()
    stats = {
        'users': len(users), 'active': sum(1 for u in users if u['active'] and not (u['expires_at'] and u['expires_at'] < time.time())),
        'month': db.one('select count(*) as n from jobs where created_at>=?', (auth.month_start(),))['n'],
        'posts_today': db.one('select count(*) as n from posts where status="posted" and posted_at>=?', (time.time() - 86400,))['n'],
        'yt_count': yt_count, 'yt_limit': pipeline.YT_DAILY_LIMIT,
    }
    return page(request, 'admin.html', admin=True, users=users, pending=pending, names=names, live=live, recent=recent,
                stats=stats, timers=pipeline.timers(), rates=db.rates(), site=db.site(), msg=request.query_params.get('msg', ''),
                has_ai=ai.ai_ready(), has_cookies=(db.DATA / 'cookies.txt').exists(), google=auth.google_ready())


@app.post('/admin/site')
async def admin_site(request: Request):
    need_user(request, admin=True)
    form = await request.form()
    mode = str(form.get('signup_mode', 'approval'))
    db.set_setting(0, 'signup_mode', mode if mode in ('approval', 'trial', 'closed') else 'approval')
    for key in ('trial_days', 'trial_videos', 'trial_minutes'):
        try:
            db.set_setting(0, key, str(max(0, int(form.get(key, db.SITE_DEFAULTS[key])))))
        except ValueError:
            pass
    return RedirectResponse('/admin?msg=site_ok#signups', status_code=303)


def _user_fields(form):
    days = form.get('days', '').strip()
    fields = {
        'name': form.get('name', '').strip()[:80],
        'videos_per_month': int(form.get('videos_per_month') or 0),
        'max_minutes': int(form.get('max_minutes') or 0),
        'notes': form.get('notes', '').strip()[:500],
    }
    if days:
        fields['expires_at'] = 0 if days == '0' else time.time() + int(days) * 86400
    return fields


@app.post('/admin/users')
async def admin_create_user(request: Request):
    need_user(request, admin=True)
    form = await request.form()
    email = str(form.get('email', '')).strip().lower()
    password = str(form.get('password', ''))
    if '@' not in email or len(password) < 8 or db.one('select id from users where email=?', (email,)):
        return RedirectResponse('/admin?msg=user_bad#users', status_code=303)
    fields = _user_fields(form)
    db.run('insert into users(email, name, password, role, videos_per_month, max_minutes, expires_at, notes, created_at) '
           'values(?,?,?,?,?,?,?,?,?)', (email, fields['name'], auth.hash_password(password), 'user',
                                         fields['videos_per_month'], fields['max_minutes'], fields.get('expires_at', 0),
                                         fields['notes'], time.time()))
    return RedirectResponse('/admin?msg=user_ok#users', status_code=303)


@app.get('/admin/users/{user_id}', response_class=HTMLResponse)
def admin_user(request: Request, user_id: int):
    target = db.one('select * from users where id=?', (user_id,))
    if not target:
        return RedirectResponse('/admin', status_code=303)
    target['used'] = auth.videos_this_month(user_id)
    target['linked'] = platforms.connected(user_id)
    jobs = db.q('select * from jobs where user_id=? order by id desc limit 30', (user_id,))
    return page(request, 'admin_user.html', admin=True, target=target, jobs=jobs, msg=request.query_params.get('msg', ''))


@app.post('/admin/users/{user_id}')
async def admin_update_user(request: Request, user_id: int):
    admin = need_user(request, admin=True)
    form = await request.form()
    action = form.get('action')
    if action == 'save':
        fields = _user_fields(form)
        cols = ', '.join(f'{k}=?' for k in fields)
        db.run(f'update users set {cols} where id=?', (*fields.values(), user_id))
    elif action == 'approve':
        fields = _user_fields(form)
        cols = ', '.join(f'{k}=?' for k in fields)
        db.run(f'update users set {cols}, approved=1, active=1 where id=?', (*fields.values(), user_id))
        return RedirectResponse('/admin?msg=approved#signups', status_code=303)
    elif action == 'reject' and user_id != admin['id']:
        db.run('delete from users where id=? and approved=0', (user_id,))
        return RedirectResponse('/admin?msg=rejected#signups', status_code=303)
    elif action == 'pause' and user_id != admin['id']:
        db.run('update users set active=0 where id=?', (user_id,))
    elif action == 'resume':
        db.run('update users set active=1 where id=?', (user_id,))
    elif action == 'extend':
        target = db.one('select expires_at from users where id=?', (user_id,))
        base = max(target['expires_at'] or 0, time.time())
        db.run('update users set expires_at=? where id=?', (base + 30 * 86400, user_id))
    elif action == 'password':
        password = str(form.get('password', ''))
        if len(password) < 8:
            return RedirectResponse(f'/admin/users/{user_id}?msg=pw_bad', status_code=303)
        db.run('update users set password=? where id=?', (auth.hash_password(password), user_id))
    elif action == 'delete' and user_id != admin['id']:
        for job in db.q('select id from jobs where user_id=?', (user_id,)):
            pipeline.delete_job(job['id'])
        db.run('delete from settings where user_id=?', (user_id,))
        db.run('delete from users where id=?', (user_id,))
        return RedirectResponse('/admin?msg=user_deleted#users', status_code=303)
    return RedirectResponse(f'/admin/users/{user_id}?msg=saved', status_code=303)


@app.post('/admin/jobs/{job_id}/cancel')
def admin_cancel(request: Request, job_id: int):
    need_user(request, admin=True)
    job = db.one('select status from jobs where id=?', (job_id,))
    if job and job['status'] in ('queued', 'working'):
        if job['status'] == 'working':
            pipeline.stop(job_id)
        db.update_job(job_id, status='failed', stage='', step='', error='Cancelled by admin.', finished_at=time.time())
    return RedirectResponse('/admin#queue', status_code=303)


@app.get('/welcome', response_class=HTMLResponse)
def welcome(request: Request):
    return templates.TemplateResponse(request, 'public/welcome.html', {'request': request})


@app.get('/privacy', response_class=HTMLResponse)
def privacy(request: Request):
    return templates.TemplateResponse(request, 'public/privacy.html', {'request': request})


@app.get('/terms', response_class=HTMLResponse)
def terms(request: Request):
    return templates.TemplateResponse(request, 'public/terms.html', {'request': request})


@app.get('/health')
def health():
    return {'ok': True}
