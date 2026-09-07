<script setup>
/* =====================================================================
   DashboardScreen.vue  —  ChatsSync ka Dashboard tab
   Har account ka apna data. Sab kuch Chatwoot ke apne endpoints se —
   koi backend kaam nahi. Har card alag se load hota hai, ek fail ho
   to baqi phir bhi bharte hain.
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
/* har card apne aap gir sakta hai, poora page nahi */
const soft = (p, fallback = null) => p.catch(() => fallback);

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

const summary = ref(null);
const series = ref([]);
const live = ref({ open: 0, unattended: 0, unassigned: 0, pending: 0 });
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
const fmtDur = secs => {
  const s = num(secs);
  if (!s) return '—';
  if (s < 60) return `${Math.round(s)}s`;
  if (s < 3600) return `${Math.round(s / 60)}m`;
  if (s < 86400) return `${(s / 3600).toFixed(1)}h`;
  return `${(s / 86400).toFixed(1)}d`;
};
const MONTHS = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const shortDate = ts => {
  const d = new Date(num(ts) * 1000);
  return `${d.getDate()} ${MONTHS[d.getMonth()]}`;
};
const agoOf = ts => {
  if (!ts) return '';
  const mins = Math.floor((Date.now() - num(ts) * 1000) / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  if (mins < 1440) return `${Math.floor(mins / 60)}h ago`;
  return `${Math.floor(mins / 1440)}d ago`;
};

const greeting = computed(() => {
  const h = new Date().getHours();
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
});
const firstName = computed(
  () => String(currentUser.value?.name || '').split(' ')[0] || 'there'
);
const accountName = computed(
  () => currentAccount.value?.name || 'your workspace'
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
const initials = name =>
  (name || '?')
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map(w => w[0])
    .join('')
    .toUpperCase();
const AV = ['#7F77DD', '#E5793A', '#12A150', '#D9455F', '#2F7FD1', '#C247A8'];
const avColor = i => AV[Math.abs(Number(i) || 0) % AV.length];

/* ---------------- derived ---------------- */
const cards = computed(() => {
  const s = summary.value || {};
  return [
    {
      k: 'conv',
      n: 'Conversations',
      v: fmtNum(s.conversations_count),
      i: 'i-lucide-messages-square',
      c: '#00A884',
    },
    {
      k: 'in',
      n: 'Incoming messages',
      v: fmtNum(s.incoming_messages_count),
      i: 'i-lucide-arrow-down-left',
      c: '#0EA5E9',
    },
    {
      k: 'out',
      n: 'Outgoing messages',
      v: fmtNum(s.outgoing_messages_count),
      i: 'i-lucide-arrow-up-right',
      c: '#8B5CF6',
    },
    {
      k: 'res',
      n: 'Resolved',
      v: fmtNum(s.resolutions_count),
      i: 'i-lucide-check-check',
      c: '#22C55E',
    },
    {
      k: 'frt',
      n: 'Avg first reply',
      v: fmtDur(s.avg_first_response_time),
      i: 'i-lucide-timer',
      c: '#F59E0B',
    },
    {
      k: 'rt',
      n: 'Avg resolution',
      v: fmtDur(s.avg_resolution_time),
      i: 'i-lucide-clock-3',
      c: '#EC4899',
    },
  ];
});

const setupCards = computed(() => [
  { n: 'Agents', v: agents.value.length, i: 'i-lucide-square-user', to: 'agent_list' },
  { n: 'Inboxes', v: inboxes.value.length, i: 'i-lucide-inbox', to: 'settings_inbox_list' },
  { n: 'Chatbots', v: bots.value.length, i: 'i-lucide-bot', to: 'agent_bots' },
  { n: 'Teams', v: teams.value.length, i: 'i-lucide-users', to: 'settings_teams_list' },
  { n: 'Labels', v: labels.value.length, i: 'i-lucide-tags', to: 'labels_list' },
  { n: 'Contacts', v: contactCount.value, i: 'i-lucide-contact', to: 'contacts_dashboard_index' },
  {
    n: 'Canned replies',
    v: cannedCount.value,
    i: 'i-lucide-message-square-quote',
    to: 'canned_list',
  },
]);

/* chart — SVG khud banate hain, koi library nahi */
const CH_W = 720;
const CH_H = 190;
const chart = computed(() => {
  const pts = series.value;
  if (!pts.length) return null;
  const max = Math.max(1, ...pts.map(p => num(p.value)));
  const gap = 4;
  const bw = Math.max(3, CH_W / pts.length - gap);
  const bars = pts.map((p, i) => {
    const val = num(p.value);
    const h = Math.max(val > 0 ? 3 : 0, (val / max) * (CH_H - 26));
    return {
      x: i * (bw + gap),
      y: CH_H - 22 - h,
      w: bw,
      h,
      val,
      label: shortDate(p.timestamp),
    };
  });
  const step = Math.ceil(pts.length / 6);
  return {
    max,
    bars,
    ticks: bars.filter((b, i) => i % step === 0),
    total: pts.reduce((a, p) => a + num(p.value), 0),
    peak: max,
  };
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
    .slice(0, 6)
    .map(a => ({ ...a, pct: Math.round((a.v / max) * 100) }));
});

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
  const s = since();
  const u = now();
  const qs = `since=${s}&until=${u}&type=account`;
  return Promise.all([
    soft(v2(`/reports/summary?${qs}`), null),
    soft(v2(`/reports?metric=conversations_count&${qs}&group_by=day`), []),
  ]).then(([sum, ser]) => {
    summary.value = sum;
    series.value = Array.isArray(ser) ? ser : ser?.payload || [];
  });
};

const loadAgentStats = () => {
  const s = since();
  const u = now();
  const list = agents.value.slice(0, 10);
  if (!list.length) {
    agentStats.value = [];
    return Promise.resolve();
  }
  return Promise.all(
    list.map(a =>
      soft(
        v2(
          `/reports/summary?since=${s}&until=${u}&type=agent&id=${a.id}`
        ),
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
  const s = since();
  const u = now();
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
    recent.value = list.slice(0, 6);
  });

const refresh = (full = false) => {
  if (full) loading.value = true;
  const jobs = [loadReports(), loadLive(), loadRecent()];
  if (full) jobs.push(loadStatic().then(() => Promise.all([loadAgentStats(), loadInboxCounts()])));
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

onMounted(() => {
  readTheme();
  themeObs = new MutationObserver(readTheme);
  themeObs.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['class'],
    subtree: true,
  });
  document.addEventListener('click', closeMenus);
  refresh(true);
  // data khud taaza hota rehta hai
  timer = setInterval(() => {
    if (!document.hidden) refresh(false);
  }, 60000);
});

onBeforeUnmount(() => {
  document.removeEventListener('click', closeMenus);
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
    <div class="cs-dscroll">
      <!-- hero -->
      <div class="cs-hero">
        <div class="cs-hb">
          <div class="cs-hg">{{ greeting }}, {{ firstName }}</div>
          <h1>Welcome to ChatsSync</h1>
          <p>
            Here is how {{ accountName }} is doing. Everything below is live
            data from this account and refreshes on its own.
          </p>
        </div>
        <div class="cs-hact">
          <div class="cs-rg" @click.stop="rangeMenu = !rangeMenu">
            <span class="i-lucide-calendar" />
            <span>{{ RANGES.find(r => r.k === range).n }}</span>
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
          <span class="cs-ic" title="Refresh" @click="refresh(true)">
            <span class="i-lucide-rotate-cw" />
          </span>
        </div>
      </div>

      <!-- stat cards -->
      <div class="cs-grid">
        <div v-for="c in cards" :key="c.k" class="cs-card stat">
          <div class="cs-sic" :style="{ background: c.c + '22', color: c.c }">
            <span :class="c.i" />
          </div>
          <div class="cs-sv">
            <span v-if="loading" class="cs-shim w60" />
            <template v-else>{{ c.v }}</template>
          </div>
          <div class="cs-sn">{{ c.n }}</div>
        </div>
      </div>

      <!-- live strip -->
      <div class="cs-live">
        <div class="cs-lvi" @click="go('home')">
          <span class="cs-dot g" /><b>{{ live.open }}</b><span>Open now</span>
        </div>
        <div class="cs-lvi" @click="go('home')">
          <span class="cs-dot a" /><b>{{ live.pending }}</b><span>Pending</span>
        </div>
        <div class="cs-lvi" @click="go('home')">
          <span class="cs-dot b" /><b>{{ live.unassigned }}</b
          ><span>Unassigned</span>
        </div>
        <div class="cs-lvi" @click="go('home')">
          <span class="cs-dot r" /><b>{{ live.unattended }}</b
          ><span>Needs reply</span>
        </div>
      </div>

      <!-- chart -->
      <div class="cs-card">
        <div class="cs-ch">
          <div>
            <h3>Conversations over time</h3>
            <span class="cs-sub">
              {{ chart ? chart.total : 0 }} total · peak
              {{ chart ? chart.peak : 0 }} in a day
            </span>
          </div>
        </div>
        <div v-if="loading" class="cs-shim tall" />
        <div v-else-if="!chart" class="cs-empty">
          <span class="i-lucide-chart-column" />
          <span>No conversation data for this range yet</span>
        </div>
        <svg
          v-else
          class="cs-svg"
          :viewBox="`0 0 ${CH_W} ${CH_H}`"
          preserveAspectRatio="none"
        >
          <g v-for="(b, i) in chart.bars" :key="i">
            <rect
              :x="b.x"
              :y="b.y"
              :width="b.w"
              :height="b.h"
              rx="2"
              class="cs-bar"
            />
            <title>{{ b.label }} · {{ b.val }}</title>
          </g>
        </svg>
        <div v-if="!loading && chart" class="cs-xax">
          <span v-for="(tk, i) in chart.ticks" :key="i">{{ tk.label }}</span>
        </div>
      </div>

      <div class="cs-two">
        <!-- inboxes -->
        <div class="cs-card">
          <div class="cs-ch">
            <h3>Conversations by inbox</h3>
            <span class="cs-lnk" @click="go('settings_inbox_list')">Manage</span>
          </div>
          <div v-if="!inboxRows.length" class="cs-empty sm">
            <span class="i-lucide-inbox" /><span>No inboxes connected yet</span>
          </div>
          <div v-for="r in inboxRows" :key="r.id" class="cs-brow">
            <span class="cs-bdot" :style="{ background: CH_COLOR[r.kind] }" />
            <span class="cs-bnm">{{ r.name }}</span>
            <div class="cs-btrack">
              <div
                class="cs-bfill"
                :style="{ width: r.pct + '%', background: CH_COLOR[r.kind] }"
              />
            </div>
            <span class="cs-bval">{{ r.v }}</span>
          </div>
        </div>

        <!-- agents -->
        <div class="cs-card">
          <div class="cs-ch">
            <h3>Top agents</h3>
            <span class="cs-lnk" @click="go('agent_list')">Manage</span>
          </div>
          <div v-if="!topAgents.length" class="cs-empty sm">
            <span class="i-lucide-square-user" /><span>No agent activity yet</span>
          </div>
          <div v-for="a in topAgents" :key="a.id" class="cs-arow">
            <div class="cs-aav" :style="{ background: avColor(a.id) }">
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
              <b>{{ a.v }}</b>
              <span>{{ a.resolved }} resolved</span>
            </div>
          </div>
        </div>
      </div>

      <div class="cs-two">
        <!-- recent -->
        <div class="cs-card">
          <div class="cs-ch">
            <h3>Recent conversations</h3>
            <span class="cs-lnk" @click="go('home')">Open Chats</span>
          </div>
          <div v-if="!recent.length" class="cs-empty sm">
            <span class="i-lucide-message-circle" /><span>Nothing open right now</span>
          </div>
          <div
            v-for="c in recent"
            :key="c.id"
            class="cs-rrow"
            @click="openConv(c)"
          >
            <div class="cs-aav sm" :style="{ background: avColor(c.id) }">
              {{ initials(c.meta?.sender?.name) }}
            </div>
            <div class="cs-rb">
              <div class="cs-rnm">
                {{ c.meta?.sender?.name || 'Unknown' }}
                <span class="cs-rid">#{{ c.id }}</span>
              </div>
              <div class="cs-rms">
                {{ c.messages?.[c.messages.length - 1]?.content || 'No message' }}
              </div>
            </div>
            <span class="cs-rtm">{{ agoOf(c.timestamp) }}</span>
          </div>
        </div>

        <!-- setup -->
        <div class="cs-card">
          <div class="cs-ch">
            <h3>Your workspace</h3>
          </div>
          <div class="cs-sgrid">
            <div
              v-for="s in setupCards"
              :key="s.n"
              class="cs-scell"
              @click="go(s.to)"
            >
              <span class="cs-scic" :class="s.i" />
              <b>{{ s.v }}</b>
              <span>{{ s.n }}</span>
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
  --panel: #111b21;
  --tx: #e9edef;
  --tx2: #aebac1;
  --tx3: #8696a0;
  --ln: #222e35;
  --hov: #202c33;
  --fld: #202c33;
  --g: #00a884;
  --g-tint: #103529;
  --menu: #233138;
  --content: #0b141a;

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
  --tx3: #55666e;
  --ln: #c7d1d6;
  --hov: #eceff1;
  --fld: #e3e9eb;
  --g: #00755f;
  --g-tint: #c8e8db;
  --menu: #ffffff;
  --content: #e3e8ea;
}
.cs-dash * {
  box-sizing: border-box;
}
.cs-dscroll {
  flex: 1;
  min-width: 0;
  overflow-y: auto;
  padding: 22px 24px 40px;
}

/* hero */
.cs-hero {
  display: flex;
  align-items: flex-start;
  gap: 18px;
  margin-bottom: 20px;
}
.cs-hb {
  flex: 1;
  min-width: 0;
}
.cs-hg {
  font-size: 13px;
  color: var(--g);
  margin-bottom: 5px;
}
.cs-hero h1 {
  font-size: 25px;
  font-weight: 600;
  margin: 0 0 7px;
}
.cs-hero p {
  margin: 0;
  font-size: 13.5px;
  color: var(--tx3);
  line-height: 1.55;
  max-width: 620px;
}
.cs-hact {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}
.cs-rg {
  position: relative;
  display: flex;
  align-items: center;
  gap: 8px;
  background: var(--panel);
  border: 1px solid var(--ln);
  border-radius: 9px;
  padding: 9px 13px;
  font-size: 13.5px;
  cursor: pointer;
  color: var(--tx2);
  white-space: nowrap;
}
.cs-rg:hover {
  background: var(--hov);
}
.cs-rg span[class*='i-'] {
  width: 16px;
  height: 16px;
  flex-shrink: 0;
}
.cs-rgm {
  position: absolute;
  top: 106%;
  inset-inline-end: 0;
  background: var(--menu);
  border: 1px solid var(--ln);
  border-radius: 9px;
  padding: 5px 0;
  min-width: 160px;
  z-index: 40;
  box-shadow: 0 6px 26px rgba(0, 0, 0, 0.35);
}
.cs-rgi {
  padding: 9px 14px;
  cursor: pointer;
  color: var(--tx);
}
.cs-rgi:hover {
  background: var(--hov);
}
.cs-rgi.on {
  color: var(--g);
}
.cs-ic {
  width: 40px;
  height: 40px;
  display: grid;
  place-items: center;
  border-radius: 9px;
  border: 1px solid var(--ln);
  background: var(--panel);
  color: var(--tx2);
  cursor: pointer;
  flex-shrink: 0;
}
.cs-ic:hover {
  background: var(--hov);
}
.cs-ic span {
  width: 17px;
  height: 17px;
}

/* cards */
.cs-card {
  background: var(--panel);
  border: 1px solid var(--ln);
  border-radius: 13px;
  padding: 17px 18px;
  margin-bottom: 16px;
}
.cs-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(168px, 1fr));
  gap: 12px;
  margin-bottom: 16px;
}
.cs-card.stat {
  margin: 0;
  padding: 16px;
}
.cs-sic {
  width: 34px;
  height: 34px;
  border-radius: 9px;
  display: grid;
  place-items: center;
  margin-bottom: 12px;
}
.cs-sic span {
  width: 17px;
  height: 17px;
}
.cs-sv {
  font-size: 25px;
  font-weight: 600;
  line-height: 1.1;
  margin-bottom: 4px;
}
.cs-sn {
  font-size: 12.5px;
  color: var(--tx3);
}

/* live */
.cs-live {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-bottom: 16px;
}
.cs-lvi {
  flex: 1;
  min-width: 150px;
  display: flex;
  align-items: center;
  gap: 9px;
  background: var(--panel);
  border: 1px solid var(--ln);
  border-radius: 11px;
  padding: 12px 15px;
  cursor: pointer;
}
.cs-lvi:hover {
  background: var(--hov);
}
.cs-lvi b {
  font-size: 18px;
  font-weight: 600;
}
.cs-lvi span:last-child {
  font-size: 12.5px;
  color: var(--tx3);
}
.cs-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.cs-dot.g {
  background: #22c55e;
}
.cs-dot.a {
  background: #f59e0b;
}
.cs-dot.b {
  background: #0ea5e9;
}
.cs-dot.r {
  background: #ef4444;
}

/* card head */
.cs-ch {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 14px;
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
}
.cs-lnk:hover {
  text-decoration: underline;
}

/* chart */
.cs-svg {
  width: 100%;
  height: 190px;
  display: block;
}
.cs-bar {
  fill: var(--g);
  opacity: 0.85;
}
.cs-bar:hover {
  opacity: 1;
}
.cs-xax {
  display: flex;
  justify-content: space-between;
  font-size: 11px;
  color: var(--tx3);
  margin-top: 4px;
}

/* two col */
.cs-two {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}
.cs-two > .cs-card {
  margin-bottom: 16px;
}

/* inbox bars */
.cs-brow {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 0;
}
.cs-bdot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  flex-shrink: 0;
}
.cs-bnm {
  width: 118px;
  flex-shrink: 0;
  font-size: 13px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-btrack {
  flex: 1;
  min-width: 0;
  height: 7px;
  border-radius: 4px;
  background: var(--fld);
  overflow: hidden;
}
.cs-bfill {
  height: 100%;
  border-radius: 4px;
  transition: width 0.3s;
}
.cs-bval {
  width: 42px;
  text-align: end;
  font-size: 13px;
  color: var(--tx2);
  flex-shrink: 0;
}

/* agents */
.cs-arow {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 9px 0;
}
.cs-aav {
  width: 34px;
  height: 34px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: #fff;
  font-size: 12px;
  font-weight: 600;
  flex-shrink: 0;
  overflow: hidden;
}
.cs-aav.sm {
  width: 32px;
  height: 32px;
}
.cs-aav img {
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
  border-radius: 3px;
  background: var(--fld);
  overflow: hidden;
}
.cs-afill {
  height: 100%;
  background: var(--g);
  border-radius: 3px;
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

/* recent */
.cs-rrow {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 9px 0;
  cursor: pointer;
}
.cs-rrow:hover {
  opacity: 0.75;
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

/* workspace grid */
.cs-sgrid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(96px, 1fr));
  gap: 9px;
}
.cs-scell {
  background: var(--fld);
  border-radius: 10px;
  padding: 13px 10px;
  text-align: center;
  cursor: pointer;
}
.cs-scell:hover {
  background: var(--hov);
  outline: 1px solid var(--g);
}
.cs-scic {
  width: 17px;
  height: 17px;
  color: var(--tx3);
  margin: 0 auto 7px;
  display: block;
}
.cs-scell b {
  display: block;
  font-size: 17px;
  margin-bottom: 2px;
}
.cs-scell span {
  font-size: 11.5px;
  color: var(--tx3);
}

/* empty + shimmer */
.cs-empty {
  padding: 34px 16px;
  text-align: center;
  color: var(--tx3);
  font-size: 13px;
}
.cs-empty.sm {
  padding: 22px 12px;
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
  border-radius: 6px;
  background: var(--fld);
  animation: csP 1.3s ease-in-out infinite;
}
.cs-shim.w60 {
  width: 60%;
}
.cs-shim.tall {
  height: 190px;
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
  padding: 6px 0 4px;
}

@media (max-width: 900px) {
  .cs-two {
    grid-template-columns: 1fr;
  }
}
@media (max-width: 768px) {
  .cs-dscroll {
    padding: 16px 14px 32px;
  }
  .cs-hero {
    flex-direction: column;
    gap: 14px;
  }
  .cs-hact {
    width: 100%;
  }
  .cs-rg {
    flex: 1;
  }
  .cs-hero h1 {
    font-size: 21px;
  }
  .cs-grid {
    grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  }
  .cs-bnm {
    width: 84px;
  }
}
</style>
