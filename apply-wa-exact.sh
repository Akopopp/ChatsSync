#!/usr/bin/env bash
# =====================================================================
#  apply-wa-exact.sh   —  target (index.html) ke EXACT numbers
#   - doodle poori scroll height par (opacity SVG mein bake ki)
#   - pills EK row mein (do row ban gayi thi)
#   - search / row / composer / menu: target ke naap
#   - audio ka min-width:13rem hataya (meri ghalti thi)
#   - chip "CH" hataya, sirf WA/FB/IG
# =====================================================================
set -euo pipefail
cd /root/staging-build
CD=app/javascript/dashboard/components/widgets/conversation/ConversationCard.vue
CL=app/javascript/dashboard/components/ChatList.vue
CH=app/javascript/dashboard/components-next/message/chips/Audio.vue
SCSS=app/javascript/dashboard/assets/scss/app.scss
BK=/root/backups; S=$(date +%F-%H%M%S)
say(){ printf '\n\033[1;36m>> %s\033[0m\n' "$*"; }
die(){ printf '\n\033[1;31m!! %s\033[0m\n' "$*"; exit 1; }
for f in "$CD" "$CL" "$CH" "$SCSS"; do [ -f "$f" ] || die "nahi mili: $f"; done
mkdir -p "$BK"
for f in "$CD" "$CL" "$CH" "$SCSS"; do cp "$f" "$BK/$(basename $f).$S.bak"; done
echo ">> backup: $BK/*.$S.bak"

cat > /tmp/cs_wa6.css <<'CSSEOF'
/* CS-WA5-START  — target ke exact numbers (index.html se) */

/* ===== 1. DOODLE: poori scroll height par (::before nahi) ===== */
.conversation-panel {
  background-color: var(--cs-chat, #0B141A) !important;
  background-image: url("data:image/svg+xml,%3Csvg%20xmlns%3D%27http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%27%20width%3D%27352%27%20height%3D%27232%27%20viewBox%3D%270%200%20352%20232%27%3E%3Cg%20fill%3D%27none%27%20stroke%3D%27%23fff%27%20stroke-opacity%3D%27.055%27%20stroke-width%3D%271.25%27%20stroke-linecap%3D%27round%27%20stroke-linejoin%3D%27round%27%3E%3Cg%20transform%3D%27translate%2818%2C20%29%27%3E%3Cpath%20d%3D%27M0%206a6%206%200%200%201%2012%200%206%206%200%200%201-6%206H2l2-3a6%206%200%200%201-4-3z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2862%2C14%29%27%3E%3Cpath%20d%3D%27M0%200h14v10H4L0%2013z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28108%2C22%29%27%3E%3Cpath%20d%3D%27M6%200l1.8%203.7%204%20.6-2.9%202.8.7%204L6%209.2%202.4%2011l.7-4L.2%204.3l4-.6z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28150%2C16%29%27%3E%3Cpath%20d%3D%27M2%202h12v12H2z%20M2%206h12%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28192%2C20%29%27%3E%3Cpath%20d%3D%27M7%200C3%200%200%203%200%206.5%200%2011%207%2016%207%2016s7-5%207-9.5C14%203%2011%200%207%200z%20M7%204a2.5%202.5%200%201%201%200%205%202.5%202.5%200%200%201%200-5z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28234%2C14%29%27%3E%3Cpath%20d%3D%27M0%208c0-4%203-7%207-7s7%203%207%207-3%207-7%207-7-3-7-7z%20M4%208h6%20M7%205v6%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28276%2C20%29%27%3E%3Cpath%20d%3D%27M0%203h16v10H0z%20M0%203l8%206%208-6%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28318%2C16%29%27%3E%3Cpath%20d%3D%27M3%200h10v4H3z%20M1%204h14v11H1z%20M6%208h4%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2814%2C64%29%27%3E%3Cpath%20d%3D%27M0%2010c3-5%209-5%2012%200%20M6%204a2.5%202.5%200%201%201%200%20.01%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2856%2C58%29%27%3E%3Cpath%20d%3D%27M0%200h13M0%205h9M0%2010h11%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2898%2C62%29%27%3E%3Cpath%20d%3D%27M8%200a8%208%200%201%201%200%2016A8%208%200%200%201%208%200z%20M8%204v4.5l3%202%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28140%2C60%29%27%3E%3Cpath%20d%3D%27M0%200l11%206-11%206z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28182%2C58%29%27%3E%3Cpath%20d%3D%27M2%200h11l3%204v11H2z%20M13%200v4h3%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28224%2C62%29%27%3E%3Cpath%20d%3D%27M0%206h4l4-5v14l-4-5H0z%20M11%204a4%204%200%200%201%200%208%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28266%2C58%29%27%3E%3Cpath%20d%3D%27M1%201h14v10H1z%20M1%2011l5-4%203%202%203-3%203%203%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28308%2C64%29%27%3E%3Cpath%20d%3D%27M6%200a6%206%200%200%201%206%206c0%204-6%2010-6%2010S0%2010%200%206a6%206%200%200%201%206-6z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2820%2C106%29%27%3E%3Cpath%20d%3D%27M0%204h5l3-4h4l3%204h1v10H0z%20M8%206a3%203%200%201%201%200%206%203%203%200%200%201%200-6z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2862%2C110%29%27%3E%3Cpath%20d%3D%27M6%200l6%2012H0z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28104%2C104%29%27%3E%3Cpath%20d%3D%27M0%200h12v12H0z%20M3%203h6v6H3z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28146%2C108%29%27%3E%3Cpath%20d%3D%27M0%206a6%206%200%201%200%2012%200%206%206%200%200%200-12%200z%20M3%206l2%202%204-4%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28188%2C104%29%27%3E%3Cpath%20d%3D%27M1%203h14v9H1z%20M4%203V1h8v2%20M4%2012v2h8v-2%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28230%2C110%29%27%3E%3Cpath%20d%3D%27M0%2012L6%200l6%2012z%20M4%2012v3h4v-3%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28272%2C106%29%27%3E%3Cpath%20d%3D%27M2%202l10%2010M12%202L2%2012%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28314%2C110%29%27%3E%3Cpath%20d%3D%27M0%208h16%20M4%204l-4%204%204%204%20M12%204l4%204-4%204%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2816%2C150%29%27%3E%3Cpath%20d%3D%27M0%202h14v12H0z%20M3%200v4M11%200v4M0%206h14%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2858%2C154%29%27%3E%3Cpath%20d%3D%27M7%200a7%207%200%201%201%200%2014A7%207%200%200%201%207%200z%20M4%207h6%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28100%2C148%29%27%3E%3Cpath%20d%3D%27M0%2010c0-6%205-10%208-10s8%204%208%2010%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28142%2C152%29%27%3E%3Cpath%20d%3D%27M2%200h10v14l-5-4-5%204z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28184%2C150%29%27%3E%3Cpath%20d%3D%27M0%200h14v3H0z%20M2%203v10h10V3%20M6%206v4M8%206v4%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28226%2C154%29%27%3E%3Cpath%20d%3D%27M8%200l2%205%205%20.5-4%203.5%201%205-4-2.6L4%2014l1-5L1%205.5%206%205z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28268%2C148%29%27%3E%3Cpath%20d%3D%27M1%201h13v13H1z%20M4%207h7M7%204v7%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28310%2C152%29%27%3E%3Cpath%20d%3D%27M0%205a5%205%200%200%201%2010%200v6H0z%20M3%2011v3h4v-3%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2822%2C196%29%27%3E%3Cpath%20d%3D%27M0%203h16v9H0z%20M5%2012v2h6v-2%20M2%2016h12%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2864%2C198%29%27%3E%3Cpath%20d%3D%27M6%200a6%206%200%201%201%200%2012A6%206%200%200%201%206%200z%20M6%203v3l2%202%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28106%2C194%29%27%3E%3Cpath%20d%3D%27M0%206h12%20M8%202l4%204-4%204%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28148%2C198%29%27%3E%3Cpath%20d%3D%27M2%200h8a2%202%200%200%201%202%202v10a2%202%200%200%201-2%202H2a2%202%200%200%201-2-2V2a2%202%200%200%201%202-2z%20M4%203h4M4%206h4M4%209h2%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28190%2C194%29%27%3E%3Cpath%20d%3D%27M0%200h14M0%205h14M0%2010h8%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28232%2C198%29%27%3E%3Cpath%20d%3D%27M7%200l7%207-7%207-7-7z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28274%2C194%29%27%3E%3Cpath%20d%3D%27M1%204h12v9H1z%20M4%204V2a3%203%200%200%201%206%200v2%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28316%2C198%29%27%3E%3Cpath%20d%3D%27M0%200l14%207-14%207%203-7z%27%2F%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fsvg%3E") !important;
  background-repeat: repeat !important;
  background-size: 352px 232px !important;
}
.conversation-panel::before { content: none !important; }
:root:not(.dark) .conversation-panel,
html:not(.dark) .conversation-panel {
  background-color: #EFE7DE !important;
  background-image: url("data:image/svg+xml,%3Csvg%20xmlns%3D%27http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%27%20width%3D%27352%27%20height%3D%27232%27%20viewBox%3D%270%200%20352%20232%27%3E%3Cg%20fill%3D%27none%27%20stroke%3D%27%230B141A%27%20stroke-opacity%3D%27.07%27%20stroke-width%3D%271.25%27%20stroke-linecap%3D%27round%27%20stroke-linejoin%3D%27round%27%3E%3Cg%20transform%3D%27translate%2818%2C20%29%27%3E%3Cpath%20d%3D%27M0%206a6%206%200%200%201%2012%200%206%206%200%200%201-6%206H2l2-3a6%206%200%200%201-4-3z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2862%2C14%29%27%3E%3Cpath%20d%3D%27M0%200h14v10H4L0%2013z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28108%2C22%29%27%3E%3Cpath%20d%3D%27M6%200l1.8%203.7%204%20.6-2.9%202.8.7%204L6%209.2%202.4%2011l.7-4L.2%204.3l4-.6z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28150%2C16%29%27%3E%3Cpath%20d%3D%27M2%202h12v12H2z%20M2%206h12%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28192%2C20%29%27%3E%3Cpath%20d%3D%27M7%200C3%200%200%203%200%206.5%200%2011%207%2016%207%2016s7-5%207-9.5C14%203%2011%200%207%200z%20M7%204a2.5%202.5%200%201%201%200%205%202.5%202.5%200%200%201%200-5z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28234%2C14%29%27%3E%3Cpath%20d%3D%27M0%208c0-4%203-7%207-7s7%203%207%207-3%207-7%207-7-3-7-7z%20M4%208h6%20M7%205v6%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28276%2C20%29%27%3E%3Cpath%20d%3D%27M0%203h16v10H0z%20M0%203l8%206%208-6%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28318%2C16%29%27%3E%3Cpath%20d%3D%27M3%200h10v4H3z%20M1%204h14v11H1z%20M6%208h4%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2814%2C64%29%27%3E%3Cpath%20d%3D%27M0%2010c3-5%209-5%2012%200%20M6%204a2.5%202.5%200%201%201%200%20.01%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2856%2C58%29%27%3E%3Cpath%20d%3D%27M0%200h13M0%205h9M0%2010h11%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2898%2C62%29%27%3E%3Cpath%20d%3D%27M8%200a8%208%200%201%201%200%2016A8%208%200%200%201%208%200z%20M8%204v4.5l3%202%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28140%2C60%29%27%3E%3Cpath%20d%3D%27M0%200l11%206-11%206z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28182%2C58%29%27%3E%3Cpath%20d%3D%27M2%200h11l3%204v11H2z%20M13%200v4h3%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28224%2C62%29%27%3E%3Cpath%20d%3D%27M0%206h4l4-5v14l-4-5H0z%20M11%204a4%204%200%200%201%200%208%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28266%2C58%29%27%3E%3Cpath%20d%3D%27M1%201h14v10H1z%20M1%2011l5-4%203%202%203-3%203%203%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28308%2C64%29%27%3E%3Cpath%20d%3D%27M6%200a6%206%200%200%201%206%206c0%204-6%2010-6%2010S0%2010%200%206a6%206%200%200%201%206-6z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2820%2C106%29%27%3E%3Cpath%20d%3D%27M0%204h5l3-4h4l3%204h1v10H0z%20M8%206a3%203%200%201%201%200%206%203%203%200%200%201%200-6z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2862%2C110%29%27%3E%3Cpath%20d%3D%27M6%200l6%2012H0z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28104%2C104%29%27%3E%3Cpath%20d%3D%27M0%200h12v12H0z%20M3%203h6v6H3z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28146%2C108%29%27%3E%3Cpath%20d%3D%27M0%206a6%206%200%201%200%2012%200%206%206%200%200%200-12%200z%20M3%206l2%202%204-4%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28188%2C104%29%27%3E%3Cpath%20d%3D%27M1%203h14v9H1z%20M4%203V1h8v2%20M4%2012v2h8v-2%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28230%2C110%29%27%3E%3Cpath%20d%3D%27M0%2012L6%200l6%2012z%20M4%2012v3h4v-3%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28272%2C106%29%27%3E%3Cpath%20d%3D%27M2%202l10%2010M12%202L2%2012%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28314%2C110%29%27%3E%3Cpath%20d%3D%27M0%208h16%20M4%204l-4%204%204%204%20M12%204l4%204-4%204%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2816%2C150%29%27%3E%3Cpath%20d%3D%27M0%202h14v12H0z%20M3%200v4M11%200v4M0%206h14%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2858%2C154%29%27%3E%3Cpath%20d%3D%27M7%200a7%207%200%201%201%200%2014A7%207%200%200%201%207%200z%20M4%207h6%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28100%2C148%29%27%3E%3Cpath%20d%3D%27M0%2010c0-6%205-10%208-10s8%204%208%2010%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28142%2C152%29%27%3E%3Cpath%20d%3D%27M2%200h10v14l-5-4-5%204z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28184%2C150%29%27%3E%3Cpath%20d%3D%27M0%200h14v3H0z%20M2%203v10h10V3%20M6%206v4M8%206v4%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28226%2C154%29%27%3E%3Cpath%20d%3D%27M8%200l2%205%205%20.5-4%203.5%201%205-4-2.6L4%2014l1-5L1%205.5%206%205z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28268%2C148%29%27%3E%3Cpath%20d%3D%27M1%201h13v13H1z%20M4%207h7M7%204v7%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28310%2C152%29%27%3E%3Cpath%20d%3D%27M0%205a5%205%200%200%201%2010%200v6H0z%20M3%2011v3h4v-3%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2822%2C196%29%27%3E%3Cpath%20d%3D%27M0%203h16v9H0z%20M5%2012v2h6v-2%20M2%2016h12%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2864%2C198%29%27%3E%3Cpath%20d%3D%27M6%200a6%206%200%201%201%200%2012A6%206%200%200%201%206%200z%20M6%203v3l2%202%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28106%2C194%29%27%3E%3Cpath%20d%3D%27M0%206h12%20M8%202l4%204-4%204%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28148%2C198%29%27%3E%3Cpath%20d%3D%27M2%200h8a2%202%200%200%201%202%202v10a2%202%200%200%201-2%202H2a2%202%200%200%201-2-2V2a2%202%200%200%201%202-2z%20M4%203h4M4%206h4M4%209h2%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28190%2C194%29%27%3E%3Cpath%20d%3D%27M0%200h14M0%205h14M0%2010h8%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28232%2C198%29%27%3E%3Cpath%20d%3D%27M7%200l7%207-7%207-7-7z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28274%2C194%29%27%3E%3Cpath%20d%3D%27M1%204h12v9H1z%20M4%204V2a3%203%200%200%201%206%200v2%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28316%2C198%29%27%3E%3Cpath%20d%3D%27M0%200l14%207-14%207%203-7z%27%2F%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fsvg%3E") !important;
}

/* ===== 2. SEARCH  (.psr) ===== */
.cs-search {
  margin: 0 12px 11px !important;
  background: var(--cs-fld, #202C33) !important;
  border-radius: 9px !important;
  padding: 0 14px !important;
  gap: 12px !important;
  display: flex; align-items: center; flex-shrink: 0;
}
.cs-search input {
  flex: 1; min-width: 0;
  background: none; border: none; outline: none;
  color: var(--cs-tx, #E9EDEF);
  font-size: 14px !important; font-family: inherit;
  padding: 10px 0 !important;
}
.cs-search input::placeholder { color: var(--cs-tx3, #8696A0); }
.cs-search__ic, .cs-search__x { width: 19px; height: 19px; color: var(--cs-tx3, #8696A0); flex-shrink: 0; }
.cs-search__x { cursor: pointer; }

/* ===== 3. PILLS: EK hi row, scroll  (.pills) ===== */
.cs-pills {
  display: flex !important;
  gap: 8px !important;
  padding: 0 12px 12px !important;
  align-items: center !important;
  overflow-x: auto !important;
  flex-wrap: nowrap !important;
  flex-shrink: 0;
}
.cs-pills::-webkit-scrollbar { display: none; }
/* ChatTypeTabs aur channel pills ko ek hi row bana do */
.cs-pills + .cs-pills { padding-top: 0 !important; margin-top: -6px !important; }
.cs-pill {
  font-size: 13.5px !important;
  padding: 5px 14px !important;
  border-radius: 16px !important;
  background: var(--cs-fld, #202C33);
  color: var(--cs-tx2, #AEBAC1);
  border: 0; cursor: pointer; white-space: nowrap;
  display: flex; align-items: center; gap: 6px;
  flex-shrink: 0 !important;
  transition: background .12s, color .12s;
}
.cs-pill--on { background: var(--cs-g-tint, #103529); color: var(--cs-g, #00A884); }

/* ===== 4. ROW  (.row) ===== */
.cs-row {
  display: flex !important;
  gap: 14px !important;
  padding: 11px 20px 11px 16px !important;
  align-items: center !important;
}
.cs-row__av > *, .cs-row__av img {
  width: 48px !important; height: 48px !important; min-width: 48px !important;
  border-radius: 50% !important; font-size: 15px !important;
}
.cs-row__body {
  flex: 1; min-width: 0;
  border-bottom: 1px solid var(--cs-ln2, #1D282F) !important;
  padding-bottom: 11px !important;
  margin-bottom: -11px !important;
}
.cs-row:last-child .cs-row__body { border-bottom: none !important; }

/* ===== 5. COMPOSER  (.cbar) ===== */
.cs-composer {
  background: var(--cs-fld, #202C33) !important;
  border-radius: 10px !important;
  display: flex !important;
  align-items: flex-end !important;
  gap: 12px !important;
  padding: 0 14px !important;
  min-height: 46px !important;
}
.resizable-editor-wrapper { min-height: 0 !important; }
.resizable-editor-wrapper .ProseMirror {
  min-height: 1.4rem !important;
  max-height: 6rem !important;
  padding: 0 !important;
}
.reply-box {
  border: none !important;
  background: transparent !important;
  padding: 8px 14px 10px !important;
}

/* ===== 6. AUDIO: meri hi ghalti thi (min-width 13rem) ===== */
.cs-voice {
  min-width: 0 !important;
  width: 100% !important;
  background: transparent !important;
}
[data-bubble-name='audio'] .cs-voice,
[data-bubble-name='audio'] > * { background: transparent !important; }
.cs-voice__wave { min-width: 0 !important; overflow: hidden !important; gap: 1px !important; }
.cs-voice__bar { flex: 1 1 0 !important; min-width: 1px !important; }

/* ===== 7. bubble ki nok ===== */
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

/* ===== 8. header h1  (.ph h1) ===== */
.conversations-list-wrap h1 {
  font-size: 22px !important;
  font-weight: 600 !important;
  letter-spacing: -.02em !important;
}

/* ===== 9. right-click menu  (.cmenu / .mi) ===== */
.z-\[9999\] > div {
  background: var(--cs-menu, #233138) !important;
  backdrop-filter: none !important;
  border-radius: 8px !important;
  outline: none !important;
  box-shadow: 0 4px 22px rgba(0,0,0,.45) !important;
  padding: 7px 0 !important;
  min-width: 212px !important;
  font-size: 14.5px !important;
}
.z-\[9999\] [role='button'], .z-\[9999\] > div > div {
  display: flex !important; align-items: center !important;
  gap: 14px !important; padding: 10px 17px !important;
  height: auto !important; border-radius: 0 !important;
}
.z-\[9999\] [role='button']:hover { background: var(--cs-menu-hov, #182229) !important; }
.z-\[9999\] span { font-size: 14.5px !important; }
.z-\[9999\] hr { margin: 6px 0 !important; border-color: var(--cs-ln, #222E35) !important; }

/* CS-WA5-END */
CSSEOF

say "1/4  chip: sirf WA/FB/IG (CH hatao)"
python3 - "$CD" <<'PYEOF'
import io, sys
p = sys.argv[1]; s = io.open(p, encoding='utf-8').read()
o = """                  : 'CH'"""
n = """                  : ''"""
if s.count(o) == 1:
    s = s.replace(o, n)
    o2 = 'v-if="inbox && inbox.channel_type"'
    n2 = ("v-if=\"inbox && inbox.channel_type && "
          "/Whatsapp|FacebookPage|Instagram/.test(inbox.channel_type)\"")
    assert s.count(o2) == 1
    s = s.replace(o2, n2)
    io.open(p,'w',encoding='utf-8').write(s)
    print("   OK")
else:
    print("   (chip pehle se theek ya match nahi - chhoda)")
PYEOF

say "2/4  audio: apna min-width hatao"
python3 - "$CH" <<'PYEOF'
import io, sys
p = sys.argv[1]; s = io.open(p, encoding='utf-8').read()
o = """  /* bubble ko WhatsApp jaisi chaudai de */
  min-width: 13rem;"""
n = """  min-width: 0;"""
if s.count(o) == 1:
    io.open(p,'w',encoding='utf-8').write(s.replace(o, n)); print("   13rem hataya")
else:
    print("   (match nahi - CSS override chal jayega)")
PYEOF

say "3/4  pills ek row"
python3 - "$CL" <<'PYEOF'
import io, sys
p = sys.argv[1]; s = io.open(p, encoding='utf-8').read()
o = '<div class="cs-pills">'
n = '<div class="cs-pills cs-pills--ch">'
if s.count(o) == 1:
    io.open(p,'w',encoding='utf-8').write(s.replace(o, n)); print("   OK")
else:
    print("   (match nahi - chhoda)")
PYEOF

say "4/4  app.scss"
python3 - "$SCSS" /tmp/cs_wa6.css <<'PYEOF'
import io, re, sys
p, c = sys.argv[1], sys.argv[2]
s = io.open(p, encoding='utf-8').read()
b = io.open(c, encoding='utf-8').read().strip()
s2 = re.sub(r"/\* CS-WA5-START.*?/\* CS-WA5-END \*/\n?", "", s, flags=re.S)
if s2 != s: print("   purana block hataya")
io.open(p,'w',encoding='utf-8').write(s2.rstrip() + "\n\n" + b + "\n")
print("   append OK")
PYEOF

say "CHECK"
for F in "$CD" "$CL" "$CH"; do
docker exec -u root chatssync-dev node -e "
const fs=require('fs');
const c=require('/src/node_modules/@vue/compiler-sfc');
const src=fs.readFileSync('/src/$F','utf8');
const {descriptor,errors}=c.parse(src,{filename:'x.vue'});
if(errors.length){console.error('PARSE FAIL $F');process.exit(1);}
try{ c.compileScript(descriptor,{id:'x'}); }catch(e){ console.error('FAIL $F: '+e.message); process.exit(1); }
console.log('   OK  $F');
" || die "FAIL — backup: $BK/*.$S.bak"
done
git diff --stat "$CD" "$CL" "$CH" "$SCSS"
echo
echo ">> tail -3 /tmp/vite.log ; bash push.sh ; Ctrl-Shift-R"
