#!/usr/bin/env bash
# =====================================================================
#  fix-recorder.sh — AudioRecorder.vue: startRecording ki nakami pakdo
#
#  Bug: startRecording() promise return karta hai. Mic block ho ya
#       WaveSurfer fail kare to rejection kahin nahi jaati — na error,
#       na waqt chalta, na recording rukti. Bilkul khamoshi.
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

old = """const startRecording = () => {
  record.value.startRecording();
  isRecording.value = true;
};"""
new = """const startRecording = () => {
  try {
    const started = record.value.startRecording();
    isRecording.value = true;
    // startRecording() promise deta hai. Mic block ho to yahi
    // reject hota hai — pehle koi ise pakadta nahi tha, isliye
    // chup-chaap fail ho jaata tha.
    if (started && typeof started.catch === 'function') {
      started.catch(error => {
        isRecording.value = false;
        emit('recordError', { error });
      });
    }
  } catch (error) {
    isRecording.value = false;
    emit('recordError', { error });
  }
};"""
c = s.count(old)
assert c == 1, "match %d (chahiye 1)" % c
io.open(p, 'w', encoding='utf-8').write(s.replace(old, new))
print("   startRecording ab error emit karta hai")
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
echo
echo ">> sleep 80 && tail -3 /tmp/vite.log ; bash push.sh"
