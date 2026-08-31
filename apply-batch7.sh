#!/bin/bash
# ============================================================
#  ChatsSync — Batch 7 : POORA WhatsApp theme (ek file)
#      cd /root/staging-build && git pull && bash apply-batch7.sh
#
#  Sirf app.scss badalti hai. Hatana ho to us file ka
#  "ChatsSync — WhatsApp theme" wala block delete kar do.
# ============================================================
set -e
REPO="/root/staging-build"
COMPOSE="/data/coolify/applications/vdcb3i4jbkc4jsw204xguhk5"
[ -f "$REPO/docker/Dockerfile" ] || { echo "ERROR: repo $REPO mein nahi mila"; exit 1; }
cd "$REPO"
echo ""
echo "=== 1/3  app.scss likh raha hun ==="
cat > app/javascript/dashboard/assets/scss/app.scss << 'CS_EOF_8f4e1'
@import 'woot';
/* ===== ChatsSync: WhatsApp-style compact reply box on mobile ===== */
@media (max-width: 767px) {
  /* rich text editor (default composer) - starts small, grows with text, scrolls after ~5 lines */
  .reply-box .ProseMirror-woot-style,
  .reply-box .ProseMirror,
  .reply-box .editor-root {
    min-height: 38px !important;
    max-height: 120px !important;
    overflow-y: auto !important;
  }
  /* plain textarea mode (if rich editor is off) */
  .reply-box textarea {
    min-height: 38px !important;
    max-height: 120px !important;
    overflow-y: auto !important;
  }
  /* slightly tighter padding so it feels like WhatsApp */
  .reply-box .reply-box__top {
    padding-top: 4px !important;
    padding-bottom: 4px !important;
  }
}
/* ===== ChatsSync: cleaner composer (no tabs, no hint line) ===== */

/* 1) Reply / Private Note toggle — hide everywhere (composer stays in Reply mode) */
div:has(> [class*='--chip-width']),
.reply-box [class*='bg-n-alpha-2'][class*='rounded-full'][class*='h-8'][class*='p-1'] {
  display: none !important;
}

/* 2) Mobile: hide the whole top row of the composer to reclaim space */
@media (max-width: 767px) {
  .reply-box [class*='h-[3.25rem]'] {
    display: none !important;
  }
}

/* 3) Replace the long "Shift + enter..." hint inside the box with a short WhatsApp-style placeholder */
.ProseMirror p.is-editor-empty:first-child::before,
.ProseMirror .is-empty::before {
  content: 'Message…' !important;
}
/* hint line fix v2 — Chatwoot editor uses .empty-node for the placeholder */
.ProseMirror p.empty-node::before,
.ProseMirror .empty-node::before,
.editor-root .empty-node::before {
  content: 'Message…' !important;
}

/* ==========================================================================
   ChatsSync — WhatsApp theme (poora app)
   Ek hi jagah. Hatana ho to yeh poora block delete kar do.
   ========================================================================== */

/* ---------------- 1. RANG ---------------- */
:root {
  --cs-sent: 217 253 211;
  --cs-recv: 255 255 255;
  --cs-chat-bg: 239 231 222;
  --cs-panel: 255 255 255;
  --cs-rail: 240 242 245;
  --cs-head: 240 242 245;
  --cs-green: 0 128 105;
  --cs-tick: 47 127 209;
}

.dark {
  --cs-sent: 0 92 75;
  --cs-recv: 32 44 51;
  --cs-chat-bg: 11 20 26;
  --cs-panel: 17 27 33;
  --cs-rail: 32 44 51;
  --cs-head: 32 44 51;
  --cs-green: 0 168 132;
  --cs-tick: 83 189 235;
}

/* ---------------- 2. RAIL ---------------- */
aside[class*='bg-n-background'] {
  background: rgb(var(--cs-rail)) !important;
  border-right-color: rgba(0, 0, 0, 0.06) !important;
}
.dark aside[class*='bg-n-background'] {
  border-right-color: rgba(255, 255, 255, 0.06) !important;
}
aside a[class*='rounded'],
aside button[class*='rounded'] {
  border-radius: 50% !important;
}
aside a[class*='bg-n-alpha'],
aside a[aria-current='page'] {
  background: rgba(var(--cs-green) / 0.15) !important;
  color: rgb(var(--cs-green)) !important;
}

/* ---------------- 3. CHAT LIST PANEL ---------------- */
.conversations-list-wrap {
  background: rgb(var(--cs-panel)) !important;
}

/* header */
.conversations-list-wrap > div > div:first-child {
  background: rgb(var(--cs-panel));
}

/* row */
.conversation {
  padding-top: 0 !important;
  padding-bottom: 0 !important;
  border-bottom: none !important;

  .border-line {
    border-bottom: 1px solid rgba(0, 0, 0, 0.06);
    padding-top: 0.6rem !important;
    padding-bottom: 0.6rem !important;
  }
  &:last-child .border-line {
    border-bottom: none;
  }
  &:hover {
    background: rgba(0, 0, 0, 0.035) !important;
  }
  &.active {
    background: rgba(0, 0, 0, 0.06) !important;
  }
}
.dark .conversation {
  .border-line {
    border-bottom-color: rgba(255, 255, 255, 0.06);
  }
  &:hover {
    background: rgba(255, 255, 255, 0.04) !important;
  }
  &.active {
    background: rgba(255, 255, 255, 0.07) !important;
  }
}

/* unread badge = hara circle */
.conversation [class*='bg-n-brand'],
.conversation [class*='bg-woot'] {
  background: rgb(var(--cs-green)) !important;
  color: #fff !important;
  border-radius: 999px !important;
}

/* ---------------- 4. CHAT HEADER ---------------- */
.conversation--header,
[class*='conversation--header'] {
  background: rgb(var(--cs-head)) !important;
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}
.dark .conversation--header {
  border-bottom-color: rgba(255, 255, 255, 0.06);
}

/* ---------------- 5. THREAD ---------------- */
.conversation-panel {
  padding-left: 5% !important;
  padding-right: 5% !important;
}
@media (max-width: 767px) {
  .conversation-panel {
    padding-left: 0.6rem !important;
    padding-right: 0.6rem !important;
  }
}

/* din ka separator */
.conversation-panel [class*='date-separator'] span,
.conversation-panel .date-separator span {
  background: rgb(var(--cs-head)) !important;
  border-radius: 0.5rem !important;
  padding: 0.3rem 0.8rem !important;
  font-size: 0.75rem !important;
  box-shadow: 0 1px 0.5px rgba(0, 0, 0, 0.13);
  border: 0 !important;
}

/* system / activity message */
.conversation-panel [class*='bg-n-alpha-1'][class*='rounded-lg'] {
  border-radius: 0.5rem !important;
  box-shadow: 0 1px 0.5px rgba(0, 0, 0, 0.13);
}

/* ---------------- 6. BUBBLES ---------------- */
.message-bubble-container {
  margin-bottom: 0.25rem !important;
}

.message-bubble-container .left-bubble,
.message-bubble-container .right-bubble {
  padding: 0.375rem 0.5rem 0.4rem 0.5rem !important;
  box-shadow: 0 1px 0.5px rgba(0, 0, 0, 0.13);
  max-width: 65% !important;
}
.dark .message-bubble-container .left-bubble,
.dark .message-bubble-container .right-bubble {
  box-shadow: 0 1px 0.5px rgba(0, 0, 0, 0.35);
}

@media (max-width: 767px) {
  .message-bubble-container .left-bubble,
  .message-bubble-container .right-bubble {
    max-width: 82% !important;
  }
}

/* ticks neele */
.message-bubble-container [class*='text-n-teal'],
.message-bubble-container [class*='i-lucide-check'] {
  color: rgb(var(--cs-tick)) !important;
}

/* ---------------- 7. COMPOSER ---------------- */
.reply-box {
  border-radius: 1.5rem !important;
  margin: 0.5rem 0.75rem 0.75rem !important;
  border-color: rgba(0, 0, 0, 0.08) !important;
}
.dark .reply-box {
  border-color: rgba(255, 255, 255, 0.06) !important;
}

/* height: ek line se shuru — saved height ko bhi override karo */
.reply-box .ProseMirror-woot-style,
.reply-box .ProseMirror,
.reply-box .editor-root,
.resizable-editor-wrapper .ProseMirror-woot-style {
  min-height: 1.5rem !important;
  max-height: 7.5rem !important;
}

/* drag handle chhupao — height ab fix hai */
.reply-box [class*='cursor-row-resize'],
.reply-box [class*='cursor-ns-resize'] {
  display: none !important;
}

.reply-box .left-wrap button {
  opacity: 0.75;
}
.reply-box .left-wrap button:hover {
  opacity: 1;
}

/* ---------------- 8. CONTACT PANEL (right side) ---------------- */
[class*='conversation-sidebar'],
.conversation-sidebar-wrap {
  background: rgb(var(--cs-panel)) !important;
}

/* ---------------- 9. BAAKI TABS (contacts, campaigns…) ---------------- */
/* poore app ka background WhatsApp jaisa */
.app-wrapper,
.dashboard-app,
main {
  background: rgb(var(--cs-chat-bg) / 0.15);
}
.dark .app-wrapper,
.dark .dashboard-app,
.dark main {
  background: rgb(var(--cs-panel));
}

/* har jagah primary button hara */
button[class*='bg-n-brand'],
.button--primary,
button[class*='bg-woot-500'] {
  background: rgb(var(--cs-green)) !important;
  border-color: rgb(var(--cs-green)) !important;
}
button[class*='bg-n-brand']:hover,
.button--primary:hover {
  filter: brightness(1.08);
}

/* links aur active states hare */
a[class*='text-n-brand'],
[class*='text-woot-500'] {
  color: rgb(var(--cs-green)) !important;
}

/* tables aur cards ko softer */
table thead {
  background: rgba(0, 0, 0, 0.03);
}
.dark table thead {
  background: rgba(255, 255, 255, 0.03);
}

/* ---------------- 10. SCROLLBARS ---------------- */
::-webkit-scrollbar {
  width: 6px;
  height: 6px;
}
::-webkit-scrollbar-thumb {
  background: rgba(0, 0, 0, 0.18);
  border-radius: 3px;
}
.dark ::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.14);
}
::-webkit-scrollbar-track {
  background: transparent;
}

/* ---------------- 11. TRANSITIONS ---------------- */
.conversation,
aside a,
aside button,
.cs-pills button {
  transition: background-color 0.13s ease, color 0.13s ease;
}
CS_EOF_8f4e1
echo "  ok  app/javascript/dashboard/assets/scss/app.scss"
echo ""
echo "=== 2/3  Build ==="
docker build -f docker/Dockerfile -t chatssync-staging:latest .
echo ""
echo "=== 3/3  Restart ==="
cd "$COMPOSE"
docker compose up -d
echo ""
echo "============================================"
echo "  HO GAYA — Ctrl+Shift+R dabana"
echo "  Light aur dark dono check karna"
echo "============================================"
