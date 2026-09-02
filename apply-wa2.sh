#!/usr/bin/env bash
# apply-wa2.sh — patch 2: doodle, day chip, bubble nok, composer, canary
set -euo pipefail
cd /root/staging-build
SCSS=app/javascript/dashboard/assets/scss/app.scss
BK=/root/backups; S=$(date +%F-%H%M%S)
[ -f "$SCSS" ] || { echo "!! app.scss nahi mili"; exit 1; }
mkdir -p "$BK"; cp "$SCSS" "$BK/app.scss.$S.bak"
echo ">> backup: $BK/app.scss.$S.bak"

cat > /tmp/cs_wa2.css <<'CSEOF'
/* CS-WA2-START */

/* ===== CANARY: agar list ke upar HARI PATTI dikhe to CSS lag rahi hai ===== */
.conversations-list-wrap::before,
.conversations-list::before {
  content: '';
  display: block;
  height: 4px;
  background: #00A884;
}

/* ===== 1. THREAD: doodle saaf nazar aaye ===== */
.conversation-panel {
  background-color: var(--cs-chat, #0B141A) !important;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='352' height='232' viewBox='0 0 352 232'%3E%3Cg fill='none' stroke='%23fff' stroke-width='1.25' stroke-linecap='round' stroke-linejoin='round'%3E%3Cg transform='translate(18,20)'%3E%3Cpath d='M0 6a6 6 0 0 1 12 0 6 6 0 0 1-6 6H2l2-3a6 6 0 0 1-4-3z'/%3E%3C/g%3E%3Cg transform='translate(62,14)'%3E%3Cpath d='M0 0h14v10H4L0 13z'/%3E%3C/g%3E%3Cg transform='translate(108,22)'%3E%3Cpath d='M6 0l1.8 3.7 4 .6-2.9 2.8.7 4L6 9.2 2.4 11l.7-4L.2 4.3l4-.6z'/%3E%3C/g%3E%3Cg transform='translate(150,16)'%3E%3Cpath d='M2 2h12v12H2z M2 6h12'/%3E%3C/g%3E%3Cg transform='translate(192,20)'%3E%3Cpath d='M7 0C3 0 0 3 0 6.5 0 11 7 16 7 16s7-5 7-9.5C14 3 11 0 7 0z M7 4a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5z'/%3E%3C/g%3E%3Cg transform='translate(234,14)'%3E%3Cpath d='M0 8c0-4 3-7 7-7s7 3 7 7-3 7-7 7-7-3-7-7z M4 8h6 M7 5v6'/%3E%3C/g%3E%3Cg transform='translate(276,20)'%3E%3Cpath d='M0 3h16v10H0z M0 3l8 6 8-6'/%3E%3C/g%3E%3Cg transform='translate(318,16)'%3E%3Cpath d='M3 0h10v4H3z M1 4h14v11H1z M6 8h4'/%3E%3C/g%3E%3Cg transform='translate(14,64)'%3E%3Cpath d='M0 10c3-5 9-5 12 0 M6 4a2.5 2.5 0 1 1 0 .01'/%3E%3C/g%3E%3Cg transform='translate(56,58)'%3E%3Cpath d='M0 0h13M0 5h9M0 10h11'/%3E%3C/g%3E%3Cg transform='translate(98,62)'%3E%3Cpath d='M8 0a8 8 0 1 1 0 16A8 8 0 0 1 8 0z M8 4v4.5l3 2'/%3E%3C/g%3E%3Cg transform='translate(140,60)'%3E%3Cpath d='M0 0l11 6-11 6z'/%3E%3C/g%3E%3Cg transform='translate(182,58)'%3E%3Cpath d='M2 0h11l3 4v11H2z M13 0v4h3'/%3E%3C/g%3E%3Cg transform='translate(224,62)'%3E%3Cpath d='M0 6h4l4-5v14l-4-5H0z M11 4a4 4 0 0 1 0 8'/%3E%3C/g%3E%3Cg transform='translate(266,58)'%3E%3Cpath d='M1 1h14v10H1z M1 11l5-4 3 2 3-3 3 3'/%3E%3C/g%3E%3Cg transform='translate(308,64)'%3E%3Cpath d='M6 0a6 6 0 0 1 6 6c0 4-6 10-6 10S0 10 0 6a6 6 0 0 1 6-6z'/%3E%3C/g%3E%3Cg transform='translate(20,106)'%3E%3Cpath d='M0 4h5l3-4h4l3 4h1v10H0z M8 6a3 3 0 1 1 0 6 3 3 0 0 1 0-6z'/%3E%3C/g%3E%3Cg transform='translate(62,110)'%3E%3Cpath d='M6 0l6 12H0z'/%3E%3C/g%3E%3Cg transform='translate(104,104)'%3E%3Cpath d='M0 0h12v12H0z M3 3h6v6H3z'/%3E%3C/g%3E%3Cg transform='translate(146,108)'%3E%3Cpath d='M0 6a6 6 0 1 0 12 0 6 6 0 0 0-12 0z M3 6l2 2 4-4'/%3E%3C/g%3E%3Cg transform='translate(188,104)'%3E%3Cpath d='M1 3h14v9H1z M4 3V1h8v2 M4 12v2h8v-2'/%3E%3C/g%3E%3Cg transform='translate(230,110)'%3E%3Cpath d='M0 12L6 0l6 12z M4 12v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(272,106)'%3E%3Cpath d='M2 2l10 10M12 2L2 12'/%3E%3C/g%3E%3Cg transform='translate(314,110)'%3E%3Cpath d='M0 8h16 M4 4l-4 4 4 4 M12 4l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(16,150)'%3E%3Cpath d='M0 2h14v12H0z M3 0v4M11 0v4M0 6h14'/%3E%3C/g%3E%3Cg transform='translate(58,154)'%3E%3Cpath d='M7 0a7 7 0 1 1 0 14A7 7 0 0 1 7 0z M4 7h6'/%3E%3C/g%3E%3Cg transform='translate(100,148)'%3E%3Cpath d='M0 10c0-6 5-10 8-10s8 4 8 10'/%3E%3C/g%3E%3Cg transform='translate(142,152)'%3E%3Cpath d='M2 0h10v14l-5-4-5 4z'/%3E%3C/g%3E%3Cg transform='translate(184,150)'%3E%3Cpath d='M0 0h14v3H0z M2 3v10h10V3 M6 6v4M8 6v4'/%3E%3C/g%3E%3Cg transform='translate(226,154)'%3E%3Cpath d='M8 0l2 5 5 .5-4 3.5 1 5-4-2.6L4 14l1-5L1 5.5 6 5z'/%3E%3C/g%3E%3Cg transform='translate(268,148)'%3E%3Cpath d='M1 1h13v13H1z M4 7h7M7 4v7'/%3E%3C/g%3E%3Cg transform='translate(310,152)'%3E%3Cpath d='M0 5a5 5 0 0 1 10 0v6H0z M3 11v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(22,196)'%3E%3Cpath d='M0 3h16v9H0z M5 12v2h6v-2 M2 16h12'/%3E%3C/g%3E%3Cg transform='translate(64,198)'%3E%3Cpath d='M6 0a6 6 0 1 1 0 12A6 6 0 0 1 6 0z M6 3v3l2 2'/%3E%3C/g%3E%3Cg transform='translate(106,194)'%3E%3Cpath d='M0 6h12 M8 2l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(148,198)'%3E%3Cpath d='M2 0h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V2a2 2 0 0 1 2-2z M4 3h4M4 6h4M4 9h2'/%3E%3C/g%3E%3Cg transform='translate(190,194)'%3E%3Cpath d='M0 0h14M0 5h14M0 10h8'/%3E%3C/g%3E%3Cg transform='translate(232,198)'%3E%3Cpath d='M7 0l7 7-7 7-7-7z'/%3E%3C/g%3E%3Cg transform='translate(274,194)'%3E%3Cpath d='M1 4h12v9H1z M4 4V2a3 3 0 0 1 6 0v2'/%3E%3C/g%3E%3Cg transform='translate(316,198)'%3E%3Cpath d='M0 0l14 7-14 7 3-7z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E") !important;
  background-repeat: repeat !important;
  background-size: 352px 232px !important;
  background-blend-mode: overlay;
}
.conversation-panel::before { content: none !important; }

/* ===== 2. DAY CHIP ===== */
.conversation-panel li > .flex.justify-center > span,
.conversation-panel .date--separator span,
.conversation-panel [class*='date'] span {
  background: var(--cs-head, #202C33) !important;
  color: var(--cs-tx2, #AEBAC1) !important;
  font-size: 12px !important;
  font-weight: 500 !important;
  padding: 5px 13px !important;
  border-radius: 8px !important;
  box-shadow: 0 1px .5px rgba(0,0,0,.35) !important;
  border: none !important;
  text-transform: none !important;
}

/* ===== 3. BUBBLE KI NOK ===== */
.right-bubble, .left-bubble { overflow: visible !important; }
.right-bubble::after {
  content: '';
  position: absolute;
  top: 0;
  right: -8px;
  width: 0; height: 0;
  border-top: 9px solid var(--cs-sent, #005C4B);
  border-right: 9px solid transparent;
}
.left-bubble::after {
  content: '';
  position: absolute;
  top: 0;
  left: -8px;
  width: 0; height: 0;
  border-top: 9px solid var(--cs-recv, #202C33);
  border-left: 9px solid transparent;
}

/* ===== 4. COMPOSER: bada khali box khatam ===== */
.ProseMirror {
  min-height: 1.5rem !important;
  max-height: 7.5rem !important;
  padding: 0 !important;
}
.conversation-footer, .reply-box,
[class*='reply-box'], [class*='ReplyBox'] {
  min-height: 0 !important;
}
.conversation-footer .editor-root,
.reply-box__top { padding: 4px 10px !important; }

/* ===== 5. LIST HEADER bara ===== */
.conversations-list-wrap h1 {
  font-size: 21px !important;
  font-weight: 600 !important;
}

/* ===== 6. ROW: avatar pakka 49px ===== */
.cs-row__av > *,
.cs-row__av img,
.cs-row__av > div {
  width: 49px !important;
  height: 49px !important;
  min-width: 49px !important;
  border-radius: 50% !important;
  font-size: 15px !important;
}

/* CS-WA2-END */
CSEOF

python3 - "$SCSS" /tmp/cs_wa2.css <<'PYEOF'
import io, re, sys
p, c = sys.argv[1], sys.argv[2]
s = io.open(p, encoding='utf-8').read()
b = io.open(c, encoding='utf-8').read().strip()
s2 = re.sub(r"/\* CS-WA2-START \*/.*?/\* CS-WA2-END \*/\n?", "", s, flags=re.S)
if s2 != s: print("   purana block hataya")
io.open(p,'w',encoding='utf-8').write(s2.rstrip() + "\n\n" + b + "\n")
print("   append OK")
PYEOF

echo ">> HO GAYA"
echo "   tail -3 /tmp/vite.log     ('built in' ka intezaar)"
echo "   bash push.sh"
echo "   Ctrl-Shift-R"
