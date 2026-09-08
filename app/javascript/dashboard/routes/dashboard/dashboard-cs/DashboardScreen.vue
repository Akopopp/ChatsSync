<script setup>
/* =====================================================================
   DashboardScreen.vue  —  ChatsSync ka Dashboard
   Har account ka apna live data. Sab kuch Chatwoot ke apne endpoints
   se — koi backend kaam nahi. Har card alag load hota hai, ek gire to
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
const rangeMenu = ref(false);
const lastSync = ref(null);
const isMobile = ref(window.innerWidth <= 768);

/* Sidebar.vue is event ko sunta hai */
const openRail = () => {
  window.dispatchEvent(new CustomEvent('chatssync:toggle-rail'));
};

const summary = ref(null);
const prevSummary = ref(null);
const series = ref([]);
const inSeries = ref([]);
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
const MON = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
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
  new Date().toLocaleDateString(undefined, {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
  })
);
const firstName = computed(
  () => String(currentUser.value?.name || '').split(' ')[0] || 'there'
);
const accountName = computed(
  () => currentAccount.value?.name || 'your workspace'
);
const rangeName = computed(
  () => RANGES.find(r => r.k === range.value)?.n || ''
);

const CH_COLOR = {
  wa: '#25D366', fb: '#0866FF', ig: '#E1306C', sms: '#7C4DFF',
  tg: '#26A5E4', em: '#F59E0B', web: '#0EA5E9', api: '#94A3B8',
  other: '#8696A0',
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
  (n || '?')
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map(w => w[0])
    .join('')
    .toUpperCase();
const AV = ['#7F77DD', '#E5793A', '#12A150', '#D9455F', '#2F7FD1', '#C247A8'];
const avColor = i => AV[Math.abs(Number(i) || 0) % AV.length];

/* pichhle arse se muqabla */
const delta = (a, b) => {
  const x = num(a);
  const y = num(b);
  if (!y) return null;
  return Math.round(((x - y) / y) * 100);
};

/* ---------------- derived ---------------- */
const s0 = computed(() => summary.value || {});
const p0 = computed(() => prevSummary.value || {});
const heroTotal = computed(() => num(s0.value.conversations_count));
const heroDelta = computed(() =>
  delta(s0.value.conversations_count, p0.value.conversations_count)
);

const cards = computed(() => [
  {
    k: 'in', n: 'Incoming', v: fmtNum(s0.value.incoming_messages_count),
    d: delta(s0.value.incoming_messages_count, p0.value.incoming_messages_count),
    i: 'i-lucide-arrow-down-left', c: '#0EA5E9',
  },
  {
    k: 'out', n: 'Outgoing', v: fmtNum(s0.value.outgoing_messages_count),
    d: delta(s0.value.outgoing_messages_count, p0.value.outgoing_messages_count),
    i: 'i-lucide-arrow-up-right', c: '#8B5CF6',
  },
  {
    k: 'res', n: 'Resolved', v: fmtNum(s0.value.resolutions_count),
    d: delta(s0.value.resolutions_count, p0.value.resolutions_count),
    i: 'i-lucide-check-check', c: '#22C55E',
  },
  {
    k: 'frt', n: 'Avg first reply', v: fmtDur(s0.value.avg_first_response_time),
    d: null, i: 'i-lucide-timer', c: '#F59E0B',
  },
]);

/* area chart — gradient bhara hua smooth line */
const CW = 760;
const CHH = 210;
const PAD = 26;
const buildArea = pts => {
  if (!pts.length) return null;
  const vals = pts.map(p => num(p.value));
  const max = Math.max(1, ...vals);
  const n = pts.length;
  const xAt = i => (n === 1 ? CW / 2 : (i / (n - 1)) * CW);
  const yAt = v => CHH - PAD - (v / max) * (CHH - PAD * 2);
  const co = vals.map((v, i) => [xAt(i), yAt(v)]);
  let line = `M ${co[0][0]} ${co[0][1]}`;
  for (let i = 1; i < co.length; i += 1) {
    const [px, py] = co[i - 1];
    const [cx, cy] = co[i];
    const mx = (px + cx) / 2;
    line += ` C ${mx} ${py} ${mx} ${cy} ${cx} ${cy}`;
  }
  const area = `${line} L ${co[co.length - 1][0]} ${CHH} L ${co[0][0]} ${CHH} Z`;
  const step = Math.max(1, Math.ceil(n / 6));
  return {
    line,
    area,
    max,
    dots: co.map(([cx, cy], i) => ({
      cx, cy, v: vals[i], l: shortDate(pts[i].timestamp),
    })),
    ticks: pts.filter((p, i) => i % step === 0).map(p => shortDate(p.timestamp)),
    total: vals.reduce((a, b) => a + b, 0),
  };
};
const chart = computed(() => buildArea(series.value));
const chart2 = computed(() => buildArea(inSeries.value));
const gridLines = computed(() =>
  [1, 2, 3, 4].map(g => PAD + ((CHH - PAD * 2) * g) / 4)
);

/* donut — status ka bantwara */
const donut = computed(() => {
  const parts = [
    { n: 'Open', v: num(live.value.open), c: '#00A884' },
    { n: 'Pending', v: num(live.value.pending), c: '#F59E0B' },
    { n: 'Resolved', v: num(s0.value.resolutions_count), c: '#0EA5E9' },
  ].filter(p => p.v > 0);
  const total = parts.reduce((a, p) => a + p.v, 0);
  const R = 54;
  const C = 2 * Math.PI * R;
  if (!total) return { total: 0, parts: [], segs: [], R, C };
  let acc = 0;
  const segs = parts.map(p => {
    const frac = p.v / total;
    const seg = {
      c: p.c,
      dash: `${frac * C} ${C}`,
      off: -acc * C,
      pct: Math.round(frac * 100),
    };
    acc += frac;
    return seg;
  });
  return { total, parts, segs, R, C };
});

const inboxRows = computed(() => {
  const rows = inboxes.value.map(ib => ({
    id: ib.id,
    name: ib.name,
    kind: chKind(ib.channel_type),
    v: num(inboxCounts.value[ib.id]),
  }));
  const max = Math.max(1, ...rows.map(r => r.v));
  return rows
    .sort((a, b) => b.v - a.v)
    .map(r => ({ ...r, pct: Math.round((r.v / max) * 100) }));
});

const topAgents = computed(() => {
  const max = Math.max(1, ...agentStats.value.map(a => a.v));
  return [...agentStats.value]
    .sort((a, b) => b.v - a.v)
    .slice(0, 5)
    .map(a => ({ ...a, pct: Math.round((a.v / max) * 100) }));
});

/* resolution rate ring */
const ring = computed(() => {
  const conv = num(s0.value.conversations_count);
  const res = num(s0.value.resolutions_count);
  const pct = conv ? Math.min(100, Math.round((res / conv) * 100)) : 0;
  const R = 40;
  const C = 2 * Math.PI * R;
  return { pct, R, C, dash: `${(pct / 100) * C} ${C}` };
});

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
    soft(v1('/agents'), []),
    soft(v1('/inboxes'), null),
    soft(v1('/teams'), []),
    soft(v1('/labels'), null),
    soft(v1('/agent_bots'), []),
    soft(v1('/canned_responses'), []),
    soft(v1('/contacts?page=1'), null),
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
  const pqs = `since=${s - span}&until=${s}&type=account`;
  return Promise.all([
    soft(v2(`/reports/summary?${qs}`), null),
    soft(v2(`/reports/summary?${pqs}`), null),
    soft(v2(`/reports?metric=conversations_count&${qs}&group_by=day`), []),
    soft(v2(`/reports?metric=incoming_messages_count&${qs}&group_by=day`), []),
  ]).then(([sum, prev, ser, iser]) => {
    summary.value = sum;
    prevSummary.value = prev;
    series.value = Array.isArray(ser) ? ser : ser?.payload || [];
    inSeries.value = Array.isArray(iser) ? iser : iser?.payload || [];
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
      soft(
        v2(`/reports/summary?since=${s}&until=${u}&type=agent&id=${a.id}`),
        null
      ).then(r => ({
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
      soft(
        v2(`/reports/summary?since=${s}&until=${u}&type=inbox&id=${ib.id}`),
        null
      ).then(r => [ib.id, num(r?.conversations_count)])
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
    jobs.push(
      loadStatic().then(() =>
        Promise.all([loadAgentStats(), loadInboxCounts()])
      )
    );
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
    document.body.classList.contains('dark') ||
    !!document.querySelector('.dark')
  );
};
const closeMenus = () => {
  rangeMenu.value = false;
};
const onResize = () => {
  isMobile.value = window.innerWidth <= 768;
};

onMounted(() => {
  readTheme();
  themeObs = new MutationObserver(readTheme);
  themeObs.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['class'],
    subtree: true,
  });
  document.addEventListener('click', closeMenus);
  window.addEventListener('resize', onResize);
  refresh(true);
  timer = setInterval(() => {
    if (!document.hidden) refresh(false);
  }, 60000);
});
onBeforeUnmount(() => {
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
      <!-- ======== TOP ======== -->
      <header class="cs-top">
        <span
          v-if="isMobile"
          class="cs-ham"
          title="Menu"
          @click.stop="openRail"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M4 6h16M4 12h16M4 18h16" stroke-linecap="round" />
          </svg>
        </span>
        <div class="cs-tt">
          <h1>Hello, {{ firstName }}</h1>
          <span class="cs-today">Today is {{ todayLine }}</span>
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

      <!-- ======== HERO + STATS ======== -->
      <div class="cs-row hero">
        <div class="cs-hero">
          <div class="cs-hglow" />
          <div class="cs-hi"><span class="i-lucide-messages-square" /></div>
          <div class="cs-hlbl">Conversations · {{ rangeName.toLowerCase() }}</div>
          <div class="cs-hnum">
            <span v-if="loading" class="cs-shim light w40" />
            <template v-else>{{ fmtNum(heroTotal) }}</template>
          </div>
          <div class="cs-hsub">
            <span
              v-if="heroDelta !== null"
              class="cs-trend"
            >
              <span
                :class="
                  heroDelta >= 0
                    ? 'i-lucide-trending-up'
                    : 'i-lucide-trending-down'
                "
              />
              {{ Math.abs(heroDelta) }}%
            </span>
            <span>Welcome to ChatsSync — {{ accountName }}</span>
          </div>
          <div class="cs-hchips">
            <span class="cs-hchip" @click="go('home')">
              <b>{{ live.open }}</b> open
            </span>
            <span class="cs-hchip" @click="go('home')">
              <b>{{ live.unassigned }}</b> unassigned
            </span>
            <span class="cs-hchip" @click="go('home')">
              <b>{{ live.unattended }}</b> needs reply
            </span>
          </div>
        </div>

        <div class="cs-stats">
          <div v-for="c in cards" :key="c.k" class="cs-card stat">
            <div class="cs-sic" :style="{ background: c.c + '1f', color: c.c }">
              <span :class="c.i" />
            </div>
            <div class="cs-sb">
              <div class="cs-sv">
                <span v-if="loading" class="cs-shim w50" />
                <template v-else>{{ c.v }}</template>
              </div>
              <div class="cs-sn">{{ c.n }}</div>
            </div>
            <span
              v-if="c.d !== null && !loading"
              class="cs-pill"
              :class="c.d >= 0 ? 'up' : 'dn'"
            >
              {{ c.d >= 0 ? '+' : '' }}{{ c.d }}%
            </span>
          </div>
        </div>
      </div>

      <!-- ======== TREND + DONUT ======== -->
      <div class="cs-row main">
        <div class="cs-card">
          <div class="cs-ch">
            <div>
              <h3>Conversation trend</h3>
              <span class="cs-sub">
                {{ chart ? chart.total : 0 }} conversations ·
                {{ chart2 ? chart2.total : 0 }} incoming
              </span>
            </div>
            <div class="cs-leg">
              <span><i style="background: #00a884" />Conversations</span>
              <span><i style="background: #0ea5e9" />Incoming</span>
            </div>
          </div>

          <div v-if="loading" class="cs-shim tall" />
          <div v-else-if="!chart" class="cs-empty">
            <span class="i-lucide-chart-spline" />
            <span>No data for this range yet</span>
          </div>
          <template v-else>
            <svg
              class="cs-svg"
              :viewBox="`0 0 ${CW} ${CHH}`"
              preserveAspectRatio="none"
            >
              <defs>
                <linearGradient id="csGa" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stop-color="#00A884" stop-opacity="0.35" />
                  <stop offset="100%" stop-color="#00A884" stop-opacity="0" />
                </linearGradient>
                <linearGradient id="csGb" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stop-color="#0EA5E9" stop-opacity="0.2" />
                  <stop offset="100%" stop-color="#0EA5E9" stop-opacity="0" />
                </linearGradient>
              </defs>
              <line
                v-for="(gy, gi) in gridLines"
                :key="gi"
                class="cs-gl"
                x1="0"
                :y1="gy"
                :x2="CW"
                :y2="gy"
              />
              <path v-if="chart2" :d="chart2.area" fill="url(#csGb)" />
              <path
                v-if="chart2"
                :d="chart2.line"
                fill="none"
                stroke="#0EA5E9"
                stroke-width="2"
                vector-effect="non-scaling-stroke"
              />
              <path :d="chart.area" fill="url(#csGa)" />
              <path
                :d="chart.line"
                fill="none"
                stroke="#00A884"
                stroke-width="2.4"
                vector-effect="non-scaling-stroke"
              />
              <g v-for="(d, i) in chart.dots" :key="i">
                <circle :cx="d.cx" :cy="d.cy" r="3" class="cs-dotc" />
                <title>{{ d.l }} · {{ d.v }}</title>
              </g>
            </svg>
            <div class="cs-xax">
              <span v-for="(t, i) in chart.ticks" :key="i">{{ t }}</span>
            </div>
          </template>
        </div>

        <div class="cs-card">
          <div class="cs-ch"><h3>Status split</h3></div>
          <div v-if="!donut.total" class="cs-empty sm">
            <span class="i-lucide-chart-pie" /><span>Nothing to show yet</span>
          </div>
          <template v-else>
            <div class="cs-dwrap">
              <svg viewBox="0 0 140 140" class="cs-donut">
                <circle cx="70" cy="70" :r="donut.R" class="cs-dtrack" />
                <circle
                  v-for="(sg, i) in donut.segs"
                  :key="i"
                  cx="70"
                  cy="70"
                  :r="donut.R"
                  fill="none"
                  :stroke="sg.c"
                  stroke-width="15"
                  stroke-linecap="round"
                  :stroke-dasharray="sg.dash"
                  :stroke-dashoffset="sg.off"
                  transform="rotate(-90 70 70)"
                />
              </svg>
              <div class="cs-dmid">
                <b>{{ fmtNum(donut.total) }}</b><span>total</span>
              </div>
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

      <!-- ======== INBOX + AGENTS + RING ======== -->
      <div class="cs-row three">
        <div class="cs-card">
          <div class="cs-ch">
            <h3>By inbox</h3>
            <span class="cs-lnk" @click="go('settings_inbox_list')">Manage</span>
          </div>
          <div v-if="!inboxRows.length" class="cs-empty sm">
            <span class="i-lucide-inbox" /><span>No inboxes connected</span>
          </div>
          <div v-for="r in inboxRows" :key="r.id" class="cs-brow">
            <span class="cs-bnm">
              <i :style="{ background: CH_COLOR[r.kind] }" />{{ r.name }}
            </span>
            <div class="cs-btrack">
              <div
                class="cs-bfill"
                :style="{ width: r.pct + '%', background: CH_COLOR[r.kind] }"
              />
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
              <div class="cs-atrack">
                <div class="cs-afill" :style="{ width: a.pct + '%' }" />
              </div>
            </div>
            <div class="cs-aval">
              <b>{{ a.v }}</b><span>{{ a.resolved }} done</span>
            </div>
          </div>
        </div>

        <div class="cs-card ringcard">
          <div class="cs-ch"><h3>Resolution rate</h3></div>
          <div class="cs-ringw">
            <svg viewBox="0 0 100 100" class="cs-ring">
              <circle cx="50" cy="50" :r="ring.R" class="cs-rtrack" />
              <circle
                cx="50"
                cy="50"
                :r="ring.R"
                fill="none"
                stroke="#00A884"
                stroke-width="10"
                stroke-linecap="round"
                :stroke-dasharray="ring.dash"
                transform="rotate(-90 50 50)"
              />
            </svg>
            <div class="cs-rmid"><b>{{ ring.pct }}%</b></div>
          </div>
          <div class="cs-rstats">
            <div>
              <b>{{ fmtDur(s0.avg_first_response_time) }}</b>
              <span>First reply</span>
            </div>
            <div>
              <b>{{ fmtDur(s0.avg_resolution_time) }}</b>
              <span>Resolution</span>
            </div>
          </div>
        </div>
      </div>

      <!-- ======== RECENT + WORKSPACE ======== -->
      <div class="cs-row main">
        <div class="cs-card">
          <div class="cs-ch">
            <h3>Recent conversations</h3>
            <span class="cs-lnk" @click="go('home')">Open Chats</span>
          </div>
          <div v-if="!recent.length" class="cs-empty sm">
            <span class="i-lucide-message-circle" />
            <span>Nothing open right now</span>
          </div>
          <div
            v-for="c in recent"
            :key="c.id"
            class="cs-rrow"
            @click="openConv(c)"
          >
            <div class="cs-av sm" :style="{ background: avColor(c.id) }">
              {{ initials(c.meta?.sender?.name) }}
            </div>
            <div class="cs-rb">
              <div class="cs-rnm">
                {{ c.meta?.sender?.name || 'Unknown' }}
                <span class="cs-rid">#{{ c.id }}</span>
              </div>
              <div class="cs-rms">{{ lastMsg(c) }}</div>
            </div>
            <span class="cs-rtm">{{ agoOf(c.timestamp) }}</span>
          </div>
        </div>

        <div class="cs-card">
          <div class="cs-ch"><h3>Your workspace</h3></div>
          <div class="cs-sgrid">
            <div
              v-for="sc in setupCards"
              :key="sc.n"
              class="cs-scell"
              @click="go(sc.to)"
            >
              <span
                class="cs-scic"
                :class="sc.i"
                :style="{ background: sc.c + '1f', color: sc.c }"
              />
              <b>{{ sc.v }}</b>
              <span>{{ sc.n }}</span>
            </div>
          </div>
        </div>
      </div>

      <div class="cs-foot">
        <span v-if="lastSync">
          Updated {{ agoOf(Math.floor(lastSync / 1000)) }} · refreshes every
          minute
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
  --ln: #e2e8ea;
  --hov: #f2f5f6;
  --fld: #f1f5f6;
  --g: #00755f;
  --menu: #ffffff;
  --content: #f4f7f8;
  --sh: 0 1px 3px rgba(11, 20, 26, 0.07);
}
.cs-dash * {
  box-sizing: border-box;
}
.cs-scroll {
  flex: 1;
  min-width: 0;
  overflow-y: auto;
  padding: 24px 26px 40px;
}

/* top */
.cs-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 20px;
  flex-wrap: wrap;
}
.cs-tt {
  flex: 1;
  min-width: 0;
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
  margin-inline-start: -8px;
}
.cs-ham:hover {
  background: var(--hov);
}
.cs-ham svg {
  width: 21px;
  height: 21px;
}
.cs-top h1 {
  font-size: 26px;
  font-weight: 700;
  margin: 0 0 4px;
  letter-spacing: -0.01em;
}
.cs-today {
  font-size: 13px;
  color: var(--tx3);
}
.cs-tact {
  display: flex;
  gap: 9px;
  align-items: center;
}
.cs-rg {
  position: relative;
  display: flex;
  align-items: center;
  gap: 9px;
  background: var(--panel);
  border: 1px solid var(--ln);
  border-radius: 11px;
  padding: 10px 14px;
  font-size: 13.5px;
  cursor: pointer;
  color: var(--tx2);
  white-space: nowrap;
  box-shadow: var(--sh);
}
.cs-rg:hover {
  background: var(--hov);
}
.cs-rg span[class*='i-'] {
  width: 16px;
  height: 16px;
  flex-shrink: 0;
}
.cs-rgt {
  flex: 1;
}
.cs-rgm {
  position: absolute;
  top: 108%;
  inset-inline-end: 0;
  background: var(--menu);
  border: 1px solid var(--ln);
  border-radius: 11px;
  padding: 5px 0;
  min-width: 168px;
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
  width: 42px;
  height: 42px;
  display: grid;
  place-items: center;
  border-radius: 11px;
  border: 1px solid var(--ln);
  background: var(--panel);
  color: var(--tx2);
  cursor: pointer;
  box-shadow: var(--sh);
  flex-shrink: 0;
}
.cs-icb:hover {
  background: var(--hov);
}
.cs-icb span {
  width: 17px;
  height: 17px;
}

/* rows */
.cs-row {
  display: grid;
  gap: 15px;
  margin-bottom: 15px;
}
.cs-row.hero {
  grid-template-columns: 1.05fr 1.6fr;
}
.cs-row.main {
  grid-template-columns: 1.6fr 1fr;
}
.cs-row.three {
  grid-template-columns: 1.1fr 1.1fr 0.85fr;
}

/* hero */
.cs-hero {
  position: relative;
  overflow: hidden;
  border-radius: 18px;
  padding: 22px 24px;
  color: #fff;
  background: linear-gradient(135deg, #00a884 0%, #018f70 45%, #046d63 100%);
  box-shadow: 0 10px 30px rgba(0, 168, 132, 0.22);
}
.cs-hglow {
  position: absolute;
  inset-inline-end: -50px;
  top: -70px;
  width: 190px;
  height: 190px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.12);
}
.cs-hi {
  position: relative;
  width: 40px;
  height: 40px;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.18);
  display: grid;
  place-items: center;
  margin-bottom: 16px;
}
.cs-hi span {
  width: 20px;
  height: 20px;
}
.cs-hlbl {
  position: relative;
  font-size: 12.5px;
  opacity: 0.85;
  margin-bottom: 5px;
}
.cs-hnum {
  position: relative;
  font-size: 42px;
  font-weight: 700;
  line-height: 1;
  margin-bottom: 10px;
  letter-spacing: -0.02em;
}
.cs-hsub {
  position: relative;
  display: flex;
  align-items: center;
  gap: 9px;
  font-size: 12.5px;
  opacity: 0.92;
  flex-wrap: wrap;
  margin-bottom: 16px;
}
.cs-trend {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  background: rgba(255, 255, 255, 0.22);
  border-radius: 20px;
  padding: 3px 9px;
  font-weight: 600;
}
.cs-trend span {
  width: 13px;
  height: 13px;
}
.cs-hchips {
  position: relative;
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
.cs-hchip {
  background: rgba(255, 255, 255, 0.16);
  border-radius: 10px;
  padding: 7px 12px;
  font-size: 12.5px;
  cursor: pointer;
}
.cs-hchip:hover {
  background: rgba(255, 255, 255, 0.28);
}
.cs-hchip b {
  font-size: 14px;
  margin-inline-end: 3px;
}

/* cards */
.cs-stats {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 13px;
}
.cs-card {
  background: var(--panel);
  border: 1px solid var(--ln);
  border-radius: 16px;
  padding: 18px 19px;
  box-shadow: var(--sh);
}
.cs-card.stat {
  display: flex;
  align-items: center;
  gap: 13px;
  padding: 16px 17px;
}
.cs-sic {
  width: 40px;
  height: 40px;
  border-radius: 12px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}
.cs-sic span {
  width: 19px;
  height: 19px;
}
.cs-sb {
  flex: 1;
  min-width: 0;
}
.cs-sv {
  font-size: 22px;
  font-weight: 700;
  line-height: 1.15;
}
.cs-sn {
  font-size: 12px;
  color: var(--tx3);
  margin-top: 2px;
}
.cs-pill {
  font-size: 11px;
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
  gap: 12px;
  margin-bottom: 15px;
}
.cs-ch h3 {
  font-size: 15px;
  font-weight: 600;
  margin: 0;
}
.cs-sub {
  font-size: 12.5px;
  color: var(--tx3);
}
.cs-lnk {
  font-size: 12.5px;
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
  gap: 13px;
  font-size: 11.5px;
  color: var(--tx3);
  flex-shrink: 0;
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
  height: 210px;
  display: block;
  overflow: visible;
}
.cs-gl {
  stroke: var(--ln);
  stroke-width: 1;
  vector-effect: non-scaling-stroke;
}
.cs-dotc {
  fill: var(--panel);
  stroke: #00a884;
  stroke-width: 2;
  opacity: 0;
  vector-effect: non-scaling-stroke;
}
.cs-svg:hover .cs-dotc {
  opacity: 1;
}
.cs-xax {
  display: flex;
  justify-content: space-between;
  font-size: 11px;
  color: var(--tx3);
  margin-top: 6px;
}

/* donut */
.cs-dwrap {
  position: relative;
  width: 160px;
  margin: 0 auto 14px;
}
.cs-donut {
  width: 100%;
  display: block;
}
.cs-dtrack {
  fill: none;
  stroke: var(--fld);
  stroke-width: 15;
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
  font-size: 24px;
  font-weight: 700;
}
.cs-dmid span {
  font-size: 11.5px;
  color: var(--tx3);
}
.cs-dleg > div {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 7px 0;
  font-size: 13px;
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
  font-size: 11.5px;
  color: var(--tx3);
  width: 36px;
  text-align: end;
}

/* inbox bars */
.cs-brow {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 8px 0;
  font-size: 13px;
}
.cs-bnm {
  width: 104px;
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
  width: 36px;
  text-align: end;
  flex-shrink: 0;
}

/* agents */
.cs-arow {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 0;
}
.cs-av {
  width: 36px;
  height: 36px;
  border-radius: 12px;
  display: grid;
  place-items: center;
  color: #fff;
  font-size: 12px;
  font-weight: 600;
  flex-shrink: 0;
  overflow: hidden;
}
.cs-av.sm {
  width: 34px;
  height: 34px;
  border-radius: 11px;
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
  font-size: 13.5px;
  margin-bottom: 6px;
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
  font-size: 15px;
}
.cs-aval span {
  font-size: 11px;
  color: var(--tx3);
}

/* ring */
.cs-ringw {
  position: relative;
  width: 132px;
  margin: 4px auto 14px;
}
.cs-ring {
  width: 100%;
  display: block;
}
.cs-rtrack {
  fill: none;
  stroke: var(--fld);
  stroke-width: 10;
}
.cs-rmid {
  position: absolute;
  inset: 0;
  display: grid;
  place-content: center;
}
.cs-rmid b {
  font-size: 24px;
  font-weight: 700;
}
.cs-rstats {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 9px;
}
.cs-rstats div {
  background: var(--fld);
  border-radius: 11px;
  padding: 11px 8px;
  text-align: center;
}
.cs-rstats b {
  display: block;
  font-size: 15px;
  margin-bottom: 2px;
}
.cs-rstats span {
  font-size: 11px;
  color: var(--tx3);
}

/* recent */
.cs-rrow {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 9px 0;
  cursor: pointer;
  border-radius: 10px;
}
.cs-rrow:hover {
  background: var(--hov);
}
.cs-rb {
  flex: 1;
  min-width: 0;
}
.cs-rnm {
  font-size: 13.5px;
  margin-bottom: 2px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-rid {
  color: var(--tx3);
  font-size: 11.5px;
  margin-inline-start: 5px;
}
.cs-rms {
  font-size: 12.5px;
  color: var(--tx3);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-rtm {
  font-size: 11.5px;
  color: var(--tx3);
  flex-shrink: 0;
}

/* workspace */
.cs-sgrid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(84px, 1fr));
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
  font-size: 11px;
  color: var(--tx3);
}

/* empty + shimmer */
.cs-empty {
  padding: 40px 16px;
  text-align: center;
  color: var(--tx3);
  font-size: 13px;
}
.cs-empty.sm {
  padding: 26px 12px;
}
.cs-empty span[class*='i-'] {
  width: 30px;
  height: 30px;
  opacity: 0.45;
  margin: 0 auto 10px;
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
  background: rgba(255, 255, 255, 0.25);
  height: 40px;
}
.cs-shim.w40 {
  width: 40%;
}
.cs-shim.w50 {
  width: 55%;
}
.cs-shim.tall {
  height: 210px;
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
  font-size: 12px;
  color: var(--tx3);
  padding: 8px 0 4px;
}

/* ---------- responsive ---------- */
@media (max-width: 1180px) {
  .cs-row.three {
    grid-template-columns: 1fr 1fr;
  }
  .cs-row.three .ringcard {
    grid-column: 1 / -1;
  }
}
@media (max-width: 980px) {
  .cs-row.hero,
  .cs-row.main,
  .cs-row.three {
    grid-template-columns: 1fr;
  }
  .cs-row.three .ringcard {
    grid-column: auto;
  }
}
@media (max-width: 768px) {
  .cs-scroll {
    padding: 16px 13px 32px;
  }
  .cs-top h1 {
    font-size: 22px;
  }
  .cs-tact {
    width: 100%;
  }
  .cs-rg {
    flex: 1;
  }
  .cs-hero {
    padding: 20px;
    border-radius: 16px;
  }
  .cs-hnum {
    font-size: 36px;
  }
  .cs-stats {
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }
  .cs-card {
    padding: 15px 14px;
    border-radius: 14px;
  }
  .cs-card.stat {
    gap: 10px;
    padding: 14px;
  }
  .cs-card.stat .cs-sic {
    width: 34px;
    height: 34px;
    border-radius: 10px;
  }
  .cs-sv {
    font-size: 19px;
  }
  .cs-ch {
    flex-wrap: wrap;
    gap: 8px;
  }
  .cs-svg {
    height: 180px;
  }
  .cs-bnm {
    width: 84px;
  }
  .cs-sgrid {
    grid-template-columns: repeat(auto-fit, minmax(74px, 1fr));
  }
}
@media (max-width: 400px) {
  .cs-stats {
    grid-template-columns: 1fr;
  }
}
</style>
