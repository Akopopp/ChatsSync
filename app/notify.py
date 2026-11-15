"""Alerts to the user's own Telegram (optional): posted, failed, clips ready."""
import threading

import requests

from . import db


def send(user_id, kind, text):
    """kind: 'posted' | 'failed' | 'done'. Silent when the user has not set up Telegram or turned that alert off."""
    s = db.settings(user_id)
    token, chat = s.get('telegram_token', '').strip(), s.get('telegram_chat', '').strip()
    if not token or not chat or s.get(f'alert_{kind}', '1') != '1':
        return

    def go():
        try:
            requests.post(f'https://api.telegram.org/bot{token}/sendMessage', timeout=20,
                          data={'chat_id': chat, 'text': text[:3500], 'disable_web_page_preview': 'true'})
        except Exception as err:
            print('telegram alert failed', err)
    threading.Thread(target=go, daemon=True).start()


def test(user_id):
    s = db.settings(user_id)
    token, chat = s.get('telegram_token', '').strip(), s.get('telegram_chat', '').strip()
    if not token or not chat:
        return 'Add the bot token and your chat id first.'
    try:
        res = requests.post(f'https://api.telegram.org/bot{token}/sendMessage', timeout=20,
                            data={'chat_id': chat, 'text': 'Clipper alerts are working.'})
        return '' if res.ok else res.json().get('description', 'Telegram said no.')
    except Exception as err:
        return str(err)[:200]
