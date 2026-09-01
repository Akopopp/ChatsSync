#!/bin/bash
# ============================================================
#  ChatsSync — voice v4
#      cd /root/staging-build && bash apply-voice4.sh
#
#  FIX: send button ab sach mein BHEJTA hai
#       (pehle sirf recording rokta aur file attach karta tha)
#  FIX: voice bubble screen se bahar nahi jaayegi
# ============================================================
set -e
REPO="/root/staging-build"
COMPOSE="/data/coolify/applications/vdcb3i4jbkc4jsw204xguhk5"
[ -f "$REPO/docker/Dockerfile" ] || { echo "ERROR: repo $REPO mein nahi mila"; exit 1; }
cd "$REPO"
echo ""
echo "=== 1/3  Files likh raha hun ==="
mkdir -p "$(dirname app/javascript/dashboard/assets/scss/app.scss)"
cat > app/javascript/dashboard/assets/scss/app.scss << 'CS_EOF_VOICE4'
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
   Rang WhatsApp Web ke apne CSS se. Har section alag se.
   Hatana ho to yeh poora block delete kar do.
   ========================================================================== */

/* ============ 1. RANG ============ */
:root {
  --wa-chat: 239 231 222;
  --wa-panel: 255 255 255;
  --wa-rail: 240 242 245;
  --wa-head: 240 242 245;
  --wa-surface: 247 248 250;
  --wa-sent: 217 253 211;
  --wa-recv: 255 255 255;
  --wa-txt: 17 27 33;
  --wa-txt2: 84 101 111;
  --wa-txt3: 134 150 160;
  --wa-hover: 245 246 246;
  --wa-active: 240 242 245;
  --wa-green: 0 128 105;
  --wa-tick: 83 189 235;
  --wa-badge: 37 211 102;
  --wa-doodle: 0.06;
  --wa-sh: 0 1px 0.5px rgba(11, 20, 26, 0.13);
  --wa-line: rgba(11, 20, 26, 0.08);
  --wa-pop: 0 4px 22px rgba(11, 20, 26, 0.16);
}

.dark {
  --wa-chat: 11 20 26;
  --wa-panel: 17 27 33;
  --wa-rail: 32 44 51;
  --wa-head: 32 44 51;
  --wa-surface: 17 27 33;
  --wa-sent: 0 92 75;
  --wa-recv: 32 44 51;
  --wa-txt: 233 237 239;
  --wa-txt2: 174 186 193;
  --wa-txt3: 134 150 160;
  --wa-hover: 32 44 51;
  --wa-active: 42 57 66;
  --wa-green: 0 168 132;
  --wa-tick: 83 189 235;
  --wa-badge: 0 168 132;
  --wa-doodle: 0.042;
  --wa-sh: 0 1px 0.5px rgba(0, 0, 0, 0.35);
  --wa-line: rgba(255, 255, 255, 0.07);
  --wa-pop: 0 4px 22px rgba(0, 0, 0, 0.45);
}

/* ============ 2. RAIL ============ */
aside[class*='bg-n-background'] {
  background: rgb(var(--wa-rail)) !important;
  border-right: 1px solid var(--wa-line) !important;
}

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

.conversations-list-wrap h1 {
  font-size: 1.375rem !important;
  font-weight: 600 !important;
  letter-spacing: -0.02em;
  color: rgb(var(--wa-txt)) !important;
}

.conversation {
  padding-top: 0 !important;
  padding-bottom: 0 !important;
  border-bottom: none !important;
  transition: background-color 0.13s ease;

  .border-line {
    border-bottom: 1px solid var(--wa-line);
    padding-top: 0.625rem !important;
    padding-bottom: 0.625rem !important;
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

/* unread badge */
.conversation [class*='bg-n-brand'],
.conversation [class*='bg-woot'] {
  background: rgb(var(--wa-badge)) !important;
  color: #fff !important;
  border-radius: 999px !important;
  font-weight: 500;
  min-width: 1.25rem;
  height: 1.25rem;
}

/* search */
.conversations-list-wrap input[type='text'] {
  background: transparent !important;
  border: 0 !important;
  outline: none !important;
  box-shadow: none !important;
  color: rgb(var(--wa-txt)) !important;
  font-size: 0.875rem;
}

.conversations-list-wrap input[type='text']::placeholder {
  color: rgb(var(--wa-txt3)) !important;
}

/* ============ 4. PILLS ============ */
.cs-pills {
  scrollbar-width: none;
}

.cs-pills::-webkit-scrollbar {
  display: none;
}

/* ============ 5. CHAT HEADER ============ */
.conversation--header,
[class*='conversation--header'] {
  background: rgb(var(--wa-head)) !important;
  border-bottom: 1px solid var(--wa-line) !important;
}

/* ============ 6. THREAD + url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='352' height='232' viewBox='0 0 352 232'%3E%3Cg fill='none' stroke='%23fff' stroke-width='1.25' stroke-linecap='round' stroke-linejoin='round'%3E%3Cg transform='translate(18,20)'%3E%3Cpath d='M0 6a6 6 0 0 1 12 0 6 6 0 0 1-6 6H2l2-3a6 6 0 0 1-4-3z'/%3E%3C/g%3E%3Cg transform='translate(62,14)'%3E%3Cpath d='M0 0h14v10H4L0 13z'/%3E%3C/g%3E%3Cg transform='translate(108,22)'%3E%3Cpath d='M6 0l1.8 3.7 4 .6-2.9 2.8.7 4L6 9.2 2.4 11l.7-4L.2 4.3l4-.6z'/%3E%3C/g%3E%3Cg transform='translate(150,16)'%3E%3Cpath d='M2 2h12v12H2z M2 6h12'/%3E%3C/g%3E%3Cg transform='translate(192,20)'%3E%3Cpath d='M7 0C3 0 0 3 0 6.5 0 11 7 16 7 16s7-5 7-9.5C14 3 11 0 7 0z M7 4a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5z'/%3E%3C/g%3E%3Cg transform='translate(234,14)'%3E%3Cpath d='M0 8c0-4 3-7 7-7s7 3 7 7-3 7-7 7-7-3-7-7z M4 8h6 M7 5v6'/%3E%3C/g%3E%3Cg transform='translate(276,20)'%3E%3Cpath d='M0 3h16v10H0z M0 3l8 6 8-6'/%3E%3C/g%3E%3Cg transform='translate(318,16)'%3E%3Cpath d='M3 0h10v4H3z M1 4h14v11H1z M6 8h4'/%3E%3C/g%3E%3Cg transform='translate(14,64)'%3E%3Cpath d='M0 10c3-5 9-5 12 0 M6 4a2.5 2.5 0 1 1 0 .01'/%3E%3C/g%3E%3Cg transform='translate(56,58)'%3E%3Cpath d='M0 0h13M0 5h9M0 10h11'/%3E%3C/g%3E%3Cg transform='translate(98,62)'%3E%3Cpath d='M8 0a8 8 0 1 1 0 16A8 8 0 0 1 8 0z M8 4v4.5l3 2'/%3E%3C/g%3E%3Cg transform='translate(140,60)'%3E%3Cpath d='M0 0l11 6-11 6z'/%3E%3C/g%3E%3Cg transform='translate(182,58)'%3E%3Cpath d='M2 0h11l3 4v11H2z M13 0v4h3'/%3E%3C/g%3E%3Cg transform='translate(224,62)'%3E%3Cpath d='M0 6h4l4-5v14l-4-5H0z M11 4a4 4 0 0 1 0 8'/%3E%3C/g%3E%3Cg transform='translate(266,58)'%3E%3Cpath d='M1 1h14v10H1z M1 11l5-4 3 2 3-3 3 3'/%3E%3C/g%3E%3Cg transform='translate(308,64)'%3E%3Cpath d='M6 0a6 6 0 0 1 6 6c0 4-6 10-6 10S0 10 0 6a6 6 0 0 1 6-6z'/%3E%3C/g%3E%3Cg transform='translate(20,106)'%3E%3Cpath d='M0 4h5l3-4h4l3 4h1v10H0z M8 6a3 3 0 1 1 0 6 3 3 0 0 1 0-6z'/%3E%3C/g%3E%3Cg transform='translate(62,110)'%3E%3Cpath d='M6 0l6 12H0z'/%3E%3C/g%3E%3Cg transform='translate(104,104)'%3E%3Cpath d='M0 0h12v12H0z M3 3h6v6H3z'/%3E%3C/g%3E%3Cg transform='translate(146,108)'%3E%3Cpath d='M0 6a6 6 0 1 0 12 0 6 6 0 0 0-12 0z M3 6l2 2 4-4'/%3E%3C/g%3E%3Cg transform='translate(188,104)'%3E%3Cpath d='M1 3h14v9H1z M4 3V1h8v2 M4 12v2h8v-2'/%3E%3C/g%3E%3Cg transform='translate(230,110)'%3E%3Cpath d='M0 12L6 0l6 12z M4 12v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(272,106)'%3E%3Cpath d='M2 2l10 10M12 2L2 12'/%3E%3C/g%3E%3Cg transform='translate(314,110)'%3E%3Cpath d='M0 8h16 M4 4l-4 4 4 4 M12 4l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(16,150)'%3E%3Cpath d='M0 2h14v12H0z M3 0v4M11 0v4M0 6h14'/%3E%3C/g%3E%3Cg transform='translate(58,154)'%3E%3Cpath d='M7 0a7 7 0 1 1 0 14A7 7 0 0 1 7 0z M4 7h6'/%3E%3C/g%3E%3Cg transform='translate(100,148)'%3E%3Cpath d='M0 10c0-6 5-10 8-10s8 4 8 10'/%3E%3C/g%3E%3Cg transform='translate(142,152)'%3E%3Cpath d='M2 0h10v14l-5-4-5 4z'/%3E%3C/g%3E%3Cg transform='translate(184,150)'%3E%3Cpath d='M0 0h14v3H0z M2 3v10h10V3 M6 6v4M8 6v4'/%3E%3C/g%3E%3Cg transform='translate(226,154)'%3E%3Cpath d='M8 0l2 5 5 .5-4 3.5 1 5-4-2.6L4 14l1-5L1 5.5 6 5z'/%3E%3C/g%3E%3Cg transform='translate(268,148)'%3E%3Cpath d='M1 1h13v13H1z M4 7h7M7 4v7'/%3E%3C/g%3E%3Cg transform='translate(310,152)'%3E%3Cpath d='M0 5a5 5 0 0 1 10 0v6H0z M3 11v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(22,196)'%3E%3Cpath d='M0 3h16v9H0z M5 12v2h6v-2 M2 16h12'/%3E%3C/g%3E%3Cg transform='translate(64,198)'%3E%3Cpath d='M6 0a6 6 0 1 1 0 12A6 6 0 0 1 6 0z M6 3v3l2 2'/%3E%3C/g%3E%3Cg transform='translate(106,194)'%3E%3Cpath d='M0 6h12 M8 2l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(148,198)'%3E%3Cpath d='M2 0h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V2a2 2 0 0 1 2-2z M4 3h4M4 6h4M4 9h2'/%3E%3C/g%3E%3Cg transform='translate(190,194)'%3E%3Cpath d='M0 0h14M0 5h14M0 10h8'/%3E%3C/g%3E%3Cg transform='translate(232,198)'%3E%3Cpath d='M7 0l7 7-7 7-7-7z'/%3E%3C/g%3E%3Cg transform='translate(274,194)'%3E%3Cpath d='M1 4h12v9H1z M4 4V2a3 3 0 0 1 6 0v2'/%3E%3C/g%3E%3Cg transform='translate(316,198)'%3E%3Cpath d='M0 0l14 7-14 7 3-7z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E") ============ */
.conversation-panel {
  position: relative;
  background-color: rgb(var(--wa-chat)) !important;
  padding-left: 6% !important;
  padding-right: 6% !important;
  scroll-behavior: smooth;
  overscroll-behavior: contain;
}

.conversation-panel::before {
  content: '';
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: 0;
  opacity: var(--wa-doodle);
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='352' height='232' viewBox='0 0 352 232'%3E%3Cg fill='none' stroke='%23fff' stroke-width='1.25' stroke-linecap='round' stroke-linejoin='round'%3E%3Cg transform='translate(18,20)'%3E%3Cpath d='M0 6a6 6 0 0 1 12 0 6 6 0 0 1-6 6H2l2-3a6 6 0 0 1-4-3z'/%3E%3C/g%3E%3Cg transform='translate(62,14)'%3E%3Cpath d='M0 0h14v10H4L0 13z'/%3E%3C/g%3E%3Cg transform='translate(108,22)'%3E%3Cpath d='M6 0l1.8 3.7 4 .6-2.9 2.8.7 4L6 9.2 2.4 11l.7-4L.2 4.3l4-.6z'/%3E%3C/g%3E%3Cg transform='translate(150,16)'%3E%3Cpath d='M2 2h12v12H2z M2 6h12'/%3E%3C/g%3E%3Cg transform='translate(192,20)'%3E%3Cpath d='M7 0C3 0 0 3 0 6.5 0 11 7 16 7 16s7-5 7-9.5C14 3 11 0 7 0z M7 4a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5z'/%3E%3C/g%3E%3Cg transform='translate(234,14)'%3E%3Cpath d='M0 8c0-4 3-7 7-7s7 3 7 7-3 7-7 7-7-3-7-7z M4 8h6 M7 5v6'/%3E%3C/g%3E%3Cg transform='translate(276,20)'%3E%3Cpath d='M0 3h16v10H0z M0 3l8 6 8-6'/%3E%3C/g%3E%3Cg transform='translate(318,16)'%3E%3Cpath d='M3 0h10v4H3z M1 4h14v11H1z M6 8h4'/%3E%3C/g%3E%3Cg transform='translate(14,64)'%3E%3Cpath d='M0 10c3-5 9-5 12 0 M6 4a2.5 2.5 0 1 1 0 .01'/%3E%3C/g%3E%3Cg transform='translate(56,58)'%3E%3Cpath d='M0 0h13M0 5h9M0 10h11'/%3E%3C/g%3E%3Cg transform='translate(98,62)'%3E%3Cpath d='M8 0a8 8 0 1 1 0 16A8 8 0 0 1 8 0z M8 4v4.5l3 2'/%3E%3C/g%3E%3Cg transform='translate(140,60)'%3E%3Cpath d='M0 0l11 6-11 6z'/%3E%3C/g%3E%3Cg transform='translate(182,58)'%3E%3Cpath d='M2 0h11l3 4v11H2z M13 0v4h3'/%3E%3C/g%3E%3Cg transform='translate(224,62)'%3E%3Cpath d='M0 6h4l4-5v14l-4-5H0z M11 4a4 4 0 0 1 0 8'/%3E%3C/g%3E%3Cg transform='translate(266,58)'%3E%3Cpath d='M1 1h14v10H1z M1 11l5-4 3 2 3-3 3 3'/%3E%3C/g%3E%3Cg transform='translate(308,64)'%3E%3Cpath d='M6 0a6 6 0 0 1 6 6c0 4-6 10-6 10S0 10 0 6a6 6 0 0 1 6-6z'/%3E%3C/g%3E%3Cg transform='translate(20,106)'%3E%3Cpath d='M0 4h5l3-4h4l3 4h1v10H0z M8 6a3 3 0 1 1 0 6 3 3 0 0 1 0-6z'/%3E%3C/g%3E%3Cg transform='translate(62,110)'%3E%3Cpath d='M6 0l6 12H0z'/%3E%3C/g%3E%3Cg transform='translate(104,104)'%3E%3Cpath d='M0 0h12v12H0z M3 3h6v6H3z'/%3E%3C/g%3E%3Cg transform='translate(146,108)'%3E%3Cpath d='M0 6a6 6 0 1 0 12 0 6 6 0 0 0-12 0z M3 6l2 2 4-4'/%3E%3C/g%3E%3Cg transform='translate(188,104)'%3E%3Cpath d='M1 3h14v9H1z M4 3V1h8v2 M4 12v2h8v-2'/%3E%3C/g%3E%3Cg transform='translate(230,110)'%3E%3Cpath d='M0 12L6 0l6 12z M4 12v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(272,106)'%3E%3Cpath d='M2 2l10 10M12 2L2 12'/%3E%3C/g%3E%3Cg transform='translate(314,110)'%3E%3Cpath d='M0 8h16 M4 4l-4 4 4 4 M12 4l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(16,150)'%3E%3Cpath d='M0 2h14v12H0z M3 0v4M11 0v4M0 6h14'/%3E%3C/g%3E%3Cg transform='translate(58,154)'%3E%3Cpath d='M7 0a7 7 0 1 1 0 14A7 7 0 0 1 7 0z M4 7h6'/%3E%3C/g%3E%3Cg transform='translate(100,148)'%3E%3Cpath d='M0 10c0-6 5-10 8-10s8 4 8 10'/%3E%3C/g%3E%3Cg transform='translate(142,152)'%3E%3Cpath d='M2 0h10v14l-5-4-5 4z'/%3E%3C/g%3E%3Cg transform='translate(184,150)'%3E%3Cpath d='M0 0h14v3H0z M2 3v10h10V3 M6 6v4M8 6v4'/%3E%3C/g%3E%3Cg transform='translate(226,154)'%3E%3Cpath d='M8 0l2 5 5 .5-4 3.5 1 5-4-2.6L4 14l1-5L1 5.5 6 5z'/%3E%3C/g%3E%3Cg transform='translate(268,148)'%3E%3Cpath d='M1 1h13v13H1z M4 7h7M7 4v7'/%3E%3C/g%3E%3Cg transform='translate(310,152)'%3E%3Cpath d='M0 5a5 5 0 0 1 10 0v6H0z M3 11v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(22,196)'%3E%3Cpath d='M0 3h16v9H0z M5 12v2h6v-2 M2 16h12'/%3E%3C/g%3E%3Cg transform='translate(64,198)'%3E%3Cpath d='M6 0a6 6 0 1 1 0 12A6 6 0 0 1 6 0z M6 3v3l2 2'/%3E%3C/g%3E%3Cg transform='translate(106,194)'%3E%3Cpath d='M0 6h12 M8 2l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(148,198)'%3E%3Cpath d='M2 0h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V2a2 2 0 0 1 2-2z M4 3h4M4 6h4M4 9h2'/%3E%3C/g%3E%3Cg transform='translate(190,194)'%3E%3Cpath d='M0 0h14M0 5h14M0 10h8'/%3E%3C/g%3E%3Cg transform='translate(232,198)'%3E%3Cpath d='M7 0l7 7-7 7-7-7z'/%3E%3C/g%3E%3Cg transform='translate(274,194)'%3E%3Cpath d='M1 4h12v9H1z M4 4V2a3 3 0 0 1 6 0v2'/%3E%3C/g%3E%3Cg transform='translate(316,198)'%3E%3Cpath d='M0 0l14 7-14 7 3-7z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
  background-size: 264px 174px;
}

.conversation-panel > * {
  position: relative;
  z-index: 1;
}

/* din ka separator + system message */
.conversation-panel [class*='date-separator'] span,
.conversation-panel [class*='bg-n-alpha-1'][class*='rounded-lg'] {
  background: rgb(var(--wa-head)) !important;
  border-radius: 0.5rem !important;
  padding: 0.32rem 0.8rem !important;
  font-size: 0.75rem !important;
  box-shadow: var(--wa-sh);
  border: 0 !important;
  color: rgb(var(--wa-txt2)) !important;
}

/* ============ 7. BUBBLES ============ */
.message-bubble-container {
  margin-bottom: 0.125rem !important;
  margin-top: 0.375rem;
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
  padding: 0.375rem 0.4375rem 0.5rem 0.5625rem !important;
  box-shadow: var(--wa-sh);
  max-width: 65% !important;
  line-height: 1.35;
  font-size: 0.8875rem;
}

.message-bubble-container [class*='i-lucide-check'],
.message-bubble-container [class*='check-double'] {
  color: rgb(var(--wa-tick)) !important;
}

.message-bubble-container time {
  color: rgb(var(--wa-txt3));
  font-size: 0.6875rem;
  opacity: 0.65;
}

/* ============ 8. COMPOSER ============ */
.reply-box {
  background: rgb(var(--wa-head)) !important;
  border: 1px solid var(--wa-line) !important;
  border-radius: 1.5rem !important;
  margin: 0.5rem 0.75rem 0.75rem !important;
  min-height: 2.75rem;
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

.reply-box [class*='cursor-row-resize'],
.reply-box [class*='cursor-ns-resize'] {
  display: none !important;
}

/* ============ 9. CONTEXT MENUS ============ */
[class*='context-menu'],
.dropdown-pane,
[role='menu'] {
  border-radius: 0.6rem !important;
  box-shadow: var(--wa-pop) !important;
  border: 1px solid var(--wa-line) !important;
  background: rgb(var(--wa-panel)) !important;
  padding: 0.4rem 0 !important;
}

[role='menuitem'],
[class*='context-menu'] button,
[class*='context-menu'] li {
  border-radius: 0 !important;
  padding: 0.55rem 1rem !important;
  font-size: 0.9rem;
  transition: background-color 0.12s ease;
}

[role='menuitem']:hover,
[class*='context-menu'] button:hover {
  background: rgb(var(--wa-hover)) !important;
}

/* ============ 10. RIGHT PANEL ============ */
[class*='conversation-sidebar'],
.conversation-sidebar-wrap {
  background: rgb(var(--wa-panel)) !important;
  border-left: 1px solid var(--wa-line);
}

/* ============ 11. SETTINGS ============ */
.settings,
[class*='bg-n-surface-1'] {
  background: rgb(var(--wa-surface)) !important;
}

/* settings ka bada heading chhota aur saaf */
.settings h1,
[class*='max-w-7xl'] h1 {
  font-size: 1.5rem !important;
  font-weight: 600 !important;
  letter-spacing: -0.02em;
}

.settings h2,
[class*='text-heading-1'] {
  font-size: 1.125rem !important;
  font-weight: 600 !important;
  letter-spacing: -0.01em;
}

/* settings ke cards */
[class*='border-n-weak'][class*='rounded'] {
  border-color: var(--wa-line) !important;
  border-radius: 0.75rem !important;
  margin-bottom: 0.875rem;
}

/* settings ke andar ke rows — v17 jaisi saans */
[class*='max-w-7xl'] [class*='py-'] > [class*='border-b'] {
  padding-top: 0.875rem !important;
  padding-bottom: 0.875rem !important;
}

/* ============ 12. TABLES (settings, reports, contacts) ============ */
table {
  border-collapse: separate;
  border-spacing: 0;
}

table thead {
  background: rgb(var(--wa-hover)) !important;
}

table thead th {
  font-size: 0.6875rem !important;
  font-weight: 600 !important;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: rgb(var(--wa-txt3)) !important;
  padding: 0.7rem 1rem !important;
}

table tbody td {
  padding: 0.8rem 1rem !important;
  font-size: 0.875rem;
  border-top: 1px solid var(--wa-line) !important;
}

table tbody tr:hover {
  background: rgb(var(--wa-hover)) !important;
}

/* numbers align */
table td[class*='text-right'],
table th[class*='text-right'] {
  font-variant-numeric: tabular-nums;
}

/* ============ 13. BUTTONS + LINKS ============ */
button[class*='bg-n-brand'],
.button--primary,
button[class*='bg-woot-500'] {
  background: rgb(var(--wa-green)) !important;
  border-color: rgb(var(--wa-green)) !important;
  transition: filter 0.14s ease, transform 0.12s ease;
}

button[class*='bg-n-brand']:hover,
.button--primary:hover {
  filter: brightness(1.08);
}

button[class*='bg-n-brand']:active,
.button--primary:active {
  transform: scale(0.97);
}

a[class*='text-n-brand'],
[class*='text-woot-500'] {
  color: rgb(var(--wa-green)) !important;
}

/* ============ 14. FORM FIELDS ============ */
input[type='text'],
input[type='email'],
input[type='password'],
input[type='number'],
input[type='search'],
select,
textarea {
  border-radius: 0.6rem !important;
  transition: border-color 0.14s ease;
}

input:focus,
select:focus,
textarea:focus {
  border-color: rgb(var(--wa-green) / 0.5) !important;
  box-shadow: none !important;
  outline: none !important;
}

/* ============ 15. SCROLLBARS ============ */
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

/* ============ 16. SMOOTHNESS ============ */
* {
  -webkit-tap-highlight-color: transparent;
}

.conversation,
aside a,
aside button,
[role='menuitem'],
table tbody tr {
  transition: background-color 0.13s ease, color 0.13s ease,
    transform 0.13s ease, opacity 0.13s ease;
}

/* ============ 17. MOBILE ============ */
@media (max-width: 767px) {
  .conversation-panel {
    padding-left: 3% !important;
    padding-right: 3% !important;
  }

  .message-bubble-container .left-bubble,
  .message-bubble-container .right-bubble {
    max-width: 84% !important;
    font-size: 0.9375rem;
  }

  .reply-box {
    margin: 0.4rem 0.5rem calc(0.5rem + env(safe-area-inset-bottom)) !important;
    border-radius: 1.5rem !important;
  }

  /* mobile par input 16px — warna iOS zoom karta hai */
  .reply-box .ProseMirror-woot-style,
  input,
  textarea,
  select {
    font-size: 16px !important;
  }

  .conversations-list-wrap h1 {
    font-size: 1.25rem !important;
  }

  .conversation .border-line {
    padding-top: 0.55rem !important;
    padding-bottom: 0.55rem !important;
  }

  /* menus mobile par neeche se, poori chaudai */
  [class*='context-menu'],
  [role='menu'] {
    border-radius: 0.9rem !important;
  }

  table thead th,
  table tbody td {
    padding: 0.6rem 0.7rem !important;
    font-size: 0.8125rem;
  }

  .settings h1,
  [class*='max-w-7xl'] h1 {
    font-size: 1.25rem !important;
  }
}

/* ============ 18. ACCESSIBILITY ============ */
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}

/* ============ 19. CHHOTI SCREEN (400px se neeche) ============ */
@media (max-width: 400px) {
  .message-bubble-container .left-bubble,
  .message-bubble-container .right-bubble {
    max-width: 88% !important;
  }

  .conversations-list-wrap h1 {
    font-size: 1.125rem !important;
  }

  .cs-pill {
    font-size: 0.75rem;
    padding: 0.28rem 0.7rem;
  }
}
/* ============ 20. VOICE MESSAGE ============ */
/* voice bubble screen se bahar na jaye */
.message-bubble-container [data-bubble-name='audio'] {
  max-width: min(19rem, 65%) !important;
  min-width: 0 !important;
}

@media (max-width: 767px) {
  .message-bubble-container [data-bubble-name='audio'] {
    max-width: min(17rem, 84%) !important;
  }
}

@media (max-width: 400px) {
  .message-bubble-container [data-bubble-name='audio'] {
    max-width: 88% !important;
  }
}
CS_EOF_VOICE4
echo "  ok  app/javascript/dashboard/assets/scss/app.scss"

mkdir -p "$(dirname app/javascript/dashboard/components/widgets/conversation/MessagesView.vue)"
cat > app/javascript/dashboard/components/widgets/conversation/MessagesView.vue << 'CS_EOF_VOICE4'
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
CS_EOF_VOICE4
echo "  ok  app/javascript/dashboard/components/widgets/conversation/MessagesView.vue"

mkdir -p "$(dirname app/javascript/dashboard/components/widgets/ChatTypeTabs.vue)"
cat > app/javascript/dashboard/components/widgets/ChatTypeTabs.vue << 'CS_EOF_VOICE4'
<script setup>
import { computed } from 'vue';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  activeTab: {
    type: String,
    default: wootConstants.ASSIGNEE_TYPE.ME,
  },
});

const emit = defineEmits(['chatTabChange']);

const activeTabIndex = computed(() => {
  return props.items.findIndex(item => item.key === props.activeTab);
});

const onTabChange = selectedTabIndex => {
  if (selectedTabIndex >= 0 && selectedTabIndex < props.items.length) {
    const selectedItem = props.items[selectedTabIndex];
    if (selectedItem.key !== props.activeTab) {
      emit('chatTabChange', selectedItem.key);
    }
  }
};

const keyboardEvents = {
  'Alt+KeyN': {
    action: () => {
      if (props.activeTab === wootConstants.ASSIGNEE_TYPE.ALL) {
        onTabChange(0);
      } else {
        const nextIndex = (activeTabIndex.value + 1) % props.items.length;
        onTabChange(nextIndex);
      }
    },
  },
};

useKeyboardEvents(keyboardEvents);
</script>

<template>
  <!-- WhatsApp filter pills -->
  <div class="cs-pills">
    <button
      v-for="(item, index) in items"
      :key="item.key"
      type="button"
      class="cs-pill"
      :class="{ 'cs-pill--on': item.key === activeTab }"
      @click="onTabChange(index)"
    >
      <span>{{ item.name }}</span>
      <span v-if="item.count" class="cs-pill__count">{{ item.count }}</span>
    </button>
  </div>
</template>

<style scoped lang="scss">
.cs-pills {
  @apply flex items-center gap-2 px-3 pb-2 pt-0.5 overflow-x-auto;
  scrollbar-width: none;

  &::-webkit-scrollbar {
    display: none;
  }
}

.cs-pill {
  @apply flex-shrink-0 flex items-center gap-1.5 rounded-full text-sm;
  padding: 0.3rem 0.9rem;
  background: rgb(var(--wa-hover, 245 246 246));
  color: rgb(var(--wa-text2, 84 101 111));
  transition: background-color 0.14s ease, color 0.14s ease, transform 0.12s ease;

  &:active {
    transform: scale(0.96);
  }

  &--on {
    background: rgb(var(--wa-green, 0 128 105) / 0.16);
    color: rgb(var(--wa-green, 0 128 105));
    font-weight: 500;
  }
}

.cs-pill__count {
  @apply text-xs font-semibold;
  opacity: 0.85;
}
</style>
CS_EOF_VOICE4
echo "  ok  app/javascript/dashboard/components/widgets/ChatTypeTabs.vue"

mkdir -p "$(dirname app/javascript/dashboard/components-next/sidebar/provider.js)"
cat > app/javascript/dashboard/components-next/sidebar/provider.js << 'CS_EOF_VOICE4'
import { inject, provide, ref, computed } from 'vue';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useRouter } from 'vue-router';
import { useUISettings } from 'dashboard/composables/useUISettings';

const SidebarControl = Symbol('SidebarControl');

// ChatsSync: WhatsApp rail — 62px par khulta hai.
// 62 < COLLAPSED_THRESHOLD, isliye icon-only mode milta hai.
const DEFAULT_WIDTH = 62;
const MIN_WIDTH = 62;
const COLLAPSED_THRESHOLD = 160;
const MAX_WIDTH = 320;

// Shared state for active popover (only one can be open at a time)
const activePopover = ref(null);
let globalCloseTimeout = null;

export function useSidebarResize() {
  const { uiSettings, updateUISettings } = useUISettings();

  // purani saved width ab bhi 160 se upar ho sakti hai; rail default rakho
  const savedWidth = uiSettings.value.sidebar_width;
  const sidebarWidth = ref(
    savedWidth && savedWidth < COLLAPSED_THRESHOLD ? savedWidth : DEFAULT_WIDTH
  );
  const isCollapsed = computed(() => sidebarWidth.value < COLLAPSED_THRESHOLD);

  const setSidebarWidth = width => {
    sidebarWidth.value = Math.max(MIN_WIDTH, Math.min(MAX_WIDTH, width));
  };

  const saveWidth = () => {
    updateUISettings({ sidebar_width: sidebarWidth.value });
  };

  const snapToCollapsed = () => {
    sidebarWidth.value = MIN_WIDTH;
    updateUISettings({ sidebar_width: MIN_WIDTH });
  };

  const snapToExpanded = () => {
    sidebarWidth.value = 300;
    updateUISettings({ sidebar_width: 300 });
  };

  return {
    sidebarWidth,
    isCollapsed,
    setSidebarWidth,
    saveWidth,
    snapToCollapsed,
    snapToExpanded,
    MIN_WIDTH,
    MAX_WIDTH,
    COLLAPSED_THRESHOLD,
    DEFAULT_WIDTH,
  };
}

export function usePopoverState() {
  const setActivePopover = name => {
    clearTimeout(globalCloseTimeout);
    activePopover.value = name;
  };

  const closeActivePopover = () => {
    activePopover.value = null;
  };

  const scheduleClose = (delay = 150) => {
    clearTimeout(globalCloseTimeout);
    globalCloseTimeout = setTimeout(() => {
      closeActivePopover();
    }, delay);
  };

  const cancelClose = () => {
    clearTimeout(globalCloseTimeout);
  };

  return {
    activePopover,
    setActivePopover,
    closeActivePopover,
    scheduleClose,
    cancelClose,
  };
}

export function useSidebarContext() {
  const context = inject(SidebarControl, null);
  if (context === null) {
    throw new Error(`Component is missing a parent <Sidebar /> component.`);
  }

  const router = useRouter();
  const { shouldShow } = usePolicy();

  const resolvePath = to => {
    if (to) return router.resolve(to)?.path || '/';
    return '/';
  };

  // Helper to find route definition by name without resolving
  const findRouteByName = name => {
    const routes = router.getRoutes();
    return routes.find(route => route.name === name);
  };

  const resolvePermissions = to => {
    if (!to) return [];

    // If navigationPath param exists, get the target route definition
    if (to.params?.navigationPath) {
      const targetRoute = findRouteByName(to.params.navigationPath);
      return targetRoute?.meta?.permissions ?? [];
    }

    return router.resolve(to)?.meta?.permissions ?? [];
  };

  const resolveFeatureFlag = to => {
    if (!to) return '';

    // If navigationPath param exists, get the target route definition
    if (to.params?.navigationPath) {
      const targetRoute = findRouteByName(to.params.navigationPath);
      return targetRoute?.meta?.featureFlag || '';
    }

    return router.resolve(to)?.meta?.featureFlag || '';
  };

  const resolveInstallationType = to => {
    if (!to) return [];

    // If navigationPath param exists, get the target route definition
    if (to.params?.navigationPath) {
      const targetRoute = findRouteByName(to.params.navigationPath);
      return targetRoute?.meta?.installationTypes || [];
    }

    return router.resolve(to)?.meta?.installationTypes || [];
  };

  const isAllowed = to => {
    const permissions = resolvePermissions(to);
    const featureFlag = resolveFeatureFlag(to);
    const installationType = resolveInstallationType(to);

    return shouldShow(featureFlag, permissions, installationType);
  };

  return {
    ...context,
    resolvePath,
    resolvePermissions,
    resolveFeatureFlag,
    isAllowed,
  };
}

export function provideSidebarContext(context) {
  provide(SidebarControl, context);
}
CS_EOF_VOICE4
echo "  ok  app/javascript/dashboard/components-next/sidebar/provider.js"

mkdir -p "$(dirname app/javascript/dashboard/components/widgets/WootWriter/AudioRecorder.vue)"
cat > app/javascript/dashboard/components/widgets/WootWriter/AudioRecorder.vue << 'CS_EOF_VOICE4'
<script setup>
import getUuid from 'widget/helpers/uuid';
import { ref, onMounted, onUnmounted } from 'vue';
import WaveSurfer from 'wavesurfer.js';
import RecordPlugin from 'wavesurfer.js/dist/plugins/record.js';
import { format, intervalToDuration } from 'date-fns';
import { convertAudio } from './utils/audioConversionUtils';

const props = defineProps({
  audioRecordFormat: {
    type: String,
    required: true,
  },
});

const emit = defineEmits([
  'recorderProgressChanged',
  'finishRecord',
  'pause',
  'play',
  'recordError',
  'recordPause',
  'recordResume',
  'recordCancel',
]);

const waveformContainer = ref(null);
const wavesurfer = ref(null);
const record = ref(null);
const isRecording = ref(false);
const isPlaying = ref(false);
const hasRecording = ref(false);
const cancelled = ref(false);
const recordedAudioUrl = ref(null);

const formatTimeProgress = time => {
  const duration = intervalToDuration({ start: 0, end: time });
  return format(
    new Date(0, 0, 0, 0, duration.minutes, duration.seconds),
    'mm:ss'
  );
};

const AUDIO_EXTENSION_MAP = {
  'audio/ogg': 'ogg',
  'audio/mp3': 'mp3',
  'audio/mpeg': 'mp3',
  'audio/wav': 'wav',
  'audio/webm': 'webm',
};

const getRecordPluginOptions = audioFormat => {
  const options = {
    scrollingWaveform: true,
    renderRecordedAudio: false,
  };
  if (
    audioFormat === 'audio/ogg' &&
    MediaRecorder.isTypeSupported('audio/ogg;codecs=opus')
  ) {
    options.mimeType = 'audio/ogg;codecs=opus';
  }
  return options;
};

const initWaveSurfer = () => {
  wavesurfer.value = WaveSurfer.create({
    container: waveformContainer.value,
    // WhatsApp jaisi waveform: patli, chhoti, grey
    waveColor: 'rgba(134, 150, 160, 0.85)',
    progressColor: 'rgba(0, 168, 132, 0.9)',
    cursorWidth: 0,
    height: 34,
    barWidth: 2,
    barGap: 2,
    barRadius: 3,
    plugins: [
      RecordPlugin.create(getRecordPluginOptions(props.audioRecordFormat)),
    ],
  });

  wavesurfer.value.on('pause', () => emit('pause'));
  wavesurfer.value.on('play', () => emit('play'));

  record.value = wavesurfer.value.plugins[0];

  wavesurfer.value.on('finish', () => {
    isPlaying.value = false;
  });

  record.value.on('record-end', async blob => {
    if (cancelled.value) {
      cancelled.value = false;
      return;
    }
    try {
      const audioBlob = await convertAudio(blob, props.audioRecordFormat);
      // Use the converted blob's actual type, which may differ from the
      // requested format when the browser can't produce it (e.g. Safari falls
      // back to MP3 instead of OGG). This keeps the filename, content type, and
      // voice-note flag consistent with the real bytes.
      const audioType = audioBlob.type || props.audioRecordFormat;
      const ext = AUDIO_EXTENSION_MAP[audioType] || 'mp3';
      const fileName = `${getUuid()}.${ext}`;
      const file = new File([audioBlob], fileName, {
        type: audioType,
      });
      if (recordedAudioUrl.value) URL.revokeObjectURL(recordedAudioUrl.value);
      recordedAudioUrl.value = URL.createObjectURL(audioBlob);
      wavesurfer.value.load(recordedAudioUrl.value);
      emit('finishRecord', {
        name: file.name,
        type: file.type,
        size: file.size,
        file,
      });
      hasRecording.value = true;
      isRecording.value = false;
    } catch (error) {
      isRecording.value = false;
      hasRecording.value = false;
      emit('recordError', { error });
    }
  });

  record.value.on('record-progress', time => {
    emit('recorderProgressChanged', formatTimeProgress(time));
  });
};

const isPaused = ref(false);

const stopRecording = () => {
  if (isRecording.value) {
    record.value.stopRecording();
    isRecording.value = false;
    isPaused.value = false;
  }
};

// WhatsApp jaisa: pause matlab recording ruk jaye — apni awaz na sunayi de
const pauseResumeRecording = () => {
  if (!isRecording.value) return;
  if (isPaused.value) {
    record.value.resumeRecording();
    isPaused.value = false;
    emit('recordResume');
  } else {
    record.value.pauseRecording();
    isPaused.value = true;
    emit('recordPause');
  }
};

// delete — recording band karo aur file bhejo hi mat
const cancelRecording = () => {
  cancelled.value = true;
  if (isRecording.value) {
    record.value.stopRecording();
    isRecording.value = false;
  }
  isPaused.value = false;
  if (recordedAudioUrl.value) {
    URL.revokeObjectURL(recordedAudioUrl.value);
    recordedAudioUrl.value = null;
  }
  hasRecording.value = false;
  emit('recordCancel');
};

const startRecording = () => {
  record.value.startRecording();
  isRecording.value = true;
};

const playPause = () => {
  if (hasRecording.value) {
    wavesurfer.value.playPause();
    isPlaying.value = !isPlaying.value;
  }
};

onMounted(() => {
  initWaveSurfer();
  startRecording();
});

onUnmounted(() => {
  if (recordedAudioUrl.value) {
    URL.revokeObjectURL(recordedAudioUrl.value);
    recordedAudioUrl.value = null;
  }
  if (wavesurfer.value) {
    wavesurfer.value.destroy();
  }
});

defineExpose({
  playPause,
  stopRecording,
  pauseResumeRecording,
  cancelRecording,
  isPaused,
  record,
});
</script>

<template>
  <div ref="waveformContainer" class="cs-wave w-full" />
</template>

<style scoped>
/* WhatsApp jaisi patli waveform */
.cs-wave {
  padding: 0.25rem 0;
  min-height: 34px;
}
</style>
CS_EOF_VOICE4
echo "  ok  app/javascript/dashboard/components/widgets/WootWriter/AudioRecorder.vue"

mkdir -p "$(dirname app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue)"
cat > app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue << 'CS_EOF_VOICE4'
<script>
import { ref } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import FileUpload from 'vue-upload-component';
import * as ActiveStorage from 'activestorage';
import inboxMixin from 'shared/mixins/inboxMixin';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { getAllowedFileTypesByChannel } from '@chatwoot/utils';
import VideoCallButton from '../VideoCallButton.vue';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import { mapGetters } from 'vuex';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  name: 'ReplyBottomPanel',
  components: { NextButton, FileUpload, VideoCallButton },
  mixins: [inboxMixin],
  props: {
    isNote: {
      type: Boolean,
      default: false,
    },
    onSend: {
      type: Function,
      default: () => {},
    },
    sendButtonText: {
      type: String,
      default: '',
    },
    recordingAudioDurationText: {
      type: String,
      default: '00:00',
    },
    // inbox prop is used in /mixins/inboxMixin,
    // remove this props when refactoring to composable if not needed
    // eslint-disable-next-line vue/no-unused-properties
    inbox: {
      type: Object,
      default: () => ({}),
    },
    showFileUpload: {
      type: Boolean,
      default: false,
    },
    showAudioRecorder: {
      type: Boolean,
      default: false,
    },
    onFileUpload: {
      type: Function,
      default: () => {},
    },
    toggleEmojiPicker: {
      type: Function,
      default: () => {},
    },
    toggleAudioRecorder: {
      type: Function,
      default: () => {},
    },
    toggleAudioRecorderPlayPause: {
      type: Function,
      default: () => {},
    },
    isRecordingAudio: {
      type: Boolean,
      default: false,
    },
    recordingAudioState: {
      type: String,
      default: '',
    },
    isSendDisabled: {
      type: Boolean,
      default: false,
    },
    isOnPrivateNote: {
      type: Boolean,
      default: false,
    },
    enableMultipleFileUpload: {
      type: Boolean,
      default: true,
    },
    enableWhatsAppTemplates: {
      type: Boolean,
      default: false,
    },
    enableContentTemplates: {
      type: Boolean,
      default: false,
    },
    conversationId: {
      type: Number,
      required: true,
    },
    // eslint-disable-next-line vue/no-unused-properties
    message: {
      type: String,
      default: '',
    },
    newConversationModalActive: {
      type: Boolean,
      default: false,
    },
    portalSlug: {
      type: String,
      required: true,
    },
    conversationType: {
      type: String,
      default: '',
    },
    showQuotedReplyToggle: {
      type: Boolean,
      default: false,
    },
    quotedReplyEnabled: {
      type: Boolean,
      default: false,
    },
    isEditorDisabled: {
      type: Boolean,
      default: false,
    },
  },
  emits: [
    'toggleInsertArticle',
    'selectWhatsappTemplate',
    'selectContentTemplate',
    'toggleQuotedReply',
    'cancelAudio',
    'finishAudio',
  ],
  setup(props) {
    const { setSignatureFlagForInbox, fetchSignatureFlagFromUISettings } =
      useUISettings();

    const uploadRef = ref(false);

    const keyboardEvents = {
      '$mod+Alt+KeyA': {
        action: () => {
          // Skip if editor is disabled (e.g., WhatsApp 24-hour window expired)
          if (props.isEditorDisabled) return;

          // TODO: This is really hacky, we need to replace the file picker component with
          // a custom one, where the logic and the component markup is isolated.
          // Once we have the custom component, we can remove the hacky logic below.

          const uploadTriggerButton = document.querySelector(
            '#conversationAttachment'
          );
          if (uploadTriggerButton) uploadTriggerButton.click();
        },
        allowOnFocusedInput: true,
      },
    };

    useKeyboardEvents(keyboardEvents);

    return {
      setSignatureFlagForInbox,
      fetchSignatureFlagFromUISettings,
      uploadRef,
    };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      uiFlags: 'integrations/getUIFlags',
    }),
    wrapClass() {
      return {
        'is-note-mode': this.isNote,
      };
    },
    showAttachButton() {
      if (this.isEditorDisabled) return false;
      return this.showFileUpload || this.isNote;
    },
    showAudioRecorderButton() {
      if (this.isEditorDisabled) return false;
      if (this.isALineChannel || this.isATiktokChannel) {
        return false;
      }
      // Disable audio recorder for safari browser as recording is not supported
      // const isSafari = /^((?!chrome|android|crios|fxios).)*safari/i.test(
      //   navigator.userAgent
      // );

      return (
        this.isFeatureEnabledonAccount(
          this.accountId,
          FEATURE_FLAGS.VOICE_RECORDER
        ) && this.showAudioRecorder
        // !isSafari
      );
    },
    showAudioPlayStopButton() {
      if (this.isEditorDisabled) return false;
      return this.showAudioRecorder && this.isRecordingAudio;
    },
    isInstagramDM() {
      return this.conversationType === 'instagram_direct_message';
    },
    allowedFileTypes() {
      if (this.isOnPrivateNote) {
        return getAllowedFileTypesByChannel();
      }

      let channelType = this.channelType || this.inbox?.channel_type;
      if (this.isAnInstagramChannel || this.isInstagramDM) {
        channelType = INBOX_TYPES.INSTAGRAM;
      }

      return getAllowedFileTypesByChannel({
        channelType,
        medium: this.inbox?.medium,
      });
    },
    enableDragAndDrop() {
      return !this.newConversationModalActive;
    },
    audioRecorderPlayStopIcon() {
      switch (this.recordingAudioState) {
        // playing paused recording stopped inactive destroyed
        case 'playing':
          return 'i-ph-pause';
        case 'paused':
          return 'i-ph-play';
        case 'stopped':
          return 'i-ph-play';
        default:
          return 'i-ph-stop';
      }
    },
    showMessageSignatureButton() {
      if (this.isEditorDisabled) return false;
      return !this.isOnPrivateNote;
    },
    sendWithSignature() {
      // channelType is sourced from inboxMixin
      return this.fetchSignatureFlagFromUISettings(this.channelType);
    },
    signatureToggleTooltip() {
      return this.sendWithSignature
        ? this.$t('CONVERSATION.FOOTER.DISABLE_SIGN_TOOLTIP')
        : this.$t('CONVERSATION.FOOTER.ENABLE_SIGN_TOOLTIP');
    },
    enableInsertArticleInReply() {
      return this.portalSlug;
    },
    isFetchingAppIntegrations() {
      return this.uiFlags.isFetching;
    },
    quotedReplyToggleTooltip() {
      return this.quotedReplyEnabled
        ? this.$t('CONVERSATION.REPLYBOX.QUOTED_REPLY.DISABLE_TOOLTIP')
        : this.$t('CONVERSATION.REPLYBOX.QUOTED_REPLY.ENABLE_TOOLTIP');
    },
  },
  mounted() {
    ActiveStorage.start();
  },
  methods: {
    toggleMessageSignature() {
      this.setSignatureFlagForInbox(this.channelType, !this.sendWithSignature);
    },
    toggleInsertArticle() {
      this.$emit('toggleInsertArticle');
    },
  },
};
</script>

<template>
  <!-- WhatsApp composer:  📎 😊 [extra]  |  input  |  🎤 / ➤ -->
  <div class="cs-composer" :class="wrapClass">
    <!-- LEFT: attach, emoji, aur zaroori extras -->
    <div v-if="!isRecordingAudio" class="cs-left">
      <FileUpload
        v-if="showAttachButton"
        ref="uploadRef"
        v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_ATTACH_ICON')"
        input-id="conversationAttachment"
        :size="4096 * 4096"
        :accept="allowedFileTypes"
        :multiple="enableMultipleFileUpload"
        :drop="enableDragAndDrop"
        :drop-directory="false"
        :data="{
          direct_upload_url: '/rails/active_storage/direct_uploads',
          direct_upload: true,
        }"
        @input-file="onFileUpload"
      >
        <NextButton
          v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_ATTACH_ICON')"
          icon="i-ph-paperclip"
          slate
          ghost
          sm
        />
      </FileUpload>

      <NextButton
        v-if="!isEditorDisabled"
        v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_EMOJI_ICON')"
        icon="i-ph-smiley"
        slate
        ghost
        sm
        @click="toggleEmojiPicker"
      />

      <NextButton
        v-if="enableWhatsAppTemplates"
        v-tooltip.top-end="$t('CONVERSATION.FOOTER.WHATSAPP_TEMPLATES')"
        icon="i-ph-list-dashes"
        slate
        ghost
        sm
        @click="$emit('selectWhatsappTemplate')"
      />

      <NextButton
        v-if="enableContentTemplates"
        v-tooltip.top-end="'Content Templates'"
        icon="i-ph-list-dashes"
        slate
        ghost
        sm
        @click="$emit('selectContentTemplate')"
      />

      <NextButton
        v-if="showQuotedReplyToggle"
        v-tooltip.top-end="quotedReplyToggleTooltip"
        icon="i-ph-quotes"
        :variant="quotedReplyEnabled ? 'solid' : 'ghost'"
        color="slate"
        sm
        :aria-pressed="quotedReplyEnabled"
        @click="$emit('toggleQuotedReply')"
      />

      <NextButton
        v-if="enableInsertArticleInReply"
        v-tooltip.top-end="$t('HELP_CENTER.ARTICLE_SEARCH.OPEN_ARTICLE_SEARCH')"
        icon="i-ph-article-ny-times"
        slate
        ghost
        sm
        @click="toggleInsertArticle"
      />

      <VideoCallButton
        v-if="
          (isAWebWidgetInbox || isAPIInbox) &&
          !isOnPrivateNote &&
          !isEditorDisabled
        "
        :conversation-id="conversationId"
      />
    </div>

    <!-- RECORDING: WhatsApp patti — delete, red dot, waqt, pause, send -->
    <div v-if="isRecordingAudio" class="cs-rec">
      <NextButton
        v-tooltip.top-end="'Delete recording'"
        icon="i-ph-trash"
        ruby
        ghost
        sm
        @click="$emit('cancelAudio')"
      />
      <span
        class="cs-rec__dot"
        :class="{ 'cs-rec__dot--paused': recordingAudioState === 'recording-paused' }"
      />
      <span class="cs-rec__time">{{ recordingAudioDurationText || '0:00' }}</span>
      <span class="cs-rec__spacer" />
      <NextButton
        v-tooltip.top-end="
          recordingAudioState === 'recording-paused' ? 'Resume' : 'Pause'
        "
        :icon="
          recordingAudioState === 'recording-paused'
            ? 'i-ph-microphone'
            : 'i-ph-pause'
        "
        slate
        ghost
        sm
        @click="toggleAudioRecorderPlayPause"
      />
      <NextButton
        v-tooltip.top-end="'Send voice message'"
        icon="i-ph-paper-plane-right-fill"
        teal
        sm
        class="cs-send"
        @click="$emit('finishAudio')"
      />
    </div>

    <!-- RIGHT: mic YA send -->
    <div v-else class="cs-right">

      <!-- kuch likha nahi hai -> mic (WhatsApp) -->
      <NextButton
        v-if="showAudioRecorderButton && isSendDisabled"
        v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_AUDIORECORDER_ICON')"
        :icon="!isRecordingAudio ? 'i-ph-microphone' : 'i-ph-microphone-slash'"
        :color="isRecordingAudio ? 'ruby' : 'slate'"
        ghost
        sm
        @click="toggleAudioRecorder"
      />

      <!-- kuch likha hai -> gol hara send -->
      <NextButton
        v-if="!isSendDisabled"
        v-tooltip.top-end="sendButtonText"
        icon="i-ph-paper-plane-right-fill"
        type="submit"
        sm
        :color="isNote ? 'amber' : 'teal'"
        class="cs-send"
        @click="onSend"
      />
    </div>

    <transition name="modal-fade">
      <div
        v-show="uploadRef && uploadRef.dropActive"
        class="flex fixed top-0 right-0 bottom-0 left-0 z-20 flex-col gap-2 justify-center items-center w-full h-full text-n-slate-12 bg-modal-backdrop-light dark:bg-modal-backdrop-dark"
      >
        <fluent-icon icon="cloud-backup" size="40" />
        <h4 class="text-2xl break-words text-n-slate-12">
          {{ $t('CONVERSATION.REPLYBOX.DRAG_DROP') }}
        </h4>
      </div>
    </transition>
  </div>
</template>

<style lang="scss" scoped>
.cs-composer {
  @apply flex items-center justify-between gap-1 px-2 py-1;
}

.cs-left {
  @apply flex items-center gap-0.5;
}

.cs-right {
  @apply flex items-center gap-1;
}

.cs-rec {
  @apply flex items-center gap-2 w-full px-1;
}

.cs-rec__dot {
  @apply rounded-full flex-shrink-0;
  width: 9px;
  height: 9px;
  background: #f15c6d;
  animation: cs-blink 1.4s ease-in-out infinite;
}

.cs-rec__dot--paused {
  animation: none;
  opacity: 0.45;
}

@keyframes cs-blink {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.3;
  }
}

.cs-rec__time {
  @apply text-sm tabular-nums flex-shrink-0;
  min-width: 2.6rem;
}

.cs-rec__spacer {
  @apply flex-1;
}

.cs-send {
  @apply rounded-full;
  width: 2.25rem;
  height: 2.25rem;
  padding: 0;
  transition: transform 0.14s cubic-bezier(0.34, 1.56, 0.64, 1);

  &:active {
    transform: scale(0.92);
  }
}

:deep(.file-uploads) {
  label {
    @apply cursor-pointer;
  }

  &:hover button {
    @apply enabled:bg-n-slate-9/20;
  }
}
</style>
CS_EOF_VOICE4
echo "  ok  app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue"

mkdir -p "$(dirname app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue)"
cat > app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue << 'CS_EOF_VOICE4'
<script>
import { defineAsyncComponent, useTemplateRef } from 'vue';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useTrack } from 'dashboard/composables';
import keyboardEventListenerMixins from 'shared/mixins/keyboardEventListenerMixins';

import ReplyToMessage from './ReplyToMessage.vue';
import AttachmentPreview from 'dashboard/components/widgets/AttachmentsPreview.vue';
import ReplyTopPanel from 'dashboard/components/widgets/WootWriter/ReplyTopPanel.vue';
import ReplyEmailHead from './ReplyEmailHead.vue';
import ReplyBottomPanel from 'dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue';
import CopilotReplyBottomPanel from 'dashboard/components/widgets/WootWriter/CopilotReplyBottomPanel.vue';
import ArticleSearchPopover from 'dashboard/routes/dashboard/helpcenter/components/ArticleSearch/SearchPopover.vue';
import CopilotEditorSection from './CopilotEditorSection.vue';
import MessageSignatureMissingAlert from './MessageSignatureMissingAlert.vue';
import ReplyBoxBanner from './ReplyBoxBanner.vue';
import QuotedEmailPreview from './QuotedEmailPreview.vue';
import { REPLY_EDITOR_MODES } from 'dashboard/components/widgets/WootWriter/constants';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import AudioRecorder from 'dashboard/components/widgets/WootWriter/AudioRecorder.vue';
import { AUDIO_FORMATS } from 'shared/constants/messages';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { CMD_AI_ASSIST } from 'dashboard/helper/commandbar/events';
import {
  getMessageVariables,
  getUndefinedVariablesInMessage,
} from '@chatwoot/utils';
import WhatsappTemplates from './WhatsappTemplates/Modal.vue';
import ContentTemplates from './ContentTemplates/ContentTemplatesModal.vue';
import { MESSAGE_MAX_LENGTH } from 'shared/helpers/MessageTypeHelper';
import inboxMixin, { INBOX_FEATURES } from 'shared/mixins/inboxMixin';
import { trimContent, debounce, getRecipients } from '@chatwoot/utils';
import wootConstants from 'dashboard/constants/globals';
import {
  extractQuotedEmailText,
  buildQuotedEmailHeader,
  truncatePreviewText,
  appendQuotedTextToMessage,
} from 'dashboard/helper/quotedEmailHelper';
import {
  CONVERSATION_EVENTS,
  CAPTAIN_EVENTS,
} from '../../../helper/AnalyticsHelper/events';
import fileUploadMixin from 'dashboard/mixins/fileUploadMixin';
import {
  appendSignature,
  removeSignature,
  getEffectiveChannelType,
} from 'dashboard/helper/editorHelper';
import { useCopilotReply } from 'dashboard/composables/useCopilotReply';
import { useKbd } from 'dashboard/composables/utils/useKbd';
import { isFileTypeAllowedForChannel } from 'shared/helpers/FileHelper';

import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { LocalStorage } from 'shared/helpers/localStorage';
import { emitter } from 'shared/helpers/mitt';
const EmojiInput = defineAsyncComponent(
  () => import('shared/components/emoji/EmojiInput.vue')
);

export default {
  components: {
    ArticleSearchPopover,
    AttachmentPreview,
    AudioRecorder,
    ReplyBoxBanner,
    EmojiInput,
    MessageSignatureMissingAlert,
    ReplyBottomPanel,
    ReplyEmailHead,
    ReplyToMessage,
    ReplyTopPanel,
    ContentTemplates,
    WhatsappTemplates,
    WootMessageEditor,
    QuotedEmailPreview,
    CopilotEditorSection,
    CopilotReplyBottomPanel,
  },
  mixins: [inboxMixin, fileUploadMixin, keyboardEventListenerMixins],
  emits: ['toggleEditorSize'],
  setup() {
    const {
      uiSettings,
      isEditorHotKeyEnabled,
      fetchSignatureFlagFromUISettings,
      setQuotedReplyFlagForInbox,
      fetchQuotedReplyFlagFromUISettings,
    } = useUISettings();

    const replyEditor = useTemplateRef('replyEditor');
    const messageEditor = useTemplateRef('messageEditor');
    const copilot = useCopilotReply();
    const shortcutKey = useKbd(['$mod', '+', 'enter']);

    return {
      uiSettings,
      isEditorHotKeyEnabled,
      fetchSignatureFlagFromUISettings,
      setQuotedReplyFlagForInbox,
      fetchQuotedReplyFlagFromUISettings,
      replyEditor,
      messageEditor,
      copilot,
      shortcutKey,
    };
  },
  data() {
    return {
      message: '',
      inReplyTo: {},
      isFocused: false,
      showEmojiPicker: false,
      attachedFiles: [],
      isRecordingAudio: false,
      recordingAudioState: '',
      sendAfterRecording: false,
      recordingAudioDurationText: '',
      replyType: REPLY_EDITOR_MODES.REPLY,
      bccEmails: '',
      ccEmails: '',
      toEmails: '',
      doAutoSaveDraft: () => {},
      showWhatsAppTemplatesModal: false,
      showContentTemplatesModal: false,
      updateEditorSelectionWith: '',
      undefinedVariableMessage: '',
      showMentions: false,
      showUserMentions: false,
      showCannedMenu: false,
      showVariablesMenu: false,
      newConversationModalActive: false,
      showArticleSearchPopover: false,
      hasRecordedAudio: false,
      copilotAcceptedMessages: {},
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      messageSignature: 'getMessageSignature',
      currentUser: 'getCurrentUser',
      lastEmail: 'getLastEmailInSelectedChat',
      globalConfig: 'globalConfig/get',
    }),
    currentContact() {
      const senderId = this.currentChat?.meta?.sender?.id;
      if (!senderId) return {};
      return this.$store.getters['contacts/getContact'](senderId);
    },
    shouldShowReplyToMessage() {
      return (
        this.inReplyTo?.id &&
        !this.isPrivate &&
        this.inboxHasFeature(INBOX_FEATURES.REPLY_TO) &&
        !this.is360DialogWhatsAppChannel &&
        !this.copilot.isActive.value
      );
    },
    showWhatsappTemplates() {
      // We support templates for API channels if someone updates templates manually via API
      // That's why we don't explicitly check for channel type here
      const templates = this.$store.getters['inboxes/getWhatsAppTemplates'](
        this.inboxId
      );
      return !!(templates && templates.length) && !this.isPrivate;
    },
    showContentTemplates() {
      return this.isATwilioWhatsAppChannel && !this.isPrivate;
    },
    isPrivate() {
      if (
        this.currentChat.can_reply ||
        this.isAWhatsAppChannel ||
        this.isAPIInbox
      ) {
        return this.isOnPrivateNote;
      }
      return true;
    },
    hasMeaningfulEditorContent() {
      const body = this.message || '';
      // Only strip the signature when it's actually being auto-appended.
      // If the toggle is off, the agent's text might happen to match their
      // saved signature and we'd incorrectly treat it as empty.
      const shouldStripSignature =
        !this.isPrivate && this.sendWithSignature && !!this.messageSignature;
      if (!shouldStripSignature) return !!body.trim();
      const stripped = removeSignature(
        body,
        this.messageSignature,
        getEffectiveChannelType(this.channelType, this.inbox?.medium || '')
      );
      return !!stripped.trim();
    },
    isReplyRestricted() {
      return (
        !this.currentChat?.can_reply &&
        !(this.isAWhatsAppChannel || this.isAPIInbox)
      );
    },
    inboxId() {
      return this.currentChat.inbox_id;
    },
    inbox() {
      return this.$store.getters['inboxes/getInbox'](this.inboxId);
    },
    messagePlaceHolder() {
      if (this.isEditorDisabled) {
        if (this.isAWhatsAppChannel) {
          return this.$t('CONVERSATION.FOOTER.MESSAGING_RESTRICTED_WHATSAPP');
        }
        if (this.isAPIInbox) {
          return this.$t('CONVERSATION.FOOTER.MESSAGING_RESTRICTED_API');
        }
        return this.$t('CONVERSATION.FOOTER.MESSAGING_RESTRICTED');
      }
      return this.isPrivate
        ? this.$t('CONVERSATION.FOOTER.PRIVATE_MSG_INPUT')
        : this.$t('CONVERSATION.FOOTER.MSG_INPUT');
    },
    isMessageLengthReachingThreshold() {
      return this.message.length > this.maxLength - 50;
    },
    charactersRemaining() {
      return this.maxLength - this.message.length;
    },
    isReplyButtonDisabled() {
      if (this.isEditorDisabled) return true;
      if (this.isATwitterInbox) return true;
      if (this.hasAttachments || this.hasRecordedAudio) return false;

      return (
        this.isMessageEmpty ||
        this.message.length === 0 ||
        this.message.length > this.maxLength
      );
    },
    sender() {
      return {
        name: this.currentUser.name,
        thumbnail: this.currentUser.avatar_url,
      };
    },
    conversationType() {
      const { additional_attributes: additionalAttributes } = this.currentChat;
      const type = additionalAttributes ? additionalAttributes.type : '';
      return type || '';
    },
    maxLength() {
      if (this.isPrivate) {
        return MESSAGE_MAX_LENGTH.GENERAL;
      }
      if (this.isAFacebookInbox) {
        return MESSAGE_MAX_LENGTH.FACEBOOK;
      }
      if (this.isAnInstagramChannel) {
        return MESSAGE_MAX_LENGTH.INSTAGRAM;
      }
      if (this.isATelegramChannel) {
        return MESSAGE_MAX_LENGTH.TELEGRAM;
      }
      if (this.isATiktokChannel) {
        return MESSAGE_MAX_LENGTH.TIKTOK;
      }
      if (this.isATwilioWhatsAppChannel) {
        return MESSAGE_MAX_LENGTH.TWILIO_WHATSAPP;
      }
      if (this.isAWhatsAppCloudChannel) {
        return MESSAGE_MAX_LENGTH.WHATSAPP_CLOUD;
      }
      if (this.isASmsInbox) {
        return MESSAGE_MAX_LENGTH.TWILIO_SMS;
      }
      if (this.isAnEmailChannel) {
        return MESSAGE_MAX_LENGTH.EMAIL;
      }
      if (this.isATwilioSMSChannel) {
        return MESSAGE_MAX_LENGTH.TWILIO_SMS;
      }
      if (this.isAWhatsAppChannel) {
        return MESSAGE_MAX_LENGTH.WHATSAPP_CLOUD;
      }
      return MESSAGE_MAX_LENGTH.GENERAL;
    },
    showFileUpload() {
      const { image_send: imageSend } =
        this.currentChat?.additional_attributes?.tiktok_capabilities ?? {};
      const tiktokAttachmentSupported = imageSend ?? true;

      return (
        this.isAWebWidgetInbox ||
        this.isAFacebookInbox ||
        this.isAWhatsAppChannel ||
        this.isAPIInbox ||
        this.isAnEmailChannel ||
        this.isASmsInbox ||
        this.isATelegramChannel ||
        this.isALineChannel ||
        this.isAnInstagramChannel ||
        (this.isATiktokChannel && tiktokAttachmentSupported)
      );
    },
    replyButtonLabel() {
      let sendMessageText = this.$t('CONVERSATION.REPLYBOX.SEND');
      if (this.isPrivate) {
        sendMessageText = this.$t('CONVERSATION.REPLYBOX.CREATE');
      }
      const keyLabel = this.isEditorHotKeyEnabled('cmd_enter')
        ? `(${this.shortcutKey})`
        : '(↵)';
      return `${sendMessageText} ${keyLabel}`;
    },
    replyBoxClass() {
      return {
        'is-private': this.isPrivate,
        'is-focused': this.isFocused || this.hasAttachments,
      };
    },
    hasAttachments() {
      return this.attachedFiles.length;
    },
    showAudioRecorder() {
      return !this.isOnPrivateNote && this.showFileUpload;
    },
    showAudioRecorderEditor() {
      return this.showAudioRecorder && this.isRecordingAudio;
    },
    isOnPrivateNote() {
      return this.replyType === REPLY_EDITOR_MODES.NOTE;
    },
    isOnExpandedLayout() {
      const {
        LAYOUT_TYPES: { CONDENSED },
      } = wootConstants;
      const { conversation_display_type: conversationDisplayType = CONDENSED } =
        this.uiSettings;
      return conversationDisplayType !== CONDENSED;
    },
    isMessageEmpty() {
      if (!this.message) {
        return true;
      }
      return !this.message.trim().replace(/\n/g, '').length;
    },
    showReplyHead() {
      return !this.isOnPrivateNote && this.isAnEmailChannel;
    },
    enableMultipleFileUpload() {
      return (
        this.isAnEmailChannel ||
        this.isAWebWidgetInbox ||
        this.isAPIInbox ||
        this.isAWhatsAppChannel ||
        this.isATelegramChannel
      );
    },
    isSignatureEnabledForInbox() {
      return !this.isPrivate && this.sendWithSignature;
    },
    isSignatureAvailable() {
      return !!this.messageSignature;
    },
    sendWithSignature() {
      return this.fetchSignatureFlagFromUISettings(this.channelType);
    },
    conversationId() {
      return this.currentChat.id;
    },
    conversationIdByRoute() {
      return this.conversationId;
    },
    editorStateId() {
      return `draft-${this.conversationIdByRoute}-${this.replyType}`;
    },
    audioRecordFormat() {
      if (this.isAWhatsAppChannel) {
        return AUDIO_FORMATS.OGG;
      }
      if (this.isATelegramChannel) {
        return AUDIO_FORMATS.MP3;
      }
      if (this.isAPIInbox) {
        return AUDIO_FORMATS.MP3;
      }
      return AUDIO_FORMATS.WAV;
    },
    messageVariables() {
      const variables = getMessageVariables({
        conversation: this.currentChat,
        contact: this.currentContact,
        inbox: this.inbox,
      });
      return variables;
    },
    connectedPortalSlug() {
      const { help_center: portal = {} } = this.inbox;
      const { slug = '' } = portal;
      return slug;
    },
    quotedReplyPreference() {
      if (!this.isAnEmailChannel) {
        return false;
      }

      return !!this.fetchQuotedReplyFlagFromUISettings(this.channelType);
    },
    lastEmailWithQuotedContent() {
      if (!this.isAnEmailChannel) {
        return null;
      }

      const lastEmail = this.lastEmail;
      if (!lastEmail || lastEmail.private) {
        return null;
      }

      return lastEmail;
    },
    quotedEmailText() {
      return extractQuotedEmailText(this.lastEmailWithQuotedContent);
    },
    quotedEmailPreviewText() {
      return truncatePreviewText(this.quotedEmailText, 80);
    },
    shouldShowQuotedReplyToggle() {
      return this.isAnEmailChannel && !this.isOnPrivateNote;
    },
    shouldShowQuotedPreview() {
      return (
        this.shouldShowQuotedReplyToggle &&
        this.quotedReplyPreference &&
        !!this.quotedEmailText
      );
    },
    isDefaultEditorMode() {
      return !this.showAudioRecorderEditor && !this.copilot.isActive.value;
    },
    isEditorDisabled() {
      return (
        (this.isAWhatsAppChannel || this.isAPIInbox) &&
        !this.isOnPrivateNote &&
        !this.currentChat.can_reply
      );
    },
  },
  watch: {
    currentChat(conversation, oldConversation) {
      const { can_reply: canReply } = conversation;
      if (oldConversation && oldConversation.id !== conversation.id) {
        // Only update email fields when switching to a completely different conversation (by ID)
        // This prevents overwriting user input (e.g., CC/BCC fields) when performing actions
        // like self-assign or other updates that do not actually change the conversation context
        this.setCCAndToEmailsFromLastChat();
        // Reset Copilot editor state (includes cancelling ongoing generation)
        this.copilot.reset();
      }

      if (this.isOnPrivateNote) {
        return;
      }

      if (canReply || this.isAWhatsAppChannel || this.isAPIInbox) {
        this.replyType = REPLY_EDITOR_MODES.REPLY;
      } else {
        this.replyType = REPLY_EDITOR_MODES.NOTE;
      }

      this.fetchAndSetReplyTo();
    },
    // When moving from one conversation to another, the store may not have the
    // list of all the messages. A fetch is subsequently made to get the messages.
    // This watcher handles two main cases:
    // 1. When switching conversations and messages are fetched/updated, ensures CC/BCC fields are set from the latest OUTGOING/INCOMING email (not activity/private messages).
    // 2. Fixes and issue where CC/BCC fields could be reset/lost after assignment/activity actions or message mutations that did not represent a true email context change.
    lastEmail: {
      handler(lastEmail) {
        if (!lastEmail) return;
        this.setCCAndToEmailsFromLastChat();
      },
      deep: true,
    },
    conversationIdByRoute(conversationId, oldConversationId) {
      if (conversationId !== oldConversationId) {
        this.setToDraft(oldConversationId, this.replyType);
        this.getFromDraft();
        this.resetRecorderAndClearAttachments();
      }
    },
    message() {
      // Autosave the current message draft.
      this.doAutoSaveDraft();
    },
    replyType(updatedReplyType, oldReplyType) {
      this.setToDraft(this.conversationIdByRoute, oldReplyType);
      this.getFromDraft();
    },
  },

  mounted() {
    this.getFromDraft();
    // Don't use the keyboard listener mixin here as the events here are supposed to be
    // working even if the editor is focussed.
    document.addEventListener('paste', this.onPaste);
    document.addEventListener('keydown', this.handleKeyEvents);
    this.setCCAndToEmailsFromLastChat();
    this.doAutoSaveDraft = debounce(
      () => {
        this.saveDraft(this.conversationIdByRoute, this.replyType);
      },
      500,
      true
    );

    this.fetchAndSetReplyTo();
    emitter.on(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.onReplyToMessage);

    // A hacky fix to solve the drag and drop
    // Is showing on top of new conversation modal drag and drop
    // TODO need to find a better solution
    emitter.on(
      BUS_EVENTS.NEW_CONVERSATION_MODAL,
      this.onNewConversationModalActive
    );
    emitter.on(BUS_EVENTS.INSERT_INTO_NORMAL_EDITOR, this.addIntoEditor);
    emitter.on(CMD_AI_ASSIST, this.executeCopilotAction);
  },
  unmounted() {
    document.removeEventListener('paste', this.onPaste);
    document.removeEventListener('keydown', this.handleKeyEvents);
    emitter.off(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.onReplyToMessage);
    emitter.off(BUS_EVENTS.INSERT_INTO_NORMAL_EDITOR, this.addIntoEditor);
    emitter.off(
      BUS_EVENTS.NEW_CONVERSATION_MODAL,
      this.onNewConversationModalActive
    );
    emitter.off(CMD_AI_ASSIST, this.executeCopilotAction);
  },
  methods: {
    getDraftKey(
      conversationId = this.conversationIdByRoute,
      replyType = this.replyType
    ) {
      return `draft-${conversationId}-${replyType}`;
    },
    getCopilotAcceptedMessage(replyType = this.replyType) {
      const key = this.getDraftKey(this.conversationIdByRoute, replyType);
      return this.copilotAcceptedMessages[key] || '';
    },
    setCopilotAcceptedMessage(message, replyType = this.replyType) {
      const key = this.getDraftKey(this.conversationIdByRoute, replyType);
      this.copilotAcceptedMessages[key] = trimContent(
        message || '',
        this.maxLength
      );
    },
    clearCopilotAcceptedMessage(replyType = this.replyType) {
      const key = this.getDraftKey(this.conversationIdByRoute, replyType);
      delete this.copilotAcceptedMessages[key];
    },
    handleInsert(article) {
      const { url, title } = article;
      // Removing empty lines from the title
      const lines = title.split('\n');
      const nonEmptyLines = lines.filter(line => line.trim() !== '');
      const filteredMarkdown = nonEmptyLines.join(' ');
      emitter.emit(
        BUS_EVENTS.INSERT_INTO_RICH_EDITOR,
        `[${filteredMarkdown}](${url})`
      );

      useTrack(CONVERSATION_EVENTS.INSERT_ARTICLE_LINK);
    },
    toggleQuotedReply() {
      if (!this.isAnEmailChannel) {
        return;
      }

      const nextValue = !this.quotedReplyPreference;
      this.setQuotedReplyFlagForInbox(this.channelType, nextValue);
    },
    shouldIncludeQuotedEmail() {
      return (
        this.quotedReplyPreference &&
        this.shouldShowQuotedReplyToggle &&
        !!this.quotedEmailText
      );
    },
    getMessageWithQuotedEmailText(message) {
      if (!this.shouldIncludeQuotedEmail()) {
        return message;
      }

      const quotedText = this.quotedEmailText || '';
      const header = buildQuotedEmailHeader(
        this.lastEmailWithQuotedContent,
        this.currentContact,
        this.inbox
      );

      return appendQuotedTextToMessage(message, quotedText, header);
    },
    resetRecorderAndClearAttachments() {
      // Reset audio recorder UI state
      this.resetAudioRecorderInput();
      // Reset attached files
      this.attachedFiles = [];
    },
    saveDraft(conversationId, replyType) {
      if (this.message || this.message === '') {
        const key = this.getDraftKey(conversationId, replyType);
        const draftToSave = trimContent(this.message || '', this.maxLength);

        this.$store.dispatch('draftMessages/set', {
          key,
          message: draftToSave,
        });
      }
    },
    setToDraft(conversationId, replyType) {
      this.saveDraft(conversationId, replyType);
      this.message = '';
    },
    getFromDraft() {
      if (this.conversationIdByRoute) {
        const key = this.getDraftKey();
        const messageFromStore =
          this.$store.getters['draftMessages/get'](key) || '';

        // ensure that the message has signature set based on the ui setting
        this.message = this.toggleSignatureForDraft(messageFromStore);
      }
    },
    toggleSignatureForDraft(message) {
      if (this.isPrivate) {
        return message;
      }

      // Even when editor is disabled (e.g. WhatsApp/API can't reply), we must
      // still normalize stale signatures out of drafts when signature is off.
      if (this.isEditorDisabled && this.sendWithSignature) {
        return message;
      }

      const effectiveChannelType = getEffectiveChannelType(
        this.channelType,
        this.inbox?.medium || ''
      );

      return this.sendWithSignature
        ? appendSignature(message, this.messageSignature, effectiveChannelType)
        : removeSignature(message, this.messageSignature, effectiveChannelType);
    },
    removeFromDraft() {
      if (this.conversationIdByRoute) {
        const key = this.getDraftKey();
        this.$store.dispatch('draftMessages/delete', { key });
      }
    },
    getElementToBind() {
      return this.replyEditor;
    },
    getKeyboardEvents() {
      return {
        Escape: {
          action: () => {
            this.hideEmojiPicker();
          },
          allowOnFocusedInput: true,
        },
        '$mod+KeyK': {
          action: e => {
            e.preventDefault();
            const ninja = document.querySelector('ninja-keys');
            ninja.open();
          },
          allowOnFocusedInput: true,
        },
        Enter: {
          action: e => {
            if (this.isAValidEvent('enter')) {
              this.onSendReply();
              e.preventDefault();
            }
          },
          allowOnFocusedInput: true,
        },
        '$mod+Enter': {
          action: () => {
            if (this.copilot.isActive.value && this.isFocused) {
              this.onSubmitCopilotReply();
            } else if (this.isAValidEvent('cmd_enter')) {
              this.onSendReply();
            }
          },
          allowOnFocusedInput: true,
        },
      };
    },
    isAValidEvent(selectedKey) {
      return (
        !this.showUserMentions &&
        !this.showMentions &&
        !this.showCannedMenu &&
        !this.showVariablesMenu &&
        this.isFocused &&
        this.isEditorHotKeyEnabled(selectedKey)
      );
    },
    onPaste(e) {
      // Don't handle paste if compose new conversation modal is open
      if (this.newConversationModalActive) return;

      // Don't handle paste if editor is disabled
      if (this.isEditorDisabled) return;
      if (!this.showFileUpload && !this.isOnPrivateNote) return;

      // Filter valid files (non-zero size)
      Array.from(e.clipboardData.files)
        .filter(file => file.size > 0)
        .filter(file => {
          const isAllowed = isFileTypeAllowedForChannel(file, {
            channelType: this.channelType || this.inbox?.channel_type,
            medium: this.inbox?.medium,
            conversationType: this.conversationType,
            isInstagramChannel: this.isAnInstagramChannel,
            isOnPrivateNote: this.isOnPrivateNote,
          });

          if (!isAllowed) {
            useAlert(
              this.$t('CONVERSATION.FILE_TYPE_NOT_SUPPORTED', {
                fileName: file.name,
              })
            );
          }

          return isAllowed;
        })
        .forEach(file => {
          const { name, type, size } = file;
          this.onFileUpload({ name, type, size, file });
        });
    },
    toggleUserMention(currentMentionState) {
      this.showUserMentions = currentMentionState;
    },
    toggleCannedMenu(value) {
      this.showCannedMenu = value;
    },
    toggleVariablesMenu(value) {
      this.showVariablesMenu = value;
    },
    openWhatsappTemplateModal() {
      this.showWhatsAppTemplatesModal = true;
    },
    hideWhatsappTemplatesModal() {
      this.showWhatsAppTemplatesModal = false;
    },
    openContentTemplateModal() {
      this.showContentTemplatesModal = true;
    },
    hideContentTemplatesModal() {
      this.showContentTemplatesModal = false;
    },
    confirmOnSendReply() {
      if (this.isReplyButtonDisabled) {
        return;
      }
      if (!this.showMentions) {
        const copilotAcceptedMessage = this.getCopilotAcceptedMessage();
        const isOnWhatsApp =
          this.isATwilioWhatsAppChannel ||
          this.isAWhatsAppCloudChannel ||
          this.is360DialogWhatsAppChannel;
        // Instagram and TikTok do not support sending text and attachments in the same message.
        // For Instagram, combining them causes duplicate messages due to separate echo events per component.
        // For TikTok, the API rejects messages that mix text and media.
        // To handle both cases, text and attachments are always sent as separate messages.
        const isOnInstagram = this.isAnInstagramChannel;
        const isOnTiktok = this.isATiktokChannel;
        if ((isOnWhatsApp || isOnInstagram || isOnTiktok) && !this.isPrivate) {
          this.sendMessageAsMultipleMessages(
            this.message,
            copilotAcceptedMessage
          );
        } else {
          const messagePayload = this.getMessagePayload(this.message);
          this.sendMessage(
            messagePayload,
            this.message,
            copilotAcceptedMessage
          );
        }

        if (!this.isPrivate) {
          this.clearEmailField();
        }

        this.clearMessage();
        this.hideEmojiPicker();
      }
    },
    sendMessageAsMultipleMessages(message, copilotAcceptedMessage = '') {
      const messages = this.getMultipleMessagesPayload(message);
      messages.forEach(messagePayload => {
        this.sendMessage(
          messagePayload,
          messagePayload.message || '',
          copilotAcceptedMessage
        );
      });
    },
    sendMessageAnalyticsData(
      isPrivate,
      { editorMessage = '', copilotAcceptedMessage = '' } = {}
    ) {
      const normalizeForComparison = message => {
        let normalizedMessage = message || '';

        if (this.sendWithSignature && this.messageSignature && !isPrivate) {
          const effectiveChannelType = getEffectiveChannelType(
            this.channelType,
            this.inbox?.medium || ''
          );
          normalizedMessage = removeSignature(
            normalizedMessage,
            this.messageSignature,
            effectiveChannelType
          );
        }

        return trimContent(normalizedMessage);
      };

      const normalizedAcceptedMessage = normalizeForComparison(
        copilotAcceptedMessage
      );
      const normalizedEditorMessage = normalizeForComparison(editorMessage);

      if (normalizedAcceptedMessage && normalizedEditorMessage) {
        useTrack(CAPTAIN_EVENTS.AI_ASSISTED_MESSAGE_SENT, {
          conversationId: this.conversationIdByRoute,
          channelType: this.channelType,
          editedBeforeSend:
            normalizedAcceptedMessage !== normalizedEditorMessage,
          isPrivate,
        });
      }

      // Analytics data for message signature is enabled or not in channels
      return isPrivate
        ? useTrack(CONVERSATION_EVENTS.SENT_PRIVATE_NOTE)
        : useTrack(CONVERSATION_EVENTS.SENT_MESSAGE, {
            channelType: this.channelType,
            signatureEnabled: this.sendWithSignature,
            hasReplyTo: !!this.inReplyTo?.id,
          });
    },
    async onSendReply() {
      const undefinedVariables = getUndefinedVariablesInMessage({
        message: this.message,
        variables: this.messageVariables,
      });
      if (undefinedVariables.length > 0) {
        const undefinedVariablesCount =
          undefinedVariables.length > 1 ? undefinedVariables.length : 1;
        this.undefinedVariableMessage = this.$t(
          'CONVERSATION.REPLYBOX.UNDEFINED_VARIABLES.MESSAGE',
          {
            undefinedVariablesCount,
            undefinedVariables: undefinedVariables.join(', '),
          }
        );

        const ok = await this.$refs.confirmDialog.showConfirmation();
        if (ok) {
          this.confirmOnSendReply();
        }
      } else {
        this.confirmOnSendReply();
      }
    },
    async sendMessage(
      messagePayload,
      editorMessage = '',
      copilotAcceptedMessage = ''
    ) {
      try {
        await this.$store.dispatch(
          'createPendingMessageAndSend',
          messagePayload
        );
        emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE);
        emitter.emit(BUS_EVENTS.MESSAGE_SENT);
        this.removeFromDraft();
        this.sendMessageAnalyticsData(messagePayload.private, {
          editorMessage,
          copilotAcceptedMessage,
        });
      } catch (error) {
        const errorMessage =
          error?.response?.data?.error || this.$t('CONVERSATION.MESSAGE_ERROR');
        useAlert(errorMessage);
      }
    },
    async onSendWhatsAppReply(messagePayload) {
      this.sendMessage({
        conversationId: this.currentChat.id,
        ...messagePayload,
      });
      this.hideWhatsappTemplatesModal();
    },
    async onSendContentTemplateReply(messagePayload) {
      this.sendMessage({
        conversationId: this.currentChat.id,
        ...messagePayload,
      });
      this.hideContentTemplatesModal();
    },
    setReplyMode(mode = REPLY_EDITOR_MODES.REPLY) {
      // Clear attachments when switching between private note and reply modes
      // This is to prevent from breaking the upload rules
      if (this.attachedFiles.length > 0) this.attachedFiles = [];

      const { can_reply: canReply } = this.currentChat;
      this.$store.dispatch('draftMessages/setReplyEditorMode', {
        mode,
      });
      if (canReply || this.isAWhatsAppChannel || this.isAPIInbox)
        this.replyType = mode;
      if (this.isRecordingAudio) {
        this.toggleAudioRecorder();
      }
    },
    clearEditorSelection() {
      this.updateEditorSelectionWith = '';
    },
    addIntoEditor(content) {
      this.updateEditorSelectionWith = content;
      this.onFocus();
    },
    executeCopilotAction(action, data) {
      this.copilot.execute(action, data);
    },
    clearMessage() {
      this.message = '';
      this.clearCopilotAcceptedMessage();
      if (this.sendWithSignature && !this.isPrivate) {
        // if signature is enabled, append it to the message
        const effectiveChannelType = getEffectiveChannelType(
          this.channelType,
          this.inbox?.medium || ''
        );
        this.message = appendSignature(
          this.message,
          this.messageSignature,
          effectiveChannelType
        );
      }
      this.attachedFiles = [];
      this.isRecordingAudio = false;
      this.resetReplyToMessage();
      this.resetAudioRecorderInput();
    },
    clearEmailField() {
      this.ccEmails = '';
      this.bccEmails = '';
      this.toEmails = '';
    },

    toggleEmojiPicker() {
      this.showEmojiPicker = !this.showEmojiPicker;
    },
    toggleAudioRecorder() {
      this.isRecordingAudio = !this.isRecordingAudio;
      if (!this.isRecordingAudio) {
        this.resetAudioRecorderInput();
      }
    },
    toggleAudioRecorderPlayPause() {
      if (!this.$refs.audioRecorderInput) return;
      // WhatsApp jaisa: recording ke dauraan pause = recording rukti hai.
      // Recording khatam hone ke baad hi playback hota hai.
      if (this.recordingAudioState === 'stopped') {
        this.$refs.audioRecorderInput.playPause();
      } else {
        this.$refs.audioRecorderInput.pauseResumeRecording();
      }
    },
    cancelAudioRecording() {
      this.sendAfterRecording = false;
      if (this.$refs.audioRecorderInput) {
        this.$refs.audioRecorderInput.cancelRecording();
      }
      this.isRecordingAudio = false;
      this.recordingAudioState = '';
      this.recordingAudioDurationText = '';
      this.hasRecordedAudio = false;
      this.resetAudioRecorderInput();
    },
    finishAudioRecording() {
      // WhatsApp jaisa: send dabate hi recording ruke AUR message chala jaye.
      // Recording rukne par record-end -> onFinishRecorder chalta hai,
      // wahan flag dekh kar asal mein bheja jaata hai.
      if (!this.$refs.audioRecorderInput) return;
      this.sendAfterRecording = true;
      this.$refs.audioRecorderInput.stopRecording();
    },
    hideEmojiPicker() {
      if (this.showEmojiPicker) {
        this.toggleEmojiPicker();
      }
    },
    onTypingOn() {
      this.toggleTyping('on');
    },
    onTypingOff() {
      this.toggleTyping('off');
    },
    onBlur() {
      this.isFocused = false;
      this.saveDraft(this.conversationIdByRoute, this.replyType);
    },
    onFocus() {
      this.isFocused = true;
    },
    onRecordProgressChanged(duration) {
      this.recordingAudioDurationText = duration;
    },
    onFinishRecorder(file) {
      this.recordingAudioState = 'stopped';
      this.hasRecordedAudio = true;
      // Added a new key isVoiceMessage to the file to identify recorded audio
      // Because to filter and show only non recorded audio and other attachments
      const autoRecordedFile = {
        ...file,
        isVoiceMessage: true,
      };
      if (!file) return undefined;
      const uploaded = this.onFileUpload(autoRecordedFile);
      if (this.sendAfterRecording) {
        this.sendAfterRecording = false;
        // attachment state settle hone ke baad bhejo
        this.$nextTick(() => {
          this.isRecordingAudio = false;
          this.recordingAudioState = '';
          this.onSendReply();
        });
      }
      return uploaded;
    },
    onRecordError() {
      this.toggleAudioRecorder();
      useAlert(this.$t('CONVERSATION.REPLYBOX.AUDIO_CONVERSION_FAILED'));
    },
    toggleTyping(status) {
      const conversationId = this.currentChat.id;
      const isPrivate = this.isPrivate;

      if (!conversationId) {
        return;
      }

      this.$store.dispatch('conversationTypingStatus/toggleTyping', {
        status,
        conversationId,
        isPrivate,
      });
    },
    attachFile({ blob, file }) {
      if (!this.showFileUpload && !this.isOnPrivateNote) return;

      const reader = new FileReader();
      reader.readAsDataURL(file.file);
      reader.onloadend = () => {
        this.attachedFiles.push({
          currentChatId: this.currentChat.id,
          resource: blob || file,
          isPrivate: this.isPrivate,
          thumb: reader.result,
          blobSignedId: blob ? blob.signed_id : undefined,
          isVoiceMessage: file?.isVoiceMessage || false,
        });
      };
    },
    removeAttachment(attachments) {
      this.attachedFiles = attachments;
    },
    setReplyToInPayload(payload) {
      if (this.inReplyTo?.id) {
        return {
          ...payload,
          contentAttributes: {
            ...payload.contentAttributes,
            in_reply_to: this.inReplyTo.id,
          },
        };
      }

      return payload;
    },
    getMultipleMessagesPayload(message) {
      const multipleMessagePayload = [];

      if (this.attachedFiles && this.attachedFiles.length) {
        let caption =
          this.isAnInstagramChannel || this.isATiktokChannel ? '' : message;
        this.attachedFiles.forEach(attachment => {
          const attachedFile = this.globalConfig.directUploadsEnabled
            ? attachment.blobSignedId
            : attachment.resource.file;
          let attachmentPayload = {
            conversationId: this.currentChat.id,
            files: [attachedFile],
            private: false,
            message: caption,
            sender: this.sender,
            isVoiceMessage: attachment.isVoiceMessage || false,
          };

          attachmentPayload = this.setReplyToInPayload(attachmentPayload);
          multipleMessagePayload.push(attachmentPayload);
          // For WhatsApp, only the first attachment gets a caption
          if (!this.isAnInstagramChannel) caption = '';
        });
      }

      const hasNoAttachments =
        !this.attachedFiles || !this.attachedFiles.length;
      // For Instagram and TikTok, text must always be sent as a separate message (no captions on attachments).
      // For WhatsApp, we only need a text message if there are no attachments.
      if (
        ((this.isAnInstagramChannel || this.isATiktokChannel) &&
          this.message) ||
        (!(this.isAnInstagramChannel || this.isATiktokChannel) &&
          hasNoAttachments)
      ) {
        let messagePayload = {
          conversationId: this.currentChat.id,
          message,
          private: false,
          sender: this.sender,
        };

        messagePayload = this.setReplyToInPayload(messagePayload);

        multipleMessagePayload.push(messagePayload);
      }

      return multipleMessagePayload;
    },
    getMessagePayload(message) {
      const messageWithQuote = this.getMessageWithQuotedEmailText(message);

      let messagePayload = {
        conversationId: this.currentChat.id,
        message: messageWithQuote,
        private: this.isPrivate,
        sender: this.sender,
      };
      messagePayload = this.setReplyToInPayload(messagePayload);

      if (this.attachedFiles && this.attachedFiles.length) {
        messagePayload.files = [];
        this.attachedFiles.forEach(attachment => {
          if (this.globalConfig.directUploadsEnabled) {
            messagePayload.files.push(attachment.blobSignedId);
            if (attachment.isVoiceMessage) {
              messagePayload.isVoiceMessage = true;
            }
          } else {
            messagePayload.files.push(attachment.resource.file);
          }
        });
      }

      if (this.ccEmails && !this.isOnPrivateNote) {
        messagePayload.ccEmails = this.ccEmails;
      }

      if (this.bccEmails && !this.isOnPrivateNote) {
        messagePayload.bccEmails = this.bccEmails;
      }

      if (this.toEmails && !this.isOnPrivateNote) {
        messagePayload.toEmails = this.toEmails;
      }
      return messagePayload;
    },
    setCcEmails(value) {
      this.bccEmails = value.bccEmails;
      this.ccEmails = value.ccEmails;
    },
    setCCAndToEmailsFromLastChat() {
      const conversationContact = this.currentChat?.meta?.sender?.email || '';
      const { email: inboxEmail, forward_to_email: forwardToEmail } =
        this.inbox;

      const { cc, bcc, to } = getRecipients(
        this.lastEmail,
        conversationContact,
        inboxEmail,
        forwardToEmail
      );

      this.toEmails = to.join(', ');
      this.ccEmails = cc.join(', ');
      this.bccEmails = bcc.join(', ');
    },
    fetchAndSetReplyTo() {
      const replyStorageKey = LOCAL_STORAGE_KEYS.MESSAGE_REPLY_TO;
      const replyToMessageId = LocalStorage.getFromJsonStore(
        replyStorageKey,
        this.conversationId
      );

      this.inReplyTo = this.currentChat?.messages?.find(message => {
        if (message.id === replyToMessageId) {
          return true;
        }
        return false;
      });
    },
    onReplyToMessage() {
      this.fetchAndSetReplyTo();
      if (this.inReplyTo) {
        this.$nextTick(() => {
          const pos = this.isSignatureEnabledForInbox ? 'start' : 'end';
          this.messageEditor?.focusEditorInputField(pos);
        });
      }
    },
    resetReplyToMessage() {
      const replyStorageKey = LOCAL_STORAGE_KEYS.MESSAGE_REPLY_TO;
      LocalStorage.deleteFromJsonStore(replyStorageKey, this.conversationId);
      emitter.emit(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE);
    },
    onNewConversationModalActive(isActive) {
      // Issue is if the new conversation modal is open and we drag and drop the file
      // then the file is not getting attached to the new conversation modal
      // and it is getting attached to the current conversation reply box
      // so to fix this we are removing the drag and drop event listener from the current conversation reply box
      // When new conversation modal is open
      this.newConversationModalActive = isActive;
    },
    onSearchPopoverClose() {
      this.showArticleSearchPopover = false;
    },
    toggleInsertArticle() {
      this.showArticleSearchPopover = !this.showArticleSearchPopover;
    },
    resetAudioRecorderInput() {
      this.recordingAudioDurationText = '00:00';
      this.isRecordingAudio = false;
      this.recordingAudioState = '';
      this.hasRecordedAudio = false;
      // Only clear the recorded audio when we click toggle button.
      this.attachedFiles = this.attachedFiles.filter(
        file => !file?.isVoiceMessage
      );
    },
    toggleEditorSize() {
      this.$emit('toggleEditorSize');
      this.$nextTick(() => this.messageEditor?.focusEditorInputField());
    },
    onSubmitCopilotReply() {
      const acceptedMessage = this.copilot.accept();
      this.message = acceptedMessage;
      this.setCopilotAcceptedMessage(acceptedMessage);
    },
  },
};
</script>

<template>
  <ReplyBoxBanner :message="message" :is-on-private-note="isOnPrivateNote" />
  <div ref="replyEditor" class="reply-box" :class="replyBoxClass">
    <ReplyTopPanel
      :mode="replyType"
      :conversation-id="conversationId"
      :is-reply-restricted="isReplyRestricted"
      :disabled="
        (copilot.isActive.value && copilot.isButtonDisabled.value) ||
        showAudioRecorderEditor
      "
      :is-editor-disabled="isEditorDisabled"
      :is-message-length-reaching-threshold="isMessageLengthReachingThreshold"
      :characters-remaining="charactersRemaining"
      :editor-content="message"
      :has-content="hasMeaningfulEditorContent"
      @set-reply-mode="setReplyMode"
      @toggle-editor-size="toggleEditorSize"
      @toggle-copilot="copilot.toggleEditor"
      @execute-copilot-action="executeCopilotAction"
    />
    <ArticleSearchPopover
      v-if="showArticleSearchPopover && connectedPortalSlug"
      :selected-portal-slug="connectedPortalSlug"
      @insert="handleInsert"
      @close="onSearchPopoverClose"
    />
    <Transition
      mode="out-in"
      enter-active-class="transition-all duration-300 ease-out"
      enter-from-class="opacity-0 translate-y-2 scale-[0.98]"
      enter-to-class="opacity-100 translate-y-0 scale-100"
      leave-active-class="transition-all duration-200 ease-in"
      leave-from-class="opacity-100 translate-y-0 scale-100"
      leave-to-class="opacity-0 translate-y-2 scale-[0.98]"
    >
      <div :key="copilot.editorTransitionKey.value" class="reply-box__top">
        <ReplyToMessage
          v-if="shouldShowReplyToMessage"
          :message="inReplyTo"
          @dismiss="resetReplyToMessage"
        />
        <EmojiInput
          v-if="showEmojiPicker"
          v-on-clickaway="hideEmojiPicker"
          :class="{
            'emoji-dialog--expanded': isOnExpandedLayout,
          }"
          :on-click="addIntoEditor"
        />
        <ReplyEmailHead
          v-if="showReplyHead && isDefaultEditorMode"
          v-model:cc-emails="ccEmails"
          v-model:bcc-emails="bccEmails"
          v-model:to-emails="toEmails"
        />
        <AudioRecorder
          v-if="showAudioRecorderEditor"
          ref="audioRecorderInput"
          :audio-record-format="audioRecordFormat"
          @recorder-progress-changed="onRecordProgressChanged"
          @finish-record="onFinishRecorder"
          @record-error="onRecordError"
          @play="recordingAudioState = 'playing'"
          @pause="recordingAudioState = 'paused'"
          @record-pause="recordingAudioState = 'recording-paused'"
          @record-resume="recordingAudioState = ''"
          @record-cancel="isRecordingAudio = false"
        />
        <CopilotEditorSection
          v-if="copilot.isActive.value && !showAudioRecorderEditor"
          :show-copilot-editor="copilot.showEditor.value"
          :is-generating-content="copilot.isGenerating.value"
          :generated-content="copilot.generatedContent.value"
          :placeholder="$t('CONVERSATION.FOOTER.COPILOT_MSG_INPUT')"
          @focus="onFocus"
          @blur="onBlur"
          @clear-selection="clearEditorSelection"
          @close="copilot.showEditor.value = false"
          @content-ready="copilot.setContentReady"
          @send="copilot.sendFollowUp"
        />
        <WootMessageEditor
          v-else-if="!showAudioRecorderEditor"
          ref="messageEditor"
          v-model="message"
          :conversation-id="conversationId"
          :editor-id="editorStateId"
          class="input popover-prosemirror-menu"
          :is-private="isOnPrivateNote"
          :placeholder="messagePlaceHolder"
          :update-selection-with="updateEditorSelectionWith"
          :min-height="4"
          :disabled="isEditorDisabled"
          enable-variables
          :variables="messageVariables"
          :signature="messageSignature"
          allow-signature
          :channel-type="channelType"
          :medium="inbox.medium"
          @typing-off="onTypingOff"
          @typing-on="onTypingOn"
          @focus="onFocus"
          @blur="onBlur"
          @toggle-user-mention="toggleUserMention"
          @toggle-canned-menu="toggleCannedMenu"
          @toggle-variables-menu="toggleVariablesMenu"
          @clear-selection="clearEditorSelection"
          @execute-copilot-action="executeCopilotAction"
        />

        <QuotedEmailPreview
          v-if="shouldShowQuotedPreview && isDefaultEditorMode"
          :quoted-email-text="quotedEmailText"
          :preview-text="quotedEmailPreviewText"
          class="mb-2"
          @toggle="toggleQuotedReply"
        />

        <div
          v-if="hasAttachments && isDefaultEditorMode"
          class="bg-transparent py-0 mb-2"
          @paste="onPaste"
        >
          <AttachmentPreview
            class="mt-2"
            :attachments="attachedFiles"
            @remove-attachment="removeAttachment"
          />
        </div>
        <MessageSignatureMissingAlert
          v-if="
            isSignatureEnabledForInbox &&
            !isSignatureAvailable &&
            isDefaultEditorMode
          "
          class="mb-2"
        />
      </div>
    </Transition>

    <Transition
      mode="out-in"
      enter-active-class="transition-all duration-300 ease-out"
      enter-from-class="opacity-0 translate-y-2 scale-[0.98]"
      enter-to-class="opacity-100 translate-y-0 scale-100"
      leave-active-class="transition-all duration-200 ease-in"
      leave-from-class="opacity-100 translate-y-0 scale-100"
      leave-to-class="opacity-0 translate-y-2 scale-[0.98]"
    >
      <CopilotReplyBottomPanel
        v-if="copilot.isActive.value"
        key="copilot-bottom-panel"
        :is-generating-content="copilot.isButtonDisabled.value"
        @submit="onSubmitCopilotReply"
        @cancel="copilot.reset"
      />
      <ReplyBottomPanel
        v-else
        key="reply-bottom-panel"
        :conversation-id="conversationId"
        :enable-multiple-file-upload="enableMultipleFileUpload"
        :enable-whats-app-templates="showWhatsappTemplates"
        :enable-content-templates="showContentTemplates"
        :inbox="inbox"
        :is-on-private-note="isOnPrivateNote"
        :is-recording-audio="isRecordingAudio"
        @cancel-audio="cancelAudioRecording"
        @finish-audio="finishAudioRecording"
        :is-send-disabled="isReplyButtonDisabled"
        :is-note="isPrivate"
        :is-editor-disabled="isEditorDisabled"
        :on-file-upload="onFileUpload"
        :on-send="onSendReply"
        :conversation-type="conversationType"
        :recording-audio-duration-text="recordingAudioDurationText"
        :recording-audio-state="recordingAudioState"
        :send-button-text="replyButtonLabel"
        :show-audio-recorder="showAudioRecorder"
        :show-emoji-picker="showEmojiPicker"
        :show-file-upload="showFileUpload"
        :show-quoted-reply-toggle="shouldShowQuotedReplyToggle"
        :quoted-reply-enabled="quotedReplyPreference"
        :toggle-audio-recorder-play-pause="toggleAudioRecorderPlayPause"
        :toggle-audio-recorder="toggleAudioRecorder"
        :toggle-emoji-picker="toggleEmojiPicker"
        :message="message"
        :portal-slug="connectedPortalSlug"
        :new-conversation-modal-active="newConversationModalActive"
        @select-whatsapp-template="openWhatsappTemplateModal"
        @select-content-template="openContentTemplateModal"
        @toggle-insert-article="toggleInsertArticle"
        @toggle-quoted-reply="toggleQuotedReply"
      />
    </Transition>

    <WhatsappTemplates
      :inbox-id="inbox.id"
      :show="showWhatsAppTemplatesModal"
      @close="hideWhatsappTemplatesModal"
      @on-send="onSendWhatsAppReply"
      @cancel="hideWhatsappTemplatesModal"
    />

    <ContentTemplates
      :inbox-id="inbox.id"
      :show="showContentTemplatesModal"
      @close="hideContentTemplatesModal"
      @on-send="onSendContentTemplateReply"
      @cancel="hideContentTemplatesModal"
    />

    <woot-confirm-modal
      ref="confirmDialog"
      :title="$t('CONVERSATION.REPLYBOX.UNDEFINED_VARIABLES.TITLE')"
      :description="undefinedVariableMessage"
    />
  </div>
</template>

<style lang="scss" scoped>
.send-button {
  @apply mb-0;
}

.reply-box {
  @apply relative mb-2 mx-2 border border-n-weak rounded-xl bg-n-solid-1;

  &.is-private {
    @apply bg-n-solid-amber dark:border-n-amber-3/10 border-n-amber-12/5;
  }
}

.send-button {
  @apply mb-0;
}

.reply-box__top {
  @apply relative py-0 px-3 -mt-px;
}

.emoji-dialog {
  @apply top-[unset] -bottom-10 ltr:-left-80 ltr:right-[unset] rtl:left-[unset] rtl:-right-80;

  &::before {
    filter: drop-shadow(0px 4px 4px rgba(0, 0, 0, 0.08));
    @apply ltr:-right-4 bottom-2 rtl:-left-4 ltr:rotate-[270deg] rtl:rotate-[90deg];
  }
}

.emoji-dialog--expanded {
  @apply left-[unset] bottom-0 absolute z-[100];

  &::before {
    transform: rotate(0deg);
    @apply ltr:left-1 rtl:right-1 -bottom-2;
  }
}
</style>
CS_EOF_VOICE4
echo "  ok  app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue"

mkdir -p "$(dirname app/javascript/dashboard/components-next/message/bubbles/Audio.vue)"
cat > app/javascript/dashboard/components-next/message/bubbles/Audio.vue << 'CS_EOF_VOICE4'
<script setup>
import { computed } from 'vue';
import BaseBubble from './Base.vue';
import AudioChip from 'next/message/chips/Audio.vue';
import { useMessageContext } from '../provider.js';

const { attachments } = useMessageContext();

const attachment = computed(() => {
  return attachments.value[0];
});
</script>

<template>
  <BaseBubble data-bubble-name="audio">
    <AudioChip
      :attachment="attachment"
      class="text-n-slate-12 skip-context-menu"
    />
  </BaseBubble>
</template>
CS_EOF_VOICE4
echo "  ok  app/javascript/dashboard/components-next/message/bubbles/Audio.vue"

mkdir -p "$(dirname app/javascript/dashboard/components-next/message/chips/Audio.vue)"
cat > app/javascript/dashboard/components-next/message/chips/Audio.vue << 'CS_EOF_VOICE4'
<script setup>
import {
  computed,
  onMounted,
  useTemplateRef,
  ref,
  getCurrentInstance,
} from 'vue';
import Icon from 'next/icon/Icon.vue';
import { timeStampAppendedURL } from 'dashboard/helper/URLHelper';
import { downloadFile } from '@chatwoot/utils';
import { useEmitter } from 'dashboard/composables/emitter';
import { emitter } from 'shared/helpers/mitt';

const { attachment } = defineProps({
  attachment: {
    type: Object,
    required: true,
  },
  showTranscribedText: {
    type: Boolean,
    default: true,
  },
});

defineOptions({
  inheritAttrs: false,
});

const timeStampURL = computed(() => {
  return timeStampAppendedURL(attachment.dataUrl);
});

const TRANSCRIPT_PREVIEW_LENGTH = 200;
const isTranscriptExpanded = ref(false);
const isTranscriptLong = computed(
  () => (attachment.transcribedText?.length || 0) > TRANSCRIPT_PREVIEW_LENGTH
);
const displayedTranscript = computed(() => {
  const text = attachment.transcribedText || '';
  if (!isTranscriptLong.value || isTranscriptExpanded.value) return text;
  return `${text.slice(0, TRANSCRIPT_PREVIEW_LENGTH).trimEnd()}…`;
});

const audioPlayer = useTemplateRef('audioPlayer');

const isPlaying = ref(false);
const isMuted = ref(false);
const currentTime = ref(0);
const duration = ref(0);
const playbackSpeed = ref(1);

const { uid } = getCurrentInstance();

// MediaRecorder-produced WebM/Opus blobs lack a Duration header → <audio>.duration
// resolves to Infinity until we seek past the end, which forces the engine to
// scan the file and compute the real length. Safe no-op for files with a real
// duration already (mp3/m4a/etc).
const resolveStreamingDuration = () => {
  const el = audioPlayer.value;
  if (!el) return;
  const onTimeUpdate = () => {
    el.removeEventListener('timeupdate', onTimeUpdate);
    el.currentTime = 0;
    duration.value = el.duration;
  };
  el.addEventListener('timeupdate', onTimeUpdate);
  try {
    el.currentTime = Number.MAX_SAFE_INTEGER;
  } catch {
    el.removeEventListener('timeupdate', onTimeUpdate);
  }
};

const onLoadedMetadata = () => {
  const d = audioPlayer.value?.duration;
  if (!Number.isFinite(d)) {
    resolveStreamingDuration();
    return;
  }
  duration.value = d;
};

const playbackSpeedLabel = computed(() => {
  return `${playbackSpeed.value}x`;
});

// There maybe a chance that the audioPlayer ref is not available
// When the onLoadMetadata is called, so we need to set the duration
// value when the component is mounted
onMounted(() => {
  const d = audioPlayer.value?.duration;
  if (Number.isFinite(d)) duration.value = d;
  audioPlayer.value.playbackRate = playbackSpeed.value;
});

// Listen for global audio play events and pause if it's not this audio
useEmitter('pause_playing_audio', currentPlayingId => {
  if (currentPlayingId !== uid && isPlaying.value) {
    try {
      audioPlayer.value.pause();
    } catch {
      /* ignore pause errors */
    }
    isPlaying.value = false;
  }
});

const formatTime = time => {
  if (!time || Number.isNaN(time)) return '00:00';
  const minutes = Math.floor(time / 60);
  const seconds = Math.floor(time % 60);
  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
};

const toggleMute = () => {
  audioPlayer.value.muted = !audioPlayer.value.muted;
  isMuted.value = audioPlayer.value.muted;
};

const onTimeUpdate = () => {
  currentTime.value = audioPlayer.value?.currentTime;
};

const seek = event => {
  const time = Number(event.target.value);
  audioPlayer.value.currentTime = time;
  currentTime.value = time;
};

const playOrPause = () => {
  if (isPlaying.value) {
    audioPlayer.value.pause();
    isPlaying.value = false;
  } else {
    // Emit event to pause all other audio
    emitter.emit('pause_playing_audio', uid);
    audioPlayer.value.play();
    isPlaying.value = true;
  }
};

const onEnd = () => {
  isPlaying.value = false;
  currentTime.value = 0;
  playbackSpeed.value = 1;
  audioPlayer.value.playbackRate = 1;
};

const changePlaybackSpeed = () => {
  const speeds = [1, 1.5, 2];
  const currentIndex = speeds.indexOf(playbackSpeed.value);
  const nextIndex = (currentIndex + 1) % speeds.length;
  playbackSpeed.value = speeds[nextIndex];
  audioPlayer.value.playbackRate = playbackSpeed.value;
};

// WhatsApp jaisi waveform: file ke naam se seed, taake har baar wahi shakl bane
const waveBars = computed(() => {
  const seedStr = String(attachment.dataUrl || attachment.id || 'a');
  let seed = 0;
  for (let i = 0; i < seedStr.length; i += 1) {
    seed = (seed * 31 + seedStr.charCodeAt(i)) % 100000;
  }
  const bars = [];
  for (let i = 0; i < 34; i += 1) {
    seed = (seed * 1103515245 + 12345) % 2147483648;
    bars.push(18 + ((seed >> 8) % 82));
  }
  return bars;
});

const progressPct = computed(() => {
  if (!duration.value) return 0;
  return Math.min(100, (currentTime.value / duration.value) * 100);
});

const remainingLabel = computed(() =>
  formatTime(currentTime.value > 0 ? currentTime.value : duration.value)
);

const seekToBar = index => {
  if (!duration.value) return;
  const t = (index / 34) * duration.value;
  audioPlayer.value.currentTime = t;
  currentTime.value = t;
};

const downloadAudio = async () => {
  const { fileType, dataUrl, extension } = attachment;
  downloadFile({ url: dataUrl, type: fileType, extension });
};
</script>

<template>
  <audio
    ref="audioPlayer"
    controls
    class="hidden"
    playsinline
    @loadedmetadata="onLoadedMetadata"
    @timeupdate="onTimeUpdate"
    @ended="onEnd"
  >
    <source :src="timeStampURL" />
  </audio>
  <div v-bind="$attrs" class="cs-voice">
    <div class="cs-voice__row">
      <button class="cs-voice__play" @click="playOrPause">
        <Icon
          v-if="isPlaying"
          class="size-5"
          icon="i-teenyicons-pause-small-solid"
        />
        <Icon v-else class="size-5" icon="i-teenyicons-play-small-solid" />
      </button>

      <div class="cs-voice__wave" @click.stop>
        <span
          v-for="(h, i) in waveBars"
          :key="i"
          class="cs-voice__bar"
          :class="{ 'cs-voice__bar--on': (i / 34) * 100 <= progressPct }"
          :style="{ height: h + '%' }"
          @click="seekToBar(i)"
        />
      </div>

      <button
        class="cs-voice__speed"
        :class="{ 'cs-voice__speed--on': playbackSpeed !== 1 }"
        @click="changePlaybackSpeed"
      >
        {{ playbackSpeedLabel }}
      </button>
    </div>

    <div class="cs-voice__meta">
      <span class="cs-voice__time">{{ remainingLabel }}</span>
      <button class="cs-voice__dl" @click="downloadAudio">
        <Icon class="size-3.5" icon="i-lucide-download" />
      </button>
    </div>

    <div
      v-if="attachment.transcribedText && showTranscribedText"
      class="text-n-slate-12 p-3 text-sm bg-n-alpha-1 rounded-lg w-full break-words"
    >
      {{ displayedTranscript }}
      <button
        v-if="isTranscriptLong"
        class="block mt-1 p-0 border-0 bg-transparent text-n-slate-11 hover:text-n-slate-12 font-medium"
        @click="isTranscriptExpanded = !isTranscriptExpanded"
      >
        {{
          isTranscriptExpanded
            ? $t('CONVERSATION.VOICE_CALL.TRANSCRIPT_SHOW_LESS')
            : $t('CONVERSATION.VOICE_CALL.TRANSCRIPT_SHOW_MORE')
        }}
      </button>
    </div>
  </div>
</template>

<style scoped>
/* WhatsApp jaisa voice player — bubble ke andar */
.cs-voice {
  width: 100%;
  max-width: 100%;
  min-width: 0;
}

.cs-voice__row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.cs-voice__play {
  border: 0;
  padding: 0;
  width: 2rem;
  height: 2rem;
  flex-shrink: 0;
  display: grid;
  place-items: center;
  background: transparent;
  cursor: pointer;
  opacity: 0.85;
}

.cs-voice__play:hover {
  opacity: 1;
}

.cs-voice__wave {
  flex: 1 1 0;
  min-width: 3rem;
  height: 1.75rem;
  display: flex;
  align-items: center;
  gap: 2px;
  cursor: pointer;
}

.cs-voice__bar {
  flex: 1;
  min-width: 2px;
  border-radius: 999px;
  background: currentColor;
  opacity: 0.32;
  transition: opacity 0.12s ease;
}

.cs-voice__bar--on {
  opacity: 0.85;
}

.cs-voice__speed {
  border: 0;
  background: transparent;
  font-size: 0.6875rem;
  font-weight: 600;
  opacity: 0.5;
  cursor: pointer;
  padding: 0 0.15rem;
  flex-shrink: 0;
}

.cs-voice__speed--on {
  opacity: 0.9;
}

.cs-voice__meta {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-top: 0.125rem;
  padding-left: 2.5rem;
}

.cs-voice__time {
  font-size: 0.6875rem;
  opacity: 0.6;
  font-variant-numeric: tabular-nums;
}

.cs-voice__dl {
  border: 0;
  background: transparent;
  cursor: pointer;
  opacity: 0.45;
  padding: 0;
  display: grid;
  place-items: center;
}

.cs-voice__dl:hover {
  opacity: 0.85;
}
</style>
CS_EOF_VOICE4
echo "  ok  app/javascript/dashboard/components-next/message/chips/Audio.vue"


echo ""
echo "=== 2/3  Build ==="
docker build -f docker/Dockerfile -t chatssync-staging:latest .
echo ""
echo "=== 3/3  Restart ==="
cd "$COMPOSE"
docker compose up -d
echo ""
echo "============================================"
echo "  HO GAYA — Ctrl+Shift+R"
echo "  mic -> bolo -> send  => voice turant jaani chahiye"
echo "============================================"
