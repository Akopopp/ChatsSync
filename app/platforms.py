"""Connecting channels (any number of YouTube channels, Instagram accounts and Facebook Pages) and posting to them."""
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


def connected(user_id):
    have = {c['platform'] for c in db.channels(user_id)}
    return {p: p in have for p in NAMES}


# ---------- post text ----------

def _hashtags(clip_meta, s, limit=5):
    """Campaign hashtags first, then the AI's. YouTube shows the first three above the title."""
    out = []
    for tag in s['hashtags'].split() + list(clip_meta.get('hashtags', [])):
        tag = '#' + ''.join(ch for ch in str(tag).strip().lstrip('#') if ch.isalnum() or ch == '_')
        if len(tag) > 1 and tag.lower() not in [t.lower() for t in out]:
            out.append(tag)
    return out[:limit]


def post_text(clip, s):
    """Title, description, tags and caption for one clip, from the AI text and the campaign rules (s)."""
    meta = clip['meta'] if isinstance(clip.get('meta'), dict) else json.loads(clip.get('meta') or '{}')
    tags_line = _hashtags(meta, s)
    title = (clip.get('title') or '').strip()
    if s.get('title_suffix'):
        title = f'{title} {s["title_suffix"]}'
    values = {'title': (clip.get('title') or '').strip(), 'description': meta.get('description', ''),
              'credit': s.get('credit', ''), 'hashtags': ' '.join(tags_line), 'campaign': '',
              'cta': s.get('cta', ''), 'links': s.get('links', '')}
    try:
        body = s['description_template'].format(**values)
    except (KeyError, IndexError, ValueError):
        body = db.DEFAULT_TEMPLATE.format(**values)
    body = '\n\n'.join(part.strip() for part in body.split('\n\n') if part.strip())
    keywords, total = [], 0
    for kw in [t.strip('#') for t in s['hashtags'].split()] + meta.get('tags', []) + [t.strip('#') for t in meta.get('hashtags', [])]:
        kw = str(kw).replace('<', '').replace('>', '').strip()
        if kw and kw.lower() not in [k.lower() for k in keywords] and total + len(kw) + (3 if ' ' in kw else 1) < 490:
            keywords.append(kw)
            total += len(kw) + (3 if ' ' in kw else 1)
    return {'title': title[:100], 'body': body[:4900], 'caption': body[:2150], 'tags': keywords,
            'comment': (meta.get('first_comment') or '').strip()[:1000], 'loc': meta.get('loc') or {}}


# ---------- YouTube ----------

YT_SCOPES = ['https://www.googleapis.com/auth/youtube.upload', 'https://www.googleapis.com/auth/youtube',
             'https://www.googleapis.com/auth/youtube.force-ssl']
YT_OLD_SCOPES = ['https://www.googleapis.com/auth/youtube.upload', 'https://www.googleapis.com/auth/youtube.readonly']


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


def full_access(ch):
    """True when the channel was connected with the scopes needed for comments, playlists and channel setup."""
    return 'https://www.googleapis.com/auth/youtube.force-ssl' in (ch['d'].get('scopes') or [])


def _yt_creds(ch):
    from google.oauth2.credentials import Credentials
    data = ch['d']
    return Credentials(token=data.get('token'), refresh_token=data['refresh_token'], token_uri='https://oauth2.googleapis.com/token',
                       client_id=os.environ['YT_CLIENT_ID'], client_secret=os.environ['YT_CLIENT_SECRET'],
                       scopes=data.get('scopes') or YT_OLD_SCOPES)


def yt(ch):
    """A YouTube API client for one connected channel. Saves the refreshed login afterwards via keep()."""
    creds = _yt_creds(ch)
    return _yt_service(creds), creds


def keep(ch, creds):
    if creds.token and creds.token != ch['d'].get('token'):
        db.set_channel_data(ch['id'], token=creds.token)


def start_auth(platform, session):
    if platform == 'youtube':
        flow = _yt_flow()
        url, state = flow.authorization_url(access_type='offline', prompt='consent select_account',
                                            include_granted_scopes='true')
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
    """Connect the account. Returns the ids of the channels that were added or refreshed."""
    if platform == 'youtube':
        flow = _yt_flow(state)
        flow.code_verifier = session.get('oauth_verifier')
        flow.fetch_token(code=code)
        creds = flow.credentials
        items = _yt_service(creds).channels().list(part='snippet', mine=True).execute().get('items') or []
        if not items:
            raise RuntimeError('This Google account has no YouTube channel yet.')
        item = items[0]
        title = item['snippet']['title']
        # channels connected before the multi-channel update were saved by name: give them their real id
        db.run('update channels set ext_id=? where user_id=? and platform="youtube" and ext_id=?',
               (item['id'], user_id, title))
        data = {'token': creds.token, 'refresh_token': creds.refresh_token, 'channel_id': item['id'],
                'thumb': ((item['snippet'].get('thumbnails') or {}).get('default') or {}).get('url', ''),
                'scopes': list(creds.scopes or YT_SCOPES)}
        if not creds.refresh_token:
            data.pop('refresh_token')
        return [db.save_channel(user_id, 'youtube', item['id'], title, data)]
    if platform == 'instagram':
        short = _ok(requests.post('https://api.instagram.com/oauth/access_token', data={
            'client_id': os.environ['IG_APP_ID'], 'client_secret': os.environ['IG_APP_SECRET'],
            'grant_type': 'authorization_code', 'redirect_uri': redirect('instagram'), 'code': code}, timeout=30))
        long = _ok(requests.get('https://graph.instagram.com/access_token', params={
            'grant_type': 'ig_exchange_token', 'client_secret': os.environ['IG_APP_SECRET'],
            'access_token': short['access_token']}, timeout=30))
        me = _ok(requests.get(f'{IG_GRAPH}/me', params={'fields': 'user_id,username',
                                                        'access_token': long['access_token']}, timeout=30))
        ig_id = str(me.get('user_id') or me['id'])
        return [db.save_channel(user_id, 'instagram', ig_id, '@' + me.get('username', ''),
                                {'token': long['access_token'], 'ig_id': ig_id, 'refreshed': time.time()})]
    app = {'client_id': os.environ['META_APP_ID'], 'client_secret': os.environ['META_APP_SECRET']}
    short = _ok(requests.get(f'{GRAPH}/oauth/access_token', params={
        **app, 'redirect_uri': redirect('facebook'), 'code': code}, timeout=30))
    long = _ok(requests.get(f'{GRAPH}/oauth/access_token', params={
        **app, 'grant_type': 'fb_exchange_token', 'fb_exchange_token': short['access_token']}, timeout=30))
    pages = _ok(requests.get(f'{GRAPH}/me/accounts', params={
        'fields': 'id,name,access_token', 'limit': 100, 'access_token': long['access_token']}, timeout=30)).get('data', [])
    if not pages:
        raise RuntimeError('No Facebook Page found on this account.')
    return [db.save_channel(user_id, 'facebook', p['id'], p['name'], {'page': p}) for p in pages]


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

def post(ch, clip, s, public_url):
    """Upload one clip to one channel. Returns (external id, link, notes)."""
    text = post_text(clip, s)
    return {'youtube': _post_youtube, 'instagram': _post_instagram, 'facebook': _post_facebook}[ch['platform']](
        ch, clip, text, s, public_url)


def _yt_error(err):
    """Readable reason from a googleapiclient HttpError."""
    try:
        data = json.loads(err.content.decode())
        return data['error']['errors'][0].get('reason', ''), data['error'].get('message', str(err))
    except Exception:
        return '', str(err)


def _post_youtube(ch, clip, text, s, public_url):
    from googleapiclient.http import MediaFileUpload
    service, creds = yt(ch)
    lang = s.get('target_language') or 'en'
    snippet = {'title': text['title'], 'description': text['body'], 'tags': text['tags'],
               'categoryId': s.get('category_id') or '24', 'defaultLanguage': lang}
    spoken = (clip.get('lang') or s.get('spoken_language') or '').strip()
    if spoken:
        snippet['defaultAudioLanguage'] = spoken
    body = {'snippet': snippet,
            'status': {'privacyStatus': s.get('privacy') or 'public', 'selfDeclaredMadeForKids': False}}
    parts = 'snippet,status'
    loc = {k: v for k, v in (text['loc'] or {}).items() if k != lang and isinstance(v, dict) and v.get('title')}
    if s.get('localize') == '1' and loc:
        body['localizations'] = {k: {'title': v['title'][:100], 'description': (v.get('description') or '')[:4900]}
                                 for k, v in loc.items()}
        parts += ',localizations'
    media = MediaFileUpload(clip['file'], mimetype='video/mp4', chunksize=8 * 1024 * 1024, resumable=True)
    request = service.videos().insert(part=parts, body=body, media_body=media)
    response = None
    while response is None:
        _, response = request.next_chunk()
    video_id = response['id']
    notes = []
    if full_access(ch):
        if s.get('first_comment') == '1' and text['comment']:
            try:
                service.commentThreads().insert(part='snippet', body={'snippet': {
                    'videoId': video_id, 'topLevelComment': {'snippet': {'textOriginal': text['comment']}}}}).execute()
            except Exception as err:
                notes.append('Comment not posted: ' + _yt_error(err)[1][:120])
        if s.get('playlist') == '1':
            try:
                pl = ensure_playlist(ch, s.get('_campaign_id'), s.get('_campaign_name') or 'Shorts', service)
                service.playlistItems().insert(part='snippet', body={'snippet': {
                    'playlistId': pl, 'resourceId': {'kind': 'youtube#video', 'videoId': video_id}}}).execute()
            except Exception as err:
                notes.append('Not added to playlist: ' + _yt_error(err)[1][:120])
    keep(ch, creds)
    return video_id, f'https://youtube.com/shorts/{video_id}', '; '.join(notes)


def ensure_playlist(ch, campaign_id, name, service=None):
    """The playlist this channel keeps for a campaign (made the first time)."""
    lists = dict(db.channel(ch['id'])['d'].get('playlists') or {})
    key = str(campaign_id or 0)
    if lists.get(key):
        return lists[key]
    own = service is None
    if own:
        service, creds = yt(ch)
    res = service.playlists().insert(part='snippet,status', body={
        'snippet': {'title': name[:150], 'description': f'{name}: best moments, new clips every day.'},
        'status': {'privacyStatus': 'public'}}).execute()
    lists[key] = res['id']
    db.set_channel_data(ch['id'], playlists=lists)
    if own:
        keep(ch, creds)
    return res['id']


def yt_stats(ch, video_ids):
    """{video_id: {'views', 'likes', 'comments'}} for up to 50 videos (1 quota unit)."""
    service, creds = yt(ch)
    res = service.videos().list(part='statistics', id=','.join(video_ids[:50])).execute()
    keep(ch, creds)
    out = {}
    for item in res.get('items', []):
        st = item.get('statistics', {})
        out[item['id']] = {'views': int(st.get('viewCount', 0)), 'likes': int(st.get('likeCount', 0)),
                           'comments': int(st.get('commentCount', 0))}
    return out


# ---------- channel setup (YouTube) ----------

def yt_branding(ch):
    service, creds = yt(ch)
    items = service.channels().list(part='brandingSettings,snippet', mine=True).execute().get('items') or []
    keep(ch, creds)
    return items[0] if items else {}


def yt_apply_branding(ch, description=None, keywords=None, country=None, language=None, banner_url=None):
    service, creds = yt(ch)
    item = (service.channels().list(part='brandingSettings', mine=True).execute().get('items') or [{}])[0]
    branding = item.get('brandingSettings') or {}
    chan = dict(branding.get('channel') or {})
    if description is not None:
        chan['description'] = description[:1000]
    if keywords is not None:
        chan['keywords'] = keywords[:500]
    if country:
        chan['country'] = country
    if language:
        chan['defaultLanguage'] = language
    chan.pop('title', None)
    body = {'id': item.get('id') or ch['ext_id'], 'brandingSettings': {'channel': chan}}
    if banner_url:
        body['brandingSettings']['image'] = {'bannerExternalUrl': banner_url}
    service.channels().update(part='brandingSettings', body=body).execute()
    keep(ch, creds)


def yt_upload_banner(ch, png: Path):
    from googleapiclient.http import MediaFileUpload
    service, creds = yt(ch)
    res = service.channelBanners().insert(media_body=MediaFileUpload(str(png), mimetype='image/png')).execute()
    keep(ch, creds)
    yt_apply_branding(db.channel(ch['id']), banner_url=res['url'])


def yt_set_watermark(ch, png: Path):
    from googleapiclient.http import MediaFileUpload
    service, creds = yt(ch)
    service.watermarks().set(channelId=ch['ext_id'], body={
        'timing': {'type': 'offsetFromStart', 'offsetMs': 0},
        'position': {'type': 'corner', 'cornerPosition': 'bottomRight'}},
        media_body=MediaFileUpload(str(png), mimetype='image/png')).execute()
    keep(ch, creds)


# ---------- Instagram and Facebook ----------

def _post_instagram(ch, clip, text, s, public_url):
    data = ch['d']
    token = data['token']
    if time.time() - data.get('refreshed', 0) > 7 * 86400:
        fresh = _ok(requests.get('https://graph.instagram.com/refresh_access_token', params={
            'grant_type': 'ig_refresh_token', 'access_token': token}, timeout=30))
        token = fresh['access_token']
        db.set_channel_data(ch['id'], token=token, refreshed=time.time())
    ig_id = data.get('ig_id') or ch['ext_id']
    container = _ok(requests.post(f'{IG_GRAPH}/{ig_id}/media', data={
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
    media_id = _ok(requests.post(f'{IG_GRAPH}/{ig_id}/media_publish', data={
        'creation_id': container, 'access_token': token}, timeout=60))['id']
    link = _ok(requests.get(f'{IG_GRAPH}/{media_id}', params={'fields': 'permalink', 'access_token': token},
                            timeout=30)).get('permalink', '')
    notes = ''
    if s.get('first_comment') == '1' and text['comment']:
        try:
            _ok(requests.post(f'{IG_GRAPH}/{media_id}/comments', data={'message': text['comment'], 'access_token': token},
                              timeout=30))
        except Exception as err:
            notes = f'Comment not posted: {str(err)[:120]}'
    return media_id, link, notes


def _post_facebook(ch, clip, text, s, public_url):
    page = ch['d']['page']
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
    return video_id, f'https://www.facebook.com/reel/{video_id}', ''
