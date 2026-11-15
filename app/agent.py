"""The AI helper: answers questions about the app and does the work in it (campaigns, videos, clips).
Anything that publishes, deletes or changes where clips go waits for the user to press Confirm."""
import json
import secrets
import threading
import time

from . import ai, auth, db, fields, geo, media, pipeline, platforms

GUIDE = '''You are the built-in helper of "{app}", an app that turns long videos into Shorts/Reels and posts them.
How the app works:
- Campaigns: each campaign has a brief (what it is about, audience, tone, rules), a target country and language, the
  channels its clips go to, posting rules, editing style and auto-pilot. Every video belongs to one campaign.
- Channels: any number of YouTube channels, Instagram accounts and Facebook Pages can be connected (Channels page,
  "Add YouTube channel"; for a second YouTube channel pick it in Google's account/channel chooser). Each channel has a
  daily limit; new/unverified YouTube channels can upload only ~10-15 videos a day (verify at youtube.com/verify).
- New clips page: paste one or many links (or upload a file), pick the campaign. The app transcribes, the AI picks the
  best moments, writes title/description/tags/hashtags/first comment for the target country, edits each clip (face
  follow, pause and "um" cuts, zoom cuts, styled captions with colored keywords and emojis, hook text, progress bar,
  music, sound effects, B-roll, translated captions) and then posts on schedule (or waits for approval).
- Channel setup page (per YouTube channel): AI writes the channel description and keywords, sets country and language,
  makes and uploads a banner, sets the subscribe watermark, and makes a logo to download. YouTube does not let apps
  change the channel name, handle or profile picture: those are done in YouTube Studio.
- Stats page: views, likes and comments of posted clips, per campaign and channel. The AI learns from the best titles.
- Settings page: Telegram alerts and password.
Campaign settings you can change (key: meaning):
{fields}
Rules for you:
- Answer in the same language and style the user writes in (Roman Urdu / Hinglish is fine). Be short and clear.
- Use the tools to look things up and do the work. Never invent ids: call overview first.
- Actions that post, delete, turn on auto-posting or change a campaign's channels show the user a Confirm button.
  When a tool says it is waiting for confirmation, tell the user to press Confirm.
- Never promise views or say content can't get copyright claims. Remind people to clip only creators who allowed it.
- When you change settings, say in one line what you changed.'''

TOOLS = [
    {'name': 'overview', 'description': "The user's campaigns, connected channels, recent videos and today's posting numbers.",
     'parameters': {'type': 'OBJECT', 'properties': {'details': {'type': 'BOOLEAN', 'description': 'unused'}}}},
    {'name': 'get_campaign', 'description': 'All settings and the brief of one campaign.',
     'parameters': {'type': 'OBJECT', 'properties': {'campaign_id': {'type': 'INTEGER'}}, 'required': ['campaign_id']}},
    {'name': 'create_campaign', 'description': 'Make a new campaign.',
     'parameters': {'type': 'OBJECT', 'properties': {
         'name': {'type': 'STRING'}, 'brief': {'type': 'STRING', 'description': 'What it is about, audience, tone, rules'},
         'changes': {'type': 'ARRAY', 'description': 'settings to set', 'items': {'type': 'OBJECT', 'properties': {
             'key': {'type': 'STRING'}, 'value': {'type': 'STRING'}}, 'required': ['key', 'value']}}},
         'required': ['name']}},
    {'name': 'update_campaign', 'description': 'Change the name, brief or settings of a campaign.',
     'parameters': {'type': 'OBJECT', 'properties': {
         'campaign_id': {'type': 'INTEGER'}, 'name': {'type': 'STRING'}, 'brief': {'type': 'STRING'},
         'changes': {'type': 'ARRAY', 'items': {'type': 'OBJECT', 'properties': {
             'key': {'type': 'STRING'}, 'value': {'type': 'STRING'}}, 'required': ['key', 'value']}}},
         'required': ['campaign_id']}},
    {'name': 'set_campaign_channels', 'description': 'Choose which connected channels a campaign posts to.',
     'parameters': {'type': 'OBJECT', 'properties': {
         'campaign_id': {'type': 'INTEGER'}, 'channel_ids': {'type': 'ARRAY', 'items': {'type': 'INTEGER'}}},
         'required': ['campaign_id', 'channel_ids']}},
    {'name': 'set_channel_limit', 'description': 'Set how many videos a channel may post per day.',
     'parameters': {'type': 'OBJECT', 'properties': {'channel_id': {'type': 'INTEGER'}, 'per_day': {'type': 'INTEGER'}},
                    'required': ['channel_id', 'per_day']}},
    {'name': 'add_videos', 'description': 'Start making clips from one or more video links in a campaign.',
     'parameters': {'type': 'OBJECT', 'properties': {
         'campaign_id': {'type': 'INTEGER'}, 'links': {'type': 'ARRAY', 'items': {'type': 'STRING'}}},
         'required': ['campaign_id', 'links']}},
    {'name': 'get_video', 'description': 'Status of one video and its clips (ids, titles, status, where posted).',
     'parameters': {'type': 'OBJECT', 'properties': {'job_id': {'type': 'INTEGER'}}, 'required': ['job_id']}},
    {'name': 'post_clip', 'description': "Post a ready clip on its campaign's channels (asks the user to confirm).",
     'parameters': {'type': 'OBJECT', 'properties': {'clip_id': {'type': 'INTEGER'}}, 'required': ['clip_id']}},
    {'name': 'remove_clip', 'description': 'Remove a clip (asks the user to confirm).',
     'parameters': {'type': 'OBJECT', 'properties': {'clip_id': {'type': 'INTEGER'}}, 'required': ['clip_id']}},
    {'name': 'rewrite_clip_text', 'description': "Write a clip's title, description, tags and comment again with AI.",
     'parameters': {'type': 'OBJECT', 'properties': {'clip_id': {'type': 'INTEGER'}}, 'required': ['clip_id']}},
    {'name': 'check_sources_now', 'description': "Look right now for new uploads on a campaign's auto-pilot channels.",
     'parameters': {'type': 'OBJECT', 'properties': {'campaign_id': {'type': 'INTEGER'}}, 'required': ['campaign_id']}},
]

CONFIRM = {'post_clip', 'remove_clip', 'set_campaign_channels'}


def _own_campaign(user, cid):
    camp = db.campaign(int(cid or 0))
    if not camp or (camp['user_id'] != user['id'] and user['role'] != 'admin'):
        raise ValueError('No campaign with that id.')
    return camp


def _own_clip(user, clip_id):
    clip = db.one('select * from clips where id=?', (int(clip_id or 0),))
    if not clip or (clip['user_id'] != user['id'] and user['role'] != 'admin'):
        raise ValueError('No clip with that id.')
    return clip


def _changes(items):
    out, bad = {}, []
    for item in items or []:
        key, value = str(item.get('key', '')).strip(), item.get('value', '')
        cleaned = fields.clean(key, value)
        if cleaned is None:
            bad.append(key)
        else:
            out[key] = cleaned
    return out, bad


def overview(user):
    chans = db.channels(user['id'])
    names = {c['id']: f'{c["name"]} ({platforms.NAMES[c["platform"]]})' for c in chans}
    camps = [{'id': c['id'], 'name': c['name'], 'country': geo.country_name(c['s']['country']),
              'auto_post': c['s']['auto_post'] == '1', 'auto_pilot': c['s']['autopilot'] == '1',
              'channels': [names.get(i, f'#{i} (removed)') for i in c['channel_ids']]} for c in db.campaigns(user['id'])]
    jobs = db.q('select id, title, source, status, step, error, campaign_id from jobs where user_id=? order by id desc limit 8',
                (user['id'],))
    today = db.one('select count(*) as n from posts where user_id=? and status="posted" and posted_at>?',
                   (user['id'], time.time() - 86400))['n']
    waiting = db.one('select count(*) as n from posts where user_id=? and status="waiting"', (user['id'],))['n']
    return {'campaigns': camps,
            'channels': [{'id': c['id'], 'name': c['name'], 'platform': c['platform'], 'per_day_limit': c['daily_limit'],
                          'note': c['note']} for c in chans],
            'recent_videos': [{'id': j['id'], 'title': (j['title'] or j['source'])[:80], 'status': j['status'],
                               'campaign_id': j['campaign_id'], 'note': (j['error'] or j['step'] or '')[:160]} for j in jobs],
            'posted_last_24h': today, 'posts_waiting': waiting, 'usage': auth.access_problem(user) or 'ok'}


def run_tool(user, name, args, pending):
    try:
        if name in CONFIRM or (name == 'update_campaign' and any(
                str(c.get('key')) in ('auto_post', 'channels') for c in args.get('changes') or [])):
            summary = describe_action(user, name, args)
            token = secrets.token_urlsafe(12)
            db.set_stat(f'pending_{token}', {'user': user['id'], 'name': name, 'args': args, 'at': time.time()})
            pending.append({'token': token, 'summary': summary})
            return {'status': 'waiting_for_confirmation', 'shown_to_user': summary}
        return execute(user, name, args)
    except Exception as err:
        return {'error': str(err)[:300]}


def describe_action(user, name, args):
    if name == 'post_clip':
        clip = _own_clip(user, args.get('clip_id'))
        job = db.one('select * from jobs where id=?', (clip['job_id'],))
        camp = db.job_campaign(job)
        chans = ', '.join(c['name'] for c in (db.channel(i) for i in camp['channel_ids']) if c) or 'no channel yet'
        return f'Post clip "{clip["title"]}" to: {chans}'
    if name == 'remove_clip':
        clip = _own_clip(user, args.get('clip_id'))
        return f'Remove clip "{clip["title"]}"'
    if name == 'set_campaign_channels':
        camp = _own_campaign(user, args.get('campaign_id'))
        chans = ', '.join(c['name'] for c in (db.channel(int(i)) for i in args.get('channel_ids') or [])
                          if c and c['user_id'] == user['id']) or 'no channels'
        return f'Campaign "{camp["name"]}" will post to: {chans}'
    if name == 'update_campaign':
        camp = _own_campaign(user, args.get('campaign_id'))
        changes, _ = _changes(args.get('changes'))
        parts = [f'{fields.FIELDS.get(k, (k,))[0]} = {v}' for k, v in changes.items()]
        return f'Change campaign "{camp["name"]}": ' + '; '.join(parts)
    return name


def execute(user, name, args):
    if name == 'overview':
        return overview(user)
    if name == 'get_campaign':
        camp = _own_campaign(user, args.get('campaign_id'))
        return {'id': camp['id'], 'name': camp['name'], 'brief': camp['brief'], 'settings': camp['s']}
    if name == 'create_campaign':
        changes, bad = _changes(args.get('changes'))
        changes.pop('auto_post', None)
        cid = db.create_campaign(user['id'], args.get('name') or 'New campaign', args.get('brief', ''), changes)
        return {'created_campaign_id': cid, 'ignored_settings': bad,
                'next': 'Pick its channels (set_campaign_channels) and turn on auto_post if wanted.'}
    if name == 'update_campaign':
        camp = _own_campaign(user, args.get('campaign_id'))
        changes, bad = _changes(args.get('changes'))
        db.update_campaign(camp['id'], name=args.get('name'), brief=args.get('brief'), values=changes)
        return {'updated': list(changes), 'ignored_settings': bad}
    if name == 'set_campaign_channels':
        camp = _own_campaign(user, args.get('campaign_id'))
        ids = [str(c['id']) for c in (db.channel(int(i)) for i in args.get('channel_ids') or [])
               if c and c['user_id'] == user['id']]
        db.update_campaign(camp['id'], values={'channels': ','.join(ids)})
        return {'campaign': camp['name'], 'channels': ids}
    if name == 'set_channel_limit':
        ch = db.channel(int(args.get('channel_id') or 0))
        if not ch or ch['user_id'] != user['id']:
            raise ValueError('No channel with that id.')
        per_day = min(max(int(args.get('per_day') or 1), 1), 100)
        db.run('update channels set daily_limit=? where id=?', (per_day, ch['id']))
        return {'channel': ch['name'], 'per_day': per_day}
    if name == 'add_videos':
        camp = _own_campaign(user, args.get('campaign_id'))
        made = []
        for link in [str(x).strip() for x in args.get('links') or []][:20]:
            problem = auth.access_problem(db.one('select * from users where id=?', (user['id'],)))
            if problem:
                return {'added_video_ids': made, 'stopped': problem}
            if not link.startswith('http'):
                continue
            made.append(add_link(user['id'], link, camp['id']))
        pipeline.wake()
        return {'added_video_ids': made, 'campaign': camp['name']}
    if name == 'get_video':
        job = db.one('select * from jobs where id=?', (int(args.get('job_id') or 0),))
        if not job or (job['user_id'] != user['id'] and user['role'] != 'admin'):
            raise ValueError('No video with that id.')
        clips = db.q('select id, title, status, error, start, end from clips where job_id=? and status != "rejected"', (job['id'],))
        for c in clips:
            c['posts'] = [{'channel': (db.channel(p['channel_id']) or {}).get('name', p['platform']), 'status': p['status'],
                           'url': p['url'], 'error': p['error'][:120]}
                          for p in db.q('select * from posts where clip_id=?', (c['id'],))]
        return {'id': job['id'], 'title': job['title'], 'status': job['status'], 'note': job['error'] or job['step'],
                'clips': clips}
    if name == 'post_clip':
        clip = _own_clip(user, args.get('clip_id'))
        if clip['status'] not in ('ready', 'approved'):
            return {'error': f'This clip is {clip["status"]}, it cannot be posted.'}
        return {'queued': pipeline.approve(clip['id']), 'note': db.one('select error from clips where id=?', (clip['id'],))['error']}
    if name == 'remove_clip':
        clip = _own_clip(user, args.get('clip_id'))
        from pathlib import Path
        if clip['file']:
            Path(clip['file']).unlink(missing_ok=True)
        db.run('delete from posts where clip_id=? and status="waiting"', (clip['id'],))
        db.update_clip(clip['id'], status='rejected', file='')
        return {'removed': clip['id']}
    if name == 'rewrite_clip_text':
        clip = _own_clip(user, args.get('clip_id'))
        problem = pipeline.rewrite_text(clip['id'])
        return {'error': problem} if problem else {'title': db.one('select title from clips where id=?', (clip['id'],))['title']}
    if name == 'check_sources_now':
        camp = _own_campaign(user, args.get('campaign_id'))
        return {'new_videos_added': pipeline.check_sources(camp, first_run_takes=1)}
    return {'error': f'Unknown tool {name}'}


def add_link(user_id, link, campaign_id):
    now = time.time()
    job_id = db.run('insert into jobs(user_id, source, source_type, step, created_at, updated_at, campaign_id) '
                    'values(?,?,?,?,?,?,?)', (user_id, link, media.source_type(link), 'Waiting', now, now, campaign_id))
    if media.source_type(link) == 'link':
        threading.Thread(target=pipeline.prefetch, args=(job_id,), daemon=True).start()
    return job_id


def chat(user, history, app_name):
    """history: [{'role': 'user'|'model', 'text': str}]. Returns {'reply', 'pending': [{'token', 'summary'}]}."""
    system = GUIDE.format(app=app_name, fields=fields.describe())
    contents = []
    for m in history[-16:]:
        text = str(m.get('text', ''))[:4000]
        if text:
            contents.append({'role': 'user' if m.get('role') == 'user' else 'model', 'parts': [{'text': text}]})
    if not contents or contents[-1]['role'] != 'user':
        return {'reply': 'Ask me anything about the app.', 'pending': []}
    pending = []
    for _ in range(8):
        content = ai.chat_with_tools(contents, system, TOOLS)
        parts = content.get('parts', [])
        calls = [p['functionCall'] for p in parts if 'functionCall' in p]
        if not calls:
            text = ''.join(p.get('text', '') for p in parts if not p.get('thought')).strip()
            return {'reply': text or 'Done.', 'pending': pending}
        contents.append({'role': 'model', 'parts': parts})
        replies = []
        for call in calls:
            result = run_tool(user, call.get('name', ''), call.get('args') or {}, pending)
            replies.append({'functionResponse': {'name': call.get('name', ''),
                                                 'response': {'result': json.loads(json.dumps(result, default=str))}}})
        contents.append({'role': 'user', 'parts': replies})
    return {'reply': 'I did several steps. Check the pages for the result.', 'pending': pending}


def confirm(user, token):
    key = f'pending_{token}'
    action = db.stat(key)
    db.run('delete from stats where key=?', (key,))
    if not action or action['user'] != user['id'] or action['at'] < time.time() - 1800:
        return 'This request expired. Ask the helper again.'
    try:
        result = execute(user, action['name'], action['args'])
    except Exception as err:
        return f'Could not do it: {str(err)[:200]}'
    if isinstance(result, dict) and result.get('error'):
        return result['error']
    return 'Done.'
