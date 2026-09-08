<script setup>
/* =====================================================================
   DashboardScreen.vue  —  ChatsSync Dashboard
   Har account ka apna live data, Chatwoot ke apne endpoints se.
   Koi backend kaam nahi. Har card alag load hota hai — ek gire to
   baqi phir bhi bharte hain.
   ===================================================================== */
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store.js';

const router = useRouter();
const accountId = useMapGetter('getCurrentAccountId');
const currentUser = useMapGetter('getCurrentUser');
const currentAccount = useMapGetter('getCurrentAccount');

/* ---------------- API ---------------- */
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
        h['access-token'] = sess['access-token'];
        h['token-type'] = sess['token-type'] || 'Bearer';
        h.client = sess.client;
        h.expiry = sess.expiry;
        h.uid = sess.uid;
        h.api_access_token = sess['access-token'];
      }
    }
  } catch (e) {
    /* ignore */
  }
  const tok = currentUser.value?.access_token;
  if (tok) h.api_access_token = tok;
  return h;
};
const call = (ver, path) =>
  fetch(`/api/${ver}/accounts/${accountId.value}${path}`, {
    credentials: 'same-origin',
    headers: authHeaders(),
  }).then(r => {
    if (!r.ok) throw new Error(`${path} → ${r.status}`);
    return r.json();
  });
const v1 = p => call('v1', p);
const v2 = p => call('v2', p);
const soft = (p, fb = null) => p.catch(() => fb);

/* ---------------- state ---------------- */
const RANGES = [
  { k: 7, n: 'Last 7 days' },
  { k: 30, n: 'Last 30 days' },
  { k: 90, n: 'Last 90 days' },
];
const range = ref(30);
const loading = ref(true);
const isLight = ref(false);
const isMobile = ref(window.innerWidth <= 768);
const rangeMenu = ref(false);
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
  if (m < 1) return 'just now';
  if (m < 60) return `${m}m ago`;
  if (m < 1440) return `${Math.floor(m / 60)}h ago`;
  return `${Math.floor(m / 1440)}d ago`;
};
const todayLine = computed(() =>
  new Date()
    .toLocaleDateString(undefined, {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    })
    .toUpperCase()
);
const fullName = computed(() => currentUser.value?.name || 'there');
const accountName = computed(() => currentAccount.value?.name || 'Workspace');
const rangeName = computed(
  () => RANGES.find(r => r.k === range.value)?.n || ''
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

/* teen rangeen tiles (reference jaisi) */
const tiles = computed(() => [
  {
    k: 'conv', n: 'Conversations',
    v: fmtNum(s0.value.conversations_count),
    d: delta(s0.value.conversations_count, p0.value.conversations_count),
    i: 'i-lucide-messages-square',
    g: 'linear-gradient(135deg,#00A884 0%,#04735E 100%)',
    sh: 'rgba(0,168,132,.28)',
  },
  {
    k: 'res', n: 'Resolved',
    v: fmtNum(s0.value.resolutions_count),
    d: delta(s0.value.resolutions_count, p0.value.resolutions_count),
    i: 'i-lucide-check-check',
    g: 'linear-gradient(135deg,#2F6BEB 0%,#1E3FA8 100%)',
    sh: 'rgba(47,107,235,.28)',
  },
  {
    k: 'ppl', n: 'Contacts',
    v: fmtNum(contactCount.value),
    d: null,
    i: 'i-lucide-contact',
    g: 'linear-gradient(135deg,#F5A524 0%,#C2660A 100%)',
    sh: 'rgba(245,165,36,.28)',
  },
]);

/* chhote metric cards */
const metrics = computed(() => [
  { n: 'Incoming', v: fmtNum(s0.value.incoming_messages_count),
    d: delta(s0.value.incoming_messages_count, p0.value.incoming_messages_count),
    i: 'i-lucide-arrow-down-left', c: '#0EA5E9' },
  { n: 'Outgoing', v: fmtNum(s0.value.outgoing_messages_count),
    d: delta(s0.value.outgoing_messages_count, p0.value.outgoing_messages_count),
    i: 'i-lucide-arrow-up-right', c: '#8B5CF6' },
  { n: 'Open now', v: fmtNum(live.value.open), d: null,
    i: 'i-lucide-message-circle', c: '#22C55E' },
  { n: 'Needs reply', v: fmtNum(live.value.unattended), d: null,
    i: 'i-lucide-alarm-clock', c: '#EF4444' },
]);

/* ---- area chart ---- */
const CW = 780;
const CHH = 250;
const PADL = 40;
const PADT = 18;
const PADB = 30;
const buildArea = (pts, maxOverride) => {
  if (!pts.length) return null;
  const vals = pts.map(p => num(p.value));
  const max = maxOverride || Math.max(1, ...vals);
  const n = pts.length;
  const xAt = i => PADL + (n === 1 ? (CW - PADL) / 2 : (i / (n - 1)) * (CW - PADL - 8));
  const yAt = v => CHH - PADB - (v / max) * (CHH - PADT - PADB);
  const co = vals.map((v, i) => [xAt(i), yAt(v)]);
  let line = `M ${co[0][0]} ${co[0][1]}`;
  for (let i = 1; i < co.length; i += 1) {
    const [px, py] = co[i - 1];
    const [cx, cy] = co[i];
    const mx = (px + cx) / 2;
    line += ` C ${mx} ${py} ${mx} ${cy} ${cx} ${cy}`;
  }
  const area = `${line} L ${co[co.length - 1][0]} ${CHH - PADB} L ${co[0][0]} ${CHH - PADB} Z`;
  const step = Math.max(1, Math.ceil(n / (isMobile.value ? 4 : 7)));
  return {
    line, area, max,
    dots: co.map(([cx, cy], i) => ({ cx, cy, v: vals[i], l: shortDate(pts[i].timestamp) })),
    ticks: co
      .map(([cx], i) => ({ x: cx, l: shortDate(pts[i].timestamp), i }))
      .filter(o => o.i % step === 0),
    total: vals.reduce((a, b) => a + b, 0),
  };
};
const chartMax = computed(() => {
  const a = series.value.map(p => num(p.value));
  const b = inSeries.value.map(p => num(p.value));
  const c = outSeries.value.map(p => num(p.value));
  return Math.max(1, ...a, ...b, ...c);
});
const chart = computed(() => buildArea(series.value, chartMax.value));
const chart2 = computed(() => buildArea(inSeries.value, chartMax.value));
const chart3 = computed(() => buildArea(outSeries.value, chartMax.value));
const yTicks = computed(() => {
  const max = chartMax.value;
  const steps = 4;
  return Array.from({ length: steps + 1 }, (_, i) => {
    const v = Math.round((max / steps) * (steps - i));
    return { v, y: PADT + ((CHH - PADT - PADB) / steps) * i };
  });
});

/* ---- donut ---- */
const donut = computed(() => {
  const parts = [
    { n: 'Open', v: num(live.value.open), c: '#00A884' },
    { n: 'Pending', v: num(live.value.pending), c: '#F5A524' },
    { n: 'Resolved', v: num(s0.value.resolutions_count), c: '#2F6BEB' },
  ].filter(p => p.v > 0);
  const total = parts.reduce((a, p) => a + p.v, 0);
  const R = 56;
  const C = 2 * Math.PI * R;
  if (!total) return { total: 0, parts: [], segs: [], R, C };
  let acc = 0;
  const segs = parts.map(p => {
    const frac = p.v / total;
    const seg = { c: p.c, dash: `${frac * C - 3} ${C}`, off: -acc * C, pct: Math.round(frac * 100) };
    acc += frac;
    return seg;
  });
  return { total, parts, segs, R, C };
});

/* ---- rings ---- */
const mkRing = (pct, color) => {
  const R = 42;
  const C = 2 * Math.PI * R;
  const p = Math.max(0, Math.min(100, Math.round(pct)));
  return { pct: p, R, C, dash: `${(p / 100) * C} ${C}`, color };
};
const rings = computed(() => {
  const conv = num(s0.value.conversations_count);
  const res = num(s0.value.resolutions_count);
  const inc = num(s0.value.incoming_messages_count);
  const out = num(s0.value.outgoing_messages_count);
  const bot = num(s0.value.bot_resolutions_count);
  return [
    {
      n: 'Resolution rate', sub: `${res} of ${conv} resolved`,
      ...mkRing(conv ? (res / conv) * 100 : 0, '#00A884'),
      foot: fmtDur(s0.value.avg_resolution_time), footN: 'avg time',
    },
    {
      n: 'Reply ratio', sub: `${out} sent · ${inc} received`,
      ...mkRing(inc + out ? (out / (inc + out)) * 100 : 0, '#2F6BEB'),
      foot: fmtDur(s0.value.avg_first_response_time), footN: 'first reply',
    },
    {
      n: 'Handled by bot', sub: bot ? `${bot} auto-resolved` : 'no bot activity',
      ...mkRing(conv ? (bot / conv) * 100 : 0, '#F5A524'),
      foot: String(bots.value.length), footN: 'bots live',
    },
  ];
});

const inboxRows = computed(() => {
  const rows = inboxes.value.map(ib => ({
    id: ib.id, name: ib.name, kind: chKind(ib.channel_type),
    v: num(inboxCounts.value[ib.id]),
  }));
  const max = Math.max(1, ...rows.map(r => r.v));
  return rows.sort((a, b) => b.v - a.v)
    .map(r => ({ ...r, pct: Math.round((r.v / max) * 100) }));
});
const topAgents = computed(() => {
  const max = Math.max(1, ...agentStats.value.map(a => a.v));
  return [...agentStats.value].sort((a, b) => b.v - a.v).slice(0, 5)
    .map(a => ({ ...a, pct: Math.round((a.v / max) * 100) }));
});
const setupCards = computed(() => [
  { n: 'Agents', v: agents.value.length, i: 'i-lucide-square-user', c: '#8B5CF6', to: 'agent_list' },
  { n: 'Inboxes', v: inboxes.value.length, i: 'i-lucide-inbox', c: '#0EA5E9', to: 'settings_inbox_list' },
  { n: 'Chatbots', v: bots.value.length, i: 'i-lucide-bot', c: '#00A884', to: 'agent_bots' },
  { n: 'Teams', v: teams.value.length, i: 'i-lucide-users', c: '#F5A524', to: 'settings_teams_list' },
  { n: 'Labels', v: labels.value.length, i: 'i-lucide-tags', c: '#EC4899', to: 'labels_list' },
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
    recent.value = list.slice(0, 5);
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
  rangeMenu.value = false;
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
let timer = null;
const readTheme = () => {
  isLight.value = !(
    document.documentElement.classList.contains('dark') ||
    document.body.classList.contains('dark')
  );
};
const closeMenus = () => {
  rangeMenu.value = false;
};
const onResize = () => {
  isMobile.value = window.innerWidth <= 768;
};

onMounted(() => {
  document.body.classList.add('cs-own-header');
  readTheme();
  themeObs = new MutationObserver(readTheme);
  themeObs.observe(document.documentElement, {
    attributes: true, attributeFilter: ['class'],
  });
  document.addEventListener('click', closeMenus);
  window.addEventListener('resize', onResize);
  refresh(true);
  timer = setInterval(() => {
    if (!document.hidden) refresh(false);
  }, 60000);
});
onBeforeUnmount(() => {
  document.body.classList.remove('cs-own-header');
  document.removeEventListener('click', closeMenus);
  window.removeEventListener('resize', onResize);
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
      <!-- ======= TOP ======= -->
      <header class="cs-top">
        <span v-if="isMobile" class="cs-ham" @click.stop="openRail">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M4 6h16M4 12h16M4 18h16" stroke-linecap="round" />
          </svg>
        </span>
        <div class="cs-tt">
          <h1>Dashboard</h1>
          <span class="cs-today">{{ accountName }} · {{ todayLine }}</span>
        </div>
        <div class="cs-tact">
          <div class="cs-rg" @click.stop="rangeMenu = !rangeMenu">
            <span class="i-lucide-calendar" />
            <span class="cs-rgt">{{ rangeName }}</span>
            <span class="i-lucide-chevron-down" />
            <div v-if="rangeMenu" class="cs-rgm" @click.stop>
              <div
                v-for="r in RANGES"
                :key="r.k"
                class="cs-rgi"
                :class="{ on: r.k === range }"
                @click="pickRange(r.k)"
              >
                {{ r.n }}
              </div>
            </div>
          </div>
          <button class="cs-icb" title="Refresh" @click="refresh(true)">
            <span class="i-lucide-rotate-cw" />
          </button>
        </div>
      </header>

      <!-- ======= WELCOME + TILES ======= -->
      <div class="cs-row a">
        <div class="cs-card cs-welcome">
          <div class="cs-wav" :style="{ background: avColor(currentUser?.id) }">
            {{ initials(fullName) }}
          </div>
          <div class="cs-wn">{{ fullName }}</div>
          <div class="cs-ws">WELCOME BACK</div>
          <div class="cs-wl">
            <div>
              <b>{{ live.open }}</b><span>Open</span>
            </div>
            <div>
              <b>{{ live.unassigned }}</b><span>Unassigned</span>
            </div>
          </div>
        </div>

        <div class="cs-tiles">
          <div
            v-for="tl in tiles"
            :key="tl.k"
            class="cs-tile"
            :style="{ background: tl.g, boxShadow: '0 8px 22px ' + tl.sh }"
          >
            <span class="cs-tglow" />
            <span class="cs-tic" :class="tl.i" />
            <div class="cs-tn">{{ tl.n }}</div>
            <div class="cs-tv">
              <span v-if="loading" class="cs-shim light w50" />
              <template v-else>{{ tl.v }}</template>
            </div>
            <span v-if="tl.d !== null && !loading" class="cs-tdel">
              {{ tl.d >= 0 ? '▲' : '▼' }} {{ Math.abs(tl.d) }}%
            </span>
          </div>
        </div>
      </div>

      <!-- ======= METRICS ======= -->
      <div class="cs-mrow">
        <div v-for="m in metrics" :key="m.n" class="cs-card cs-metric">
          <div class="cs-mic" :style="{ background: m.c + '1f', color: m.c }">
            <span :class="m.i" />
          </div>
          <div class="cs-mb">
            <div class="cs-mv">
              <span v-if="loading" class="cs-shim w50" />
              <template v-else>{{ m.v }}</template>
            </div>
            <div class="cs-mn">{{ m.n }}</div>
          </div>
          <span v-if="m.d !== null && !loading" class="cs-pill" :class="m.d >= 0 ? 'up' : 'dn'">
            {{ m.d >= 0 ? '+' : '' }}{{ m.d }}%
          </span>
        </div>
      </div>

      <!-- ======= CHART + DONUT ======= -->
      <div class="cs-row b">
        <div class="cs-card">
          <div class="cs-ch">
            <div>
              <h3>Activity</h3>
              <span class="cs-sub">{{ rangeName }} · {{ chart ? chart.total : 0 }} conversations</span>
            </div>
            <div class="cs-leg">
              <span><i style="background:#00A884" />Conversations</span>
              <span><i style="background:#0EA5E9" />Incoming</span>
              <span><i style="background:#8B5CF6" />Outgoing</span>
            </div>
          </div>
          <div v-if="loading" class="cs-shim tall" />
          <div v-else-if="!chart" class="cs-empty">
            <span class="i-lucide-chart-spline" /><span>No data for this range yet</span>
          </div>
          <svg v-else class="cs-svg" :viewBox="`0 0 ${CW} ${CHH}`">
            <defs>
              <linearGradient id="csA" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#00A884" stop-opacity=".38" />
                <stop offset="100%" stop-color="#00A884" stop-opacity="0" />
              </linearGradient>
              <linearGradient id="csB" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#0EA5E9" stop-opacity=".2" />
                <stop offset="100%" stop-color="#0EA5E9" stop-opacity="0" />
              </linearGradient>
            </defs>
            <g v-for="(tk, i) in yTicks" :key="'y' + i">
              <line class="cs-gl" :x1="PADL" :y1="tk.y" :x2="CW - 4" :y2="tk.y" />
              <text class="cs-yt" :x="PADL - 9" :y="tk.y + 4">{{ tk.v }}</text>
            </g>
            <path v-if="chart2" :d="chart2.area" fill="url(#csB)" />
            <path v-if="chart2" :d="chart2.line" fill="none" stroke="#0EA5E9" stroke-width="2" />
            <path v-if="chart3" :d="chart3.line" fill="none" stroke="#8B5CF6" stroke-width="2" stroke-dasharray="5 4" />
            <path :d="chart.area" fill="url(#csA)" />
            <path :d="chart.line" fill="none" stroke="#00A884" stroke-width="2.6" />
            <g v-for="(d, i) in chart.dots" :key="'d' + i">
              <circle :cx="d.cx" :cy="d.cy" r="3.5" class="cs-dotc" />
              <title>{{ d.l }} · {{ d.v }}</title>
            </g>
            <text
              v-for="(tk, i) in chart.ticks"
              :key="'x' + i"
              class="cs-xt"
              :x="tk.x"
              :y="CHH - 8"
            >
              {{ tk.l }}
            </text>
          </svg>
        </div>

        <div class="cs-card">
          <div class="cs-ch"><h3>Status split</h3></div>
          <div v-if="!donut.total" class="cs-empty sm">
            <span class="i-lucide-chart-pie" /><span>Nothing to show yet</span>
          </div>
          <template v-else>
            <div class="cs-dwrap">
              <svg viewBox="0 0 144 144" class="cs-donut">
                <circle cx="72" cy="72" :r="donut.R" class="cs-dtrack" />
                <circle
                  v-for="(sg, i) in donut.segs"
                  :key="i"
                  cx="72" cy="72" :r="donut.R" fill="none"
                  :stroke="sg.c" stroke-width="16" stroke-linecap="round"
                  :stroke-dasharray="sg.dash" :stroke-dashoffset="sg.off"
                  transform="rotate(-90 72 72)"
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

      <!-- ======= RINGS ======= -->
      <div class="cs-mrow rings">
        <div v-for="rg in rings" :key="rg.n" class="cs-card cs-ring">
          <div class="cs-rgw">
            <svg viewBox="0 0 100 100">
              <circle cx="50" cy="50" :r="rg.R" class="cs-rtrack" />
              <circle
                cx="50" cy="50" :r="rg.R" fill="none" :stroke="rg.color"
                stroke-width="9" stroke-linecap="round"
                :stroke-dasharray="rg.dash" transform="rotate(-90 50 50)"
              />
            </svg>
            <span class="cs-rpct" :style="{ color: rg.color }">{{ rg.pct }}%</span>
          </div>
          <div class="cs-rb">
            <div class="cs-rn">{{ rg.n }}</div>
            <div class="cs-rs">{{ rg.sub }}</div>
            <div class="cs-rf"><b>{{ rg.foot }}</b> {{ rg.footN }}</div>
          </div>
        </div>
      </div>

      <!-- ======= INBOX · AGENTS · RECENT ======= -->
      <div class="cs-row c">
        <div class="cs-card">
          <div class="cs-ch">
            <h3>By inbox</h3>
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
          <div class="cs-ch">
            <h3>Top agents</h3>
            <span class="cs-lnk" @click="go('agent_list')">Manage</span>
          </div>
          <div v-if="!topAgents.length" class="cs-empty sm">
            <span class="i-lucide-square-user" /><span>No agent activity</span>
          </div>
          <div v-for="a in topAgents" :key="a.id" class="cs-arow">
            <div class="cs-av" :style="{ background: avColor(a.id) }">
              <img v-if="a.thumbnail" :src="a.thumbnail" alt="" />
              <template v-else>{{ initials(a.name) }}</template>
            </div>
            <div class="cs-ab">
              <div class="cs-anm">{{ a.name }}</div>
              <div class="cs-atrack"><div class="cs-afill" :style="{ width: a.pct + '%' }" /></div>
            </div>
            <div class="cs-aval"><b>{{ a.v }}</b><span>{{ a.resolved }} done</span></div>
          </div>
        </div>

        <div class="cs-card">
          <div class="cs-ch">
            <h3>Recent</h3>
            <span class="cs-lnk" @click="go('home')">Open Chats</span>
          </div>
          <div v-if="!recent.length" class="cs-empty sm">
            <span class="i-lucide-message-circle" /><span>Nothing open</span>
          </div>
          <div v-for="c in recent" :key="c.id" class="cs-rrow" @click="openConv(c)">
            <div class="cs-av sm" :style="{ background: avColor(c.id) }">
              {{ initials(c.meta?.sender?.name) }}
            </div>
            <div class="cs-rrb">
              <div class="cs-rnm">{{ c.meta?.sender?.name || 'Unknown' }}</div>
              <div class="cs-rms">{{ lastMsg(c) }}</div>
            </div>
            <span class="cs-rtm">{{ agoOf(c.timestamp) }}</span>
          </div>
        </div>
      </div>

      <!-- ======= WORKSPACE ======= -->
      <div class="cs-card">
        <div class="cs-ch"><h3>Your workspace</h3></div>
        <div class="cs-sgrid">
          <div v-for="sc in setupCards" :key="sc.n" class="cs-scell" @click="go(sc.to)">
            <span class="cs-scic" :class="sc.i" :style="{ background: sc.c + '1f', color: sc.c }" />
            <b>{{ sc.v }}</b>
            <span>{{ sc.n }}</span>
          </div>
        </div>
      </div>

      <div class="cs-foot">
        <span v-if="lastSync">
          Updated {{ agoOf(Math.floor(lastSync / 1000)) }} · refreshes every minute
        </span>
      </div>
    </div>
  </section>
</template>

<style scoped>
.cs-dash {
  --panel: #131f26;
  --tx: #e9edef;
  --tx2: #aebac1;
  --tx3: #8696a0;
  --ln: #223039;
  --hov: #1c2a33;
  --fld: #1c2a33;
  --g: #00a884;
  --menu: #233138;
  --content: #0b141a;
  --sh: 0 1px 2px rgba(0, 0, 0, 0.3);

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
  --tx: #0a1519;
  --tx2: #3d4f57;
  --tx3: #64757d;
  --ln: #e3e8ea;
  --hov: #f2f5f6;
  --fld: #f1f5f6;
  --g: #00755f;
  --menu: #ffffff;
  --content: #f2f5f7;
  --sh: 0 1px 3px rgba(11, 20, 26, 0.07);
}
.cs-dash * {
  box-sizing: border-box;
}
.cs-scroll {
  flex: 1;
  min-width: 0;
  overflow-y: auto;
  padding: 20px 22px 34px;
}

/* top */
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
  font-size: 23px;
  font-weight: 700;
  margin: 0 0 2px;
  letter-spacing: -0.01em;
}
.cs-today {
  font-size: 11.5px;
  color: var(--tx3);
  letter-spacing: 0.03em;
}
.cs-tact {
  display: flex;
  gap: 8px;
  align-items: center;
  flex-shrink: 0;
}
.cs-rg {
  position: relative;
  display: flex;
  align-items: center;
  gap: 8px;
  background: var(--panel);
  border: 1px solid var(--ln);
  border-radius: 11px;
  padding: 9px 13px;
  font-size: 13px;
  cursor: pointer;
  color: var(--tx2);
  white-space: nowrap;
}
.cs-rg:hover {
  background: var(--hov);
}
.cs-rg span[class*='i-'] {
  width: 15px;
  height: 15px;
  flex-shrink: 0;
}
.cs-rgm {
  position: absolute;
  top: 108%;
  inset-inline-end: 0;
  background: var(--menu);
  border: 1px solid var(--ln);
  border-radius: 11px;
  padding: 5px 0;
  min-width: 164px;
  z-index: 40;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.25);
}
.cs-rgi {
  padding: 10px 15px;
  cursor: pointer;
  color: var(--tx);
}
.cs-rgi:hover {
  background: var(--hov);
}
.cs-rgi.on {
  color: var(--g);
  font-weight: 600;
}
.cs-icb {
  width: 40px;
  height: 40px;
  display: grid;
  place-items: center;
  border-radius: 11px;
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

/* rows */
.cs-row {
  display: grid;
  gap: 14px;
  margin-bottom: 14px;
}
.cs-row.a {
  grid-template-columns: 260px minmax(0, 1fr);
}
.cs-row.b {
  grid-template-columns: minmax(0, 1.75fr) minmax(0, 1fr);
}
.cs-row.c {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}
.cs-mrow {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
  margin-bottom: 14px;
}
.cs-mrow.rings {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}
.cs-card {
  background: var(--panel);
  border: 1px solid var(--ln);
  border-radius: 16px;
  padding: 17px 18px;
  box-shadow: var(--sh);
  margin-bottom: 14px;
}
.cs-row > .cs-card,
.cs-mrow > .cs-card {
  margin-bottom: 0;
}

/* welcome */
.cs-welcome {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 22px 18px;
}
.cs-wav {
  width: 62px;
  height: 62px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: #fff;
  font-size: 20px;
  font-weight: 700;
  margin-bottom: 12px;
}
.cs-wn {
  font-size: 17px;
  font-weight: 650;
  margin-bottom: 3px;
}
.cs-ws {
  font-size: 10.5px;
  color: var(--tx3);
  letter-spacing: 0.09em;
  margin-bottom: 16px;
}
.cs-wl {
  display: flex;
  gap: 10px;
  width: 100%;
}
.cs-wl > div {
  flex: 1;
  background: var(--fld);
  border-radius: 11px;
  padding: 10px 6px;
}
.cs-wl b {
  display: block;
  font-size: 18px;
}
.cs-wl span {
  font-size: 10.5px;
  color: var(--tx3);
}

/* tiles */
.cs-tiles {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 14px;
}
.cs-tile {
  position: relative;
  overflow: hidden;
  border-radius: 16px;
  padding: 18px 19px;
  color: #fff;
  display: flex;
  flex-direction: column;
  justify-content: center;
  min-height: 150px;
}
.cs-tglow {
  position: absolute;
  inset-inline-end: -40px;
  top: -55px;
  width: 150px;
  height: 150px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.13);
}
.cs-tic {
  position: relative;
  width: 26px;
  height: 26px;
  margin-bottom: 14px;
  opacity: 0.92;
}
.cs-tn {
  position: relative;
  font-size: 12.5px;
  opacity: 0.88;
  margin-bottom: 4px;
}
.cs-tv {
  position: relative;
  font-size: 34px;
  font-weight: 700;
  line-height: 1;
  letter-spacing: -0.02em;
}
.cs-tdel {
  position: relative;
  margin-top: 10px;
  align-self: flex-start;
  background: rgba(255, 255, 255, 0.22);
  border-radius: 20px;
  padding: 3px 10px;
  font-size: 11px;
  font-weight: 600;
}

/* metrics */
.cs-metric {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 15px 16px;
}
.cs-mic {
  width: 38px;
  height: 38px;
  border-radius: 12px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}
.cs-mic span {
  width: 18px;
  height: 18px;
}
.cs-mb {
  flex: 1;
  min-width: 0;
}
.cs-mv {
  font-size: 20px;
  font-weight: 700;
  line-height: 1.15;
}
.cs-mn {
  font-size: 11.5px;
  color: var(--tx3);
  margin-top: 2px;
}
.cs-pill {
  font-size: 10.5px;
  font-weight: 600;
  border-radius: 20px;
  padding: 3px 8px;
  flex-shrink: 0;
}
.cs-pill.up {
  background: rgba(34, 197, 94, 0.16);
  color: #22c55e;
}
.cs-pill.dn {
  background: rgba(239, 68, 68, 0.16);
  color: #ef4444;
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
  font-size: 12px;
  color: var(--tx3);
}
.cs-lnk {
  font-size: 12px;
  color: var(--g);
  cursor: pointer;
  flex-shrink: 0;
  font-weight: 500;
}
.cs-lnk:hover {
  text-decoration: underline;
}
.cs-leg {
  display: flex;
  gap: 11px;
  font-size: 11px;
  color: var(--tx3);
  flex-shrink: 0;
  flex-wrap: wrap;
}
.cs-leg span {
  display: flex;
  align-items: center;
  gap: 5px;
}
.cs-leg i {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

/* chart */
.cs-svg {
  width: 100%;
  height: 250px;
  display: block;
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
  stroke-width: 2.4;
  opacity: 0;
}
.cs-svg:hover .cs-dotc {
  opacity: 1;
}

/* donut */
.cs-dwrap {
  position: relative;
  width: 168px;
  margin: 0 auto 12px;
}
.cs-donut {
  width: 100%;
  display: block;
}
.cs-dtrack {
  fill: none;
  stroke: var(--fld);
  stroke-width: 16;
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
  font-size: 25px;
  font-weight: 700;
}
.cs-dmid span {
  font-size: 11px;
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
  width: 9px;
  height: 9px;
  border-radius: 3px;
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
  width: 34px;
  text-align: end;
}

/* rings */
.cs-ring {
  display: flex;
  align-items: center;
  gap: 15px;
  padding: 16px 17px;
}
.cs-rgw {
  position: relative;
  width: 82px;
  flex-shrink: 0;
}
.cs-rgw svg {
  width: 100%;
  display: block;
}
.cs-rtrack {
  fill: none;
  stroke: var(--fld);
  stroke-width: 9;
}
.cs-rpct {
  position: absolute;
  inset: 0;
  display: grid;
  place-content: center;
  font-size: 16px;
  font-weight: 700;
}
.cs-rb {
  flex: 1;
  min-width: 0;
}
.cs-rn {
  font-size: 13.5px;
  font-weight: 600;
  margin-bottom: 3px;
}
.cs-rs {
  font-size: 11.5px;
  color: var(--tx3);
  margin-bottom: 9px;
}
.cs-rf {
  font-size: 11.5px;
  color: var(--tx3);
}
.cs-rf b {
  color: var(--tx);
  font-size: 13px;
}

/* inbox bars */
.cs-brow {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 7px 0;
  font-size: 12.5px;
}
.cs-bnm {
  width: 88px;
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
  height: 8px;
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

/* agents */
.cs-arow {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 7px 0;
}
.cs-av {
  width: 34px;
  height: 34px;
  border-radius: 11px;
  display: grid;
  place-items: center;
  color: #fff;
  font-size: 11.5px;
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
.cs-ab {
  flex: 1;
  min-width: 0;
}
.cs-anm {
  font-size: 13px;
  margin-bottom: 5px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-atrack {
  height: 6px;
  border-radius: 4px;
  background: var(--fld);
  overflow: hidden;
}
.cs-afill {
  height: 100%;
  background: var(--g);
  border-radius: 4px;
  transition: width 0.4s ease;
}
.cs-aval {
  text-align: end;
  flex-shrink: 0;
}
.cs-aval b {
  display: block;
  font-size: 14px;
}
.cs-aval span {
  font-size: 10.5px;
  color: var(--tx3);
}

/* recent */
.cs-rrow {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 7px 0;
  cursor: pointer;
  border-radius: 10px;
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
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(96px, 1fr));
  gap: 10px;
}
.cs-scell {
  background: var(--fld);
  border-radius: 13px;
  padding: 14px 8px;
  text-align: center;
  cursor: pointer;
  transition: transform 0.12s;
}
.cs-scell:hover {
  transform: translateY(-2px);
}
.cs-scic {
  width: 32px;
  height: 32px;
  border-radius: 10px;
  margin: 0 auto 8px;
  display: block;
}
.cs-scell b {
  display: block;
  font-size: 17px;
  margin-bottom: 2px;
}
.cs-scell span {
  font-size: 10.5px;
  color: var(--tx3);
}

/* empty + shimmer */
.cs-empty {
  padding: 38px 16px;
  text-align: center;
  color: var(--tx3);
  font-size: 12.5px;
}
.cs-empty.sm {
  padding: 24px 12px;
}
.cs-empty span[class*='i-'] {
  width: 28px;
  height: 28px;
  opacity: 0.45;
  margin: 0 auto 9px;
  display: block;
}
.cs-shim {
  display: block;
  height: 22px;
  border-radius: 7px;
  background: var(--fld);
  animation: csP 1.3s ease-in-out infinite;
}
.cs-shim.light {
  background: rgba(255, 255, 255, 0.28);
  height: 32px;
}
.cs-shim.w50 {
  width: 55%;
}
.cs-shim.tall {
  height: 250px;
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
  font-size: 11.5px;
  color: var(--tx3);
  padding: 4px 0;
}

/* ---------- responsive ---------- */
@media (max-width: 1240px) {
  .cs-row.c {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
  .cs-row.c > .cs-card:last-child {
    grid-column: 1 / -1;
  }
}
@media (max-width: 1050px) {
  .cs-row.a {
    grid-template-columns: 1fr;
  }
  .cs-row.b {
    grid-template-columns: 1fr;
  }
  .cs-mrow {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
  .cs-mrow.rings {
    grid-template-columns: 1fr;
  }
  .cs-welcome {
    flex-direction: row;
    text-align: start;
    gap: 16px;
  }
  .cs-welcome .cs-wav {
    margin-bottom: 0;
  }
  .cs-wl {
    width: auto;
    margin-inline-start: auto;
  }
  .cs-wl > div {
    min-width: 92px;
  }
}
@media (max-width: 768px) {
  .cs-scroll {
    padding: 14px 12px 30px;
  }
  .cs-top h1 {
    font-size: 20px;
  }
  .cs-tact .cs-rgt {
    display: none;
  }
  .cs-tiles {
    grid-template-columns: 1fr;
  }
  .cs-tile {
    min-height: 0;
    padding: 15px 16px;
  }
  .cs-tv {
    font-size: 28px;
  }
  .cs-tic {
    margin-bottom: 10px;
  }
  .cs-card {
    padding: 14px 13px;
    border-radius: 14px;
  }
  .cs-row.c {
    grid-template-columns: 1fr;
  }
  .cs-row.c > .cs-card:last-child {
    grid-column: auto;
  }
  .cs-welcome {
    flex-wrap: wrap;
  }
  .cs-wl {
    width: 100%;
    margin-inline-start: 0;
  }
  .cs-svg {
    height: 210px;
  }
  .cs-ch {
    flex-wrap: wrap;
    gap: 7px;
  }
}
@media (max-width: 430px) {
  .cs-mrow {
    grid-template-columns: 1fr;
  }
}
</style>
