# Clipper

Turns long videos into vertical clips (Shorts / Reels) and posts them to YouTube, Instagram and Facebook.

Link or upload → Whisper transcript → AI picks the best moments → 9:16 crop that follows the speaker → word-by-word captions → AI title, description, tags and hashtags → scheduled posting.

## Environment

| Variable | What |
|---|---|
| `PUBLIC_URL` | e.g. `https://clips.chatssync.online` |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | Owner login, created on first start (`ADMIN_PASSWORD_RESET=1` to reset) |
| `YT_CLIENT_ID`, `YT_CLIENT_SECRET` | Google OAuth web client (redirect `PUBLIC_URL/oauth/youtube/callback`) |
| `IG_APP_ID`, `IG_APP_SECRET` | Meta app, Instagram API with Instagram Login (redirect `/oauth/instagram/callback`) |
| `META_APP_ID`, `META_APP_SECRET` | Meta app, Facebook Login (redirect `/oauth/facebook/callback`) |
| `MISTRAL_API_KEY` | Optional. Smarter clip picks and post text |
| `CPU_THREADS` | Cores used for transcript and editing (default 2) |
| `MIN_FREE_GB` | New videos wait when free disk is below this (default 8) |
| `YT_DAILY_LIMIT` | YouTube uploads per day across all users (default 95) |

Data lives in `/data` (mount a volume). One video is processed at a time; users take turns in the queue.
