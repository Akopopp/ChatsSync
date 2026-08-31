#!/bin/bash
# ============================================================
#  ChatsSync — Batch 5 : ek hi CSS file mein poora WhatsApp look
#      cd /root/staging-build && git pull && bash apply-batch5.sh
# ============================================================
set -e
REPO="/root/staging-build"
COMPOSE="/data/coolify/applications/vdcb3i4jbkc4jsw204xguhk5"
[ -f "$REPO/docker/Dockerfile" ] || { echo "ERROR: repo $REPO mein nahi mila"; exit 1; }
cd "$REPO"
echo ""
echo "=== 1/3  app.scss likh raha hun ==="
cat > app/javascript/dashboard/assets/scss/app.scss << 'CS_EOF_5d0a3'
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
   ChatsSync — WhatsApp look (global)
   Ek hi jagah, taake har cheez ke liye alag component na chhoona pade.
   Hatana ho to bas is block ko delete kar do.
   ========================================================================== */

/* ---------- 1. CHAT LIST ROW ---------- */
.conversation {
  padding-top: 0 !important;
  padding-bottom: 0 !important;

  /* WhatsApp ka hairline divider avatar ke baad shuru hota hai */
  border-bottom: none !important;

  .border-line {
    border-bottom: 1px solid rgb(var(--slate-3));
    padding-top: 0.625rem !important;
    padding-bottom: 0.625rem !important;
  }

  &:last-child .border-line {
    border-bottom: none;
  }

  &:hover {
    background: rgba(var(--alpha-2)) !important;
  }

  &.active {
    background: rgb(var(--slate-3)) !important;
  }
}

.dark .conversation.active {
  background: rgb(var(--slate-4)) !important;
}

/* waqt aur badge ko WhatsApp jaisi jagah */
.conversation .conversation--meta,
.conversation [class*='conversation--meta'] {
  align-self: flex-start;
}

/* ---------- 2. CHAT LIST HEADER ---------- */
/* "Conversations" ko bada aur WhatsApp jaisa */
.conversations-sidebar-header h1,
.conversations-list-wrap h1 {
  font-size: 1.35rem !important;
  font-weight: 600 !important;
  letter-spacing: -0.02em;
}

/* ---------- 3. FILTER PILLS ---------- */
.cs-pills button {
  transition: background-color 0.14s ease, color 0.14s ease;
}

/* ---------- 4. MESSAGE BUBBLES ---------- */
/* bubble ke andar ki padding WhatsApp jaisi tight */
.message-bubble-container .left-bubble,
.message-bubble-container .right-bubble {
  padding: 0.375rem 0.5rem 0.4rem 0.5rem !important;
  box-shadow: 0 1px 0.5px rgba(0, 0, 0, 0.13);
}

.dark .message-bubble-container .left-bubble,
.dark .message-bubble-container .right-bubble {
  box-shadow: 0 1px 0.5px rgba(0, 0, 0, 0.35);
}

/* messages ke beech ka faasla kam */
.message-bubble-container {
  margin-bottom: 0.25rem !important;
}

/* bhejne wale ka naam chhota aur hara */
.message-bubble-container .right-bubble .text-n-slate-11:first-child {
  font-size: 0.78rem;
}

/* ---------- 5. THREAD ---------- */
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

/* din ka separator WhatsApp jaisa pill */
.conversation-panel .date-separator,
.conversation-panel [class*='date-separator'] span {
  background: rgb(var(--solid-1)) !important;
  border-radius: 0.5rem !important;
  padding: 0.3rem 0.75rem !important;
  font-size: 0.75rem !important;
  box-shadow: 0 1px 0.5px rgba(0, 0, 0, 0.13);
}

/* ---------- 6. COMPOSER ---------- */
.reply-box {
  border-radius: 1.5rem !important;
  margin: 0.5rem 0.75rem 0.75rem !important;
}

/* composer ki height ek line se shuru */
.reply-box .ProseMirror-woot-style {
  min-height: 1.5rem !important;
}

/* icons ko halka rakho, WhatsApp jaisa */
.reply-box .left-wrap button {
  opacity: 0.8;
}
.reply-box .left-wrap button:hover {
  opacity: 1;
}

/* ---------- 7. RAIL (collapsed sidebar) ---------- */
/* rail ka background chat panel se thoda alag */
aside[class*='bg-n-background'] {
  background: rgb(var(--solid-1)) !important;
}

.dark aside[class*='bg-n-background'] {
  background: rgb(var(--slate-2)) !important;
}

/* rail ke icons ko WhatsApp jaisi gol jagah */
aside a[class*='rounded'],
aside button[class*='rounded'] {
  border-radius: 50% !important;
}

/* ---------- 8. CHAT HEADER ---------- */
/* header ko chat background se alag dikhao */
.conversation--header {
  border-bottom: 1px solid rgb(var(--slate-3));
}

/* ---------- 9. SCROLLBARS ---------- */
.conversation-panel::-webkit-scrollbar,
.conversations-list::-webkit-scrollbar {
  width: 6px;
}
.conversation-panel::-webkit-scrollbar-thumb,
.conversations-list::-webkit-scrollbar-thumb {
  background: rgba(var(--alpha-2));
  border-radius: 3px;
}
.conversation-panel::-webkit-scrollbar-track,
.conversations-list::-webkit-scrollbar-track {
  background: transparent;
}
CS_EOF_5d0a3
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
echo "============================================"
