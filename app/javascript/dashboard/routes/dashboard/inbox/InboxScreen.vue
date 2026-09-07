<script setup>
/* =====================================================================
   InboxScreen.vue  —  ChatsSync ka apna "My Inbox" tab
   chatssync-v16.html ka markup, Chatwoot ke notifications ka data.

   Data REST se aata hai (store action ke naam version ke saath
   badalte hain). Endpoints wahi hain jo Chatwoot khud use karta hai:
     GET  /notifications?page=N
     GET  /notifications/unread_count
     POST /notifications/read_all       (poore ya ek actor ke liye)
     POST /notifications/destroy_all    {type: 'read'}
     DELETE /notifications/:id
   ===================================================================== */
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store.js';

const store = useStore();
const router = useRouter();

const accountId = useMapGetter('getCurrentAccountId');
const currentUser = useMapGetter('getCurrentUser');

/* ---------------- safe dispatch ---------------- */
const warned = {};
const has = name => !!(store._actions && store._actions[name]);
const safeD = (name, payload) => {
  if (!has(name)) {
    if (!warned[name]) {
      warned[name] = 1;
      console.warn('[ChatsSync] action not found:', name);
    }
    return Promise.resolve(null);
  }
  try {
    const r = store.dispatch(name, payload);
    return r && typeof r.then === 'function' ? r : Promise.resolve(r);
  } catch (e) {
    console.warn('[ChatsSync] dispatch failed:', name, e);
    return Promise.reject(e);
  }
};

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

const api = (path, opts = {}) =>
  fetch(`/api/v1/accounts/${accountId.value}${path}`, {
    credentials: 'same-origin',
    headers: authHeaders(),
    ...opts,
  }).then(r => {
    if (!r.ok) throw new Error(`${opts.method || 'GET'} ${path} → ${r.status}`);
    return r.status === 204 ? null : r.json().catch(() => null);
  });

/* Chatwoot ke do shakl hain: {data:{payload,meta}} ya {payload,meta} */
const unwrap = res => {
  const d = res?.data && (res.data.payload || res.data.meta) ? res.data : res;
  return { payload: d?.payload || [], meta: d?.meta || {} };
};

/* ---------------- state ---------------- */
const items = ref([]);
const loading = ref(true);
const loadingMore = ref(false);
const page = ref(1);
const noMore = ref(false);
const unreadCount = ref(0);
const selectedId = ref(null);

const filt = ref('all');
const hmenu = ref(false);
const isMobile = ref(window.innerWidth <= 768);
const isLight = ref(false);

const toasts = ref([]);
let toastId = 0;
const toast = (text, kind = 'ok') => {
  const id = ++toastId;
  toasts.value.push({ id, text, kind });
  setTimeout(() => {
    toasts.value = toasts.value.filter(t => t.id !== id);
  }, 3200);
};

const ask = ref(null);
const confirmBox = (title, body, okText, onOk) => {
  ask.value = {
    title,
    body,
    okText: okText || 'Confirm',
    ok: () => {
      ask.value = null;
      onOk?.();
    },
    cancel: () => {
      ask.value = null;
    },
  };
};

/* ---------------- kism + rang (v16 ke mutabiq) ---------------- */
const KIND = {
  msg: { i: 'i-lucide-message-circle', bg: '#0D5C4A', c: '#7DD99B', n: 'Message' },
  mention: { i: 'i-lucide-at-sign', bg: '#3E2E63', c: '#C4AEF0', n: 'Mention' },
  assign: { i: 'i-lucide-users', bg: '#12405E', c: '#8CBEF2', n: 'Assigned' },
  sla: { i: 'i-lucide-clock-3', bg: '#5C3A15', c: '#F0B429', n: 'Overdue' },
  resolve: { i: 'i-lucide-check', bg: '#0D4A3C', c: '#6ED3B4', n: 'Resolved' },
  newconv: { i: 'i-lucide-inbox', bg: '#4A1F33', c: '#F09BC0', n: 'New' },
};
const KIND_LITE = {
  msg: { bg: '#d5f0e2', c: '#0a6b4f' },
  mention: { bg: '#e6ddf7', c: '#5b3fa0' },
  assign: { bg: '#d9e9f8', c: '#1c5f8f' },
  sla: { bg: '#fbeacc', c: '#8a5a08' },
  resolve: { bg: '#d2f0e6', c: '#0a6b57' },
  newconv: { bg: '#f8dce8', c: '#9c3560' },
};

const kindOf = n => {
  const t = String(n?.notification_type || '');
  if (/mention/i.test(t)) return 'mention';
  if (/assign/i.test(t)) return 'assign';
  if (/sla/i.test(t)) return 'sla';
  if (/resolv/i.test(t)) return 'resolve';
  if (/creation/i.test(t)) return 'newconv';
  return 'msg';
};
const meta = n => {
  const k = kindOf(n);
  const base = KIND[k] || KIND.msg;
  if (!isLight.value) return base;
  const lite = KIND_LITE[k] || KIND_LITE.msg;
  return { ...base, bg: lite.bg, c: lite.c };
};

const isUnread = n => !n?.read_at;

/* ---------------- text ---------------- */
const TYPE_TEXT = {
  conversation_creation: 'New conversation',
  conversation_assignment: 'Conversation assigned to you',
  assigned_conversation_new_message: 'New message',
  conversation_mention: 'You were mentioned',
  participating_conversation_new_message: 'New message',
  sla_missed_first_response: 'First reply overdue',
  sla_missed_next_response: 'Next reply overdue',
  sla_missed_resolution: 'Resolution overdue',
};

const titleOf = n =>
  n?.push_message_title ||
  TYPE_TEXT[n?.notification_type] ||
  String(n?.notification_type || 'Notification').replace(/_/g, ' ');

const senderOf = n => {
  const pa = n?.primary_actor || {};
  return (
    pa.meta?.sender?.name ||
    n?.secondary_actor?.name ||
    pa.sender?.name ||
    ''
  );
};

const convIdOf = n => {
  const pa = n?.primary_actor || {};
  return (
    pa.display_id ||
    pa.conversation_display_id ||
    (n?.primary_actor_type === 'Message'
      ? pa.conversation_id || pa.conversation?.display_id
      : pa.id) ||
    null
  );
};

const subOf = n => {
  const who = senderOf(n);
  const cid = convIdOf(n);
  const bits = [];
  if (who) bits.push(who);
  if (cid) bits.push(`#${cid}`);
  return bits.join(' · ') || KIND[kindOf(n)]?.n || '';
};

const MONTHS = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const timeOf = n => {
  const ts = n?.created_at || n?.last_activity_at;
  if (!ts) return '';
  const d = new Date(Number(ts) * 1000);
  if (Number.isNaN(d.getTime())) return '';
  const now = new Date();
  if (d.toDateString() === now.toDateString())
    return d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  const y = new Date(now);
  y.setDate(y.getDate() - 1);
  if (d.toDateString() === y.toDateString()) return 'Yesterday';
  const days = Math.floor((now - d) / 86400000);
  if (days < 7) return d.toLocaleDateString(undefined, { weekday: 'long' });
  return `${d.getDate()} ${MONTHS[d.getMonth()]}`;
};

/* ---------------- load ---------------- */
const fetchPage = (p, reset = false) =>
  api(`/notifications?page=${p}`)
    .then(res => {
      const { payload, meta: m } = unwrap(res);
      if (reset) items.value = payload;
      else {
        const seen = new Set(items.value.map(x => x.id));
        items.value = [...items.value, ...payload.filter(x => !seen.has(x.id))];
      }
      if (typeof m.unread_count === 'number') unreadCount.value = m.unread_count;
      if (!payload.length) noMore.value = true;
      else page.value = p;
      return payload;
    })
    .catch(err => {
      console.warn('[ChatsSync] notifications load failed', err);
      if (reset) items.value = [];
      noMore.value = true;
      toast('Could not load notifications', 'err');
      return [];
    });

const reload = () => {
  loading.value = true;
  noMore.value = false;
  page.value = 1;
  fetchPage(1, true).finally(() => {
    loading.value = false;
  });
};

const onListScroll = e => {
  const el = e.target;
  if (
    el.scrollHeight - el.scrollTop - el.clientHeight < 260 &&
    !loadingMore.value &&
    !loading.value &&
    !noMore.value
  ) {
    loadingMore.value = true;
    fetchPage(page.value + 1).finally(() => {
      loadingMore.value = false;
    });
  }
};

/* ---------------- filter ---------------- */
const rows = computed(() => {
  const f = filt.value;
  let L = [...items.value];
  if (f === 'unread') L = L.filter(isUnread);
  else if (f !== 'all') L = L.filter(n => kindOf(n) === f);
  return L.sort(
    (a, b) => (b.created_at || 0) - (a.created_at || 0)
  );
});

const countOf = key => {
  if (key === 'all') return items.value.length;
  if (key === 'unread') return items.value.filter(isUnread).length;
  return items.value.filter(n => kindOf(n) === key).length;
};

const pills = computed(() =>
  [
    { k: 'all', n: 'All' },
    { k: 'unread', n: 'Unread' },
    { k: 'mention', n: 'Mentions' },
    { k: 'assign', n: 'Assigned' },
    { k: 'sla', n: 'Overdue' },
  ].map(p => ({ ...p, c: countOf(p.k) }))
);

/* ---------------- actions ---------------- */
const markRead = n => {
  if (!n || !isUnread(n)) return Promise.resolve();
  n.read_at = Math.floor(Date.now() / 1000);
  unreadCount.value = Math.max(0, unreadCount.value - 1);
  return api('/notifications/read_all', {
    method: 'POST',
    body: JSON.stringify({
      primary_actor_type: n.primary_actor_type,
      primary_actor_id: n.primary_actor_id,
    }),
  }).catch(() => {
    /* UI pehle hi update ho chuka — chup rehna theek hai */
  });
};

const openNotif = n => {
  selectedId.value = n.id;
  markRead(n);
  const cid = convIdOf(n);
  if (!cid) {
    toast('This notification has no conversation attached', 'err');
    return;
  }
  router.push({
    name: 'inbox_conversation',
    params: { accountId: accountId.value, conversation_id: cid },
  });
};

const markAllRead = () => {
  hmenu.value = false;
  if (!items.value.some(isUnread)) {
    toast('Nothing unread');
    return;
  }
  const now = Math.floor(Date.now() / 1000);
  items.value.forEach(n => {
    if (!n.read_at) n.read_at = now;
  });
  unreadCount.value = 0;
  api('/notifications/read_all', { method: 'POST' })
    .then(() => toast('All notifications marked read'))
    .catch(() => {
      toast('Could not mark all read', 'err');
      reload();
    });
};

const deleteRead = () => {
  hmenu.value = false;
  const readOnes = items.value.filter(n => !isUnread(n));
  if (!readOnes.length) {
    toast('Nothing to clear');
    return;
  }
  confirmBox(
    'Delete read notifications',
    `Remove ${readOnes.length} read notification(s)? Conversations stay untouched.`,
    'Delete',
    () => {
      api('/notifications/destroy_all', {
        method: 'POST',
        body: JSON.stringify({ type: 'read' }),
      })
        .then(() => {
          items.value = items.value.filter(isUnread);
          toast('Read notifications cleared');
        })
        .catch(() => toast('Could not clear notifications', 'err'));
    }
  );
};

const dropOne = n => {
  const id = n?.id;
  if (!id) return;
  const was = isUnread(n);
  items.value = items.value.filter(x => x.id !== id);
  if (was) unreadCount.value = Math.max(0, unreadCount.value - 1);
  api(`/notifications/${id}`, { method: 'DELETE' }).catch(() => {
    toast('Could not delete notification', 'err');
    reload();
  });
};

const goSettings = () => {
  hmenu.value = false;
  router.push({
    name: 'profile_settings_index',
    params: { accountId: accountId.value },
  });
};

/* ---------------- rail (mobile drawer) ---------------- */
const railOpen = ref(false);
const railEl = () =>
  document.querySelector('aside.bg-n-background') ||
  document.querySelector('aside');

const openRail = () => {
  const a = railEl();
  if (!a) return;
  railOpen.value = true;
  a.classList.remove('ltr:-translate-x-full', 'rtl:translate-x-full');
  a.style.transform = 'translateX(0)';
  a.style.zIndex = '9997';
  a.style.boxShadow = '0 0 40px rgba(0,0,0,.5)';
  document.body.classList.add('cs-rail-open');
};
const closeRail = () => {
  const a = railEl();
  railOpen.value = false;
  if (a) {
    a.style.transform = '';
    a.style.boxShadow = '';
    a.style.zIndex = '';
    if (window.innerWidth <= 768) a.classList.add('ltr:-translate-x-full');
  }
  document.body.classList.remove('cs-rail-open');
};

const closeEverything = () => {
  hmenu.value = false;
  closeRail();
};

/* ---------------- lifecycle ---------------- */
let themeObs = null;
let poller = null;
const onResize = () => {
  isMobile.value = window.innerWidth <= 768;
};
const readTheme = () => {
  isLight.value = !(
    document.documentElement.classList.contains('dark') ||
    document.body.classList.contains('dark') ||
    !!document.querySelector('.dark')
  );
};
const onHotkey = e => {
  if (e.key === 'Escape') {
    hmenu.value = false;
    if (ask.value) ask.value.cancel();
  }
};

onMounted(() => {
  closeRail();
  reload();
  document.addEventListener('click', closeEverything);
  document.addEventListener('keydown', onHotkey);
  window.addEventListener('resize', onResize);
  readTheme();
  themeObs = new MutationObserver(readTheme);
  themeObs.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['class'],
    subtree: true,
  });
  // har 60s par sirf naya page 1 — poori list dobara nahi
  poller = setInterval(() => {
    if (document.hidden) return;
    api('/notifications?page=1')
      .then(res => {
        const { payload, meta: m } = unwrap(res);
        if (typeof m.unread_count === 'number') unreadCount.value = m.unread_count;
        const seen = new Set(items.value.map(x => x.id));
        const fresh = payload.filter(x => !seen.has(x.id));
        if (fresh.length) items.value = [...fresh, ...items.value];
      })
      .catch(() => {});
  }, 60000);
});

onBeforeUnmount(() => {
  document.removeEventListener('click', closeEverything);
  document.removeEventListener('keydown', onHotkey);
  window.removeEventListener('resize', onResize);
  if (themeObs) {
    themeObs.disconnect();
    themeObs = null;
  }
  clearInterval(poller);
  toasts.value = [];
  closeRail();
});
</script>

<template>
  <section class="cs-app cs-inb" :class="{ mob: isMobile, lite: isLight }">
    <!-- ============ LEFT: NOTIFICATIONS ============ -->
    <div class="cs-panel">
      <div class="cs-ph">
        <span
          v-if="isMobile"
          class="cs-ic cs-ham"
          title="Menu"
          @click.stop="openRail"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M4 6h16M4 12h16M4 18h16" stroke-linecap="round" />
          </svg>
        </span>
        <h1>My Inbox</h1>
        <span v-if="unreadCount" class="cs-hcount">{{ unreadCount }}</span>
        <span class="cs-ic" title="More" @click.stop="hmenu = !hmenu">
          <svg viewBox="0 0 24 24" fill="currentColor">
            <circle cx="12" cy="5" r="1.6" />
            <circle cx="12" cy="12" r="1.6" />
            <circle cx="12" cy="19" r="1.6" />
          </svg>
        </span>

        <div v-if="hmenu" class="cs-hm" @click.stop>
          <div class="cs-mi" @click="markAllRead">
            <span class="i-lucide-check-check" /><span>Mark all as read</span>
          </div>
          <div class="cs-mi" @click="deleteRead">
            <span class="i-lucide-trash-2" /><span>Delete read notifications</span>
          </div>
          <div
            class="cs-mi"
            @click="
              hmenu = false;
              reload();
            "
          >
            <span class="i-lucide-rotate-cw" /><span>Refresh</span>
          </div>
          <div class="cs-sep" />
          <div class="cs-mi" @click="goSettings">
            <span class="i-lucide-settings" /><span>Notification settings</span>
          </div>
        </div>
      </div>

      <div class="cs-pills">
        <div
          v-for="p in pills"
          :key="p.k"
          class="cs-pl"
          :class="{ on: filt === p.k }"
          @click="filt = p.k"
        >
          <span>{{ p.n }}</span>
          <span v-if="p.c" class="cs-plc">{{ p.c }}</span>
        </div>
      </div>

      <div class="cs-list" @scroll.passive="onListScroll">
        <div v-if="loading" class="cs-sk">
          <div v-for="i in 7" :key="i" class="cs-skr">
            <div class="cs-ska" />
            <div class="cs-skb">
              <div class="cs-skl" />
              <div class="cs-skl short" />
            </div>
          </div>
        </div>

        <div v-else-if="!rows.length" class="cs-nempty">
          <span class="i-lucide-inbox" />
          <div class="cs-net">Nothing here</div>
          <div class="cs-nes">
            {{
              filt === 'all'
                ? 'You are all caught up.'
                : 'No notifications match this filter.'
            }}
          </div>
          <button v-if="filt !== 'all'" class="cs-btn ghost" @click="filt = 'all'">
            Show all
          </button>
        </div>

        <template v-else>
          <div
            v-for="n in rows"
            :key="n.id"
            class="cs-nrow"
            :class="{ unrd: isUnread(n), on: selectedId === n.id }"
            @click="openNotif(n)"
          >
            <div
              class="cs-nic"
              :style="{ background: meta(n).bg, color: meta(n).c }"
            >
              <span :class="meta(n).i" />
            </div>
            <div class="cs-nb">
              <div class="cs-n1">
                <span class="cs-nt">{{ titleOf(n) }}</span>
                <span class="cs-ntm">{{ timeOf(n) }}</span>
              </div>
              <div class="cs-n2">{{ subOf(n) }}</div>
            </div>
            <span
              class="cs-nx i-lucide-x"
              title="Remove"
              @click.stop="dropOne(n)"
            />
          </div>
          <div v-if="loadingMore" class="cs-more">Loading more…</div>
        </template>
      </div>
    </div>

    <!-- ============ RIGHT: BLANK ============ -->
    <div class="cs-side">
      <div class="cs-blank">
        <span class="i-lucide-inbox" />
        <div class="cs-bt">Select a notification</div>
        <div class="cs-bs">
          Mentions, assignments and overdue conversations land here. Pick one on
          the left to open the chat it belongs to.
        </div>
      </div>
    </div>

    <div v-if="isMobile && hmenu" class="cs-sheetbg" />

    <!-- ============ CONFIRM ============ -->
    <div v-if="ask" class="cs-fw" @click.self="ask.cancel()">
      <div class="cs-ask" @click.stop>
        <div class="cs-askt">{{ ask.title }}</div>
        <div class="cs-askb">{{ ask.body }}</div>
        <div class="cs-askf">
          <button class="cs-btn ghost" @click="ask.cancel()">Cancel</button>
          <button class="cs-btn dgr" @click="ask.ok()">{{ ask.okText }}</button>
        </div>
      </div>
    </div>

    <!-- ============ TOASTS ============ -->
    <div class="cs-toasts">
      <div
        v-for="t in toasts"
        :key="t.id"
        class="cs-toast"
        :class="{ err: t.kind === 'err' }"
      >
        {{ t.text }}
      </div>
    </div>
  </section>
</template>

<style scoped>
/* tokens — ChatsScreen / ContactsScreen jaise hi */
.cs-app {
  position: relative;
  max-width: 100%;
  overflow: hidden;

  --panel: #111b21;
  --head: #202c33;
  --fld: #202c33;
  --tx: #e9edef;
  --tx2: #aebac1;
  --tx3: #8696a0;
  --ln: #222e35;
  --ln2: #1d282f;
  --hov: #202c33;
  --sel: #2a3942;
  --g: #00a884;
  --g-tint: #103529;
  --menu: #233138;
  --menu-hov: #182229;
  --content: #0b141a;
  --red: #f15c6d;
  --red-tint: #3a1d22;

  display: flex;
  width: 100%;
  height: 100%;
  min-width: 0;
  font-size: 14px;
  color: var(--tx);
  background: var(--content);
}
.cs-app.lite {
  --panel: #ffffff;
  --head: #eff3f4;
  --fld: #e3e9eb;
  --tx: #0a1519;
  --tx2: #3d4f57;
  --tx3: #55666e;
  --ln: #c7d1d6;
  --ln2: #dce3e6;
  --hov: #eceff1;
  --sel: #cfe6dd;
  --g: #00755f;
  --g-tint: #c8e8db;
  --menu: #ffffff;
  --menu-hov: #eceff1;
  --content: #e3e8ea;
  --red: #c22b3b;
  --red-tint: #f9dde1;
}
.cs-app.lite .cs-hm,
.cs-app.lite .cs-ask {
  border: 1px solid var(--ln);
  box-shadow: 0 8px 28px rgba(11, 20, 26, 0.16);
}
.cs-app.lite .cs-pl {
  border: 1px solid var(--ln);
}
.cs-app.lite .cs-pl.on {
  border-color: var(--g);
}
.cs-app.lite .cs-toast {
  background: #10202a;
  color: #fff;
}
.cs-app.lite .cs-toast.err {
  background: var(--red);
  color: #fff;
}
.cs-app.lite .cs-fw {
  background: rgba(11, 20, 26, 0.4);
}
.cs-app * {
  box-sizing: border-box;
}

/* panel */
.cs-panel {
  flex: 0 0 auto;
  width: 34%;
  min-width: 320px;
  max-width: 440px;
  display: flex;
  flex-direction: column;
  background: var(--panel);
  border-right: 1px solid var(--ln);
  min-height: 0;
  overflow: hidden;
}
.cs-ph {
  height: 60px;
  flex-shrink: 0;
  background: var(--head);
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 0 8px 0 18px;
  position: relative;
}
.cs-ph h1 {
  flex: 1;
  min-width: 0;
  font-size: 19px;
  font-weight: 600;
  margin: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-hcount {
  background: var(--g);
  color: #fff;
  font-size: 11.5px;
  font-weight: 600;
  min-width: 20px;
  height: 20px;
  padding: 0 6px;
  border-radius: 10px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}
.cs-ic {
  width: 38px;
  height: 38px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  cursor: pointer;
  color: var(--tx2);
  flex-shrink: 0;
}
.cs-ic:hover {
  background: var(--hov);
}
.cs-ic svg {
  width: 20px;
  height: 20px;
}
.cs-ham {
  margin-left: -8px;
}

/* pills */
.cs-pills {
  display: flex;
  gap: 7px;
  padding: 10px 12px;
  overflow-x: auto;
  flex-shrink: 0;
  scrollbar-width: none;
  max-width: 100%;
}
.cs-pills::-webkit-scrollbar {
  display: none;
}
.cs-pl {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 13px;
  border-radius: 15px;
  background: var(--fld);
  color: var(--tx2);
  font-size: 13.5px;
  cursor: pointer;
  white-space: nowrap;
  flex-shrink: 0;
}
.cs-pl:hover {
  filter: brightness(1.12);
}
.cs-pl.on {
  background: var(--g-tint);
  color: var(--g);
}
.cs-plc {
  font-size: 11.5px;
  opacity: 0.75;
  font-weight: 600;
}

/* list */
.cs-list {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  overscroll-behavior: contain;
}
.cs-nrow {
  display: flex;
  gap: 14px;
  padding: 13px 12px 13px 20px;
  cursor: pointer;
  align-items: flex-start;
  position: relative;
}
.cs-nrow:hover {
  background: var(--hov);
}
.cs-nrow.on {
  background: var(--sel);
}
.cs-nrow.unrd::after {
  content: '';
  position: absolute;
  left: 7px;
  top: 26px;
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--g);
}
.cs-nic {
  width: 38px;
  height: 38px;
  border-radius: 10px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}
.cs-nic span {
  width: 18px;
  height: 18px;
}
.cs-nb {
  flex: 1;
  min-width: 0;
  border-bottom: 1px solid var(--ln2);
  padding-bottom: 13px;
  margin-bottom: -13px;
}
.cs-nrow:last-child .cs-nb {
  border-bottom: none;
}
.cs-n1 {
  display: flex;
  align-items: baseline;
  gap: 10px;
  margin-bottom: 3px;
}
.cs-nt {
  flex: 1;
  min-width: 0;
  font-size: 14.5px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-nrow.unrd .cs-nt {
  font-weight: 600;
}
.cs-ntm {
  font-size: 11.5px;
  color: var(--tx3);
  flex-shrink: 0;
}
.cs-n2 {
  font-size: 13px;
  color: var(--tx3);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-nx {
  width: 15px;
  height: 15px;
  color: var(--tx3);
  opacity: 0;
  flex-shrink: 0;
  margin-top: 11px;
  cursor: pointer;
}
.cs-nrow:hover .cs-nx {
  opacity: 0.6;
}
.cs-nx:hover {
  opacity: 1 !important;
  color: var(--red);
}
.cs-more {
  text-align: center;
  font-size: 12.5px;
  color: var(--tx3);
  padding: 14px 0 20px;
}

/* skeleton */
.cs-sk {
  padding: 6px 0;
}
.cs-skr {
  display: flex;
  gap: 14px;
  padding: 13px 20px;
  align-items: center;
  animation: csPulse 1.3s ease-in-out infinite;
}
.cs-ska {
  width: 38px;
  height: 38px;
  border-radius: 10px;
  background: var(--fld);
  flex-shrink: 0;
}
.cs-skb {
  flex: 1;
  min-width: 0;
}
.cs-skl {
  height: 11px;
  border-radius: 6px;
  background: var(--fld);
  margin-bottom: 8px;
}
.cs-skl.short {
  width: 45%;
  margin-bottom: 0;
}
@keyframes csPulse {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
}

/* empty */
.cs-nempty {
  padding: 56px 26px;
  text-align: center;
  color: var(--tx3);
}
.cs-nempty > span[class*='i-'] {
  width: 44px;
  height: 44px;
  opacity: 0.5;
  margin: 0 auto 14px;
  display: block;
}
.cs-net {
  font-size: 15.5px;
  color: var(--tx2);
  margin-bottom: 6px;
}
.cs-nes {
  font-size: 13px;
  line-height: 1.5;
  margin-bottom: 16px;
}

/* right blank */
.cs-side {
  flex: 1;
  min-width: 0;
  display: flex;
  background: var(--content);
}
.cs-blank {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 40px;
  color: var(--tx3);
}
.cs-blank > span[class*='i-'] {
  width: 58px;
  height: 58px;
  opacity: 0.4;
  margin-bottom: 18px;
}
.cs-bt {
  font-size: 22px;
  color: var(--tx2);
  font-weight: 300;
  margin-bottom: 10px;
}
.cs-bs {
  font-size: 13.5px;
  max-width: 440px;
  line-height: 1.6;
}

/* menu */
.cs-hm {
  position: absolute;
  top: 52px;
  right: 8px;
  min-width: 244px;
  background: var(--menu);
  border-radius: 10px;
  box-shadow: 0 6px 26px rgba(0, 0, 0, 0.45);
  padding: 7px 0;
  z-index: 700;
  max-height: 76vh;
  overflow-y: auto;
}
.cs-mi {
  display: flex;
  align-items: center;
  gap: 13px;
  padding: 10px 16px;
  cursor: pointer;
  font-size: 14px;
  color: var(--tx);
  white-space: nowrap;
}
.cs-mi:hover {
  background: var(--menu-hov);
}
.cs-mi span[class*='i-'] {
  width: 17px;
  height: 17px;
  color: var(--tx3);
  flex-shrink: 0;
}
.cs-sep {
  height: 1px;
  background: var(--ln);
  margin: 6px 0;
}

/* overlays */
.cs-fw {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.55);
  z-index: 9000;
  display: grid;
  place-items: center;
  padding: 16px;
}
.cs-ask {
  background: var(--panel);
  border-radius: 12px;
  padding: 22px;
  width: 400px;
  max-width: 100%;
}
.cs-askt {
  font-size: 17px;
  margin-bottom: 10px;
}
.cs-askb {
  font-size: 13.8px;
  color: var(--tx2);
  line-height: 1.55;
  margin-bottom: 20px;
}
.cs-askf {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}
.cs-btn {
  background: var(--g);
  color: #fff;
  border: 0;
  border-radius: 20px;
  padding: 9px 22px;
  font-size: 14px;
  font-family: inherit;
  cursor: pointer;
}
.cs-btn:hover {
  filter: brightness(1.08);
}
.cs-btn.ghost {
  background: transparent;
  color: var(--tx2);
  border: 1px solid var(--ln);
}
.cs-btn.ghost:hover {
  background: var(--hov);
}
.cs-btn.dgr {
  background: var(--red);
}

.cs-sheetbg {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  z-index: 9390;
}
.cs-toasts {
  position: fixed;
  bottom: 26px;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  flex-direction: column;
  gap: 8px;
  z-index: 9500;
  pointer-events: none;
}
.cs-toast {
  background: var(--menu);
  color: var(--tx);
  padding: 11px 20px;
  border-radius: 22px;
  font-size: 13.5px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
  white-space: nowrap;
}
.cs-toast.err {
  background: var(--red-tint);
  color: var(--red);
}

/* mobile */
@media (max-width: 768px) {
  .cs-app {
    max-width: 100vw;
  }
  .cs-panel {
    width: 100%;
    max-width: 100vw;
    min-width: 0;
    border-right: none;
  }
  .cs-side {
    display: none;
  }
  .cs-ph {
    padding: 0 6px 0 12px;
  }
  .cs-nrow {
    padding: 13px 10px 13px 18px;
  }
  .cs-nx {
    opacity: 0.5;
  }
  .cs-hm {
    position: fixed;
    left: 0;
    right: 0;
    top: auto;
    bottom: 0;
    min-width: 0;
    max-width: none;
    border-radius: 14px 14px 0 0;
    z-index: 9400;
    box-shadow: 0 -8px 40px rgba(0, 0, 0, 0.5);
    padding-bottom: calc(10px + env(safe-area-inset-bottom));
  }
  .cs-mi {
    padding: 13px 20px;
    font-size: 15px;
  }
  .cs-toasts {
    bottom: 80px;
  }
}
</style>

<style>
/* ===== RAIL (Chatwoot ka sidebar) — ChatsScreen/ContactsScreen jaisa ===== */
body aside {
  width: 62px !important;
  min-width: 62px !important;
  max-width: 62px !important;
  background: #202c33 !important;
  padding: 11px 0 10px !important;
  border-right: none !important;
  align-items: center !important;
}
body:not(.dark) aside,
html:not(.dark) body aside {
  background: #eff3f4 !important;
}
body aside nav,
body aside > section {
  padding: 0 !important;
  width: 100%;
}
body aside nav ul {
  align-items: center !important;
  gap: 5px !important;
  width: 100%;
}
body aside nav a,
body aside nav > ul > li > a,
body aside nav [role='button'] {
  width: 42px !important;
  height: 42px !important;
  border-radius: 50% !important;
  display: grid !important;
  place-items: center !important;
  padding: 0 !important;
  margin: 0 auto !important;
  color: #aebac1 !important;
  transition: background 0.13s, color 0.13s !important;
}
body aside nav a:hover {
  background: #2a3942 !important;
}
body aside nav a.active,
body aside nav a[aria-current='page'],
body aside nav a.router-link-active {
  background: #103529 !important;
  color: #00a884 !important;
}
html:not(.dark) body aside nav a {
  color: #3d4f57 !important;
}
html:not(.dark) body aside nav a:hover {
  background: #dde4e7 !important;
}
html:not(.dark) body aside nav a.active,
html:not(.dark) body aside nav a.router-link-active {
  background: #c8e8db !important;
  color: #00755f !important;
}
body aside nav a span:not([class*='i-']):not([class*='icon']),
body aside nav a > span + span {
  display: none !important;
}
body aside nav a [class*='i-'] {
  width: 21px !important;
  height: 21px !important;
}
body aside nav ul + ul {
  border-top: 1px solid #2a3942;
  margin-top: 8px !important;
  padding-top: 8px !important;
  width: 28px;
}
html:not(.dark) body aside nav ul + ul {
  border-top-color: #c7d1d6;
}
body aside > div[class*='cursor-col-resize'] {
  display: none !important;
}

/* mobile par drawer */
body.cs-rail-open aside {
  width: 272px !important;
  min-width: 272px !important;
  max-width: 272px !important;
  align-items: stretch !important;
  padding: 12px 0 calc(16px + env(safe-area-inset-bottom)) !important;
  overflow-y: auto !important;
}
body.cs-rail-open aside nav ul {
  align-items: stretch !important;
  gap: 2px !important;
}
body.cs-rail-open aside nav ul + ul {
  width: auto !important;
  margin: 10px 14px 0 !important;
  padding-top: 10px !important;
}
body.cs-rail-open aside nav a,
body.cs-rail-open aside nav [role='button'] {
  width: auto !important;
  height: auto !important;
  min-height: 46px !important;
  border-radius: 10px !important;
  display: flex !important;
  align-items: center !important;
  gap: 16px !important;
  justify-content: flex-start !important;
  padding: 0 16px !important;
  margin: 0 10px !important;
  font-size: 15px !important;
}
/* naam dikhane wale rule ki specificity hide wale se zyada honi chahiye */
body.cs-rail-open aside nav a span:not([class*='i-']):not([class*='icon']),
body.cs-rail-open aside nav a > span + span {
  display: inline !important;
  white-space: nowrap !important;
}
body.cs-rail-open::before {
  content: '';
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 9996;
}

@media (max-width: 768px) {
  body aside {
    position: fixed !important;
    top: 0 !important;
    bottom: 0 !important;
    left: 0 !important;
    width: 272px !important;
    min-width: 0 !important;
    max-width: 272px !important;
    align-items: stretch !important;
    transition: transform 0.18s ease !important;
  }
  body:not(.cs-rail-open) aside {
    transform: translateX(-100%) !important;
    box-shadow: none !important;
  }
  body.cs-rail-open aside {
    transform: translateX(0) !important;
    z-index: 9997 !important;
  }
  html,
  body {
    overflow-x: hidden !important;
  }
}
</style>
