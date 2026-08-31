#!/bin/bash
# ============================================================
#  ChatsSync — WhatsApp theme (poora)
#      cd /root/staging-build && git pull && bash apply-wa-theme.sh
#
#  app.scss  : poora theme, WhatsApp Web ke asli rang
#  MessagesView.vue : dohra doodle hata diya (ab sirf app.scss mein)
# ============================================================
set -e
REPO="/root/staging-build"
COMPOSE="/data/coolify/applications/vdcb3i4jbkc4jsw204xguhk5"
[ -f "$REPO/docker/Dockerfile" ] || { echo "ERROR: repo $REPO mein nahi mila"; exit 1; }
cd "$REPO"
echo ""
echo "=== 1/3  Files likh raha hun ==="
mkdir -p "$(dirname app/javascript/dashboard/assets/scss/app.scss)"
cat > app/javascript/dashboard/assets/scss/app.scss << 'CS_EOF_9a1c6'
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
   ChatsSync — WhatsApp theme
   Rang WhatsApp Web ke apne CSS se liye gaye hain.
   Hatana ho to yeh poora block delete kar do.
   ========================================================================== */

/* ============ 1. RANG ============ */
:root {
  --wa-chat-bg: 239 231 222;
  --wa-panel: 255 255 255;
  --wa-rail: 240 242 245;
  --wa-header: 240 242 245;
  --wa-sent: 217 253 211;
  --wa-recv: 255 255 255;
  --wa-text: 17 27 33;
  --wa-text2: 84 101 111;
  --wa-text3: 134 150 160;
  --wa-border: 233 237 239;
  --wa-hover: 245 246 246;
  --wa-active: 240 242 245;
  --wa-green: 0 128 105;
  --wa-tick: 83 189 235;
  --wa-badge: 37 211 102;
  --wa-doodle-opacity: 0.06;
  --wa-shadow: 0 1px 0.5px rgba(11, 20, 26, 0.13);
  --wa-line: rgba(11, 20, 26, 0.08);
}

.dark {
  --wa-chat-bg: 11 20 26;
  --wa-panel: 17 27 33;
  --wa-rail: 32 44 51;
  --wa-header: 32 44 51;
  --wa-sent: 0 92 75;
  --wa-recv: 32 44 51;
  --wa-text: 233 237 239;
  --wa-text2: 174 186 193;
  --wa-text3: 134 150 160;
  --wa-border: 34 45 52;
  --wa-hover: 32 44 51;
  --wa-active: 42 57 66;
  --wa-green: 0 168 132;
  --wa-tick: 83 189 235;
  --wa-badge: 0 168 132;
  --wa-doodle-opacity: 0.042;
  --wa-shadow: 0 1px 0.5px rgba(0, 0, 0, 0.35);
  --wa-line: rgba(255, 255, 255, 0.07);
}

/* ============ 2. RAIL ============ */
aside[class*='bg-n-background'] {
  background: rgb(var(--wa-rail)) !important;
  border-right: 1px solid var(--wa-line) !important;
}

/* icon slots gol, hover halka */
aside nav a,
aside nav button,
aside > section a,
aside > section button {
  border-radius: 50% !important;
  transition: background-color 0.14s ease, color 0.14s ease;
}

aside nav a:hover,
aside nav button:hover {
  background: var(--wa-line) !important;
}

/* sirf active route hara — baaki kuch nahi */
aside a[aria-current='page'] {
  background: rgb(var(--wa-green) / 0.14) !important;
  color: rgb(var(--wa-green)) !important;
}
aside a[aria-current='page'] span[class*='i-'] {
  color: rgb(var(--wa-green)) !important;
}

/* ============ 3. CHAT LIST ============ */
.conversations-list-wrap {
  background: rgb(var(--wa-panel)) !important;
  border-right: 1px solid var(--wa-line);
}

.conversation {
  padding-top: 0 !important;
  padding-bottom: 0 !important;
  border-bottom: none !important;
  transition: background-color 0.13s ease;

  .border-line {
    border-bottom: 1px solid var(--wa-line);
    padding-top: 0.6rem !important;
    padding-bottom: 0.6rem !important;
  }
  &:last-child .border-line {
    border-bottom: none;
  }
  &:hover {
    background: rgb(var(--wa-hover)) !important;
  }
  &.active,
  &.selected {
    background: rgb(var(--wa-active)) !important;
  }
}

/* unread badge — hara circle */
.conversation [class*='bg-n-brand'],
.conversation [class*='bg-woot'],
.conversation [class*='rounded-full'][class*='bg-n-'][class*='text-white'] {
  background: rgb(var(--wa-badge)) !important;
  color: #fff !important;
  border-radius: 999px !important;
  font-weight: 500;
}

/* ============ 4. CHAT HEADER ============ */
.conversation--header,
[class*='conversation--header'] {
  background: rgb(var(--wa-header)) !important;
  border-bottom: 1px solid var(--wa-line) !important;
}

/* ============ 5. THREAD + url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='352' height='232' viewBox='0 0 352 232'%3E%3Cg fill='none' stroke='%23fff' stroke-width='1.25' stroke-linecap='round' stroke-linejoin='round'%3E%3Cg transform='translate(18,20)'%3E%3Cpath d='M0 6a6 6 0 0 1 12 0 6 6 0 0 1-6 6H2l2-3a6 6 0 0 1-4-3z'/%3E%3C/g%3E%3Cg transform='translate(62,14)'%3E%3Cpath d='M0 0h14v10H4L0 13z'/%3E%3C/g%3E%3Cg transform='translate(108,22)'%3E%3Cpath d='M6 0l1.8 3.7 4 .6-2.9 2.8.7 4L6 9.2 2.4 11l.7-4L.2 4.3l4-.6z'/%3E%3C/g%3E%3Cg transform='translate(150,16)'%3E%3Cpath d='M2 2h12v12H2z M2 6h12'/%3E%3C/g%3E%3Cg transform='translate(192,20)'%3E%3Cpath d='M7 0C3 0 0 3 0 6.5 0 11 7 16 7 16s7-5 7-9.5C14 3 11 0 7 0z M7 4a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5z'/%3E%3C/g%3E%3Cg transform='translate(234,14)'%3E%3Cpath d='M0 8c0-4 3-7 7-7s7 3 7 7-3 7-7 7-7-3-7-7z M4 8h6 M7 5v6'/%3E%3C/g%3E%3Cg transform='translate(276,20)'%3E%3Cpath d='M0 3h16v10H0z M0 3l8 6 8-6'/%3E%3C/g%3E%3Cg transform='translate(318,16)'%3E%3Cpath d='M3 0h10v4H3z M1 4h14v11H1z M6 8h4'/%3E%3C/g%3E%3Cg transform='translate(14,64)'%3E%3Cpath d='M0 10c3-5 9-5 12 0 M6 4a2.5 2.5 0 1 1 0 .01'/%3E%3C/g%3E%3Cg transform='translate(56,58)'%3E%3Cpath d='M0 0h13M0 5h9M0 10h11'/%3E%3C/g%3E%3Cg transform='translate(98,62)'%3E%3Cpath d='M8 0a8 8 0 1 1 0 16A8 8 0 0 1 8 0z M8 4v4.5l3 2'/%3E%3C/g%3E%3Cg transform='translate(140,60)'%3E%3Cpath d='M0 0l11 6-11 6z'/%3E%3C/g%3E%3Cg transform='translate(182,58)'%3E%3Cpath d='M2 0h11l3 4v11H2z M13 0v4h3'/%3E%3C/g%3E%3Cg transform='translate(224,62)'%3E%3Cpath d='M0 6h4l4-5v14l-4-5H0z M11 4a4 4 0 0 1 0 8'/%3E%3C/g%3E%3Cg transform='translate(266,58)'%3E%3Cpath d='M1 1h14v10H1z M1 11l5-4 3 2 3-3 3 3'/%3E%3C/g%3E%3Cg transform='translate(308,64)'%3E%3Cpath d='M6 0a6 6 0 0 1 6 6c0 4-6 10-6 10S0 10 0 6a6 6 0 0 1 6-6z'/%3E%3C/g%3E%3Cg transform='translate(20,106)'%3E%3Cpath d='M0 4h5l3-4h4l3 4h1v10H0z M8 6a3 3 0 1 1 0 6 3 3 0 0 1 0-6z'/%3E%3C/g%3E%3Cg transform='translate(62,110)'%3E%3Cpath d='M6 0l6 12H0z'/%3E%3C/g%3E%3Cg transform='translate(104,104)'%3E%3Cpath d='M0 0h12v12H0z M3 3h6v6H3z'/%3E%3C/g%3E%3Cg transform='translate(146,108)'%3E%3Cpath d='M0 6a6 6 0 1 0 12 0 6 6 0 0 0-12 0z M3 6l2 2 4-4'/%3E%3C/g%3E%3Cg transform='translate(188,104)'%3E%3Cpath d='M1 3h14v9H1z M4 3V1h8v2 M4 12v2h8v-2'/%3E%3C/g%3E%3Cg transform='translate(230,110)'%3E%3Cpath d='M0 12L6 0l6 12z M4 12v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(272,106)'%3E%3Cpath d='M2 2l10 10M12 2L2 12'/%3E%3C/g%3E%3Cg transform='translate(314,110)'%3E%3Cpath d='M0 8h16 M4 4l-4 4 4 4 M12 4l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(16,150)'%3E%3Cpath d='M0 2h14v12H0z M3 0v4M11 0v4M0 6h14'/%3E%3C/g%3E%3Cg transform='translate(58,154)'%3E%3Cpath d='M7 0a7 7 0 1 1 0 14A7 7 0 0 1 7 0z M4 7h6'/%3E%3C/g%3E%3Cg transform='translate(100,148)'%3E%3Cpath d='M0 10c0-6 5-10 8-10s8 4 8 10'/%3E%3C/g%3E%3Cg transform='translate(142,152)'%3E%3Cpath d='M2 0h10v14l-5-4-5 4z'/%3E%3C/g%3E%3Cg transform='translate(184,150)'%3E%3Cpath d='M0 0h14v3H0z M2 3v10h10V3 M6 6v4M8 6v4'/%3E%3C/g%3E%3Cg transform='translate(226,154)'%3E%3Cpath d='M8 0l2 5 5 .5-4 3.5 1 5-4-2.6L4 14l1-5L1 5.5 6 5z'/%3E%3C/g%3E%3Cg transform='translate(268,148)'%3E%3Cpath d='M1 1h13v13H1z M4 7h7M7 4v7'/%3E%3C/g%3E%3Cg transform='translate(310,152)'%3E%3Cpath d='M0 5a5 5 0 0 1 10 0v6H0z M3 11v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(22,196)'%3E%3Cpath d='M0 3h16v9H0z M5 12v2h6v-2 M2 16h12'/%3E%3C/g%3E%3Cg transform='translate(64,198)'%3E%3Cpath d='M6 0a6 6 0 1 1 0 12A6 6 0 0 1 6 0z M6 3v3l2 2'/%3E%3C/g%3E%3Cg transform='translate(106,194)'%3E%3Cpath d='M0 6h12 M8 2l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(148,198)'%3E%3Cpath d='M2 0h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V2a2 2 0 0 1 2-2z M4 3h4M4 6h4M4 9h2'/%3E%3C/g%3E%3Cg transform='translate(190,194)'%3E%3Cpath d='M0 0h14M0 5h14M0 10h8'/%3E%3C/g%3E%3Cg transform='translate(232,198)'%3E%3Cpath d='M7 0l7 7-7 7-7-7z'/%3E%3C/g%3E%3Cg transform='translate(274,194)'%3E%3Cpath d='M1 4h12v9H1z M4 4V2a3 3 0 0 1 6 0v2'/%3E%3C/g%3E%3Cg transform='translate(316,198)'%3E%3Cpath d='M0 0l14 7-14 7 3-7z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E") ============ */
.conversation-panel {
  position: relative;
  background-color: rgb(var(--wa-chat-bg)) !important;
  padding-left: 5% !important;
  padding-right: 5% !important;
  scroll-behavior: smooth;
  overscroll-behavior: contain;
}

.conversation-panel::before {
  content: '';
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: 0;
  opacity: var(--wa-doodle-opacity);
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='352' height='232' viewBox='0 0 352 232'%3E%3Cg fill='none' stroke='%23fff' stroke-width='1.25' stroke-linecap='round' stroke-linejoin='round'%3E%3Cg transform='translate(18,20)'%3E%3Cpath d='M0 6a6 6 0 0 1 12 0 6 6 0 0 1-6 6H2l2-3a6 6 0 0 1-4-3z'/%3E%3C/g%3E%3Cg transform='translate(62,14)'%3E%3Cpath d='M0 0h14v10H4L0 13z'/%3E%3C/g%3E%3Cg transform='translate(108,22)'%3E%3Cpath d='M6 0l1.8 3.7 4 .6-2.9 2.8.7 4L6 9.2 2.4 11l.7-4L.2 4.3l4-.6z'/%3E%3C/g%3E%3Cg transform='translate(150,16)'%3E%3Cpath d='M2 2h12v12H2z M2 6h12'/%3E%3C/g%3E%3Cg transform='translate(192,20)'%3E%3Cpath d='M7 0C3 0 0 3 0 6.5 0 11 7 16 7 16s7-5 7-9.5C14 3 11 0 7 0z M7 4a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5z'/%3E%3C/g%3E%3Cg transform='translate(234,14)'%3E%3Cpath d='M0 8c0-4 3-7 7-7s7 3 7 7-3 7-7 7-7-3-7-7z M4 8h6 M7 5v6'/%3E%3C/g%3E%3Cg transform='translate(276,20)'%3E%3Cpath d='M0 3h16v10H0z M0 3l8 6 8-6'/%3E%3C/g%3E%3Cg transform='translate(318,16)'%3E%3Cpath d='M3 0h10v4H3z M1 4h14v11H1z M6 8h4'/%3E%3C/g%3E%3Cg transform='translate(14,64)'%3E%3Cpath d='M0 10c3-5 9-5 12 0 M6 4a2.5 2.5 0 1 1 0 .01'/%3E%3C/g%3E%3Cg transform='translate(56,58)'%3E%3Cpath d='M0 0h13M0 5h9M0 10h11'/%3E%3C/g%3E%3Cg transform='translate(98,62)'%3E%3Cpath d='M8 0a8 8 0 1 1 0 16A8 8 0 0 1 8 0z M8 4v4.5l3 2'/%3E%3C/g%3E%3Cg transform='translate(140,60)'%3E%3Cpath d='M0 0l11 6-11 6z'/%3E%3C/g%3E%3Cg transform='translate(182,58)'%3E%3Cpath d='M2 0h11l3 4v11H2z M13 0v4h3'/%3E%3C/g%3E%3Cg transform='translate(224,62)'%3E%3Cpath d='M0 6h4l4-5v14l-4-5H0z M11 4a4 4 0 0 1 0 8'/%3E%3C/g%3E%3Cg transform='translate(266,58)'%3E%3Cpath d='M1 1h14v10H1z M1 11l5-4 3 2 3-3 3 3'/%3E%3C/g%3E%3Cg transform='translate(308,64)'%3E%3Cpath d='M6 0a6 6 0 0 1 6 6c0 4-6 10-6 10S0 10 0 6a6 6 0 0 1 6-6z'/%3E%3C/g%3E%3Cg transform='translate(20,106)'%3E%3Cpath d='M0 4h5l3-4h4l3 4h1v10H0z M8 6a3 3 0 1 1 0 6 3 3 0 0 1 0-6z'/%3E%3C/g%3E%3Cg transform='translate(62,110)'%3E%3Cpath d='M6 0l6 12H0z'/%3E%3C/g%3E%3Cg transform='translate(104,104)'%3E%3Cpath d='M0 0h12v12H0z M3 3h6v6H3z'/%3E%3C/g%3E%3Cg transform='translate(146,108)'%3E%3Cpath d='M0 6a6 6 0 1 0 12 0 6 6 0 0 0-12 0z M3 6l2 2 4-4'/%3E%3C/g%3E%3Cg transform='translate(188,104)'%3E%3Cpath d='M1 3h14v9H1z M4 3V1h8v2 M4 12v2h8v-2'/%3E%3C/g%3E%3Cg transform='translate(230,110)'%3E%3Cpath d='M0 12L6 0l6 12z M4 12v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(272,106)'%3E%3Cpath d='M2 2l10 10M12 2L2 12'/%3E%3C/g%3E%3Cg transform='translate(314,110)'%3E%3Cpath d='M0 8h16 M4 4l-4 4 4 4 M12 4l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(16,150)'%3E%3Cpath d='M0 2h14v12H0z M3 0v4M11 0v4M0 6h14'/%3E%3C/g%3E%3Cg transform='translate(58,154)'%3E%3Cpath d='M7 0a7 7 0 1 1 0 14A7 7 0 0 1 7 0z M4 7h6'/%3E%3C/g%3E%3Cg transform='translate(100,148)'%3E%3Cpath d='M0 10c0-6 5-10 8-10s8 4 8 10'/%3E%3C/g%3E%3Cg transform='translate(142,152)'%3E%3Cpath d='M2 0h10v14l-5-4-5 4z'/%3E%3C/g%3E%3Cg transform='translate(184,150)'%3E%3Cpath d='M0 0h14v3H0z M2 3v10h10V3 M6 6v4M8 6v4'/%3E%3C/g%3E%3Cg transform='translate(226,154)'%3E%3Cpath d='M8 0l2 5 5 .5-4 3.5 1 5-4-2.6L4 14l1-5L1 5.5 6 5z'/%3E%3C/g%3E%3Cg transform='translate(268,148)'%3E%3Cpath d='M1 1h13v13H1z M4 7h7M7 4v7'/%3E%3C/g%3E%3Cg transform='translate(310,152)'%3E%3Cpath d='M0 5a5 5 0 0 1 10 0v6H0z M3 11v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(22,196)'%3E%3Cpath d='M0 3h16v9H0z M5 12v2h6v-2 M2 16h12'/%3E%3C/g%3E%3Cg transform='translate(64,198)'%3E%3Cpath d='M6 0a6 6 0 1 1 0 12A6 6 0 0 1 6 0z M6 3v3l2 2'/%3E%3C/g%3E%3Cg transform='translate(106,194)'%3E%3Cpath d='M0 6h12 M8 2l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(148,198)'%3E%3Cpath d='M2 0h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V2a2 2 0 0 1 2-2z M4 3h4M4 6h4M4 9h2'/%3E%3C/g%3E%3Cg transform='translate(190,194)'%3E%3Cpath d='M0 0h14M0 5h14M0 10h8'/%3E%3C/g%3E%3Cg transform='translate(232,198)'%3E%3Cpath d='M7 0l7 7-7 7-7-7z'/%3E%3C/g%3E%3Cg transform='translate(274,194)'%3E%3Cpath d='M1 4h12v9H1z M4 4V2a3 3 0 0 1 6 0v2'/%3E%3C/g%3E%3Cg transform='translate(316,198)'%3E%3Cpath d='M0 0l14 7-14 7 3-7z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
  background-size: 264px 174px;
}

.conversation-panel > * {
  position: relative;
  z-index: 1;
}

@media (max-width: 767px) {
  .conversation-panel {
    padding-left: 0.6rem !important;
    padding-right: 0.6rem !important;
  }
}

/* din ka separator + system message = WhatsApp pill */
.conversation-panel [class*='date-separator'] span,
.conversation-panel [class*='bg-n-alpha-1'][class*='rounded-lg'] {
  background: rgb(var(--wa-header)) !important;
  border-radius: 0.5rem !important;
  padding: 0.32rem 0.8rem !important;
  font-size: 0.75rem !important;
  box-shadow: var(--wa-shadow);
  border: 0 !important;
  color: rgb(var(--wa-text2)) !important;
}

/* ============ 6. BUBBLES ============ */
.message-bubble-container {
  margin-bottom: 0.25rem !important;
  animation: wa-in 0.18s cubic-bezier(0.22, 1, 0.36, 1);
}

@keyframes wa-in {
  from {
    opacity: 0;
    transform: translateY(6px) scale(0.99);
  }
  to {
    opacity: 1;
    transform: none;
  }
}

.message-bubble-container .left-bubble,
.message-bubble-container .right-bubble {
  padding: 0.375rem 0.5rem 0.4rem 0.5rem !important;
  box-shadow: var(--wa-shadow);
  max-width: 65% !important;
  line-height: 1.42;
}

@media (max-width: 767px) {
  .message-bubble-container .left-bubble,
  .message-bubble-container .right-bubble {
    max-width: 82% !important;
  }
}

/* ticks neele */
.message-bubble-container [class*='i-lucide-check'],
.message-bubble-container [class*='check-double'] {
  color: rgb(var(--wa-tick)) !important;
}

/* waqt halka */
.message-bubble-container time {
  color: rgb(var(--wa-text3));
  font-size: 0.6875rem;
}

/* ============ 7. COMPOSER ============ */
.reply-box {
  background: rgb(var(--wa-header)) !important;
  border: 1px solid var(--wa-line) !important;
  border-radius: 1.5rem !important;
  margin: 0.5rem 0.75rem 0.75rem !important;
  transition: border-color 0.16s ease;
}

.reply-box:focus-within {
  border-color: rgb(var(--wa-green) / 0.4) !important;
}

.reply-box .ProseMirror-woot-style,
.reply-box .ProseMirror,
.reply-box .editor-root,
.resizable-editor-wrapper .ProseMirror-woot-style {
  min-height: 1.5rem !important;
  max-height: 7.5rem !important;
}

/* drag handle chhupao */
.reply-box [class*='cursor-row-resize'],
.reply-box [class*='cursor-ns-resize'] {
  display: none !important;
}

.reply-box .left-wrap button {
  opacity: 0.72;
  transition: opacity 0.14s ease;
}
.reply-box .left-wrap button:hover {
  opacity: 1;
}

/* send button hara aur gol */
.reply-box .right-wrap button[type='submit'] {
  border-radius: 50% !important;
  background: rgb(var(--wa-green)) !important;
  border-color: rgb(var(--wa-green)) !important;
  color: #fff !important;
  transition: transform 0.14s cubic-bezier(0.34, 1.56, 0.64, 1);
}
.reply-box .right-wrap button[type='submit']:active {
  transform: scale(0.92);
}

/* ============ 8. RIGHT PANEL ============ */
[class*='conversation-sidebar'],
.conversation-sidebar-wrap {
  background: rgb(var(--wa-panel)) !important;
  border-left: 1px solid var(--wa-line);
}

/* ============ 9. CONTEXT MENUS ============ */
[class*='context-menu'],
.dropdown-pane,
[role='menu'] {
  border-radius: 0.6rem !important;
  box-shadow: 0 4px 22px rgba(11, 20, 26, 0.18) !important;
  border: 1px solid var(--wa-line) !important;
}
.dark [class*='context-menu'],
.dark .dropdown-pane,
.dark [role='menu'] {
  box-shadow: 0 4px 22px rgba(0, 0, 0, 0.45) !important;
}

/* ============ 10. BAAKI TABS ============ */
button[class*='bg-n-brand'],
.button--primary,
button[class*='bg-woot-500'] {
  background: rgb(var(--wa-green)) !important;
  border-color: rgb(var(--wa-green)) !important;
  transition: filter 0.14s ease;
}
button[class*='bg-n-brand']:hover,
.button--primary:hover {
  filter: brightness(1.08);
}

a[class*='text-n-brand'],
[class*='text-woot-500'] {
  color: rgb(var(--wa-green)) !important;
}

/* ============ 11. SCROLLBARS ============ */
::-webkit-scrollbar {
  width: 6px;
  height: 6px;
}
::-webkit-scrollbar-thumb {
  background: rgba(11, 20, 26, 0.18);
  border-radius: 3px;
}
.dark ::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.14);
}
::-webkit-scrollbar-track {
  background: transparent;
}

/* ============ 12. SMOOTHNESS ============ */
* {
  -webkit-tap-highlight-color: transparent;
}

.conversation,
.reply-box button,
aside a,
aside button,
[role='menuitem'] {
  transition: background-color 0.13s ease, color 0.13s ease,
    transform 0.13s ease, opacity 0.13s ease;
}

[role='menuitem']:active,
.reply-box button:active {
  transform: scale(0.96);
}

@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}

/* ============ 13. SEARCH BAR + LIST HEADER ============ */
/* header ka title WhatsApp jaisa bada */
.conversations-list-wrap h1 {
  font-size: 1.375rem !important;
  font-weight: 600 !important;
  letter-spacing: -0.02em;
  color: rgb(var(--wa-text)) !important;
}

/* search field */
.conversations-list-wrap input[type='text'] {
  background: transparent !important;
  border: 0 !important;
  outline: none !important;
  box-shadow: none !important;
  color: rgb(var(--wa-text)) !important;
  font-size: 0.875rem;
}

.conversations-list-wrap input[type='text']::placeholder {
  color: rgb(var(--wa-text3)) !important;
}

/* search ka wrapper */
.conversations-list-wrap [class*='rounded-full'][class*='bg-n-alpha'] {
  background: rgb(var(--wa-hover)) !important;
  border-radius: 999px !important;
  transition: background-color 0.14s ease;
}
.dark .conversations-list-wrap [class*='rounded-full'][class*='bg-n-alpha'] {
  background: rgb(var(--wa-active)) !important;
}

/* ============ 14. PILLS ============ */
.cs-pills button {
  border-radius: 999px !important;
  font-size: 0.8125rem;
  transition: background-color 0.14s ease, color 0.14s ease;
}

.cs-pills button:active {
  transform: scale(0.96);
}

/* ============ 15. EMPTY STATE ============ */
.conversations-list-wrap [class*='text-center'] p,
.conversations-list-wrap [class*='text-center'] span {
  color: rgb(var(--wa-text3)) !important;
}
CS_EOF_9a1c6
echo "  ok  app/javascript/dashboard/assets/scss/app.scss"

mkdir -p "$(dirname app/javascript/dashboard/components/widgets/conversation/MessagesView.vue)"
cat > app/javascript/dashboard/components/widgets/conversation/MessagesView.vue << 'CS_EOF_9a1c6'
<script>
import { ref, provide, useTemplateRef } from 'vue';
import { useElementSize } from '@vueuse/core';
// composable
import { useLabelSuggestions } from 'dashboard/composables/useLabelSuggestions';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';

// components
import ReplyBox from './ReplyBox.vue';
import MessageList from 'next/message/MessageList.vue';
import ConversationLabelSuggestion from './conversation/LabelSuggestion.vue';
import Banner from 'dashboard/components/ui/Banner.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ResizableEditorWrapper from './ResizableEditorWrapper.vue';

// stores and apis
import { mapGetters } from 'vuex';

// mixins
import inboxMixin, { INBOX_FEATURES } from 'shared/mixins/inboxMixin';

// utils
import { emitter } from 'shared/helpers/mitt';
import { getTypingUsersText } from '../../../helper/commons';
import { calculateScrollTop } from './helpers/scrollTopCalculationHelper';
import { LocalStorage } from 'shared/helpers/localStorage';
import {
  filterDuplicateSourceMessages,
  getReadMessages,
  getUnreadMessages,
} from 'dashboard/helper/conversationHelper';

// constants
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { REPLY_POLICY } from 'shared/constants/links';
import wootConstants from 'dashboard/constants/globals';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

export default {
  components: {
    MessageList,
    ReplyBox,
    Banner,
    ConversationLabelSuggestion,
    Spinner,
    ResizableEditorWrapper,
  },
  mixins: [inboxMixin],
  setup() {
    const conversationPanelRef = ref(null);
    const resizableEditorWrapperRef = ref(null);
    const messagesViewRef = useTemplateRef('messagesViewRef');
    const topBannerRef = useTemplateRef('topBannerRef');
    const { height: containerHeight } = useElementSize(messagesViewRef);
    const { height: topBannerHeight } = useElementSize(topBannerRef);

    const {
      captainTasksEnabled,
      isLabelSuggestionFeatureEnabled,
      getLabelSuggestions,
    } = useLabelSuggestions();

    provide('contextMenuElementTarget', conversationPanelRef);

    return {
      captainTasksEnabled,
      getLabelSuggestions,
      isLabelSuggestionFeatureEnabled,
      conversationPanelRef,
      resizableEditorWrapperRef,
      messagesViewRef,
      topBannerRef,
      containerHeight,
      topBannerHeight,
    };
  },
  data() {
    return {
      isLoadingPrevious: true,
      heightBeforeLoad: null,
      conversationPanel: null,
      hasUserScrolled: false,
      isProgrammaticScroll: false,
      messageSentSinceOpened: false,
      labelSuggestions: [],
    };
  },

  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      currentUserId: 'getCurrentUserID',
      listLoadingStatus: 'getAllMessagesLoaded',
      currentAccountId: 'getCurrentAccountId',
    }),
    isOpen() {
      return this.currentChat?.status === wootConstants.STATUS_TYPE.OPEN;
    },
    shouldShowLabelSuggestions() {
      return (
        this.isOpen &&
        this.captainTasksEnabled &&
        this.isLabelSuggestionFeatureEnabled &&
        !this.messageSentSinceOpened
      );
    },
    inboxId() {
      return this.currentChat.inbox_id;
    },
    inbox() {
      return this.$store.getters['inboxes/getInbox'](this.inboxId);
    },
    typingUsersList() {
      const userList = this.$store.getters[
        'conversationTypingStatus/getUserList'
      ](this.currentChat.id);
      return userList;
    },
    isAnyoneTyping() {
      const userList = this.typingUsersList;
      return userList.length !== 0;
    },
    typingUserNames() {
      const userList = this.typingUsersList;
      if (this.isAnyoneTyping) {
        const [i18nKey, params] = getTypingUsersText(userList);
        return this.$t(i18nKey, params);
      }

      return '';
    },
    getMessages() {
      const messages = this.currentChat.messages || [];
      if (this.isAWhatsAppChannel) {
        return filterDuplicateSourceMessages(messages);
      }
      return messages;
    },
    readMessages() {
      return getReadMessages(
        this.getMessages,
        this.currentChat.agent_last_seen_at
      );
    },
    unReadMessages() {
      return getUnreadMessages(
        this.getMessages,
        this.currentChat.agent_last_seen_at
      );
    },
    shouldShowSpinner() {
      return (
        (this.currentChat && this.currentChat.dataFetched === undefined) ||
        (!this.listLoadingStatus && this.isLoadingPrevious)
      );
    },
    // Check there is a instagram inbox exists with the same instagram_id
    hasDuplicateInstagramInbox() {
      const instagramId = this.inbox.instagram_id;
      const { additional_attributes: additionalAttributes = {} } = this.inbox;
      const instagramInbox =
        this.$store.getters['inboxes/getInstagramInboxByInstagramId'](
          instagramId
        );

      return (
        this.inbox.channel_type === INBOX_TYPES.FB &&
        additionalAttributes.type === 'instagram_direct_message' &&
        instagramInbox
      );
    },

    replyWindowBannerMessage() {
      if (this.isAWhatsAppChannel) {
        return this.$t('CONVERSATION.TWILIO_WHATSAPP_CAN_REPLY');
      }
      if (this.isAPIInbox) {
        const { additional_attributes: additionalAttributes = {} } = this.inbox;
        if (additionalAttributes) {
          const {
            agent_reply_time_window_message: agentReplyTimeWindowMessage,
            agent_reply_time_window: agentReplyTimeWindow,
          } = additionalAttributes;
          return (
            agentReplyTimeWindowMessage ||
            this.$t('CONVERSATION.API_HOURS_WINDOW', {
              hours: agentReplyTimeWindow,
            })
          );
        }
        return '';
      }
      return this.$t('CONVERSATION.CANNOT_REPLY');
    },
    replyWindowLink() {
      if (this.isAFacebookInbox || this.isAnInstagramChannel) {
        return REPLY_POLICY.FACEBOOK;
      }
      if (this.isAWhatsAppCloudChannel) {
        return REPLY_POLICY.WHATSAPP_CLOUD;
      }
      if (this.isATiktokChannel) {
        return REPLY_POLICY.TIKTOK;
      }
      if (!this.isAPIInbox) {
        return REPLY_POLICY.TWILIO_WHATSAPP;
      }
      return '';
    },
    replyWindowLinkText() {
      if (
        this.isAWhatsAppChannel ||
        this.isAFacebookInbox ||
        this.isAnInstagramChannel
      ) {
        return this.$t('CONVERSATION.24_HOURS_WINDOW');
      }
      if (this.isATiktokChannel) {
        return this.$t('CONVERSATION.48_HOURS_WINDOW');
      }
      if (!this.isAPIInbox) {
        return this.$t('CONVERSATION.TWILIO_WHATSAPP_24_HOURS_WINDOW');
      }
      return '';
    },
    unreadMessageCount() {
      return this.currentChat.unread_count || 0;
    },
    unreadMessageLabel() {
      const count =
        this.unreadMessageCount > 9 ? '9+' : this.unreadMessageCount;
      const label =
        this.unreadMessageCount > 1
          ? 'CONVERSATION.UNREAD_MESSAGES'
          : 'CONVERSATION.UNREAD_MESSAGE';
      return `${count} ${this.$t(label)}`;
    },
    inboxSupportsReplyTo() {
      const incoming = this.inboxHasFeature(INBOX_FEATURES.REPLY_TO);
      const outgoing =
        this.inboxHasFeature(INBOX_FEATURES.REPLY_TO_OUTGOING) &&
        !this.is360DialogWhatsAppChannel;

      return { incoming, outgoing };
    },
  },

  watch: {
    currentChat(newChat, oldChat) {
      if (newChat.id === oldChat.id) {
        return;
      }
      this.fetchAllAttachmentsFromCurrentChat();
      this.fetchSuggestions();
      this.messageSentSinceOpened = false;
      this.resetReplyEditorHeight();
    },
  },

  created() {
    emitter.on(BUS_EVENTS.SCROLL_TO_MESSAGE, this.onScrollToMessage);
    // when a message is sent we set the flag to true this hides the label suggestions,
    // until the chat is changed and the flag is reset in the watch for currentChat
    emitter.on(BUS_EVENTS.MESSAGE_SENT, () => {
      this.messageSentSinceOpened = true;
    });
  },

  mounted() {
    this.addScrollListener();
    this.fetchAllAttachmentsFromCurrentChat();
    this.fetchSuggestions();
  },

  unmounted() {
    this.removeBusListeners();
    this.removeScrollListener();
  },

  methods: {
    async fetchSuggestions() {
      // start empty, this ensures that the label suggestions are not shown
      this.labelSuggestions = [];

      if (this.isLabelSuggestionDismissed()) {
        return;
      }

      // Early exit if conversation already has labels - no need to suggest more
      const existingLabels = this.currentChat?.labels || [];
      if (existingLabels.length > 0) return;

      if (!this.captainTasksEnabled || !this.isLabelSuggestionFeatureEnabled) {
        return;
      }

      this.labelSuggestions = await this.getLabelSuggestions();

      // once the labels are fetched, we need to scroll to bottom
      // but we need to wait for the DOM to be updated
      // so we use the nextTick method
      this.$nextTick(() => {
        // this param is added to route, telling the UI to navigate to the message
        // it is triggered by the SCROLL_TO_MESSAGE method
        // see setActiveChat on ConversationView.vue for more info
        const { messageId } = this.$route.query;

        // only trigger the scroll to bottom if the user has not scrolled
        // and there's no active messageId that is selected in view
        if (!messageId && !this.hasUserScrolled) {
          this.scrollToBottom();
        }
      });
    },
    isLabelSuggestionDismissed() {
      return LocalStorage.getFlag(
        LOCAL_STORAGE_KEYS.DISMISSED_LABEL_SUGGESTIONS,
        this.currentAccountId,
        this.currentChat.id
      );
    },
    fetchAllAttachmentsFromCurrentChat() {
      this.$store.dispatch('fetchAllAttachments', this.currentChat.id);
    },
    removeBusListeners() {
      emitter.off(BUS_EVENTS.SCROLL_TO_MESSAGE, this.onScrollToMessage);
    },
    onScrollToMessage({ messageId = '' } = {}) {
      this.$nextTick(() => {
        const messageElement = document.getElementById('message' + messageId);
        if (messageElement) {
          this.isProgrammaticScroll = true;
          messageElement.scrollIntoView({ behavior: 'smooth' });
          this.fetchPreviousMessages();
        } else {
          this.scrollToBottom();
        }
      });
      this.makeMessagesRead();
    },
    addScrollListener() {
      this.conversationPanel = this.$el.querySelector('.conversation-panel');
      this.setScrollParams();
      this.conversationPanel.addEventListener('scroll', this.handleScroll);
      this.$nextTick(() => this.scrollToBottom());
      this.isLoadingPrevious = false;
    },
    removeScrollListener() {
      this.conversationPanel.removeEventListener('scroll', this.handleScroll);
    },
    scrollToBottom() {
      this.isProgrammaticScroll = true;
      let relevantMessages = [];

      // label suggestions are not part of the messages list
      // so we need to handle them separately
      let labelSuggestions =
        this.conversationPanel.querySelector('.label-suggestion');

      // if there are unread messages, scroll to the first unread message
      if (this.unreadMessageCount > 0) {
        // capturing only the unread messages
        relevantMessages =
          this.conversationPanel.querySelectorAll('.message--unread');
      } else if (labelSuggestions) {
        // when scrolling to the bottom, the label suggestions is below the last message
        // so we scroll there if there are no unread messages
        // Unread messages always take the highest priority
        relevantMessages = [labelSuggestions];
      } else {
        // if there are no unread messages or label suggestion, scroll to the last message
        // capturing last message from the messages list
        relevantMessages = Array.from(
          this.conversationPanel.querySelectorAll('.message--read')
        ).slice(-1);
      }

      this.conversationPanel.scrollTop = calculateScrollTop(
        this.conversationPanel.scrollHeight,
        this.$el.scrollHeight,
        relevantMessages
      );
    },
    setScrollParams() {
      this.heightBeforeLoad = this.conversationPanel.scrollHeight;
      this.scrollTopBeforeLoad = this.conversationPanel.scrollTop;
    },

    async fetchPreviousMessages(scrollTop = 0) {
      this.setScrollParams();
      const shouldLoadMoreMessages =
        this.currentChat.dataFetched === true &&
        !this.listLoadingStatus &&
        !this.isLoadingPrevious;

      if (
        scrollTop < 100 &&
        !this.isLoadingPrevious &&
        shouldLoadMoreMessages
      ) {
        this.isLoadingPrevious = true;
        try {
          await this.$store.dispatch('fetchPreviousMessages', {
            conversationId: this.currentChat.id,
            before: this.currentChat.messages[0].id,
          });
          const heightDifference =
            this.conversationPanel.scrollHeight - this.heightBeforeLoad;
          this.conversationPanel.scrollTop =
            this.scrollTopBeforeLoad + heightDifference;
          this.setScrollParams();
        } catch (error) {
          // Ignore Error
        } finally {
          this.isLoadingPrevious = false;
        }
      }
    },

    handleScroll(e) {
      if (this.isProgrammaticScroll) {
        // Reset the flag
        this.isProgrammaticScroll = false;
        this.hasUserScrolled = false;
      } else {
        this.hasUserScrolled = true;
      }
      emitter.emit(BUS_EVENTS.ON_MESSAGE_LIST_SCROLL);
      this.fetchPreviousMessages(e.target.scrollTop);
    },

    makeMessagesRead() {
      this.$store.dispatch('markMessagesRead', { id: this.currentChat.id });
    },
    async handleMessageRetry(message) {
      if (!message) return;
      const payload = useSnakeCase(message);
      await this.$store.dispatch('sendMessageWithData', payload);
    },
    toggleReplyEditorSize() {
      this.resizableEditorWrapperRef?.toggleEditorExpand?.();
    },
    resetReplyEditorHeight() {
      this.resizableEditorWrapperRef?.resetEditorHeight?.();
    },
  },
};
</script>

<template>
  <div
    ref="messagesViewRef"
    class="flex flex-col justify-between flex-grow h-full min-w-0 m-0"
  >
    <div ref="topBannerRef">
      <Banner
        v-if="!currentChat.can_reply"
        color-scheme="alert"
        class="mx-2 mt-2 overflow-hidden rounded-lg"
        :banner-message="replyWindowBannerMessage"
        :href-link="replyWindowLink"
        :href-link-text="replyWindowLinkText"
      />
      <Banner
        v-else-if="hasDuplicateInstagramInbox"
        color-scheme="alert"
        class="mx-2 mt-2 overflow-hidden rounded-lg"
        :banner-message="$t('CONVERSATION.OLD_INSTAGRAM_INBOX_REPLY_BANNER')"
      />
    </div>
    <MessageList
      ref="conversationPanelRef"
      class="conversation-panel cs-chat-bg flex-shrink flex-grow basis-px flex flex-col overflow-y-auto relative h-full m-0 pb-4"
      :current-user-id="currentUserId"
      :first-unread-id="unReadMessages[0]?.id"
      :is-an-email-channel="isAnEmailChannel"
      :inbox-supports-reply-to="inboxSupportsReplyTo"
      :messages="getMessages"
      @retry="handleMessageRetry"
    >
      <template #beforeAll>
        <transition name="slide-up">
          <!-- eslint-disable-next-line vue/require-toggle-inside-transition -->
          <li
            class="min-h-[4rem] flex flex-shrink-0 flex-grow-0 items-center flex-auto justify-center max-w-full mt-0 mr-0 mb-1 ml-0 relative first:mt-auto last:mb-0"
          >
            <Spinner v-if="shouldShowSpinner" class="text-n-brand" />
          </li>
        </transition>
      </template>
      <template #unreadBadge>
        <li
          v-show="unreadMessageCount != 0"
          class="list-none flex justify-center items-center"
        >
          <span
            class="shadow-lg rounded-full bg-n-brand text-white text-xs font-medium my-2.5 mx-auto px-2.5 py-1.5"
          >
            {{ unreadMessageLabel }}
          </span>
        </li>
      </template>
      <template #after>
        <ConversationLabelSuggestion
          v-if="shouldShowLabelSuggestions"
          :suggested-labels="labelSuggestions"
          :chat-labels="currentChat.labels"
          :conversation-id="currentChat.id"
        />
      </template>
    </MessageList>
    <div class="flex relative flex-col bg-n-surface-1">
      <div
        v-if="isAnyoneTyping"
        class="absolute flex items-center w-full h-0 -top-7"
      >
        <div
          class="flex py-2 pr-4 pl-5 shadow-md rounded-full bg-white dark:bg-n-solid-3 text-n-slate-11 text-xs font-semibold my-2.5 mx-auto"
        >
          {{ typingUserNames }}
          <img
            class="w-6 ltr:ml-2 rtl:mr-2"
            src="assets/images/typing.gif"
            alt="Someone is typing"
          />
        </div>
      </div>
      <ResizableEditorWrapper
        ref="resizableEditorWrapperRef"
        :container-height="Math.max(0, containerHeight - topBannerHeight)"
      >
        <ReplyBox @toggle-editor-size="toggleReplyEditorSize" />
      </ResizableEditorWrapper>
    </div>
  </div>
</template>
CS_EOF_9a1c6
echo "  ok  app/javascript/dashboard/components/widgets/conversation/MessagesView.vue"


echo ""
echo "=== 2/3  Build ==="
docker build -f docker/Dockerfile -t chatssync-staging:latest .
echo ""
echo "=== 3/3  Restart ==="
cd "$COMPOSE"
docker compose up -d
echo ""
echo "============================================"
echo "  HO GAYA"
echo "  Ctrl+Shift+R dabana"
echo "  Light aur dark dono check karna"
echo "============================================"
