<script setup>
/* =====================================================================
   DashboardScreen.vue  —  ChatsSync Dashboard
   Flat cards, saaf typography, sparklines. Koi gradient banner nahi.
   Data Chatwoot ke apne endpoints se — koi backend kaam nahi.
   ===================================================================== */
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store.js';

const router = useRouter();
const accountId = useMapGetter('getCurrentAccountId');
const currentUser = useMapGetter('getCurrentUser');
const currentAccount = useMapGetter('getCurrentAccount');

/* ---------------- API ---------------- */
/* ===================================================================
   AUTH
   Ek daur mein ise bare `axios` par le gaya tha — woh ghalti thi: us
   import par Chatwoot ke auth headers lagte hi nahi, isliye Contacts,
   Inbox aur Dashboard teeno 401 par gir gaye.
   Ab wapas cookie ke headers, magar do sudhaar ke saath:
     1. token HAR call par taaza parha jaata hai
     2. 401 aaye to 250ms ruk kar EK baar dobara — devise-token-auth har
        request par token badalta hai, aur kabhi kabhi hum purana token
        pakad lete hain. Dobara koshish par cookie mein naya token aa
        chuka hota hai.
   =================================================================== */
const authHeaders = () => {
  const h = { 'Content-Type': 'application/json' };
  try {
    const raw = (document.cookie.match(
      /(?:^|;\s*)cw_d_session_info=([^;]+)/
    ) || [])[1];
    if (raw) {
      let txt = decodeURIComponent(raw);
      if (txt.charAt(0) === 'j' && txt.charAt(1) === ':') txt = txt.slice(2);
      const sess = JSON.parse(txt);
      if (sess['access-token']) {
        /* SIRF ye paanch headers — bilkul wahi jo Chatwoot ka apna
           APIHelper.js bhejta hai.
           `api_access_token` YAHAN NAHI BHEJNA. Chatwoot ka usool ye hai
           ke woh header maujood ho to session ki parwah nahi karta —
           usay ek alag long-lived API token samajh kar check karta hai
           (authenticate_access_token!). Hum us mein devise ka session
           token bhej rahe the, jo API token hai hi nahi, isliye server
           foran 401 "Invalid Access Token" de deta tha. */
        h['access-token'] = sess['access-token'];
        h['token-type'] = sess['token-type'] || 'Bearer';
        h.client = sess.client;
        h.expiry = sess.expiry;
        h.uid = sess.uid;
      }
    }
  } catch (e) {
    /* ignore */
  }
  return h;
};

const rawFetch = (url, opts = {}) =>
  fetch(url, { credentials: 'same-origin', ...opts, headers: authHeaders() });

/* 401 par ek baar dobara — token rotate ho chuka hota hai */
const httpJson = (url, opts = {}) =>
  rawFetch(url, opts).then(r => {
    if (r.status !== 401) {
      if (!r.ok) throw new Error(`${opts.method || 'GET'} ${url} → ${r.status}`);
      return r.status === 204 ? null : r.json().catch(() => null);
    }
    return new Promise(res => setTimeout(res, 250))
      .then(() => rawFetch(url, opts))
      .then(r2 => {
        if (!r2.ok) throw new Error(`${opts.method || 'GET'} ${url} → ${r2.status}`);
        return r2.status === 204 ? null : r2.json().catch(() => null);
      });
  });

const call = (ver, path) =>
  httpJson(`/api/${ver}/accounts/${accountId.value}${path}`);
const v1 = p => call('v1', p);
const v2 = p => call('v2', p);
const soft = (p, fb = null) => p.catch(() => fb);

/* ---------------- state ---------------- */
const RANGES = [
  { k: 7, n: '7D' },
  { k: 30, n: '30D' },
  { k: 90, n: '90D' },
];
const range = ref(30);
const loading = ref(true);
const isLight = ref(false);
const isMobile = ref(window.innerWidth <= 768);
const lastSync = ref(null);

const summary = ref(null);
const prevSummary = ref(null);
const series = ref([]);
const inSeries = ref([]);
const outSeries = ref([]);
const live = ref({ open: 0, pending: 0, unassigned: 0, unattended: 0 });
const agents = ref([]);
const agentStats = ref([]);
const inboxes = ref([]);
const inboxCounts = ref({});
const teams = ref([]);
const labels = ref([]);
const bots = ref([]);
const cannedCount = ref(0);
const contactCount = ref(0);
const recent = ref([]);

const openRail = () => {
  window.dispatchEvent(new CustomEvent('chatssync:toggle-rail'));
};

/* ---------------- helpers ---------------- */
const now = () => Math.floor(Date.now() / 1000);
const since = () => now() - range.value * 86400;
const num = v => {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
};
const fmtNum = v => {
  const n = num(v);
  if (n >= 1000000) return `${(n / 1000000).toFixed(1)}M`;
  if (n >= 1000) return `${(n / 1000).toFixed(n >= 10000 ? 0 : 1)}k`;
  return String(n);
};
const fmtDur = s => {
  const v = num(s);
  if (!v) return '—';
  if (v < 60) return `${Math.round(v)}s`;
  if (v < 3600) return `${Math.round(v / 60)}m`;
  if (v < 86400) return `${(v / 3600).toFixed(1)}h`;
  return `${(v / 86400).toFixed(1)}d`;
};
const MON = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const shortDate = ts => {
  const d = new Date(num(ts) * 1000);
  return `${d.getDate()} ${MON[d.getMonth()]}`;
};
const agoOf = ts => {
  if (!ts) return '';
  const m = Math.floor((Date.now() - num(ts) * 1000) / 60000);
  if (m < 1) return 'now';
  if (m < 60) return `${m}m`;
  if (m < 1440) return `${Math.floor(m / 60)}h`;
  return `${Math.floor(m / 1440)}d`;
};
const accountName = computed(() => currentAccount.value?.name || 'Workspace');
const rangeLabel = computed(() =>
  range.value === 7 ? 'last 7 days' : range.value === 30 ? 'last 30 days' : 'last 90 days'
);

const CH_COLOR = {
  wa: '#25D366', fb: '#0866FF', ig: '#E1306C', sms: '#7C4DFF',
  tg: '#26A5E4', em: '#F59E0B', web: '#0EA5E9', api: '#94A3B8', other: '#8696A0',
};
const chKind = t => {
  const s = String(t || '');
  if (/Whatsapp/i.test(s)) return 'wa';
  if (/FacebookPage/i.test(s)) return 'fb';
  if (/Instagram/i.test(s)) return 'ig';
  if (/Sms|Twilio/i.test(s)) return 'sms';
  if (/Telegram/i.test(s)) return 'tg';
  if (/Email/i.test(s)) return 'em';
  if (/WebWidget/i.test(s)) return 'web';
  if (/Api/i.test(s)) return 'api';
  return 'other';
};
const initials = n =>
  (n || '?').trim().split(/\s+/).filter(Boolean).slice(0, 2)
    .map(w => w[0]).join('').toUpperCase();
const AV = ['#7F77DD','#E5793A','#12A150','#D9455F','#2F7FD1','#C247A8'];
const avColor = i => AV[Math.abs(Number(i) || 0) % AV.length];
const delta = (a, b) => {
  const x = num(a);
  const y = num(b);
  if (!y) return null;
  return Math.round(((x - y) / y) * 100);
};

/* ---------------- derived ---------------- */
const s0 = computed(() => summary.value || {});
const p0 = computed(() => prevSummary.value || {});

/* sparkline path (KPI cards ke liye) */
const spark = pts => {
  const vals = (pts || []).map(p => num(p.value));
  if (vals.length < 2) return '';
  const max = Math.max(1, ...vals);
  const W = 100;
  const H = 26;
  return vals
    .map((v, i) => {
      const x = (i / (vals.length - 1)) * W;
      const y = H - (v / max) * (H - 3) - 1.5;
      return `${i ? 'L' : 'M'} ${x.toFixed(1)} ${y.toFixed(1)}`;
    })
    .join(' ');
};

const kpis = computed(() => [
  {
    k: 'conv', n: 'Conversations', v: fmtNum(s0.value.conversations_count),
    d: delta(s0.value.conversations_count, p0.value.conversations_count),
    i: 'i-lucide-messages-square', c: '#00A884', sp: spark(series.value),
  },
  {
    k: 'res', n: 'Resolved', v: fmtNum(s0.value.resolutions_count),
    d: delta(s0.value.resolutions_count, p0.value.resolutions_count),
    i: 'i-lucide-circle-check-big', c: '#2F6BEB', sp: '',
  },
  {
    k: 'in', n: 'Incoming', v: fmtNum(s0.value.incoming_messages_count),
    d: delta(s0.value.incoming_messages_count, p0.value.incoming_messages_count),
    i: 'i-lucide-arrow-down-left', c: '#0EA5E9', sp: spark(inSeries.value),
  },
  {
    k: 'out', n: 'Outgoing', v: fmtNum(s0.value.outgoing_messages_count),
    d: delta(s0.value.outgoing_messages_count, p0.value.outgoing_messages_count),
    i: 'i-lucide-arrow-up-right', c: '#8B5CF6', sp: spark(outSeries.value),
  },
]);

const queue = computed(() => [
  { n: 'Open', v: live.value.open, c: '#00A884' },
  { n: 'Pending', v: live.value.pending, c: '#F59E0B' },
  { n: 'Unassigned', v: live.value.unassigned, c: '#0EA5E9' },
  { n: 'Needs reply', v: live.value.unattended, c: '#EF4444' },
]);

/* ---- main chart ---- */
const CW = 800;
const CHH = 260;
const PADL = 42;
const PADT = 16;
const PADB = 28;
const chartMax = computed(() =>
  Math.max(
    1,
    ...series.value.map(p => num(p.value)),
    ...inSeries.value.map(p => num(p.value)),
    ...outSeries.value.map(p => num(p.value))
  )
);
const buildLine = pts => {
  if (!pts.length) return null;
  const vals = pts.map(p => num(p.value));
  const max = chartMax.value;
  const n = pts.length;
  const xAt = i => PADL + (n === 1 ? (CW - PADL) / 2 : (i / (n - 1)) * (CW - PADL - 10));
  const yAt = v => CHH - PADB - (v / max) * (CHH - PADT - PADB);
  const co = vals.map((v, i) => [xAt(i), yAt(v)]);
  let d = `M ${co[0][0]} ${co[0][1]}`;
  for (let i = 1; i < co.length; i += 1) {
    const [px, py] = co[i - 1];
    const [cx, cy] = co[i];
    const mx = (px + cx) / 2;
    d += ` C ${mx} ${py} ${mx} ${cy} ${cx} ${cy}`;
  }
  const step = Math.max(1, Math.ceil(n / (isMobile.value ? 4 : 8)));
  return {
    line: d,
    area: `${d} L ${co[co.length - 1][0]} ${CHH - PADB} L ${co[0][0]} ${CHH - PADB} Z`,
    dots: co.map(([cx, cy], i) => ({ cx, cy, v: vals[i], l: shortDate(pts[i].timestamp) })),
    ticks: co.map(([cx], i) => ({ x: cx, l: shortDate(pts[i].timestamp), i }))
      .filter(o => o.i % step === 0),
    total: vals.reduce((a, b) => a + b, 0),
  };
};
const chart = computed(() => buildLine(series.value));
const chartIn = computed(() => buildLine(inSeries.value));
const chartOut = computed(() => buildLine(outSeries.value));
const yTicks = computed(() => {
  const max = chartMax.value;
  return Array.from({ length: 5 }, (_, i) => ({
    v: Math.round((max / 4) * (4 - i)),
    y: PADT + ((CHH - PADT - PADB) / 4) * i,
  }));
});

/* ---- donut ---- */
const donut = computed(() => {
  const parts = [
    { n: 'Open', v: num(live.value.open), c: '#00A884' },
    { n: 'Pending', v: num(live.value.pending), c: '#F59E0B' },
    { n: 'Resolved', v: num(s0.value.resolutions_count), c: '#2F6BEB' },
  ].filter(p => p.v > 0);
  const total = parts.reduce((a, p) => a + p.v, 0);
  const R = 52;
  const C = 2 * Math.PI * R;
  if (!total) return { total: 0, parts: [], segs: [], R, C };
  let acc = 0;
  const segs = parts.map(p => {
    const frac = p.v / total;
    const seg = { c: p.c, dash: `${Math.max(0, frac * C - 4)} ${C}`, off: -acc * C, pct: Math.round(frac * 100) };
    acc += frac;
    return seg;
  });
  return { total, parts, segs, R, C };
});

/* ---- performance bars ---- */
const perf = computed(() => {
  const conv = num(s0.value.conversations_count);
  const res = num(s0.value.resolutions_count);
  const inc = num(s0.value.incoming_messages_count);
  const out = num(s0.value.outgoing_messages_count);
  const bot = num(s0.value.bot_resolutions_count);
  const pct = (a, b) => (b ? Math.min(100, Math.round((a / b) * 100)) : 0);
  return [
    { n: 'Resolution rate', v: `${pct(res, conv)}%`, p: pct(res, conv), c: '#00A884', s: `${res} of ${conv}` },
    { n: 'Reply ratio', v: `${pct(out, inc + out)}%`, p: pct(out, inc + out), c: '#2F6BEB', s: `${out} sent · ${inc} in` },
    { n: 'Handled by bot', v: `${pct(bot, conv)}%`, p: pct(bot, conv), c: '#F59E0B', s: bot ? `${bot} auto` : 'no bot activity' },
    { n: 'First reply', v: fmtDur(s0.value.avg_first_response_time), p: null, c: '#8B5CF6', s: `resolution ${fmtDur(s0.value.avg_resolution_time)}` },
  ];
});

const speeds = computed(() => [
  { n: 'First reply', v: fmtDur(s0.value.avg_first_response_time), i: 'i-lucide-zap', c: '#F59E0B' },
  { n: 'Resolution', v: fmtDur(s0.value.avg_resolution_time), i: 'i-lucide-flag', c: '#00A884' },
  { n: 'Reply time', v: fmtDur(s0.value.reply_time), i: 'i-lucide-timer', c: '#0EA5E9' },
]);

const inboxRows = computed(() => {
  const rows = inboxes.value.map(ib => ({
    id: ib.id, name: ib.name, kind: chKind(ib.channel_type),
    v: num(inboxCounts.value[ib.id]),
  }));
  const max = Math.max(1, ...rows.map(r => r.v));
  return rows.sort((a, b) => b.v - a.v)
    .map(r => ({ ...r, pct: Math.round((r.v / max) * 100) }));
});
const topAgents = computed(() =>
  [...agentStats.value].sort((a, b) => b.v - a.v).slice(0, 5)
);
const setupCards = computed(() => [
  { n: 'Agents', v: agents.value.length, i: 'i-lucide-square-user', c: '#8B5CF6', to: 'agent_list' },
  { n: 'Inboxes', v: inboxes.value.length, i: 'i-lucide-inbox', c: '#0EA5E9', to: 'settings_inbox_list' },
  { n: 'Chatbots', v: bots.value.length, i: 'i-lucide-bot', c: '#00A884', to: 'agent_bots' },
  { n: 'Teams', v: teams.value.length, i: 'i-lucide-users', c: '#F59E0B', to: 'settings_teams_list' },
  { n: 'Labels', v: labels.value.length, i: 'i-lucide-tags', c: '#EC4899', to: 'labels_list' },
  { n: 'Contacts', v: contactCount.value, i: 'i-lucide-contact', c: '#14B8A6', to: 'contacts_dashboard_index' },
  { n: 'Canned', v: cannedCount.value, i: 'i-lucide-message-square-quote', c: '#F97316', to: 'canned_list' },
]);

/* ---------------- load ---------------- */
const loadStatic = () =>
  Promise.all([
    soft(v1('/agents'), []), soft(v1('/inboxes'), null), soft(v1('/teams'), []),
    soft(v1('/labels'), null), soft(v1('/agent_bots'), []),
    soft(v1('/canned_responses'), []), soft(v1('/contacts?page=1'), null),
  ]).then(([ag, ib, tm, lb, bt, cn, ct]) => {
    agents.value = Array.isArray(ag) ? ag : ag?.payload || [];
    inboxes.value = ib?.payload || (Array.isArray(ib) ? ib : []);
    teams.value = Array.isArray(tm) ? tm : tm?.payload || [];
    labels.value = lb?.payload || (Array.isArray(lb) ? lb : []);
    bots.value = Array.isArray(bt) ? bt : bt?.payload || [];
    cannedCount.value = (Array.isArray(cn) ? cn : cn?.payload || []).length;
    contactCount.value = num(ct?.meta?.count) || (ct?.payload || []).length;
  });

const loadLive = () =>
  Promise.all([
    soft(v1('/conversations/meta?status=open'), null),
    soft(v1('/conversations/meta?status=pending'), null),
    soft(v2('/reports/conversations?type=account'), null),
  ]).then(([op, pd, rep]) => {
    live.value = {
      open: num(op?.meta?.all_count),
      pending: num(pd?.meta?.all_count),
      unassigned: num(op?.meta?.unassigned_count),
      unattended: num(rep?.unattended_count ?? rep?.unattended),
    };
  });

const loadReports = () => {
  const u = now();
  const s = since();
  const span = range.value * 86400;
  const qs = `since=${s}&until=${u}&type=account`;
  return Promise.all([
    soft(v2(`/reports/summary?${qs}`), null),
    soft(v2(`/reports/summary?since=${s - span}&until=${s}&type=account`), null),
    soft(v2(`/reports?metric=conversations_count&${qs}&group_by=day`), []),
    soft(v2(`/reports?metric=incoming_messages_count&${qs}&group_by=day`), []),
    soft(v2(`/reports?metric=outgoing_messages_count&${qs}&group_by=day`), []),
  ]).then(([sum, prev, a, b, c]) => {
    summary.value = sum;
    prevSummary.value = prev;
    const arr = x => (Array.isArray(x) ? x : x?.payload || []);
    series.value = arr(a);
    inSeries.value = arr(b);
    outSeries.value = arr(c);
  });
};

const loadAgentStats = () => {
  const u = now();
  const s = since();
  const list = agents.value.slice(0, 10);
  if (!list.length) {
    agentStats.value = [];
    return Promise.resolve();
  }
  return Promise.all(
    list.map(a =>
      soft(v2(`/reports/summary?since=${s}&until=${u}&type=agent&id=${a.id}`), null)
        .then(r => ({
          id: a.id,
          name: a.name || a.available_name || a.email,
          thumbnail: a.thumbnail,
          v: num(r?.conversations_count),
          resolved: num(r?.resolutions_count),
          frt: fmtDur(r?.avg_first_response_time),
        }))
    )
  ).then(rows => {
    agentStats.value = rows;
  });
};

const loadInboxCounts = () => {
  const u = now();
  const s = since();
  const list = inboxes.value.slice(0, 10);
  if (!list.length) return Promise.resolve();
  return Promise.all(
    list.map(ib =>
      soft(v2(`/reports/summary?since=${s}&until=${u}&type=inbox&id=${ib.id}`), null)
        .then(r => [ib.id, num(r?.conversations_count)])
    )
  ).then(pairs => {
    const out = {};
    pairs.forEach(([id, v]) => {
      out[id] = v;
    });
    inboxCounts.value = out;
  });
};

const loadRecent = () =>
  soft(v1('/conversations?status=open&page=1'), null).then(res => {
    const list = res?.data?.payload || res?.payload || [];
    recent.value = list.slice(0, 6);
  });

const refresh = (full = false) => {
  if (full) loading.value = true;
  const jobs = [loadReports(), loadLive(), loadRecent()];
  if (full)
    jobs.push(loadStatic().then(() => Promise.all([loadAgentStats(), loadInboxCounts()])));
  else jobs.push(loadAgentStats(), loadInboxCounts());
  return Promise.all(jobs)
    .catch(() => {})
    .finally(() => {
      loading.value = false;
      lastSync.value = Date.now();
    });
};

const pickRange = k => {
  range.value = k;
  refresh(false);
};
const go = name => {
  router.push({ name, params: { accountId: accountId.value } }).catch(() => {});
};
const openConv = c => {
  if (!c?.id) return;
  router.push({
    name: 'inbox_conversation',
    params: { accountId: accountId.value, conversation_id: c.id },
  });
};
const lastMsg = c => {
  const m = c?.messages || [];
  return m.length ? m[m.length - 1]?.content || 'Attachment' : 'No message yet';
};

/* ---------------- lifecycle ---------------- */
let themeObs = null;
let themePoll = null;
let timer = null;
/* Chatwoot ki apni themed surface ka asli rang dekh kar faisla.
   Pehle html.dark aur Tailwind probe try kiye the — dono is fork mein
   bharosay ke laaiq nahi nikle. Rang har tareeqe ke saath sahi rehta hai. */
const THEME_SEL =
  '[class*="bg-n-background"],[class*="bg-n-solid"],[class*="bg-n-alpha"],main';
const detectDark = () => {
  try {
    const els = document.querySelectorAll(THEME_SEL);
    for (let i = 0; i < els.length && i < 14; i += 1) {
      const el = els[i];
      if (el.closest('.cs-rail') || el.closest('.cs-app') || el.closest('.cs-dash'))
        continue;
      const m = getComputedStyle(el).backgroundColor.match(/[\d.]+/g);
      if (m && m.length >= 3 && (m.length < 4 || Number(m[3]) > 0.2)) {
        const lum = 0.299 * +m[0] + 0.587 * +m[1] + 0.114 * +m[2];
        return lum < 128;
      }
    }
  } catch (e) {
    /* ignore */
  }
  return (
    document.documentElement.classList.contains('dark') ||
    document.body.classList.contains('dark') ||
    !!document.querySelector('.dark')
  );
};
const readTheme = () => {
  const l = !detectDark();
  if (l !== isLight.value) isLight.value = l;
};
const onThemeEvent = e => {
  isLight.value = !e?.detail?.dark;
};
const onResize = () => {
  isMobile.value = window.innerWidth <= 768;
};

onMounted(() => {
  document.body.classList.add('cs-own-header');
  readTheme();
  window.addEventListener('chatssync:theme', onThemeEvent);
  themePoll = setInterval(readTheme, 1000);
  themeObs = new MutationObserver(readTheme);
  themeObs.observe(document.documentElement, { attributes: true });
  themeObs.observe(document.body, { attributes: true });
  window.addEventListener('resize', onResize);
  refresh(true);
  timer = setInterval(() => {
    if (!document.hidden) refresh(false);
  }, 60000);
});
onBeforeUnmount(() => {
  document.body.classList.remove('cs-own-header');
  window.removeEventListener('chatssync:theme', onThemeEvent);
  window.removeEventListener('resize', onResize);
  clearInterval(themePoll);
  if (themeObs) {
    themeObs.disconnect();
    themeObs = null;
  }
  clearInterval(timer);
});
watch(accountId, () => refresh(true));
</script>

<template>
  <section class="cs-dash" :class="{ lite: isLight }">
    <div class="cs-scroll">
      <!-- header -->
      <header class="cs-top">
        <span v-if="isMobile" class="cs-ham" @click.stop="openRail">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M4 6h16M4 12h16M4 18h16" stroke-linecap="round" />
          </svg>
        </span>
        <div class="cs-tt">
          <h1>Overview</h1>
          <span class="cs-today">{{ accountName }} · {{ rangeLabel }}</span>
        </div>
        <div class="cs-seg">
          <button
            v-for="r in RANGES"
            :key="r.k"
            :class="{ on: r.k === range }"
            @click="pickRange(r.k)"
          >
            {{ r.n }}
          </button>
        </div>
        <button class="cs-icb" title="Refresh" @click="refresh(true)">
          <span class="i-lucide-rotate-cw" />
        </button>
      </header>

      <!-- KPI -->
      <div class="cs-kpis">
        <div
          v-for="k in kpis"
          :key="k.k"
          class="cs-card cs-kpi"
          :style="{ color: k.c }"
        >
          <div class="cs-kh">
            <span class="cs-kic" :style="{ background: k.c + '1a', color: k.c }">
              <span :class="k.i" />
            </span>
            <span class="cs-kn">{{ k.n }}</span>
          </div>
          <div class="cs-kbody">
            <div class="cs-kv">
              <span v-if="loading" class="cs-shim w60" />
              <template v-else>{{ k.v }}</template>
            </div>
            <svg v-if="k.sp && !loading" class="cs-spark" viewBox="0 0 100 26" preserveAspectRatio="none">
              <path :d="k.sp" fill="none" :stroke="k.c" stroke-width="2" vector-effect="non-scaling-stroke" />
            </svg>
          </div>
          <div v-if="!loading" class="cs-kf">
            <span v-if="k.d !== null" class="cs-pill" :class="k.d >= 0 ? 'up' : 'dn'">
              <span :class="k.d >= 0 ? 'i-lucide-trending-up' : 'i-lucide-trending-down'" />
              {{ Math.abs(k.d) }}%
            </span>
            <span class="cs-kfp">vs previous period</span>
          </div>
        </div>
      </div>

      <!-- queue strip -->
      <div class="cs-card cs-queue">
        <div v-for="q in queue" :key="q.n" class="cs-qi" @click="go('home')">
          <span class="cs-qdot" :style="{ background: q.c }" />
          <b>{{ q.v }}</b>
          <span>{{ q.n }}</span>
        </div>
        <span class="cs-qlnk" @click="go('home')">Open Chats →</span>
      </div>

      <!-- chart + donut -->
      <div class="cs-row b">
        <div class="cs-card">
          <div class="cs-ch">
            <div>
              <h3>Activity</h3>
              <span class="cs-sub">{{ chart ? chart.total : 0 }} conversations · {{ rangeLabel }}</span>
            </div>
            <div class="cs-leg">
              <span><i style="background:#00A884" />Conversations</span>
              <span><i style="background:#0EA5E9" />Incoming</span>
              <span><i style="background:#8B5CF6" />Outgoing</span>
            </div>
          </div>
          <div v-if="loading" class="cs-shim tall" />
          <div v-else-if="!chart" class="cs-empty">
            <span class="i-lucide-chart-spline" /><span>No data for this range</span>
          </div>
          <svg v-else class="cs-svg" :viewBox="`0 0 ${CW} ${CHH}`">
            <defs>
              <linearGradient id="csDA" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#00A884" stop-opacity=".22" />
                <stop offset="100%" stop-color="#00A884" stop-opacity="0" />
              </linearGradient>
            </defs>
            <g v-for="(tk, i) in yTicks" :key="'y' + i">
              <line class="cs-gl" :x1="PADL" :y1="tk.y" :x2="CW - 6" :y2="tk.y" />
              <text class="cs-yt" :x="PADL - 10" :y="tk.y + 4">{{ tk.v }}</text>
            </g>
            <path :d="chart.area" fill="url(#csDA)" />
            <path v-if="chartIn" :d="chartIn.line" fill="none" stroke="#0EA5E9" stroke-width="1.8" />
            <path v-if="chartOut" :d="chartOut.line" fill="none" stroke="#8B5CF6" stroke-width="1.8" stroke-dasharray="5 4" />
            <path :d="chart.line" fill="none" stroke="#00A884" stroke-width="2.4" />
            <g v-for="(d, i) in chart.dots" :key="'d' + i">
              <circle :cx="d.cx" :cy="d.cy" r="3.2" class="cs-dotc" />
              <title>{{ d.l }} · {{ d.v }}</title>
            </g>
            <text v-for="(tk, i) in chart.ticks" :key="'x' + i" class="cs-xt" :x="tk.x" :y="CHH - 7">
              {{ tk.l }}
            </text>
          </svg>
        </div>

        <div class="cs-card">
          <div class="cs-ch"><h3>Status</h3></div>
          <div v-if="!donut.total" class="cs-empty sm">
            <span class="i-lucide-chart-pie" /><span>Nothing yet</span>
          </div>
          <template v-else>
            <div class="cs-dwrap">
              <svg viewBox="0 0 136 136" class="cs-donut">
                <circle cx="68" cy="68" :r="donut.R" class="cs-dtrack" />
                <circle
                  v-for="(sg, i) in donut.segs" :key="i"
                  cx="68" cy="68" :r="donut.R" fill="none"
                  :stroke="sg.c" stroke-width="13" stroke-linecap="round"
                  :stroke-dasharray="sg.dash" :stroke-dashoffset="sg.off"
                  transform="rotate(-90 68 68)"
                />
              </svg>
              <div class="cs-dmid"><b>{{ fmtNum(donut.total) }}</b><span>total</span></div>
            </div>
            <div class="cs-dleg">
              <div v-for="(p, i) in donut.parts" :key="p.n">
                <i :style="{ background: p.c }" />
                <span class="cs-dn">{{ p.n }}</span>
                <b>{{ p.v }}</b>
                <em>{{ donut.segs[i].pct }}%</em>
              </div>
            </div>
          </template>
        </div>
      </div>

      <!-- performance + channels + speed -->
      <div class="cs-row c3">
        <div class="cs-card">
          <div class="cs-ch"><h3>Performance</h3></div>
          <div v-for="p in perf" :key="p.n" class="cs-prow">
            <div class="cs-pl">
              <span class="cs-pn">{{ p.n }}</span>
              <span class="cs-ps">{{ p.s }}</span>
            </div>
            <div v-if="p.p !== null" class="cs-ptrack">
              <div class="cs-pfill" :style="{ width: p.p + '%', background: p.c }" />
            </div>
            <b class="cs-pv" :style="{ color: p.c }">{{ p.v }}</b>
          </div>
        </div>

        <div class="cs-card">
          <div class="cs-ch">
            <h3>Channels</h3>
            <span class="cs-lnk" @click="go('settings_inbox_list')">Manage</span>
          </div>
          <div v-if="!inboxRows.length" class="cs-empty sm">
            <span class="i-lucide-inbox" /><span>No inboxes connected</span>
          </div>
          <div v-for="r in inboxRows" :key="r.id" class="cs-brow">
            <span class="cs-bnm"><i :style="{ background: CH_COLOR[r.kind] }" />{{ r.name }}</span>
            <div class="cs-btrack">
              <div class="cs-bfill" :style="{ width: r.pct + '%', background: CH_COLOR[r.kind] }" />
            </div>
            <b>{{ r.v }}</b>
          </div>
        </div>

        <div class="cs-card">
          <div class="cs-ch"><h3>Response speed</h3></div>
          <div class="cs-speed">
            <div v-for="sp in speeds" :key="sp.n" class="cs-sp">
              <span class="cs-spic" :style="{ background: sp.c + '1a', color: sp.c }">
                <span :class="sp.i" />
              </span>
              <div>
                <b>{{ sp.v }}</b>
                <span>{{ sp.n }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- agents table + recent -->
      <div class="cs-row b">
        <div class="cs-card">
          <div class="cs-ch">
            <h3>Team performance</h3>
            <span class="cs-lnk" @click="go('agent_list')">Manage</span>
          </div>
          <div v-if="!topAgents.length" class="cs-empty sm">
            <span class="i-lucide-square-user" /><span>No agent activity</span>
          </div>
          <table v-else class="cs-tbl">
            <thead>
              <tr><th>Agent</th><th>Chats</th><th>Resolved</th><th>First reply</th></tr>
            </thead>
            <tbody>
              <tr v-for="a in topAgents" :key="a.id">
                <td>
                  <div class="cs-tag">
                    <span class="cs-av" :style="{ background: avColor(a.id) }">
                      <img v-if="a.thumbnail" :src="a.thumbnail" alt="" />
                      <template v-else>{{ initials(a.name) }}</template>
                    </span>
                    <span class="cs-tnm">{{ a.name }}</span>
                  </div>
                </td>
                <td><b>{{ a.v }}</b></td>
                <td>{{ a.resolved }}</td>
                <td>{{ a.frt }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="cs-card">
          <div class="cs-ch">
            <h3>Recent</h3>
            <span class="cs-lnk" @click="go('home')">All</span>
          </div>
          <div v-if="!recent.length" class="cs-empty sm">
            <span class="i-lucide-message-circle" /><span>Nothing open</span>
          </div>
          <div v-for="c in recent" :key="c.id" class="cs-rrow" @click="openConv(c)">
            <span class="cs-av sm" :style="{ background: avColor(c.id) }">
              {{ initials(c.meta?.sender?.name) }}
            </span>
            <div class="cs-rrb">
              <div class="cs-rnm">{{ c.meta?.sender?.name || 'Unknown' }}</div>
              <div class="cs-rms">{{ lastMsg(c) }}</div>
            </div>
            <span class="cs-rtm">{{ agoOf(c.timestamp) }}</span>
          </div>
        </div>
      </div>

      <!-- workspace -->
      <div class="cs-card">
        <div class="cs-ch"><h3>Workspace</h3></div>
        <div class="cs-sgrid">
          <div v-for="sc in setupCards" :key="sc.n" class="cs-scell" @click="go(sc.to)">
            <span class="cs-scic" :class="sc.i" :style="{ background: sc.c + '1a', color: sc.c }" />
            <b>{{ sc.v }}</b>
            <span>{{ sc.n }}</span>
          </div>
        </div>
      </div>

    <span ref="probeEl" class="cs-probe hidden dark:block" aria-hidden="true" />

      <div class="cs-foot">
        <span v-if="lastSync">Updated {{ agoOf(Math.floor(lastSync / 1000)) }} ago · auto refresh</span>
      </div>
    </div>
  </section>
</template>

<style scoped>
.cs-dash {
  --panel: #131f26;
  --tx: #e9edef;
  --tx2: #aebac1;
  --tx3: #7d8f99;
  --ln: #223039;
  --hov: #1a272f;
  --fld: #1a272f;
  --g: #00a884;
  --content: #0d171d;

  width: 100%;
  height: 100%;
  min-width: 0;
  display: flex;
  background: var(--content);
  color: var(--tx);
  font-size: 14px;
}
.cs-dash.lite {
  --panel: #ffffff;
  --tx: #0f1c24;
  --tx2: #465962;
  --tx3: #6b7d86;
  --ln: #e4eaec;
  --hov: #f3f6f7;
  --fld: #f1f5f6;
  --g: #00755f;
  --content: #f6f8f9;
}
.cs-dash * {
  box-sizing: border-box;
}
.cs-scroll {
  flex: 1;
  min-width: 0;
  overflow-y: auto;
  padding: 20px 22px 32px;
}

/* header */
.cs-top {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
}
.cs-ham {
  width: 38px;
  height: 38px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: var(--tx2);
  cursor: pointer;
  flex-shrink: 0;
  margin-inline-start: -6px;
}
.cs-ham:hover {
  background: var(--hov);
}
.cs-ham svg {
  width: 21px;
  height: 21px;
}
.cs-tt {
  flex: 1;
  min-width: 0;
}
.cs-top h1 {
  font-size: 21px;
  font-weight: 650;
  margin: 0 0 2px;
  letter-spacing: -0.01em;
}
.cs-today {
  font-size: 12px;
  color: var(--tx3);
}
.cs-seg {
  display: flex;
  background: var(--fld);
  border: 1px solid var(--ln);
  border-radius: 10px;
  padding: 3px;
  gap: 2px;
  flex-shrink: 0;
}
.cs-seg button {
  border: 0;
  background: transparent;
  color: var(--tx3);
  font-family: inherit;
  font-size: 12.5px;
  font-weight: 600;
  padding: 6px 13px;
  border-radius: 7px;
  cursor: pointer;
}
.cs-seg button.on {
  background: var(--panel);
  color: var(--g);
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.14);
}
.cs-icb {
  width: 38px;
  height: 38px;
  display: grid;
  place-items: center;
  border-radius: 10px;
  border: 1px solid var(--ln);
  background: var(--panel);
  color: var(--tx2);
  cursor: pointer;
  flex-shrink: 0;
}
.cs-icb:hover {
  background: var(--hov);
}
.cs-icb span {
  width: 16px;
  height: 16px;
}

/* cards */
.cs-card {
  position: relative;
  background: var(--panel);
  border: 1px solid var(--ln);
  border-radius: 14px;
  padding: 16px 17px;
  margin-bottom: 13px;
  /* halka sa upar uthta hai — flat nahi lagta */
  transition: transform 0.18s ease, box-shadow 0.18s ease,
    border-color 0.18s ease;
  animation: csRise 0.42s cubic-bezier(0.22, 0.8, 0.3, 1) both;
}
.cs-card:hover {
  transform: translateY(-2px);
  border-color: color-mix(in srgb, var(--g) 40%, var(--ln));
  box-shadow: 0 10px 26px rgba(0, 0, 0, 0.22);
}
.cs-dash.lite .cs-card:hover {
  box-shadow: 0 10px 26px rgba(15, 28, 36, 0.09);
}
@keyframes csRise {
  from {
    opacity: 0;
    transform: translateY(12px);
  }
  to {
    opacity: 1;
    transform: none;
  }
}
/* thoda thoda kar ke aate hain */
.cs-kpis .cs-card:nth-child(1) { animation-delay: 0.02s; }
.cs-kpis .cs-card:nth-child(2) { animation-delay: 0.07s; }
.cs-kpis .cs-card:nth-child(3) { animation-delay: 0.12s; }
.cs-kpis .cs-card:nth-child(4) { animation-delay: 0.17s; }
.cs-queue { animation-delay: 0.2s; }
.cs-row.b { animation: none; }
.cs-row.b > .cs-card:nth-child(1) { animation-delay: 0.24s; }
.cs-row.b > .cs-card:nth-child(2) { animation-delay: 0.29s; }
.cs-row.c3 > .cs-card:nth-child(1) { animation-delay: 0.3s; }
.cs-row.c3 > .cs-card:nth-child(2) { animation-delay: 0.34s; }
.cs-row.c3 > .cs-card:nth-child(3) { animation-delay: 0.38s; }
/* GRID ki jagah FLEX. auto-fit grid wide screen par khali track
   chhoR deti thi (isi liye dashboard mein itni khali jagah lag rahi thi).
   flex-wrap + flex-grow har haal mein poori chauRai bhar deta hai, aur
   viewport nahi balke asli jagah dekh kar toot-ta hai — mobile par bhi
   theek. */
.cs-row {
  display: flex;
  flex-wrap: wrap;
  gap: 13px;
  margin-bottom: 13px;
  align-items: stretch;
}
.cs-row > .cs-card {
  flex: 1 1 300px;
  min-width: 0;
}
/* chart wala card doguna chauRa */
.cs-row.b > .cs-card:first-child {
  flex: 2.2 1 420px;
}
.cs-row.c3 > .cs-card {
  flex: 1 1 250px;
}

/* speed card */
.cs-speed {
  display: flex;
  flex-direction: column;
  gap: 11px;
}
.cs-sp {
  display: flex;
  align-items: center;
  gap: 12px;
  background: var(--fld);
  border-radius: 11px;
  padding: 12px 13px;
}
.cs-spic {
  width: 34px;
  height: 34px;
  border-radius: 10px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}
.cs-spic span {
  width: 16px;
  height: 16px;
}
.cs-sp b {
  display: block;
  font-size: 17px;
  font-weight: 700;
  line-height: 1.15;
}
.cs-sp > div > span {
  font-size: 11px;
  color: var(--tx3);
}
.cs-row > .cs-card {
  margin-bottom: 0;
}

/* KPI */
.cs-kpis {
  display: flex;
  flex-wrap: wrap;
  gap: 13px;
  margin-bottom: 13px;
}
.cs-kpis > .cs-card {
  flex: 1 1 190px;
  min-width: 0;
}
.cs-kpi {
  margin-bottom: 0;
  padding: 15px 16px;
  overflow: hidden;
}
/* upar patli rangeen lakeer — hover par chamakti hai */
.cs-kpi::before {
  content: '';
  position: absolute;
  inset: 0 0 auto;
  height: 2px;
  background: currentColor;
  opacity: 0.25;
  transition: opacity 0.18s;
}
.cs-kpi:hover::before {
  opacity: 0.9;
}
.cs-kh {
  display: flex;
  align-items: center;
  gap: 9px;
  margin-bottom: 12px;
}
.cs-kic {
  width: 30px;
  height: 30px;
  border-radius: 9px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}
.cs-kic span {
  width: 15px;
  height: 15px;
}
.cs-kpi .cs-kv,
.cs-kpi .cs-kfp {
  color: var(--tx);
}
.cs-kpi .cs-kfp {
  color: var(--tx3);
}
.cs-kn {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--tx3);
}
.cs-kbody {
  display: flex;
  align-items: flex-end;
  gap: 10px;
  margin-bottom: 10px;
}
.cs-kv {
  flex: 1;
  min-width: 0;
  font-size: 27px;
  font-weight: 700;
  line-height: 1;
  letter-spacing: -0.02em;
}
.cs-spark {
  width: 74px;
  height: 26px;
  flex-shrink: 0;
  opacity: 0.85;
}
.cs-kf {
  display: flex;
  align-items: center;
  gap: 8px;
}
.cs-kfp {
  font-size: 10.5px;
  color: var(--tx3);
}
.cs-pill {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  font-size: 11px;
  font-weight: 600;
  border-radius: 6px;
  padding: 3px 7px;
}
.cs-pill span {
  width: 12px;
  height: 12px;
}
.cs-pill.up {
  background: rgba(34, 197, 94, 0.14);
  color: #22c55e;
}
.cs-pill.dn {
  background: rgba(239, 68, 68, 0.14);
  color: #ef4444;
}

/* queue */
.cs-queue {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
  padding: 13px 17px;
}
.cs-qi {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 14px 6px 12px;
  border-radius: 9px;
  cursor: pointer;
}
.cs-qi:hover {
  background: var(--hov);
}
.cs-qdot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}
.cs-qi b {
  font-size: 17px;
  font-weight: 700;
}
.cs-qi span:last-child {
  font-size: 12px;
  color: var(--tx3);
}
.cs-qlnk {
  margin-inline-start: auto;
  font-size: 12.5px;
  color: var(--g);
  cursor: pointer;
  font-weight: 500;
}

/* card head */
.cs-ch {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 14px;
}
.cs-ch h3 {
  font-size: 14.5px;
  font-weight: 650;
  margin: 0;
}
.cs-sub {
  font-size: 11.5px;
  color: var(--tx3);
}
.cs-lnk {
  font-size: 12px;
  color: var(--g);
  cursor: pointer;
  flex-shrink: 0;
  font-weight: 500;
}
.cs-leg {
  display: flex;
  gap: 11px;
  font-size: 10.5px;
  color: var(--tx3);
  flex-wrap: wrap;
  flex-shrink: 0;
}
.cs-leg span {
  display: flex;
  align-items: center;
  gap: 5px;
}
.cs-leg i {
  width: 7px;
  height: 7px;
  border-radius: 50%;
}

/* chart */
.cs-svg {
  width: 100%;
  height: 260px;
  display: block;
}
/* line khud ban-ti hui aati hai */
.cs-svg path[stroke] {
  stroke-dasharray: 2200;
  stroke-dashoffset: 2200;
  animation: csDraw 1.1s cubic-bezier(0.4, 0, 0.2, 1) 0.2s forwards;
}
@keyframes csDraw {
  to {
    stroke-dashoffset: 0;
  }
}
.cs-svg path[fill^='url'] {
  animation: csFade 0.7s ease 0.7s both;
}
@keyframes csFade {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}
/* bars aur rings bhi bharte hue */
@media (prefers-reduced-motion: reduce) {
  .cs-card,
  .cs-svg path[stroke],
  .cs-svg path[fill^='url'] {
    animation: none;
  }
}
.cs-gl {
  stroke: var(--ln);
  stroke-width: 1;
}
.cs-yt {
  fill: var(--tx3);
  font-size: 10px;
  text-anchor: end;
}
.cs-xt {
  fill: var(--tx3);
  font-size: 10px;
  text-anchor: middle;
}
.cs-dotc {
  fill: var(--panel);
  stroke: #00a884;
  stroke-width: 2.2;
  opacity: 0;
}
.cs-svg:hover .cs-dotc {
  opacity: 1;
}

/* donut */
.cs-dwrap {
  position: relative;
  width: 152px;
  margin: 4px auto 12px;
}
.cs-donut {
  width: 100%;
  display: block;
}
.cs-dtrack {
  fill: none;
  stroke: var(--fld);
  stroke-width: 13;
}
.cs-dmid {
  position: absolute;
  inset: 0;
  display: grid;
  place-content: center;
  text-align: center;
}
.cs-dmid b {
  display: block;
  font-size: 23px;
  font-weight: 700;
}
.cs-dmid span {
  font-size: 10.5px;
  color: var(--tx3);
}
.cs-dleg > div {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 6px 0;
  font-size: 12.5px;
}
.cs-dleg i {
  width: 8px;
  height: 8px;
  border-radius: 2px;
  flex-shrink: 0;
}
.cs-dn {
  flex: 1;
  color: var(--tx2);
}
.cs-dleg em {
  font-style: normal;
  font-size: 11px;
  color: var(--tx3);
  width: 32px;
  text-align: end;
}

/* performance */
.cs-prow {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 9px 0;
}
.cs-pl {
  width: 132px;
  flex-shrink: 0;
}
.cs-pn {
  display: block;
  font-size: 13px;
  margin-bottom: 2px;
}
.cs-ps {
  font-size: 10.5px;
  color: var(--tx3);
}
.cs-ptrack {
  flex: 1;
  min-width: 0;
  height: 7px;
  border-radius: 5px;
  background: var(--fld);
  overflow: hidden;
}
.cs-pfill {
  height: 100%;
  border-radius: 5px;
  transition: width 0.4s ease;
}
.cs-pv {
  width: 52px;
  text-align: end;
  font-size: 14px;
  flex-shrink: 0;
}

/* channels */
.cs-brow {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 7px 0;
  font-size: 12.5px;
}
.cs-bnm {
  width: 96px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  gap: 7px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-bnm i {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.cs-btrack {
  flex: 1;
  min-width: 0;
  height: 7px;
  border-radius: 5px;
  background: var(--fld);
  overflow: hidden;
}
.cs-bfill {
  height: 100%;
  border-radius: 5px;
  transition: width 0.4s ease;
}
.cs-brow b {
  width: 30px;
  text-align: end;
  flex-shrink: 0;
}

/* table */
.cs-tbl {
  width: 100%;
  border-collapse: collapse;
  font-size: 12.5px;
}
.cs-tbl th {
  text-align: start;
  font-size: 10.5px;
  font-weight: 600;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: var(--tx3);
  padding: 0 0 9px;
  border-bottom: 1px solid var(--ln);
}
.cs-tbl th:not(:first-child),
.cs-tbl td:not(:first-child) {
  text-align: end;
  width: 74px;
}
.cs-tbl td {
  padding: 9px 0;
  border-bottom: 1px solid var(--ln);
  color: var(--tx2);
}
.cs-tbl tr:last-child td {
  border-bottom: none;
}
.cs-tbl td b {
  color: var(--tx);
  font-size: 13.5px;
}
.cs-tag {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}
.cs-tnm {
  color: var(--tx);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-av {
  width: 30px;
  height: 30px;
  border-radius: 9px;
  display: grid;
  place-items: center;
  color: #fff;
  font-size: 11px;
  font-weight: 600;
  flex-shrink: 0;
  overflow: hidden;
}
.cs-av.sm {
  width: 32px;
  height: 32px;
  border-radius: 10px;
}
.cs-av img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

/* recent */
.cs-rrow {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 8px 0;
  cursor: pointer;
  border-radius: 9px;
}
.cs-rrow:hover {
  background: var(--hov);
}
.cs-rrb {
  flex: 1;
  min-width: 0;
}
.cs-rnm {
  font-size: 13px;
  margin-bottom: 2px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-rms {
  font-size: 11.5px;
  color: var(--tx3);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-rtm {
  font-size: 10.5px;
  color: var(--tx3);
  flex-shrink: 0;
}

/* workspace */
.cs-sgrid {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}
.cs-sgrid > .cs-scell {
  flex: 1 1 92px;
  min-width: 0;
}
.cs-scell {
  background: var(--fld);
  border-radius: 12px;
  padding: 13px 8px;
  text-align: center;
  cursor: pointer;
  transition: transform 0.12s;
}
.cs-scell:hover {
  transform: translateY(-2px);
}
.cs-scic {
  width: 30px;
  height: 30px;
  border-radius: 9px;
  margin: 0 auto 8px;
  display: block;
}
.cs-scell b {
  display: block;
  font-size: 16px;
  margin-bottom: 2px;
}
.cs-scell span {
  font-size: 10.5px;
  color: var(--tx3);
}

/* empty + shimmer */
.cs-empty {
  padding: 40px 16px;
  text-align: center;
  color: var(--tx3);
  font-size: 12.5px;
}
.cs-empty.sm {
  padding: 24px 12px;
}
.cs-empty span[class*='i-'] {
  width: 26px;
  height: 26px;
  opacity: 0.45;
  margin: 0 auto 9px;
  display: block;
}
.cs-shim {
  display: block;
  height: 24px;
  border-radius: 6px;
  background: var(--fld);
  animation: csP 1.3s ease-in-out infinite;
}
.cs-shim.w60 {
  width: 60%;
}
.cs-shim.tall {
  height: 260px;
}
@keyframes csP {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
}
.cs-foot {
  text-align: center;
  font-size: 11px;
  color: var(--tx3);
  padding: 2px 0;
}

/* responsive */
/* grid ab khud sambhalti hai — yahan sirf spacing/typography */
@media (max-width: 768px) {
  .cs-scroll {
    padding: 14px 12px 28px;
  }
  .cs-top h1 {
    font-size: 19px;
  }
  .cs-top {
    flex-wrap: wrap;
  }
  .cs-tt {
    flex: 1 1 60%;
  }
  .cs-card {
    padding: 14px 13px;
  }
  .cs-kv {
    font-size: 23px;
  }
  .cs-svg {
    height: 210px;
  }
  .cs-pl {
    width: 108px;
  }
  .cs-bnm {
    width: 82px;
  }
  .cs-tbl th:nth-child(4),
  .cs-tbl td:nth-child(4) {
    display: none;
  }
}

.cs-probe {
  position: fixed;
  top: -20px;
  inset-inline-start: -20px;
  width: 1px;
  height: 1px;
  pointer-events: none;
  opacity: 0;
}

</style>
