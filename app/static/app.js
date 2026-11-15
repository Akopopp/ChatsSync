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


// AI helper: chat that can explain the app and do work in it. Actions that publish or delete show a Confirm button.
(() => {
  const box = document.getElementById('helper');
  if (!box) return;
  const log = document.getElementById('helper-log');
  const form = document.getElementById('helper-form');
  const input = document.getElementById('helper-in');
  const KEY = 'clipper-helper';
  let history = [];
  try { history = JSON.parse(sessionStorage.getItem(KEY) || '[]'); } catch (e) { history = []; }
  const save = () => { try { sessionStorage.setItem(KEY, JSON.stringify(history.slice(-30))); } catch (e) { /* ignore */ } };
  const esc = (t) => String(t).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const fmt = (t) => esc(t).replace(/\*\*(.+?)\*\*/g, '<b>$1</b>').replace(/^\s*[*-] /gm, '• ');
  const add = (cls, text) => {
    const el = document.createElement('div');
    el.className = 'msg ' + cls;
    if (cls === 'bot') el.innerHTML = fmt(text); else el.textContent = text;
    log.appendChild(el);
    log.scrollTop = log.scrollHeight;
    return el;
  };
  const confirmCard = (p) => {
    const card = document.createElement('div');
    card.className = 'confirm-card';
    card.innerHTML = '<b>Please confirm</b><div class="txt"></div><div class="row"><button type="button" class="yes">Confirm</button><button type="button" class="no">Cancel</button></div>';
    card.querySelector('.txt').textContent = p.summary;
    card.querySelector('.no').onclick = () => { card.remove(); };
    card.querySelector('.yes').onclick = async () => {
      card.querySelector('.row').textContent = 'Working…';
      try {
        const res = await fetch('/helper/confirm', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ token: p.token }) });
        const data = await res.json();
        card.remove();
        add('bot', data.reply);
        history.push({ role: 'model', text: '[Confirmed: ' + p.summary + '] ' + data.reply });
        save();
      } catch (e) { card.querySelector('.row').textContent = 'Could not reach the server.'; }
    };
    log.appendChild(card);
    log.scrollTop = log.scrollHeight;
  };
  history.forEach(m => add(m.role === 'user' ? 'user' : 'bot', m.text));
  const open = () => { box.hidden = false; input.focus(); };
  document.querySelectorAll('[data-helper-open]').forEach(b => b.addEventListener('click', open));
  box.querySelector('[data-helper-close]').addEventListener('click', () => { box.hidden = true; });
  box.querySelector('[data-helper-clear]').addEventListener('click', () => {
    history = []; save();
    log.querySelectorAll('.msg:not(:first-child), .confirm-card').forEach(el => el.remove());
  });
  const send = async (text) => {
    text = text.trim();
    if (!text) return;
    add('user', text);
    history.push({ role: 'user', text });
    save();
    input.value = '';
    const wait = add('bot wait', 'Thinking…');
    try {
      const res = await fetch('/helper/chat', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ messages: history }) });
      const data = await res.json();
      wait.remove();
      add('bot', data.reply || '…');
      history.push({ role: 'model', text: data.reply || '' });
      save();
      (data.pending || []).forEach(confirmCard);
    } catch (e) { wait.textContent = 'Could not reach the server. Try again.'; }
  };
  form.addEventListener('submit', (e) => { e.preventDefault(); send(input.value); });
  input.addEventListener('keydown', (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(input.value); } });
  log.addEventListener('click', (e) => { const b = e.target.closest('[data-ask]'); if (b) send(b.dataset.ask); });
})();
