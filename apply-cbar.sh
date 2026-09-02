#!/usr/bin/env bash
# =====================================================================
#  apply-cbar.sh   —  composer ek row + thread + menu
#  SIRF CSS. Koi markup nahi badla, koi feature nahi hataya.
#  Reply/Private note, canned, macros, copilot, attachments — sab chalta rahega.
# =====================================================================
set -euo pipefail
cd /root/staging-build
SCSS=app/javascript/dashboard/assets/scss/app.scss
BK=/root/backups; S=$(date +%F-%H%M%S)
[ -f "$SCSS" ] || { echo "!! app.scss nahi mili"; exit 1; }
mkdir -p "$BK"; cp "$SCSS" "$BK/app.scss.$S.bak"
echo ">> backup: $BK/app.scss.$S.bak"

cat > /tmp/cs_cbar.css <<'CSSEOF'
/* CS-CBAR-START  — composer ek row (target .cbar) */

/* ReplyTopPanel (Reply / Private note) bar ke UPAR */
.reply-box {
  position: relative !important;
  display: flex !important;
  flex-wrap: wrap !important;
  align-items: flex-end !important;
  gap: 12px !important;
  background: var(--cs-fld, #202C33) !important;
  border-radius: 10px !important;
  padding: 0 14px !important;
  min-height: 46px !important;
  margin: 34px 14px 12px !important;
  border: none !important;
}
.reply-box > *:first-child {
  position: absolute !important;
  top: -31px; left: 0; right: 0;
  background: none !important;
  border: none !important;
  padding: 0 !important;
}

/* icons aur editor ek hi row mein */
.cs-composer { display: contents !important; }
.cs-left  { order: 1; display: flex; align-items: center; gap: 2px; flex-shrink: 0; }
.cs-right { order: 3; display: flex; align-items: center; gap: 2px; flex-shrink: 0; }
.cs-rec   { order: 1; display: flex; align-items: center; gap: 8px; flex: 1; }
.reply-box__top {
  order: 2 !important;
  flex: 1 1 0 !important;
  min-width: 0 !important;
  padding: 0 !important;
  margin: 0 !important;
}
.reply-box__top .ProseMirror {
  min-height: 1.4rem !important;
  max-height: 6rem !important;
  padding: 11px 0 !important;
  margin: 0 !important;
}

/* editor ka wrapper: height ab bar se aati hai */
.resizable-editor-wrapper { min-height: 0 !important; }
.resizable-editor-wrapper > div:first-child { display: none !important; }

/* send gol hara */
.cs-send > *, .cs-send button {
  border-radius: 50% !important;
  background: var(--cs-g, #00A884) !important;
  color: #fff !important;
  width: 34px !important; height: 34px !important;
}

/* recording patti */
.cs-rec__spacer { flex: 1; }
.cs-rec__dot {
  width: 9px; height: 9px; border-radius: 50%;
  background: #F15C6D; animation: cs-blink 1.4s ease-in-out infinite;
}
.cs-rec__dot--paused { animation: none; opacity: .45; }
@keyframes cs-blink { 0%,100%{opacity:1} 50%{opacity:.25} }
.cs-rec__time { font-size: 13px; color: var(--cs-tx2, #AEBAC1); font-variant-numeric: tabular-nums; }

/* ---------- THREAD ---------- */
/* day chip */
.conversation-panel li > div.flex.justify-center > span,
.conversation-panel .date--separator span {
  background: var(--cs-head, #202C33) !important;
  color: var(--cs-tx2, #AEBAC1) !important;
  font-size: 12px !important; font-weight: 500 !important;
  padding: 5px 13px !important; border-radius: 8px !important;
  box-shadow: 0 1px .5px rgba(0,0,0,.35) !important;
  border: none !important; text-transform: none !important;
}

/* bubble ki nok */
.right-bubble, .left-bubble { overflow: visible !important; }
.right-bubble::after {
  content: ''; position: absolute; top: 0; right: -8px;
  width: 0; height: 0;
  border-top: 9px solid var(--cs-sent, #005C4B);
  border-right: 9px solid transparent;
}
.left-bubble::after {
  content: ''; position: absolute; top: 0; left: -8px;
  width: 0; height: 0;
  border-top: 9px solid var(--cs-recv, #202C33);
  border-left: 9px solid transparent;
}

/* audio bubble ka apna box na bane */
.cs-voice { min-width: 0 !important; width: 100% !important; background: transparent !important; }
[data-bubble-name='audio'] .cs-voice { background: transparent !important; }
.cs-voice__wave { min-width: 0 !important; overflow: hidden !important; gap: 1px !important; }
.cs-voice__bar { flex: 1 1 0 !important; min-width: 1px !important; }

/* ---------- right-click menu (target .cmenu / .mi) ---------- */
.z-\[9999\] > div {
  background: var(--cs-menu, #233138) !important;
  backdrop-filter: none !important;
  border-radius: 8px !important; outline: none !important;
  box-shadow: 0 4px 22px rgba(0,0,0,.45) !important;
  padding: 7px 0 !important; min-width: 212px !important;
  font-size: 14.5px !important;
}
.z-\[9999\] [role='button'], .z-\[9999\] > div > div {
  display: flex !important; align-items: center !important;
  gap: 14px !important; padding: 10px 17px !important;
  height: auto !important; border-radius: 0 !important;
}
.z-\[9999\] [role='button']:hover { background: var(--cs-menu-hov, #182229) !important; }
.z-\[9999\] span { font-size: 14.5px !important; }
.z-\[9999\] svg { width: 19px !important; height: 19px !important; }
.z-\[9999\] hr { margin: 6px 0 !important; border-color: var(--cs-ln, #222E35) !important; }

/* CS-CBAR-END */
CSSEOF

python3 - "$SCSS" /tmp/cs_cbar.css <<'PYEOF'
import io, re, sys
p, c = sys.argv[1], sys.argv[2]
s = io.open(p, encoding='utf-8').read()
b = io.open(c, encoding='utf-8').read().strip()
s2 = re.sub(r"/\* CS-CBAR-START.*?/\* CS-CBAR-END \*/\n?", "", s, flags=re.S)
if s2 != s: print(">> purana block hataya")
io.open(p,'w',encoding='utf-8').write(s2.rstrip() + "\n\n" + b + "\n")
print(">> append OK")
PYEOF

docker exec -u root chatssync-dev node -e "
const sass=require('/src/node_modules/sass');
try{ sass.compile('/src/$SCSS',{loadPaths:['/src/app/javascript','/src/node_modules']}); console.log('>> scss compile OK'); }
catch(e){ console.error('SCSS FAIL: '+e.message); process.exit(1); }
" || echo ">> (sass check skip - vite khud pakad legi)"

git diff --stat "$SCSS"
echo
echo ">> tail -3 /tmp/vite.log ; bash push.sh ; Ctrl-Shift-R"
echo ">> wapas lena ho to: cp $BK/app.scss.$S.bak $SCSS"
