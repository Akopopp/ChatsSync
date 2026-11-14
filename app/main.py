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

from . import ai, auth, db, media, pipeline, platforms

ROOT = Path(__file__).resolve().parent
PKT = timezone(timedelta(hours=5))
APP_NAME = os.environ.get('APP_NAME', 'Clipper')

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
templates.env.globals.update(APP_NAME=APP_NAME, NAMES=platforms.NAMES)


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
    return templates.TemplateResponse(request, 'login.html', {'request': request, 'error': ''})


@app.post('/login')
def login(request: Request, email: str = Form(...), password: str = Form(...)):
    user = auth.login(email, password)
    if not user:
        time.sleep(1)
        return templates.TemplateResponse(request, 'login.html', {'request': request, 'error': 'Wrong email or password.'},
                                          status_code=401)
    request.session['uid'] = user['id']
    return RedirectResponse('/', status_code=303)


@app.get('/logout')
def logout(request: Request):
    request.session.clear()
    return RedirectResponse('/login', status_code=303)


# ---------- videos ----------

@app.get('/', response_class=HTMLResponse)
def home(request: Request):
    user = current_user(request)
    if not user:
        return RedirectResponse('/login', status_code=303)
    jobs = db.q('''select j.*, (select count(*) from clips c where c.job_id=j.id and c.status not in ('failed','rejected')) as clip_count,
                   (select count(*) from posts p join clips c on c.id=p.clip_id where c.job_id=j.id and p.status='posted') as posted
                   from jobs j where j.user_id=? order by j.id desc limit 60''', (user['id'],))
    return page(request, 'home.html', jobs=jobs, timers=pipeline.timers(), problem=auth.access_problem(user),
                used=auth.videos_this_month(user['id']), error=request.query_params.get('error', ''))


@app.post('/jobs')
async def new_job(request: Request, url: str = Form(''), file: UploadFile | None = File(None)):
    user = need_user(request)
    problem = auth.access_problem(user)
    if problem:
        return RedirectResponse('/?error=limit', status_code=303)
    url = url.strip()
    now = time.time()
    if file is not None and file.filename:
        job_id = db.run('insert into jobs(user_id, source, source_type, title, status, step, created_at, updated_at) '
                        'values(?,?,?,?,?,?,?,?)', (user['id'], file.filename, 'upload', Path(file.filename).stem[:150],
                                                    'uploading', 'Uploading', now, now))
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
    elif url.startswith('http'):
        job_id = db.run('insert into jobs(user_id, source, source_type, step, created_at, updated_at) values(?,?,?,?,?,?)',
                        (user['id'], url, media.source_type(url), 'Waiting', now, now))
        if media.source_type(url) == 'link':
            threading.Thread(target=pipeline.prefetch, args=(job_id,), daemon=True).start()
    else:
        return RedirectResponse('/?error=link', status_code=303)
    pipeline.wake()
    return RedirectResponse(f'/jobs/{job_id}', status_code=303)


def clip_rows(job_id):
    clips = db.q('select * from clips where job_id=? and status != "rejected" order by score desc, id', (job_id,))
    for clip in clips:
        clip['posts'] = db.q('select * from posts where clip_id=? order by platform', (clip['id'],))
        clip['meta'] = json.loads(clip['meta'] or '{}')
    return clips


@app.get('/jobs/{job_id}', response_class=HTMLResponse)
def job_page(request: Request, job_id: int):
    user = current_user(request)
    if not user:
        return RedirectResponse('/login', status_code=303)
    job = own_job(user, job_id)
    clips = clip_rows(job_id)
    for clip in clips:
        clip['text'] = platforms.post_text({**clip, 'meta': json.dumps(clip['meta'])}, db.settings(job['user_id']))
    return page(request, 'job.html', job=job, clips=clips, timer=pipeline.timers().get(job_id))


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
    db.update_job(job_id, status='queued', step='Waiting', error='', created_at=time.time())
    pipeline.wake()
    return RedirectResponse(f'/jobs/{job_id}', status_code=303)


@app.post('/jobs/{job_id}/delete')
def remove_job(request: Request, job_id: int):
    user = need_user(request)
    job = own_job(user, job_id)
    if job['status'] == 'working':
        return RedirectResponse(f'/jobs/{job_id}', status_code=303)
    pipeline.delete_job(job_id)
    return RedirectResponse(request.query_params.get('back', '/'), status_code=303)


# ---------- clips ----------

@app.post('/clips/{clip_id}/save')
async def save_clip(request: Request, clip_id: int):
    user = need_user(request)
    clip = own_clip(user, clip_id)
    form = await request.form()
    meta = json.loads(clip['meta'] or '{}')
    meta['description'] = str(form.get('description', meta.get('description', ''))).strip()[:1500]
    db.update_clip(clip_id, title=str(form.get('title', clip['title'])).strip()[:100], meta=json.dumps(meta))
    if form.get('post'):
        if not pipeline.approve(clip_id):
            return RedirectResponse(f'/jobs/{clip["job_id"]}?nolink=1#clip-{clip_id}', status_code=303)
    return RedirectResponse(f'/jobs/{clip["job_id"]}#clip-{clip_id}', status_code=303)


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


@app.get('/media/{clip_id}.{ext}')
def clip_media(request: Request, clip_id: int, ext: str):
    user = need_user(request)
    clip = own_clip(user, clip_id)
    path = clip['file'] if ext == 'mp4' else clip['thumb']
    if not path or not Path(path).exists():
        raise HTTPException(status_code=404)
    name = f'clip-{clip_id}.{ext}' if request.query_params.get('dl') else None
    return FileResponse(path, media_type='video/mp4' if ext == 'mp4' else 'image/jpeg', filename=name)


@app.get('/p/{token}.mp4')
def public_clip(token: str):
    try:
        clip_id = platforms.check_public(token)
    except Exception:
        raise HTTPException(status_code=404)
    clip = db.one('select file from clips where id=?', (clip_id,))
    if not clip or not clip['file'] or not Path(clip['file']).exists():
        raise HTTPException(status_code=404)
    return FileResponse(clip['file'], media_type='video/mp4')


# ---------- settings and accounts ----------

@app.get('/settings', response_class=HTMLResponse)
def settings_page(request: Request):
    user = current_user(request)
    accounts = {p: platforms.account(user['id'], p) for p in platforms.NAMES} if user else {}
    return page(request, 'settings.html', msg=request.query_params.get('msg', ''), accounts=accounts,
                ready={p: platforms.configured(p) for p in platforms.NAMES},
                has_cookies=(db.DATA / 'cookies.txt').exists(), has_ai=ai.ai_ready())


@app.post('/settings')
async def save_settings(request: Request):
    user = need_user(request)
    form = await request.form()
    checks = ('show_title', 'caption_uppercase', 'post_youtube', 'post_instagram', 'post_facebook')
    for key in db.DEFAULT_SETTINGS:
        if key in checks:
            db.set_setting(user['id'], key, '1' if form.get(key) else '0')
        elif key in form:
            db.set_setting(user['id'], key, str(form.get(key)).strip()[:3000])
    for key, low, high in (('clip_min', 10, 170), ('clip_max', 15, 180), ('clips_per_video', 1, 15)):
        value = db.settings(user['id'])[key]
        try:
            db.set_setting(user['id'], key, str(int(min(max(float(value), low), high))))
        except ValueError:
            db.set_setting(user['id'], key, db.DEFAULT_SETTINGS[key])
    if form.get('page_id'):
        platforms.choose_page(user['id'], str(form.get('page_id')))
    if user['role'] == 'admin':
        cookies = form.get('cookies')
        if cookies is not None and getattr(cookies, 'filename', ''):
            (db.DATA / 'cookies.txt').write_bytes(await cookies.read())
        if form.get('remove_cookies'):
            (db.DATA / 'cookies.txt').unlink(missing_ok=True)
    return RedirectResponse('/settings?msg=saved', status_code=303)


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
        return RedirectResponse('/settings', status_code=303)
    return RedirectResponse(platforms.start_auth(platform, request.session), status_code=303)


@app.get('/oauth/{platform}/callback')
def oauth_callback(request: Request, platform: str, code: str = '', state: str = ''):
    user = need_user(request)
    if platform not in platforms.NAMES or not code or state != request.session.get('oauth_state'):
        return RedirectResponse(f'/settings?msg=link_fail_{platform}', status_code=303)
    try:
        platforms.finish_auth(platform, user['id'], code, state, request.session)
    except Exception as err:
        print('oauth failed', platform, err)
        return RedirectResponse(f'/settings?msg=link_fail_{platform}', status_code=303)
    return RedirectResponse(f'/settings?msg=linked_{platform}', status_code=303)


@app.post('/oauth/{platform}/disconnect')
def oauth_disconnect(request: Request, platform: str):
    user = need_user(request)
    if platform in platforms.NAMES:
        platforms.save_account(user['id'], platform, None)
    return RedirectResponse('/settings', status_code=303)


# ---------- admin ----------

@app.get('/admin', response_class=HTMLResponse)
def admin_home(request: Request):
    users = db.q('select * from users order by id desc')
    for u in users:
        u['used'] = auth.videos_this_month(u['id'])
        u['linked'] = platforms.connected(u['id'])
    names = {u['id']: u['name'] or u['email'] for u in users}
    live = db.q('select * from jobs where status in ("working", "queued", "uploading") order by created_at')
    recent = db.q('select * from jobs where status in ("done", "failed") order by finished_at desc limit 15')
    date, yt_count = pipeline.yt_today()
    stats = {
        'users': len(users), 'active': sum(1 for u in users if u['active'] and not (u['expires_at'] and u['expires_at'] < time.time())),
        'month': db.one('select count(*) as n from jobs where created_at>=?', (auth.month_start(),))['n'],
        'posts_today': db.one('select count(*) as n from posts where status="posted" and posted_at>=?', (time.time() - 86400,))['n'],
        'yt_count': yt_count, 'yt_limit': pipeline.YT_DAILY_LIMIT,
    }
    return page(request, 'admin.html', admin=True, users=users, names=names, live=live, recent=recent, stats=stats,
                timers=pipeline.timers(), rates=db.rates(), msg=request.query_params.get('msg', ''))


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
    if job and job['status'] == 'queued':
        db.update_job(job_id, status='failed', error='Cancelled by admin.', finished_at=time.time())
    return RedirectResponse('/admin#queue', status_code=303)


@app.get('/health')
def health():
    return {'ok': True}
