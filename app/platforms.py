"""Connecting accounts and posting clips to YouTube, Instagram and Facebook."""
import json
import os
import time
from pathlib import Path
from urllib.parse import urlencode

import requests

from . import db

PUBLIC_URL = os.environ.get('PUBLIC_URL', 'https://clips.chatssync.online').rstrip('/')
GRAPH = 'https://graph.facebook.com/v21.0'
IG_GRAPH = 'https://graph.instagram.com/v21.0'
NAMES = {'youtube': 'YouTube', 'instagram': 'Instagram', 'facebook': 'Facebook'}


def secret_key():
    key_file = db.DATA / 'secret.key'
    if not key_file.exists():
        import secrets
        key_file.write_text(secrets.token_hex(32))
    return key_file.read_text().strip()


def _signer():
    from itsdangerous import URLSafeTimedSerializer
    return URLSafeTimedSerializer(secret_key(), salt='public-clip')


def public_link(clip_id):
    """Short-lived link Instagram uses to fetch the video file."""
    return f'{PUBLIC_URL}/p/{_signer().dumps(clip_id)}.mp4'


def check_public(token, max_age=6 * 3600):
    return _signer().loads(token, max_age=max_age)


def redirect(platform):
    return f'{PUBLIC_URL}/oauth/{platform}/callback'


def configured(platform):
    keys = {'youtube': ('YT_CLIENT_ID', 'YT_CLIENT_SECRET'), 'instagram': ('IG_APP_ID', 'IG_APP_SECRET'),
            'facebook': ('META_APP_ID', 'META_APP_SECRET')}[platform]
    return all(os.environ.get(k) for k in keys)


def account(user_id, platform):
    return db.get_json(user_id, f'acct_{platform}')


def save_account(user_id, platform, data):
    db.set_json(user_id, f'acct_{platform}', data)


def connected(user_id):
    return {p: bool(account(user_id, p)) for p in NAMES}


# ---------- post text ----------

def post_text(clip, settings):
    meta = json.loads(clip.get('meta') or '{}')
    campaign_tags = [t for t in settings['hashtags'].split() if t.startswith('#')]
    tags = []
    for tag in campaign_tags + meta.get('hashtags', []):
        if tag.lower() not in [t.lower() for t in tags]:
            tags.append(tag)
    title = clip['title'].strip()
    if settings['title_suffix']:
        title = f'{title} {settings["title_suffix"]}'
    body = settings['description_template'].format(
        title=clip['title'].strip(), description=meta.get('description', ''), credit=settings['creator_credit'],
        hashtags=' '.join(tags[:15]), campaign=settings['campaign_name'],
    )
    body = '\n\n'.join(part.strip() for part in body.split('\n\n') if part.strip())
    keywords, total = [], 0
    for kw in [t.strip('#') for t in campaign_tags] + meta.get('tags', []) + [t.strip('#') for t in meta.get('hashtags', [])]:
        if kw and kw.lower() not in [k.lower() for k in keywords] and total + len(kw) + 1 < 480:
            keywords.append(kw)
            total += len(kw) + 1
    return {'title': title[:100], 'body': body[:4900], 'caption': body[:2150], 'tags': keywords}


# ---------- YouTube ----------

YT_SCOPES = ['https://www.googleapis.com/auth/youtube.upload', 'https://www.googleapis.com/auth/youtube.readonly']


def _yt_flow(state=None):
    from google_auth_oauthlib.flow import Flow
    config = {'web': {
        'client_id': os.environ['YT_CLIENT_ID'], 'client_secret': os.environ['YT_CLIENT_SECRET'],
        'auth_uri': 'https://accounts.google.com/o/oauth2/auth', 'token_uri': 'https://oauth2.googleapis.com/token',
    }}
    return Flow.from_client_config(config, scopes=YT_SCOPES, state=state, redirect_uri=redirect('youtube'))


def _yt_service(creds):
    from googleapiclient.discovery import build
    return build('youtube', 'v3', credentials=creds, cache_discovery=False)


def _yt_creds(data):
    from google.oauth2.credentials import Credentials
    return Credentials(token=data.get('token'), refresh_token=data['refresh_token'], token_uri='https://oauth2.googleapis.com/token',
                       client_id=os.environ['YT_CLIENT_ID'], client_secret=os.environ['YT_CLIENT_SECRET'], scopes=YT_SCOPES)


def start_auth(platform, session):
    if platform == 'youtube':
        flow = _yt_flow()
        url, state = flow.authorization_url(access_type='offline', prompt='consent', include_granted_scopes='true')
        session['oauth_verifier'] = flow.code_verifier
    else:
        import secrets
        state = secrets.token_urlsafe(16)
        if platform == 'instagram':
            url = 'https://www.instagram.com/oauth/authorize?' + urlencode({
                'client_id': os.environ['IG_APP_ID'], 'redirect_uri': redirect('instagram'), 'response_type': 'code',
                'scope': 'instagram_business_basic,instagram_business_content_publish', 'state': state})
        else:
            url = 'https://www.facebook.com/v21.0/dialog/oauth?' + urlencode({
                'client_id': os.environ['META_APP_ID'], 'redirect_uri': redirect('facebook'), 'state': state,
                'scope': 'pages_show_list,pages_manage_posts,pages_read_engagement,business_management'})
    session['oauth_state'] = state
    return url


def finish_auth(platform, user_id, code, state, session):
    if platform == 'youtube':
        flow = _yt_flow(state)
        flow.code_verifier = session.get('oauth_verifier')
        flow.fetch_token(code=code)
        creds = flow.credentials
        channel = _yt_service(creds).channels().list(part='snippet', mine=True).execute().get('items') or []
        save_account(user_id, 'youtube', {'token': creds.token, 'refresh_token': creds.refresh_token,
                                          'name': channel[0]['snippet']['title'] if channel else 'YouTube'})
    elif platform == 'instagram':
        short = _ok(requests.post('https://api.instagram.com/oauth/access_token', data={
            'client_id': os.environ['IG_APP_ID'], 'client_secret': os.environ['IG_APP_SECRET'],
            'grant_type': 'authorization_code', 'redirect_uri': redirect('instagram'), 'code': code}, timeout=30))
        long = _ok(requests.get('https://graph.instagram.com/access_token', params={
            'grant_type': 'ig_exchange_token', 'client_secret': os.environ['IG_APP_SECRET'],
            'access_token': short['access_token']}, timeout=30))
        me = _ok(requests.get(f'{IG_GRAPH}/me', params={'fields': 'user_id,username',
                                                        'access_token': long['access_token']}, timeout=30))
        save_account(user_id, 'instagram', {'token': long['access_token'], 'ig_id': me.get('user_id') or me['id'],
                                            'name': '@' + me.get('username', ''), 'refreshed': time.time()})
    else:
        app = {'client_id': os.environ['META_APP_ID'], 'client_secret': os.environ['META_APP_SECRET']}
        short = _ok(requests.get(f'{GRAPH}/oauth/access_token', params={
            **app, 'redirect_uri': redirect('facebook'), 'code': code}, timeout=30))
        long = _ok(requests.get(f'{GRAPH}/oauth/access_token', params={
            **app, 'grant_type': 'fb_exchange_token', 'fb_exchange_token': short['access_token']}, timeout=30))
        pages = _ok(requests.get(f'{GRAPH}/me/accounts', params={
            'fields': 'id,name,access_token', 'limit': 100, 'access_token': long['access_token']}, timeout=30)).get('data', [])
        if not pages:
            raise RuntimeError('No Facebook Page found on this account.')
        save_account(user_id, 'facebook', {'pages': pages, 'page_id': pages[0]['id'], 'name': pages[0]['name']})


def choose_page(user_id, page_id):
    acct = account(user_id, 'facebook')
    page = next((p for p in acct['pages'] if p['id'] == page_id), None)
    if page:
        acct.update(page_id=page['id'], name=page['name'])
        save_account(user_id, 'facebook', acct)


def _ok(res):
    try:
        data = res.json()
    except ValueError:
        data = {}
    if res.status_code >= 400 or 'error' in data and data['error']:
        err = data.get('error')
        msg = err.get('message') if isinstance(err, dict) else (data.get('error_message') or err or res.text[:300])
        raise RuntimeError(str(msg)[:400])
    return data


# ---------- posting ----------

def post(platform, user_id, clip, settings, public_url):
    acct = account(user_id, platform)
    if not acct:
        raise RuntimeError(f'{NAMES[platform]} is not connected.')
    text = post_text(clip, settings)
    return {'youtube': _post_youtube, 'instagram': _post_instagram, 'facebook': _post_facebook}[platform](
        acct, clip, text, public_url, user_id)


def _post_youtube(acct, clip, text, public_url, user_id):
    from googleapiclient.http import MediaFileUpload
    creds = _yt_creds(acct)
    body = {'snippet': {'title': text['title'], 'description': text['body'], 'tags': text['tags'], 'categoryId': '24'},
            'status': {'privacyStatus': 'public', 'selfDeclaredMadeForKids': False}}
    media = MediaFileUpload(clip['file'], mimetype='video/mp4', chunksize=8 * 1024 * 1024, resumable=True)
    request = _yt_service(creds).videos().insert(part='snippet,status', body=body, media_body=media)
    response = None
    while response is None:
        _, response = request.next_chunk()
    if creds.token != acct.get('token'):
        save_account(user_id, 'youtube', {**acct, 'token': creds.token})
    return response['id'], f'https://youtube.com/shorts/{response["id"]}'


def _post_instagram(acct, clip, text, public_url, user_id):
    token = acct['token']
    if time.time() - acct.get('refreshed', 0) > 7 * 86400:
        fresh = _ok(requests.get('https://graph.instagram.com/refresh_access_token', params={
            'grant_type': 'ig_refresh_token', 'access_token': token}, timeout=30))
        token = fresh['access_token']
        save_account(user_id, 'instagram', {**acct, 'token': token, 'refreshed': time.time()})
    container = _ok(requests.post(f'{IG_GRAPH}/{acct["ig_id"]}/media', data={
        'media_type': 'REELS', 'video_url': public_url, 'caption': text['caption'], 'share_to_feed': 'true',
        'access_token': token}, timeout=60))['id']
    for _ in range(90):
        time.sleep(10)
        status = _ok(requests.get(f'{IG_GRAPH}/{container}', params={'fields': 'status_code,status',
                                                                   'access_token': token}, timeout=30))
        if status.get('status_code') == 'FINISHED':
            break
        if status.get('status_code') in ('ERROR', 'EXPIRED'):
            raise RuntimeError(f'Instagram could not process the video: {status.get("status", "")}'[:400])
    else:
        raise RuntimeError('Instagram took too long to process the video.')
    media_id = _ok(requests.post(f'{IG_GRAPH}/{acct["ig_id"]}/media_publish', data={
        'creation_id': container, 'access_token': token}, timeout=60))['id']
    link = _ok(requests.get(f'{IG_GRAPH}/{media_id}', params={'fields': 'permalink', 'access_token': token},
                            timeout=30)).get('permalink', '')
    return media_id, link


def _post_facebook(acct, clip, text, public_url, user_id):
    page = next(p for p in acct['pages'] if p['id'] == acct['page_id'])
    token, page_id = page['access_token'], page['id']
    start = _ok(requests.post(f'{GRAPH}/{page_id}/video_reels', data={'upload_phase': 'start', 'access_token': token},
                              timeout=60))
    video_id = start['video_id']
    size = Path(clip['file']).stat().st_size
    with open(clip['file'], 'rb') as fh:
        _ok(requests.post(f'https://rupload.facebook.com/video-upload/v21.0/{video_id}', data=fh, timeout=900, headers={
            'Authorization': f'OAuth {token}', 'offset': '0', 'file_size': str(size)}))
    _ok(requests.post(f'{GRAPH}/{page_id}/video_reels', data={
        'upload_phase': 'finish', 'video_id': video_id, 'video_state': 'PUBLISHED',
        'description': text['caption'], 'title': text['title'], 'access_token': token}, timeout=60))
    return video_id, f'https://www.facebook.com/reel/{video_id}'
