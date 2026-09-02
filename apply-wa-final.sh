#!/usr/bin/env bash
# =====================================================================
#  apply-wa-final.sh
#   1. ResizableEditorWrapper.vue  composer 120px -> 52px  (JS constant,
#                                  CSS se nahi ho sakta - inline style hai)
#   2. ConversationCard.vue        WA/FB/IG chip + tick row mein
#   3. ChatList.vue                "Unread" pill
#   4. app.scss                    search patli, day chip, bubble nok,
#                                  chip/tick ke rang, row ki line
# =====================================================================
set -euo pipefail
cd /root/staging-build
RW=app/javascript/dashboard/components/widgets/conversation/ResizableEditorWrapper.vue
CD=app/javascript/dashboard/components/widgets/conversation/ConversationCard.vue
CL=app/javascript/dashboard/components/ChatList.vue
SCSS=app/javascript/dashboard/assets/scss/app.scss
BK=/root/backups; S=$(date +%F-%H%M%S)
say(){ printf '\n\033[1;36m>> %s\033[0m\n' "$*"; }
die(){ printf '\n\033[1;31m!! %s\033[0m\n' "$*"; exit 1; }
for f in "$RW" "$CD" "$CL" "$SCSS"; do [ -f "$f" ] || die "nahi mili: $f"; done
mkdir -p "$BK"
cp "$RW" "$BK/RW.$S.bak"; cp "$CD" "$BK/CD.$S.bak"
cp "$CL" "$BK/CL.$S.bak"; cp "$SCSS" "$BK/scss.$S.bak"
echo ">> backup: $BK/*.$S.bak"

cat > /tmp/cs_wa5.css <<'CSSEOF'
/* CS-WA4-START */

/* search bar patli — target jaisi */
.cs-search { margin: 0 12px 10px !important; padding: 0 14px !important; }
.cs-search input { padding: 9px 0 !important; font-size: 14px !important; }
.cs-search__ic { width: 18px !important; height: 18px !important; }

/* channel chip  WA / FB / IG */
.cs-chip {
  font-size: 9.5px; font-weight: 600;
  padding: 1px 6px; border-radius: 4px;
  flex-shrink: 0; line-height: 1.5;
  background: #123A22; color: #7DD99B;
}
.cs-chip--fb { background: #12283F; color: #8CBEF2; }
.cs-chip--ig { background: #3A1526; color: #F09BC0; }

/* tick */
.cs-tick { color: var(--cs-b, #53BDEB); font-size: 13px; flex-shrink: 0; line-height: 1; }

/* row: line sirf text ke neeche (avatar ke neeche nahi) */
.cs-row { padding: 10px 20px 10px 16px !important; }
.cs-row__body {
  border-bottom: 1px solid var(--cs-ln2, #1D282F) !important;
  padding-bottom: 10px !important;
  margin-bottom: -10px !important;
}
.cs-row:last-child .cs-row__body { border-bottom: none !important; }

/* day chip */
.conversation-panel li > div.flex.justify-center > span,
.conversation-panel .date--separator span {
  background: var(--cs-head, #202C33) !important;
  color: var(--cs-tx2, #AEBAC1) !important;
  font-size: 12px !important; font-weight: 500 !important;
  padding: 5px 13px !important; border-radius: 8px !important;
  box-shadow: 0 1px .5px rgba(0,0,0,.35) !important;
  border: none !important;
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

/* composer wrapper */
.resizable-editor-wrapper { min-height: 0 !important; }
.resizable-editor-wrapper .ProseMirror { min-height: 1.4rem !important; }

/* CS-WA4-END */
CSSEOF

say "1/4  composer ki height"
python3 - "$RW" <<'PYEOF'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
E = [
("const DEFAULT_HEIGHT = 120;", "const DEFAULT_HEIGHT = 52;"),
("const MIN_HEIGHT = 80;", "const MIN_HEIGHT = 44;"),
]
for i,(o,n) in enumerate(E):
    c = s.count(o)
    assert c == 1, "block %d: match %d" % (i+1, c)
    s = s.replace(o, n)
io.open(p,'w',encoding='utf-8').write(s)
print("   120px -> 52px OK")
PYEOF

say "2/4  row mein WA chip + tick"
python3 - "$CD" <<'PYEOF'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
old = """      <div class="cs-row__l2">
        <VoiceCallStatus"""
new = """      <div class="cs-row__l2">
        <span
          v-if="inbox && inbox.channel_type"
          class="cs-chip"
          :class="{
            'cs-chip--fb': inbox.channel_type.includes('FacebookPage'),
            'cs-chip--ig': inbox.channel_type.includes('Instagram'),
          }"
        >
          {{
            inbox.channel_type.includes('Whatsapp')
              ? 'WA'
              : inbox.channel_type.includes('FacebookPage')
                ? 'FB'
                : inbox.channel_type.includes('Instagram')
                  ? 'IG'
                  : 'CH'
          }}
        </span>
        <VoiceCallStatus"""
assert s.count(old) == 1, "row match %d" % s.count(old)
s = s.replace(old, new)
io.open(p,'w',encoding='utf-8').write(s)
print("   chip OK")
PYEOF

say "3/4  Unread pill"
python3 - "$CL" <<'PYEOF'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
E = []
E.append((
"const activeChannel = ref(null);",
"const activeChannel = ref(null);\nconst onlyUnread = ref(false);"))
E.append((
"""  if (activeChannel.value) {""",
"""  if (onlyUnread.value) {
    localConversationList = localConversationList.filter(
      c => (c.unread_count || 0) > 0
    );
  }

  if (activeChannel.value) {"""))
E.append((
"""      <button
        type="button"
        class="cs-pill"
        :class="{ 'cs-pill--on': !activeChannel }"
        @click="activeChannel = null"
      >
        All channels
      </button>""",
"""      <button
        type="button"
        class="cs-pill"
        :class="{ 'cs-pill--on': onlyUnread }"
        @click="onlyUnread = !onlyUnread"
      >
        Unread
      </button>
      <button
        type="button"
        class="cs-pill"
        :class="{ 'cs-pill--on': !activeChannel }"
        @click="activeChannel = null"
      >
        All channels
      </button>"""))
E.append((
'<div v-if="inboxesList.length > 1" class="cs-pills">',
'<div class="cs-pills">'))
for i,(o,n) in enumerate(E):
    c = s.count(o)
    assert c == 1, "block %d: match %d" % (i+1, c)
    s = s.replace(o, n)
io.open(p,'w',encoding='utf-8').write(s)
print("   4/4 blocks OK")
PYEOF

say "4/4  app.scss"
python3 - "$SCSS" /tmp/cs_wa5.css <<'PYEOF'
import io, re, sys
p, c = sys.argv[1], sys.argv[2]
s = io.open(p, encoding='utf-8').read()
b = io.open(c, encoding='utf-8').read().strip()
s2 = re.sub(r"/\* CS-WA4-START \*/.*?/\* CS-WA4-END \*/\n?", "", s, flags=re.S)
if s2 != s: print("   purana block hataya")
io.open(p,'w',encoding='utf-8').write(s2.rstrip() + "\n\n" + b + "\n")
print("   append OK")
PYEOF

say "CHECK"
for F in "$RW" "$CD" "$CL"; do
docker exec -u root chatssync-dev node -e "
const fs=require('fs');
const c=require('/src/node_modules/@vue/compiler-sfc');
const src=fs.readFileSync('/src/$F','utf8');
const {descriptor,errors}=c.parse(src,{filename:'x.vue'});
if(errors.length){console.error('PARSE FAIL $F');errors.forEach(e=>console.error(e.message));process.exit(1);}
try{ c.compileScript(descriptor,{id:'x'}); }catch(e){ console.error('SCRIPT FAIL $F: '+e.message); process.exit(1); }
console.log('   OK  $F');
" || die "FAIL — backup: $BK/*.$S.bak"
done
git diff --stat "$RW" "$CD" "$CL" "$SCSS"
echo
echo ">> tail -3 /tmp/vite.log   ('built in' ka intezaar)"
echo ">> bash push.sh            (done aane tak Ctrl-C mat dabana)"
echo ">> Ctrl-Shift-R"
