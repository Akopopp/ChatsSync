#!/usr/bin/env bash
# =====================================================================
#  fix-voice-ext.sh
#
#  Bug: AUDIO_EXTENSION_MAP mein key 'audio/ogg' hai, magar
#       MediaRecorder blob ka type 'audio/ogg;codecs=opus' hota hai.
#       Lookup fail -> fallback 'mp3' -> file ka naam uuid.mp3 ban
#       jaata hai chahe bytes OGG hi hon.
#       WhatsApp voice note (PTT) tabhi banta hai jab file .ogg ho,
#       warna woh usay aam audio FILE ki tarah bhejta hai.
#
#  Fix: type se ';codecs=...' hata kar lookup karo.
# =====================================================================
set -euo pipefail
cd /root/staging-build
F=app/javascript/dashboard/components/widgets/WootWriter/AudioRecorder.vue
BK=/root/backups; S=$(date +%F-%H%M%S)
[ -f "$F" ] || { echo "!! $F nahi mili"; exit 1; }
mkdir -p "$BK"; cp "$F" "$BK/AudioRecorder.$S.bak"
echo ">> backup: $BK/AudioRecorder.$S.bak"

python3 - "$F" <<'PYEOF'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()

old = """        const audioType = audioBlob.type || props.audioRecordFormat;
        const ext = AUDIO_EXTENSION_MAP[audioType] || 'mp3';"""
new = """        const audioType = audioBlob.type || props.audioRecordFormat;
        // 'audio/ogg;codecs=opus' -> 'audio/ogg' warna lookup fail hota
        // hai aur file .mp3 ban jaati hai. Us soorat mein WhatsApp
        // usay voice note nahi, aam file samajhta hai.
        const baseType = String(audioType).split(';')[0].trim();
        const ext = AUDIO_EXTENSION_MAP[baseType] || 'ogg';"""
c = s.count(old)
assert c == 1, "match %d (chahiye 1)" % c
s = s.replace(old, new)

# File ka type bhi base rakho, codec suffix ke bagair
old2 = """        const file = new File([audioBlob], fileName, {
          type: audioType,
        });"""
new2 = """        const file = new File([audioBlob], fileName, {
          type: baseType,
        });"""
c2 = s.count(old2)
assert c2 == 1, "file block match %d" % c2
s = s.replace(old2, new2)

io.open(p, 'w', encoding='utf-8').write(s)
print("   extension lookup theek — ab .ogg banega")
PYEOF

docker exec -u root chatssync-dev node -e "
const fs=require('fs');const c=require('/src/node_modules/@vue/compiler-sfc');
const src=fs.readFileSync('/src/$F','utf8');
const {descriptor,errors}=c.parse(src,{filename:'AudioRecorder.vue'});
if(errors.length){console.error('PARSE FAIL');process.exit(1);}
c.compileScript(descriptor,{id:'x'});
console.log('   compile OK');
" || { echo "!! FAIL — wapas: cp $BK/AudioRecorder.$S.bak $F"; exit 1; }

git diff --stat "$F"
