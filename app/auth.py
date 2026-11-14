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
    if not user['active']:
        return 'Your account is paused. Contact the admin.'
    if user['expires_at'] and user['expires_at'] < time.time():
        return 'Your plan has expired. Contact the admin to renew.'
    limit = user['videos_per_month']
    if limit and videos_this_month(user['id']) >= limit:
        return f'You have used all {limit} videos for this month.'
    return ''
