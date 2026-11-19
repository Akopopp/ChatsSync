// Live countdowns: any element with data-left="<seconds>" counts down every second.
function fmtLeft(sec) {
  sec = Math.max(0, Math.round(sec));
  if (sec < 60) return 'under a minute';
  if (sec < 3600) return Math.round(sec / 60) + ' min';
  return Math.floor(sec / 3600) + ' h ' + Math.floor((sec % 3600) / 60) + ' min';
}

function tick() {
  document.querySelectorAll('[data-left]').forEach(el => {
    const left = parseFloat(el.dataset.left) - 1;
    el.dataset.left = left;
    el.textContent = left <= 0 ? (el.dataset.done || 'any moment now') : fmtLeft(left);
  });
  document.querySelectorAll('[data-bar]').forEach(el => {
    const total = parseFloat(el.dataset.total) || 1;
    const left = parseFloat(document.getElementById(el.dataset.bar)?.dataset.left || 0);
    el.style.width = Math.min(98, Math.max(3, (1 - left / total) * 100)) + '%';
  });
}
setInterval(tick, 1000);
tick();

// Job page: refresh numbers from the server and reload when something finishes.
const live = document.querySelector('[data-poll]');
if (live) {
  let sig = null;
  setInterval(async () => {
    try {
      const res = await fetch(live.dataset.poll, { headers: { Accept: 'application/json' } });
      if (!res.ok) return;
      const data = await res.json();
      if (sig !== null && data.sig !== sig) return location.reload();
      sig = data.sig;
      const step = document.getElementById('step');
      if (step && data.step) step.textContent = data.step;
      if (data.timer) {
        const start = document.getElementById('starts');
        const left = document.getElementById('left');
        if (start) start.dataset.left = data.timer.starts_in;
        if (left) left.dataset.left = data.timer.left;
        const ahead = document.getElementById('ahead');
        if (ahead) ahead.textContent = data.timer.ahead;
      }
    } catch (e) { /* try again next round */ }
  }, 5000);
}

// Clip editor: click words in the transcript to set where the clip starts and ends, or to cut words out.
const editor = document.getElementById('editor');
if (editor) {
  const box = document.getElementById('words');
  const words = [...box.querySelectorAll('.w')];
  const field = name => editor.querySelector(`[name="${name}"]`);
  const mid = w => (parseFloat(w.dataset.s) + parseFloat(w.dataset.e)) / 2;
  const fmt = t => `${Math.floor(t / 60)}:${(t % 60).toFixed(1).padStart(4, '0')}`;
  const lo = parseFloat(box.dataset.lo), hi = parseFloat(box.dataset.hi);
  let start = parseFloat(field('start').value), end = parseFloat(field('end').value);
  const cut = new Set();
  JSON.parse(field('cuts').value || '[]').forEach(([a, b]) => words.forEach((w, i) => {
    if (mid(w) >= a && mid(w) <= b) cut.add(i);
  }));
  const inside = w => mid(w) >= start && mid(w) <= end;

  function paint() {
    let first = -1, last = -1, cutLen = 0;
    const ranges = [];
    words.forEach((w, i) => {
      const on = inside(w);
      w.classList.toggle('keep', on && !cut.has(i));
      w.classList.toggle('cut', on && cut.has(i));
      w.classList.remove('first', 'last');
      if (!on) return;
      if (first < 0) first = i;
      last = i;
      if (cut.has(i)) {
        const a = parseFloat(w.dataset.s) - 0.03, b = parseFloat(w.dataset.e) + 0.03;
        cutLen += b - a;
        const prev = ranges[ranges.length - 1];
        if (prev && cut.has(i - 1) && inside(words[i - 1])) prev[1] = b; else ranges.push([a, b]);
      }
    });
    if (first >= 0) { words[first].classList.add('first'); words[last].classList.add('last'); }
    const span = end - start;
    const ok = span >= 3 && span <= 180;
    document.getElementById('span-info').textContent =
      `${fmt(start)} to ${fmt(end)}, about ${Math.round(span - cutLen)} s` + (ok ? '' : '. A clip must be 3 s to 3 min.');
    const save = document.getElementById('save');
    if (!editor.querySelector('fieldset').disabled) save.disabled = !ok;
    field('start').value = start.toFixed(2);
    field('end').value = end.toFixed(2);
    field('cuts').value = JSON.stringify(ranges.map(r => r.map(x => Math.round(x * 100) / 100)));
  }

  box.addEventListener('click', e => {
    const w = e.target.closest('.w');
    if (!w) return;
    const i = words.indexOf(w);
    const mode = editor.querySelector('[name=mode]:checked').value;
    if (mode === 'start') start = Math.max(lo, parseFloat(w.dataset.s) - 0.08);
    else if (mode === 'end') end = Math.min(hi, parseFloat(w.dataset.e) + 0.25);
    else if (inside(w)) cut.has(i) ? cut.delete(i) : cut.add(i);
    paint();
  });
  document.getElementById('reset-cuts').addEventListener('click', () => { cut.clear(); paint(); });
  paint();
  const firstWord = box.querySelector('.w.first');
  if (firstWord) box.scrollTop = firstWord.offsetTop - box.offsetTop - 40;
}
