# Clipper

Turns long videos into vertical clips (Shorts / Reels) and posts them to YouTube, Instagram and Facebook.

Link or upload → Whisper transcript → AI picks the best moments → pro edit → AI post text for the target country → posting at that country's peak hours.

## Features

- **Campaigns**: brief for the AI, target country and language, the channels to post to, posting rules, editing style, auto-pilot. Every switch is explained on the page.
- **Many channels**: any number of YouTube channels, Instagram accounts and Facebook Pages; daily limit per channel; upload-limit errors move posts to the next day.
- **AI post text**: best of 3 titles, 70-150 word description, 15-25 tags, hashtags, first comment, translated titles (localizations), learns from the best-performing titles.
- **Pro edit**: smooth face follow, pause and "um" cuts, zoom cuts, 5 caption styles with colored keywords, emojis, hook text, translated captions, progress bar, music with ducking, sound effects, Pexels B-roll, loudness, ending text, watermark. Falls back to a simpler edit if anything fails.
- **Channel setup**: AI channel description and keywords, country/language, banner upload, subscribe watermark, playlists, logo to download.
- **Auto-pilot**: watches creators' channels and clips new uploads.
- **Stats**: views/likes/comments per campaign, channel and clip.
- **AI helper**: chat that explains the app and does the work (asks before posting or deleting).
- **Telegram alerts** per user.

## Environment

| Variable | What |
|---|---|
| `PUBLIC_URL` | e.g. `https://clips.chatssync.online` |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | Owner login, created on first start (`ADMIN_PASSWORD_RESET=1` to reset) |
| `YT_CLIENT_ID`, `YT_CLIENT_SECRET` | Google OAuth web client (redirect `PUBLIC_URL/oauth/youtube/callback`) |
| `IG_APP_ID`, `IG_APP_SECRET` | Meta app, Instagram API with Instagram Login (redirect `/oauth/instagram/callback`) |
| `META_APP_ID`, `META_APP_SECRET` | Meta app, Facebook Login (redirect `/oauth/facebook/callback`) |
| `GEMINI_API_KEY` | Optional, free from aistudio.google.com/apikey. Smarter clip picks and post text (`MISTRAL_API_KEY` also works) |
| `CPU_THREADS` | Cores used for transcript and editing (default 2) |
| `MIN_FREE_GB` | New videos wait when free disk is below this (default 8) |
| `YT_DAILY_LIMIT` | YouTube uploads per day across all users (default 95) |
| `PEXELS_API_KEY` | Optional, free from pexels.com/api. Turns on stock B-roll in the edit |
| `AUTOPILOT_MINUTES` | How often auto-pilot looks for new uploads (default 20) |

YouTube channels need the scopes `youtube.upload`, `youtube` and `youtube.force-ssl` (comments, playlists, channel setup). Channels connected before this update keep posting; reconnect them for the extras.

Data lives in `/data` (mount a volume). One video is processed at a time; users take turns in the queue.
