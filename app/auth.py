import hashlib
import hmac
import os
import secrets
import time
from datetime import datetime, timedelta, timezone

from . import db

PKT = timezone(timedelta(hours=5))


def hash_password(password):
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(password.encode(), salt=salt, n=2 ** 14, r=8, p=1)
    return f'{salt.hex()}${digest.hex()}'


def check_password(password, stored):
    try:
        salt, digest = stored.split('$')
    except (AttributeError, ValueError):
        return False
    test = hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt), n=2 ** 14, r=8, p=1)
    return hmac.compare_digest(test.hex(), digest)


def bootstrap_admin():
    """Create the owner account from ADMIN_EMAIL / ADMIN_PASSWORD on first start."""
    email = os.environ.get('ADMIN_EMAIL', '').strip().lower()
    password = os.environ.get('ADMIN_PASSWORD', '')
    if not email or not password:
        return
    user = db.one('select * from users where email=?', (email,))
    if not user:
        db.run('insert into users(email, name, password, role, videos_per_month, max_minutes, created_at) '
               'values(?,?,?,?,?,?,?)', (email, 'Admin', hash_password(password), 'admin', 0, 300, time.time()))
    elif os.environ.get('ADMIN_PASSWORD_RESET') == '1':
        db.run('update users set password=?, role="admin", active=1 where id=?', (hash_password(password), user['id']))


def login(email, password):
    user = db.one('select * from users where email=?', (email.strip().lower(),))
    if user and check_password(password, user['password']):
        db.run('update users set last_login=? where id=?', (time.time(), user['id']))
        return user
    return None


def month_start():
    now = datetime.now(PKT)
    return now.replace(day=1, hour=0, minute=0, second=0, microsecond=0).timestamp()


def videos_this_month(user_id):
    row = db.one('select count(*) as n from jobs where user_id=? and created_at>=? and status != "failed"',
                 (user_id, month_start()))
    return row['n']


def access_problem(user):
    """Why this user can't start a new video right now, or '' if they can."""
    if not user.get('approved', 1):
        return 'Your account is waiting for approval.'
    if not user['active']:
        return 'Your account is paused. Contact the admin.'
    if user['expires_at'] and user['expires_at'] < time.time():
        return 'Your plan has expired. Contact the admin to renew.'
    limit = user['videos_per_month']
    if limit and videos_this_month(user['id']) >= limit:
        return f'You have used all {limit} videos for this month.'
    return ''


# ---------- Sign in with Google ----------

GOOGLE_AUTH = 'https://accounts.google.com/o/oauth2/v2/auth'
GOOGLE_TOKEN = 'https://oauth2.googleapis.com/token'
GOOGLE_USERINFO = 'https://openidconnect.googleapis.com/v1/userinfo'


def google_ready():
    return bool(os.environ.get('YT_CLIENT_ID') and os.environ.get('YT_CLIENT_SECRET'))


def google_redirect():
    return os.environ.get('PUBLIC_URL', 'https://clips.chatssync.online').rstrip('/') + '/auth/google/callback'


def google_url(state):
    from urllib.parse import urlencode
    return GOOGLE_AUTH + '?' + urlencode({
        'client_id': os.environ['YT_CLIENT_ID'], 'redirect_uri': google_redirect(), 'response_type': 'code',
        'scope': 'openid email profile', 'state': state, 'prompt': 'select_account'})


def google_profile(code):
    import requests
    token = requests.post(GOOGLE_TOKEN, data={
        'code': code, 'client_id': os.environ['YT_CLIENT_ID'], 'client_secret': os.environ['YT_CLIENT_SECRET'],
        'redirect_uri': google_redirect(), 'grant_type': 'authorization_code'}, timeout=30)
    token.raise_for_status()
    info = requests.get(GOOGLE_USERINFO, timeout=30,
                        headers={'Authorization': f'Bearer {token.json()["access_token"]}'})
    info.raise_for_status()
    return info.json()


def google_login(profile):
    """Find or create the account for a Google profile. New people follow the admin's sign-up rule."""
    email = (profile.get('email') or '').strip().lower()
    if not email or not profile.get('email_verified', False):
        return None, 'Your Google account has no verified email.'
    user = db.one('select * from users where google_sub=? or email=?', (profile.get('sub', ''), email))
    if user:
        db.run('update users set google_sub=?, avatar=?, name=coalesce(nullif(name, ""), ?), last_login=? where id=?',
               (profile.get('sub', ''), profile.get('picture', ''), profile.get('name', ''), time.time(), user['id']))
        return db.one('select * from users where id=?', (user['id'],)), ''
    rules = db.site()
    if rules['signup_mode'] == 'closed':
        return None, 'New sign-ups are closed right now. Contact the admin.'
    trial = rules['signup_mode'] == 'trial'
    user_id = db.run(
        'insert into users(email, name, password, role, approved, active, expires_at, videos_per_month, max_minutes, '
        'google_sub, avatar, notes, created_at, last_login) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        (email, profile.get('name', '')[:80], '', 'user', 1 if trial else 0, 1,
         time.time() + int(rules['trial_days']) * 86400 if trial else 0,
         int(rules['trial_videos']) if trial else 0, int(rules['trial_minutes']) if trial else 60,
         profile.get('sub', ''), profile.get('picture', ''), 'Signed up with Google', time.time(), time.time()))
    return db.one('select * from users where id=?', (user_id,)), ''
