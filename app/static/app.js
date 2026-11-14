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
