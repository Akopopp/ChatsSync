<script setup>
/* =====================================================================
   Sidebar.vue  —  ChatsSync rail
   chatssync-v16.html ki asal values:
     rail 62px · brand 40px (radius 11) · brandsep 28x1
     .ri 42x42 gol · margin-bottom 5 · hover/on tints
     badge 17px top-right · green dot 8px · rsep 28x1 · rsp flex
     tooltip: left 50px, kaala, 12px, scale .92 -> 1
   Mobile: 272px drawer + apna floating hamburger (har page par).
   ===================================================================== */
import {
  ref,
  computed,
  nextTick,
  onMounted,
  onBeforeUnmount,
  watch,
} from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import { useWindowSize } from '@vueuse/core';

import { provideSidebarContext } from './provider';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import { useSidebarKeyboardShortcuts } from './useSidebarKeyboardShortcuts';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import SidebarProfileMenu from './SidebarProfileMenu.vue';

const props = defineProps({
  isMobileSidebarOpen: { type: Boolean, default: false },
});
const emit = defineEmits([
  'closeKeyShortcutModal',
  'openKeyShortcutModal',
  'showCreateAccountModal',
  'closeMobileSidebar',
]);

const store = useStore();
const route = useRoute();
const { t } = useI18n();
const { accountScopedRoute } = useAccount();

const currentUserRole = useMapGetter('getCurrentRole');
const isAdmin = computed(() => currentUserRole.value === 'administrator');
const accountId = useMapGetter('getCurrentAccountId');
const unreadNotifications = useMapGetter('notifications/getUnreadCount');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);
const inboxesList = useMapGetter('inboxes/getInboxes');
const globalConfig = useMapGetter('globalConfig/get');
/* ChatsSync ka asli icon file ke andar hi hai (data URI) — na koi extra
   request, na kisi asset path par bharosa, na khud banai hui naqal.
   Account mein apna logo set ho to woh pehle. */
const CS_ICON = 'data:image/png;base64,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';
/* Hamesha ChatsSync ka apna icon. PEHLE yahan installation ka logo
   (globalConfig) pehle dekha jaata tha — woh set hone ki soorat mein
   hamara icon kabhi lagta hi nahi tha. */
const brandLogo = computed(() => CS_ICON);

const { width: windowWidth } = useWindowSize();
const isMobile = computed(() => windowWidth.value < 768);

/* ---- mobile drawer ---- */
const mobileOpen = ref(false);
const onRailToggle = () => {
  mobileOpen.value = !mobileOpen.value;
};
const drawerOpen = computed(
  () => isMobile.value && (props.isMobileSidebarOpen || mobileOpen.value)
);
const expanded = computed(() => drawerOpen.value);

const expandedItem = ref(null);
const setExpandedItem = name => {
  expandedItem.value = expandedItem.value === name ? null : name;
};
provideSidebarContext({
  expandedItem,
  setExpandedItem,
  isCollapsed: computed(() => !expanded.value),
  sidebarWidth: computed(() => (expanded.value ? 272 : 62)),
  isResizing: ref(false),
});

useSidebarKeyboardShortcuts(show =>
  emit(show ? 'openKeyShortcutModal' : 'closeKeyShortcutModal')
);

const hasConversationUnreadCounts = computed(() =>
  isFeatureEnabledonAccount.value(
    accountId.value,
    FEATURE_FLAGS.CONVERSATION_UNREAD_COUNTS
  )
);
const convUnread = computed(() => {
  const g = store.getters || {};
  const direct = g['conversationUnreadCounts/getTotalUnreadCount'];
  if (typeof direct === 'number') return direct;
  const perInbox = g['conversationUnreadCounts/getInboxUnreadCount'];
  if (typeof perInbox === 'function') {
    return (inboxesList.value || []).reduce(
      (a, ib) => a + (Number(perInbox(ib.id)) || 0),
      0
    );
  }
  return 0;
});
const botsOnline = computed(() => {
  const list = (store.getters || {})['agentBots/getBots'];
  return Array.isArray(list) && list.length > 0;
});

/* ---- theme ---- */
let themeObs = null;
const isDark = ref(true);
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
  const d = detectDark();
  if (d !== isDark.value) isDark.value = d;
};

/* Theme ek hi jagah se lagti hai taake rail ka button aur Chatwoot ke
   profile menu wala button dono ek doosre se juday rahen. */
const applyTheme = dark => {
  const html = document.documentElement;
  html.classList.toggle('dark', dark);
  html.classList.toggle('light', !dark);
  document.body.classList.toggle('dark', dark);
  try {
    localStorage.setItem('cs_theme', dark ? 'dark' : 'light');
  } catch (e) {
    /* ignore */
  }
  // Chatwoot ke apne setting mein bhi likho — reload par bachi rahe
  try {
    store.dispatch('updateUISettings', { color_scheme: dark ? 'dark' : 'light' });
  } catch (e) {
    /* ignore */
  }
  // baqi screens foran sun lein, MutationObserver ka intezaar na karein
  window.dispatchEvent(
    new CustomEvent('chatssync:theme', { detail: { dark } })
  );
};
const toggleTheme = () => {
  applyTheme(!isDark.value);
  // rang badalne mein ek do frame lagte hain — phir khud parh lenge
  setTimeout(readTheme, 60);
  setTimeout(readTheme, 400);
};

onMounted(() => {
  window.addEventListener('chatssync:toggle-rail', onRailToggle);
  store.dispatch('labels/get');
  store.dispatch('inboxes/get');
  store.dispatch('notifications/unReadCount');
  store.dispatch('teams/get');
  store.dispatch('attributes/get');
  store.dispatch('customViews/get', 'conversation');
  store.dispatch('customViews/get', 'contact');
  try {
    store.dispatch('agentBots/get');
  } catch (e) {
    /* optional */
  }
  // pichhla intikhab wapas lagao (Chatwoot 'auto' par chhod deta hai)
  try {
    const saved = localStorage.getItem('cs_theme');
    if (saved) applyTheme(saved === 'dark');
  } catch (e) {
    /* ignore */
  }
  readTheme();
  themeObs = new MutationObserver(readTheme);
  themeObs.observe(document.documentElement, { attributes: true });
  themeObs.observe(document.body, { attributes: true });
  /* Pehle yahan har second ek poll chalti thi. Ab uski zaroorat nahi —
     rail ke rang Chatwoot ke apne --slate-* se aate hain jo khud badalte
     hain. isDark sirf moon/sun icon ke liye chahiye, aur uske liye
     observer kaafi hai. Mobile par ye bojh bekar tha. */
});
onBeforeUnmount(() => {
  window.removeEventListener('chatssync:toggle-rail', onRailToggle);
  if (themeObs) {
    themeObs.disconnect();
    themeObs = null;
  }
});

watch(
  [accountId, hasConversationUnreadCounts],
  ([id, on]) => {
    if (!id) return;
    store.dispatch(
      on ? 'conversationUnreadCounts/get' : 'conversationUnreadCounts/clear'
    );
  },
  { immediate: true }
);

const closeMobileSidebar = () => {
  mobileOpen.value = false;
  if (!props.isMobileSidebarOpen) return;
  emit('closeMobileSidebar');
};

/* ---------------- tabs (v16 ki tarteeb + Dashboard) ---------------- */
const groupA = computed(() => [
  {
    name: 'Dashboard',
    label: 'Dashboard',
    icon: 'i-lucide-layout-dashboard',
    to: accountScopedRoute('chatssync_dashboard'),
    activeOn: ['chatssync_dashboard'],
  },
  {
    name: 'Conversation',
    label: t('SIDEBAR.CONVERSATIONS'),
    icon: 'i-lucide-message-circle',
    to: accountScopedRoute('home'),
    activeOn: ['inbox_conversation', 'home'],
    count: () => convUnread.value,
  },
  {
    name: 'Inbox',
    label: t('SIDEBAR.INBOX'),
    icon: 'i-lucide-inbox',
    to: accountScopedRoute('inbox_view'),
    activeOn: ['inbox_view', 'inbox_view_conversation'],
    count: () => unreadNotifications.value,
  },
  {
    name: 'Contacts',
    label: t('SIDEBAR.CONTACTS'),
    icon: 'i-lucide-contact',
    to: accountScopedRoute(
      'contacts_dashboard_index',
      {},
      { page: 1, search: undefined }
    ),
    activeOn: [
      'contacts_dashboard_index',
      'contacts_dashboard_active',
      'contacts_dashboard_labels_index',
      'contacts_dashboard_segments_index',
      'contacts_edit',
    ],
  },
  {
    name: 'Campaigns',
    label: t('SIDEBAR.CAMPAIGNS'),
    icon: 'i-lucide-megaphone',
    activeOn: [
      'campaigns_whatsapp_index',
      'campaigns_livechat_index',
      'campaigns_sms_index',
    ],
    children: [
      {
        label: t('SIDEBAR.WHATSAPP'),
        icon: 'i-lucide-message-circle',
        to: accountScopedRoute('campaigns_whatsapp_index'),
      },
      {
        label: t('SIDEBAR.LIVE_CHAT'),
        icon: 'i-lucide-globe',
        to: accountScopedRoute('campaigns_livechat_index'),
      },
      {
        label: t('SIDEBAR.SMS'),
        icon: 'i-lucide-smartphone',
        to: accountScopedRoute('campaigns_sms_index'),
      },
    ],
  },
]);

const groupB = computed(() => [
  ...(isAdmin.value
    ? [
        {
          name: 'Chatbot',
          label: 'Chatbot Builder',
          icon: 'i-lucide-bot',
          to: accountScopedRoute('chatbot_builder'),
          activeOn: ['chatbot_builder'],
          dot: () => botsOnline.value,
        },
        {
          name: 'Templates',
          label: 'Templates',
          icon: 'i-lucide-layout-template',
          to: accountScopedRoute('templates_index'),
          activeOn: ['templates_index'],
        },
        {
          name: 'Gallery',
          label: 'Gallery',
          icon: 'i-lucide-image',
          to: accountScopedRoute('gallery_index'),
          activeOn: ['gallery_index'],
        },
      ]
    : []),
  {
    name: 'Reports',
    label: t('SIDEBAR.REPORTS'),
    icon: 'i-lucide-chart-spline',
    activeOn: [
      'account_overview_reports', 'conversation_reports', 'agent_reports_index',
      'agent_reports_show', 'label_reports_index', 'inbox_reports_index',
      'inbox_reports_show', 'team_reports_index', 'team_reports_show',
      'csat_reports', 'bot_reports',
    ],
    children: [
      { label: t('SIDEBAR.REPORTS_OVERVIEW'), icon: 'i-lucide-layout-dashboard', to: accountScopedRoute('account_overview_reports') },
      { label: t('SIDEBAR.REPORTS_CONVERSATION'), icon: 'i-lucide-message-circle', to: accountScopedRoute('conversation_reports') },
      { label: t('SIDEBAR.REPORTS_AGENT'), icon: 'i-lucide-square-user', to: accountScopedRoute('agent_reports_index') },
      { label: t('SIDEBAR.REPORTS_LABEL'), icon: 'i-lucide-tags', to: accountScopedRoute('label_reports_index') },
      { label: t('SIDEBAR.REPORTS_INBOX'), icon: 'i-lucide-inbox', to: accountScopedRoute('inbox_reports_index') },
      { label: t('SIDEBAR.REPORTS_TEAM'), icon: 'i-lucide-users', to: accountScopedRoute('team_reports_index') },
      { label: t('SIDEBAR.CSAT'), icon: 'i-lucide-smile', to: accountScopedRoute('csat_reports') },
      { label: t('SIDEBAR.REPORTS_BOT'), icon: 'i-lucide-bot', to: accountScopedRoute('bot_reports') },
    ],
  },
]);

const settingsItem = computed(() => ({
  name: 'Settings',
  label: t('SIDEBAR.SETTINGS'),
  icon: 'i-lucide-settings',
  activeOn: [
    'general_settings_index', 'agent_list', 'settings_teams_list',
    'settings_teams_new', 'settings_teams_finish', 'settings_teams_add_agents',
    'settings_teams_show', 'settings_teams_edit', 'settings_teams_edit_members',
    'settings_teams_edit_finish', 'settings_inbox_list', 'settings_inbox_show',
    'settings_inbox_new', 'settings_inbox_finish', 'settings_inboxes_page_channel',
    'settings_inboxes_add_agents', 'labels_list', 'attributes_list',
    'automation_list', 'agent_bots', 'macros_wrapper', 'canned_list',
    'settings_applications',
  ],
  children: [
    { label: t('SIDEBAR.ACCOUNT_SETTINGS'), icon: 'i-lucide-briefcase', to: accountScopedRoute('general_settings_index') },
    { label: t('SIDEBAR.AGENTS'), icon: 'i-lucide-square-user', to: accountScopedRoute('agent_list') },
    { label: t('SIDEBAR.TEAMS'), icon: 'i-lucide-users', to: accountScopedRoute('settings_teams_list') },
    { label: t('SIDEBAR.INBOXES'), icon: 'i-lucide-inbox', to: accountScopedRoute('settings_inbox_list') },
    { label: t('SIDEBAR.LABELS'), icon: 'i-lucide-tags', to: accountScopedRoute('labels_list') },
    { label: t('SIDEBAR.CUSTOM_ATTRIBUTES'), icon: 'i-lucide-code', to: accountScopedRoute('attributes_list') },
    { label: t('SIDEBAR.AUTOMATION'), icon: 'i-lucide-repeat', to: accountScopedRoute('automation_list') },
    { label: t('SIDEBAR.AGENT_BOTS'), icon: 'i-lucide-bot', to: accountScopedRoute('agent_bots') },
    { label: t('SIDEBAR.MACROS'), icon: 'i-lucide-toy-brick', to: accountScopedRoute('macros_wrapper') },
    { label: t('SIDEBAR.CANNED_RESPONSES'), icon: 'i-lucide-message-square-quote', to: accountScopedRoute('canned_list') },
    { label: t('SIDEBAR.INTEGRATIONS'), icon: 'i-lucide-blocks', to: accountScopedRoute('settings_applications') },
  ],
}));

const isActive = item => (item.activeOn || []).includes(route.name);

/* ---- flyout: fixed, warna nav ka overflow-y usay kaat deta hai ---- */
const openFly = ref(null);
const flyPos = ref({ top: 0, left: 0 });
const toggleFly = (name, ev) => {
  if (openFly.value === name) {
    openFly.value = null;
    return;
  }
  openFly.value = name;
  if (expanded.value || !ev?.currentTarget) return;
  const r = ev.currentTarget.getBoundingClientRect();
  flyPos.value = { top: r.top - 4, left: r.right + 10 };
  nextTick(() => {
    const el = document.querySelector('.cs-rl-sub');
    if (!el) return;
    let top = r.top - 4;
    if (top + el.offsetHeight > window.innerHeight - 12)
      top = Math.max(12, window.innerHeight - el.offsetHeight - 12);
    flyPos.value = { top, left: r.right + 10 };
  });
};
const closeFly = () => {
  openFly.value = null;
};
const onLeafClick = () => {
  closeFly();
  closeMobileSidebar();
};
watch(
  () => route.name,
  () => closeFly()
);
</script>

<template>
  <aside
    v-on-click-outside="[
      () => {
        closeFly();
        closeMobileSidebar();
      },
      { ignore: ['.cs-rl-ham', '[data-popover-content]', '[data-popover-backdrop]'] },
    ]"
    class="cs-rail"
    :class="{ open: expanded, 'cs-rail--hidden': isMobile && !drawerOpen }"
  >
    <!-- brand -->
    <div class="cs-rl-brand">
      <span class="cs-rl-mark">
        <img :src="brandLogo" alt="ChatsSync" />
      </span>
      <span v-if="expanded" class="cs-rl-name">ChatsSync</span>
    </div>
    <div class="cs-rl-bsep" />

    <nav class="cs-rl-nav">
      <template v-for="(grp, gi) in [groupA, groupB]" :key="gi">
        <div v-if="gi === 1" class="cs-rl-sep" />
        <template v-for="item in grp" :key="item.name">
          <RouterLink
            v-if="!item.children"
            :to="item.to"
            class="cs-ri"
            :class="{ on: isActive(item) }"
            @click="onLeafClick"
          >
            <span class="cs-ri-ic" :class="item.icon" />
            <span v-if="expanded" class="cs-ri-lbl">{{ item.label }}</span>
            <span v-if="item.count && item.count() > 0" class="cs-ri-bg">
              {{ item.count() > 99 ? '99+' : item.count() }}
            </span>
            <span v-if="item.dot && item.dot()" class="cs-ri-gd" />
            <span v-if="!expanded" class="cs-ri-tip">{{ item.label }}</span>
          </RouterLink>

          <div v-else class="cs-rl-wrap">
            <button
              type="button"
              class="cs-ri"
              :class="{ on: isActive(item), fly: openFly === item.name }"
              @click.stop="toggleFly(item.name, $event)"
            >
              <span class="cs-ri-ic" :class="item.icon" />
              <span v-if="expanded" class="cs-ri-lbl">{{ item.label }}</span>
              <span
                v-if="expanded"
                class="cs-ri-arw i-lucide-chevron-down"
                :class="{ up: openFly === item.name }"
              />
              <span v-if="!expanded" class="cs-ri-tip">{{ item.label }}</span>
            </button>
            <div
              v-if="openFly === item.name"
              class="cs-rl-sub"
              :class="{ inline: expanded }"
              :style="expanded ? null : { top: flyPos.top + 'px', left: flyPos.left + 'px' }"
              @click.stop
            >
              <div v-if="!expanded" class="cs-rl-subh">{{ item.label }}</div>
              <RouterLink
                v-for="c in item.children"
                :key="c.label"
                :to="c.to"
                class="cs-rl-leaf"
                @click="onLeafClick"
              >
                <span class="cs-rl-lic" :class="c.icon" />
                <span class="cs-rl-ltx">{{ c.label }}</span>
              </RouterLink>
            </div>
          </div>
        </template>
      </template>
    </nav>

    <!-- neeche: theme · settings · profile -->
    <div class="cs-rl-foot">
      <button type="button" class="cs-ri" @click.stop="toggleTheme">
        <span class="cs-ri-ic" :class="isDark ? 'i-lucide-moon' : 'i-lucide-sun'" />
        <span v-if="expanded" class="cs-ri-lbl">
          {{ isDark ? 'Dark mode' : 'Light mode' }}
        </span>
        <span v-if="!expanded" class="cs-ri-tip">
          {{ isDark ? 'Dark mode' : 'Light mode' }}
        </span>
      </button>

      <div class="cs-rl-wrap">
        <button
          type="button"
          class="cs-ri"
          :class="{ on: isActive(settingsItem), fly: openFly === settingsItem.name }"
          @click.stop="toggleFly(settingsItem.name, $event)"
        >
          <span class="cs-ri-ic" :class="settingsItem.icon" />
          <span v-if="expanded" class="cs-ri-lbl">{{ settingsItem.label }}</span>
          <span
            v-if="expanded"
            class="cs-ri-arw i-lucide-chevron-down"
            :class="{ up: openFly === settingsItem.name }"
          />
          <span v-if="!expanded" class="cs-ri-tip">{{ settingsItem.label }}</span>
        </button>
        <div
          v-if="openFly === settingsItem.name"
          class="cs-rl-sub"
          :class="{ inline: expanded }"
          :style="expanded ? null : { top: flyPos.top + 'px', left: flyPos.left + 'px' }"
          @click.stop
        >
          <div v-if="!expanded" class="cs-rl-subh">{{ settingsItem.label }}</div>
          <RouterLink
            v-for="c in settingsItem.children"
            :key="c.label"
            :to="c.to"
            class="cs-rl-leaf"
            @click="onLeafClick"
          >
            <span class="cs-rl-lic" :class="c.icon" />
            <span class="cs-rl-ltx">{{ c.label }}</span>
          </RouterLink>
        </div>
      </div>

      <div class="cs-rl-prof">
        <SidebarProfileMenu
          :is-collapsed="!expanded"
          @open-key-shortcut-modal="emit('openKeyShortcutModal')"
        />
      </div>
    </div>
  </aside>

  <!-- theme probe: Tailwind se poochta hai ke abhi dark hai ya nahi -->
  <span ref="probeEl" class="cs-probe hidden dark:block" aria-hidden="true" />

  <!-- HAR PAGE ka apna hamburger. Jin screens ka apna header-hamburger
       hai (Chats/Contacts/Inbox/Dashboard) wahan CSS se chhup jaata hai. -->
  <button
    v-if="isMobile && !drawerOpen"
    type="button"
    class="cs-rl-ham"
    aria-label="Menu"
    @click.stop="mobileOpen = true"
  >
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
      <path d="M4 6h16M4 12h16M4 18h16" stroke-linecap="round" />
    </svg>
  </button>
  <div v-if="isMobile && drawerOpen" class="cs-rl-scrim" @click="closeMobileSidebar" />
</template>

<style scoped>
/* v16 ke asal rang */
/* ===== RANG =====
   Rail ke rang ab Chatwoot ke apne palette (--slate-*) se aate hain.
   Woh variables `_next-colors.scss` mein `.dark` ke neeche khud badal
   jaate hain — yani rail bina kisi JavaScript ke theme ke saath chalti
   hai. Pehle yahan pakke hex rang the aur JS se dark/light ka pata
   lagate the; woh nazuk tha aur rail dark par atak jaati thi.
   Sirf hara rang hamara apna hai (Chatwoot ke palette mein green nahi). */
.cs-rail {
  --rail: rgb(var(--slate-2));
  --rail-hov: rgb(var(--slate-4));
  --rail-on: rgb(0 168 132 / 0.18);
  --rail-ic: rgb(var(--slate-11));
  --rail-ic-on: #00a884;
  --fld-b: rgb(var(--slate-6));
  --badge: #00a884;
  --badge-tx: #ffffff;
  --menu: rgb(var(--slate-2));
  --tx: rgb(var(--slate-12));
  --tx3: rgb(var(--slate-11));

  position: relative;
  z-index: 40;
  flex-shrink: 0;
  width: 62px;
  height: 100%;
  background: var(--rail);
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 11px 0 10px;
  font-size: 14px;
  color: var(--tx);
  transition: width 0.16s ease, transform 0.28s cubic-bezier(0.32, 0.72, 0, 1);
}
/* border dono theme mein — rang khud slate se aata hai */
.cs-rail {
  border-inline-end: 1px solid var(--fld-b);
}
.cs-rail * {
  box-sizing: border-box;
}
.cs-rail.open {
  width: 272px;
  align-items: stretch;
  padding: 12px 10px calc(10px + env(safe-area-inset-bottom));
}

/* brand */
.cs-rl-brand {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-shrink: 0;
}
.cs-rl-mark {
  width: 40px;
  height: 40px;
  border-radius: 11px;
  overflow: hidden;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}
.cs-rl-mark svg,
.cs-rl-mark img {
  width: 32px;
  height: 32px;
  object-fit: contain;
  display: block;
}
.cs-rail.open .cs-rl-mark svg,
.cs-rail.open .cs-rl-mark img {
  width: 100%;
  height: 100%;
}
.cs-rl-name {
  font-size: 15.5px;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-rl-bsep {
  width: 28px;
  height: 1px;
  background: var(--fld-b);
  margin: 9px 0 10px;
  flex-shrink: 0;
}
.cs-rail.open .cs-rl-bsep {
  width: 100%;
  margin: 10px 0;
}

/* nav */
.cs-rl-nav {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  align-items: center;
  width: 100%;
  scrollbar-width: none;
}
.cs-rl-nav::-webkit-scrollbar {
  display: none;
}
.cs-rail.open .cs-rl-nav {
  align-items: stretch;
  gap: 2px;
}
.cs-rl-wrap {
  position: relative;
  width: 100%;
  display: flex;
  justify-content: center;
}
.cs-rail.open .cs-rl-wrap {
  flex-direction: column;
}

/* .ri — v16 ki asal values */
.cs-ri {
  width: 42px;
  height: 42px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  cursor: pointer;
  color: var(--rail-ic);
  margin-bottom: 5px;
  position: relative;
  transition: 0.13s;
  border: 0;
  background: transparent;
  text-decoration: none;
  font-family: inherit;
  flex-shrink: 0;
}
.cs-ri:hover {
  background: var(--rail-hov);
}
.cs-ri.on,
.cs-ri.fly {
  background: var(--rail-on);
  color: var(--rail-ic-on);
}
.cs-rail.open .cs-ri {
  width: 100%;
  height: 46px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: flex-start;
  gap: 16px;
  padding: 0 14px;
  margin-bottom: 2px;
  font-size: 15px;
}
.cs-ri-ic {
  width: 22px;
  height: 22px;
  flex-shrink: 0;
}
.cs-ri-lbl {
  flex: 1;
  min-width: 0;
  text-align: start;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-ri-arw {
  width: 15px;
  height: 15px;
  flex-shrink: 0;
  opacity: 0.7;
  transition: transform 0.15s;
}
.cs-ri-arw.up {
  transform: rotate(180deg);
}

/* badge + green dot */
.cs-ri-bg {
  position: absolute;
  top: 1px;
  inset-inline-end: 1px;
  background: var(--badge);
  color: var(--badge-tx);
  font-size: 9.5px;
  font-weight: 600;
  min-width: 17px;
  height: 17px;
  border-radius: 9px;
  display: grid;
  place-items: center;
  padding: 0 4px;
}
.cs-ri-gd {
  position: absolute;
  top: 5px;
  inset-inline-end: 7px;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--badge);
}
.cs-rail.open .cs-ri-bg,
.cs-rail.open .cs-ri-gd {
  position: static;
  margin-inline-start: auto;
}

/* tooltip — v16 */
.cs-ri-tip {
  position: absolute;
  inset-inline-start: 50px;
  top: 50%;
  transform: translateY(-50%) scale(0.92);
  background: rgb(var(--slate-12));
  color: rgb(var(--slate-1));
  font-size: 12px;
  padding: 5px 10px;
  border-radius: 6px;
  white-space: nowrap;
  opacity: 0;
  pointer-events: none;
  transition: 0.14s;
  z-index: 9999;
}
.cs-ri:hover .cs-ri-tip {
  opacity: 0.92;
  transform: translateY(-50%) scale(1);
}

/* separators */
.cs-rl-sep {
  width: 28px;
  height: 1px;
  background: var(--fld-b);
  margin: 7px 0 9px;
  flex-shrink: 0;
}
.cs-rail.open .cs-rl-sep {
  width: 100%;
  margin: 8px 0;
}

/* submenu */
.cs-rl-sub {
  position: fixed;
  min-width: 224px;
  background: var(--menu);
  border-radius: 12px;
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.45);
  padding: 7px 0;
  z-index: 9998;
  max-height: 72vh;
  overflow-y: auto;
}
.cs-rl-sub {
  border: 1px solid var(--fld-b);
}
.cs-rl-sub.inline {
  position: static;
  min-width: 0;
  box-shadow: none;
  border-radius: 10px;
  margin: 0 0 5px;
  padding: 5px 0;
  background: var(--rail-hov);
  max-height: none;
}
.cs-rl-subh {
  font-size: 11.5px;
  color: var(--tx3);
  padding: 4px 16px 8px;
}
.cs-rl-leaf {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 16px;
  color: var(--tx);
  text-decoration: none;
  font-size: 13.5px;
  white-space: nowrap;
}
.cs-rail.open .cs-rl-leaf {
  padding-inline-start: 46px;
}
.cs-rl-leaf:hover {
  background: var(--rail-hov);
}
.cs-rl-leaf.router-link-active {
  color: var(--rail-ic-on);
}
.cs-rl-lic {
  width: 17px;
  height: 17px;
  color: var(--tx3);
  flex-shrink: 0;
}
.cs-rl-ltx {
  flex: 1;
  min-width: 0;
}

/* foot */
.cs-rl-foot {
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  width: 100%;
  padding-top: 7px;
}
.cs-rail.open .cs-rl-foot {
  align-items: stretch;
  border-top: 1px solid var(--fld-b);
  margin-top: 8px;
}
.cs-rl-prof {
  display: flex;
  justify-content: center;
  margin-top: 4px;
}
.cs-rail.open .cs-rl-prof {
  justify-content: flex-start;
  padding: 6px 4px 0;
}

/* mobile drawer */
@media (max-width: 767px) {
  .cs-rail {
    position: fixed;
    top: 0;
    inset-inline-start: 0;
    height: 100%;
    width: 272px;
    z-index: 9997;
    align-items: stretch;
    padding: 12px 10px calc(10px + env(safe-area-inset-bottom));
    box-shadow: 0 0 40px rgba(0, 0, 0, 0.5);
  }
  .cs-rail--hidden {
    transform: translateX(-100%);
    box-shadow: none;
  }
  [dir='rtl'] .cs-rail--hidden {
    transform: translateX(100%);
  }
  .cs-ri-tip {
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

/* apna hamburger — har page par */
.cs-rl-ham {
  display: none;
}
.cs-rl-scrim {
  display: none;
}
@media (max-width: 767px) {
  .cs-rl-ham {
    position: fixed;
    top: 9px;
    inset-inline-start: 9px;
    z-index: 9990;
    width: 40px;
    height: 40px;
    display: grid;
    place-items: center;
    border: 0;
    border-radius: 50%;
    background: var(--rail);
    color: var(--rail-ic);
    cursor: pointer;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
  }
  .cs-rl-ham svg {
    width: 21px;
    height: 21px;
  }
  .cs-rl-scrim {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    z-index: 9996;
    display: block;
  }
}
</style>

<style>
/* =====================================================================
   1. Chatwoot ka purana floating launcher har jagah band.
   2. Jin screens ka apna header-hamburger hai wahan hamara floating
      button bhi chhupa do — warna do button nazar aate hain.
   3. Purani "body aside ..." wali CSS (agar bundle mein reh jaye) ka tor.
   ===================================================================== */
@media (max-width: 767px) {
  /* Chatwoot ka apna floating launcher band — hamara istemal hota hai */
  #mobile-sidebar-launcher,
  [data-testid='mobile-sidebar-launcher'] {
    display: none !important;
  }
  /* Hamari screens (Chats/Contacts/Inbox/Dashboard) ka apna
     header-hamburger hai, wahan floating wala nahi chahiye */
  body.cs-own-header .cs-rl-ham {
    display: none !important;
  }

  /* ===== STOCK PAGES KA MOBILE =====
     (Campaigns, Reports, Settings, Templates, Gallery)

     1. Hamara hamburger position:fixed hai, isliye woh page ke unwaan
        ke UPAR chaR jaata tha — "Reports" ke lafz par. Ab main ko upar
        se jagah de di hai taake button apni jagah baithe.
     2. In pages ke tables aur forms desktop ke liye bane hain. main par
        overflow-hidden laga hai, isliye mobile par content kat jaata
        tha. Ab horizontal scroll ho jaata hai — kuch chhupta nahi. */
  body:not(.cs-own-header) main {
    padding-top: 52px;
    overflow-x: auto;
  }
  body:not(.cs-own-header) main table {
    min-width: max-content;
  }
}

body aside.cs-rail {
  width: 62px !important;
  min-width: 62px !important;
  max-width: 62px !important;
  padding: 11px 0 10px !important;
  align-items: center !important;
  background: var(--rail) !important;
}
body aside.cs-rail.open {
  width: 272px !important;
  min-width: 272px !important;
  max-width: 272px !important;
  align-items: stretch !important;
  padding: 12px 10px !important;
}
body aside.cs-rail nav {
  padding: 0 !important;
  width: 100% !important;
}
body aside.cs-rail nav a.cs-ri,
body aside.cs-rail nav button.cs-ri,
body aside.cs-rail .cs-ri {
  width: 42px !important;
  height: 42px !important;
  margin: 0 auto 5px !important;
  border-radius: 50% !important;
  display: grid !important;
  place-items: center !important;
  padding: 0 !important;
  color: var(--rail-ic) !important;
  background: transparent !important;
}
body aside.cs-rail nav a.cs-ri.on,
body aside.cs-rail nav button.cs-ri.on,
body aside.cs-rail nav button.cs-ri.fly,
body aside.cs-rail .cs-ri.on,
body aside.cs-rail .cs-ri.fly {
  background: var(--rail-on) !important;
  color: var(--rail-ic-on) !important;
}
body aside.cs-rail.open nav a.cs-ri,
body aside.cs-rail.open nav button.cs-ri,
body aside.cs-rail.open .cs-ri {
  width: 100% !important;
  height: 46px !important;
  margin: 0 0 2px !important;
  border-radius: 11px !important;
  display: flex !important;
  justify-content: flex-start !important;
  padding: 0 14px !important;
}
body aside.cs-rail nav a.cs-rl-leaf,
body aside.cs-rail .cs-rl-leaf {
  width: auto !important;
  height: auto !important;
  margin: 0 !important;
  border-radius: 0 !important;
  display: flex !important;
  justify-content: flex-start !important;
  padding: 10px 16px !important;
  background: transparent !important;
  color: var(--tx) !important;
}
/* naam wapas: purana rule (0,2,5) tha, ye (0,3,5) hai */
body aside.cs-rail nav a.cs-ri span.cs-ri-lbl,
body aside.cs-rail nav a.cs-rl-leaf span.cs-rl-ltx,
body aside.cs-rail nav a.cs-ri span.cs-ri-tip,
body aside.cs-rail .cs-ri-lbl,
body aside.cs-rail .cs-rl-ltx,
body aside.cs-rail .cs-ri-tip,
body aside.cs-rail .cs-rl-name,
body aside.cs-rail .cs-rl-subh,
body aside.cs-rail .cs-ri-arw {
  display: block !important;
}
body aside.cs-rail nav a.cs-ri span.cs-ri-bg,
body aside.cs-rail .cs-ri-bg,
body aside.cs-rail .cs-rl-mark {
  display: grid !important;
}
body aside.cs-rail nav a.cs-ri span.cs-ri-gd,
body aside.cs-rail .cs-ri-gd {
  display: block !important;
}
body aside.cs-rail nav a.cs-ri span.cs-ri-ic,
body aside.cs-rail nav button.cs-ri span.cs-ri-ic,
body aside.cs-rail .cs-ri-ic {
  width: 22px !important;
  height: 22px !important;
}
body aside.cs-rail nav a.cs-rl-leaf span.cs-rl-lic,
body aside.cs-rail .cs-rl-lic {
  width: 17px !important;
  height: 17px !important;
}

@media (max-width: 767px) {
  body aside.cs-rail {
    position: fixed !important;
    inset-inline-start: 0 !important;
    top: 0 !important;
    bottom: 0 !important;
    width: 272px !important;
    min-width: 272px !important;
    max-width: 272px !important;
    align-items: stretch !important;
    z-index: 9997 !important;
    transform: translateX(0) !important;
  }
  body aside.cs-rail.cs-rail--hidden {
    transform: translateX(-100%) !important;
  }
}
</style>
