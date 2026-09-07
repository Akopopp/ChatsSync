<script setup>
/* =====================================================================
   Sidebar.vue  —  ChatsSync ka rail
   62px patti · 40px gol icons · hover par naam ka tooltip
   Conversations/Inbox par hara count badge · Chatbot par online dot
   Neeche alag group: theme toggle, Settings, profile
   Tabs ki list wahi hai, sirf Dashboard naya hai.
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
import Logo from 'next/icon/Logo.vue';

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

const { width: windowWidth } = useWindowSize();
const isMobile = computed(() => windowWidth.value < 768);

/* ---- mobile drawer ----
   Screens ka hamburger pehle #mobile-sidebar-launcher dhoondta tha jo
   maujood hi nahi — isliye mobile par tabs khulte hi nahi the. Ab woh
   seedha ye event bhejti hain. */
const mobileOpen = ref(false);
const onRailToggle = () => {
  mobileOpen.value = !mobileOpen.value;
};
const drawerOpen = computed(
  () => isMobile.value && (props.isMobileSidebarOpen || mobileOpen.value)
);
const expanded = computed(() => drawerOpen.value);

/* SidebarProfileMenu context inject karta hai — dena zaroori hai */
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

/* getter har version mein nahi hota — isliye seedha aur bacha kar */
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

/* chatbot online hai ya nahi */
const botsOnline = computed(() => {
  const g = store.getters || {};
  const list = g['agentBots/getBots'];
  return Array.isArray(list) && list.length > 0;
});

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
  readTheme();
  themeObs = new MutationObserver(readTheme);
  themeObs.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['class'],
  });
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

/* ---- theme toggle ---- */
let themeObs = null;
const isDark = ref(true);
const readTheme = () => {
  isDark.value = document.documentElement.classList.contains('dark');
};
const toggleTheme = () => {
  const next = !isDark.value;
  document.documentElement.classList.toggle('dark', next);
  isDark.value = next;
  try {
    localStorage.setItem('cs_theme', next ? 'dark' : 'light');
  } catch (e) {
    /* ignore */
  }
  // Chatwoot ke apne setting mein bhi likh do taake reload par bachi rahe
  const scheme = next ? 'dark' : 'light';
  try {
    store.dispatch('updateUISettings', { uiSettings: { color_scheme: scheme } });
  } catch (e) {
    /* ignore */
  }
};

/* ---------------- tabs ---------------- */
const mainItems = computed(() => [
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
      'account_overview_reports',
      'conversation_reports',
      'agent_reports_index',
      'agent_reports_show',
      'label_reports_index',
      'inbox_reports_index',
      'inbox_reports_show',
      'team_reports_index',
      'team_reports_show',
      'csat_reports',
      'bot_reports',
    ],
    children: [
      {
        label: t('SIDEBAR.REPORTS_OVERVIEW'),
        icon: 'i-lucide-layout-dashboard',
        to: accountScopedRoute('account_overview_reports'),
      },
      {
        label: t('SIDEBAR.REPORTS_CONVERSATION'),
        icon: 'i-lucide-message-circle',
        to: accountScopedRoute('conversation_reports'),
      },
      {
        label: t('SIDEBAR.REPORTS_AGENT'),
        icon: 'i-lucide-square-user',
        to: accountScopedRoute('agent_reports_index'),
      },
      {
        label: t('SIDEBAR.REPORTS_LABEL'),
        icon: 'i-lucide-tags',
        to: accountScopedRoute('label_reports_index'),
      },
      {
        label: t('SIDEBAR.REPORTS_INBOX'),
        icon: 'i-lucide-inbox',
        to: accountScopedRoute('inbox_reports_index'),
      },
      {
        label: t('SIDEBAR.REPORTS_TEAM'),
        icon: 'i-lucide-users',
        to: accountScopedRoute('team_reports_index'),
      },
      {
        label: t('SIDEBAR.CSAT'),
        icon: 'i-lucide-smile',
        to: accountScopedRoute('csat_reports'),
      },
      {
        label: t('SIDEBAR.REPORTS_BOT'),
        icon: 'i-lucide-bot',
        to: accountScopedRoute('bot_reports'),
      },
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
    'settings_applications', 'security_settings_index', 'billing_settings_index',
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
    { label: t('SIDEBAR.SECURITY'), icon: 'i-lucide-shield', to: accountScopedRoute('security_settings_index') },
    { label: t('SIDEBAR.BILLING'), icon: 'i-lucide-credit-card', to: accountScopedRoute('billing_settings_index') },
  ],
}));

const isActive = item => (item.activeOn || []).includes(route.name);

/* ---- flyout ----
   Pehle .cs-rl-nav ke andar absolute tha aur us par overflow-y:auto hai —
   CSS overflow-x ko bhi auto kar deta hai, isliye options kat jaate the.
   Ab fixed hai aur button ke rect se apni jagah nikalta hai. */
const openFly = ref(null);
const flyPos = ref({ top: 0, left: 0, bottom: 'auto' });

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
    const h = el.offsetHeight;
    if (top + h > window.innerHeight - 12)
      top = Math.max(12, window.innerHeight - h - 12);
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
      {
        ignore: [
          '#mobile-sidebar-launcher',
          '[data-popover-content]',
          '[data-popover-backdrop]',
        ],
      },
    ]"
    class="cs-rail"
    :class="{ open: expanded, 'cs-rail--hidden': isMobile && !drawerOpen }"
  >
    <!-- brand -->
    <div class="cs-rl-top">
      <div class="cs-rl-brand">
        <span class="cs-rl-mark"><Logo class="cs-rl-logo" /></span>
        <span v-if="expanded" class="cs-rl-name">ChatsSync</span>
      </div>
      <RouterLink
        :to="{ name: 'search' }"
        class="cs-rl-item cs-rl-search"
        @click="onLeafClick"
      >
        <span class="cs-rl-ic i-lucide-search" />
        <span v-if="expanded" class="cs-rl-lbl">
          {{ t('COMBOBOX.SEARCH_PLACEHOLDER') }}
        </span>
        <span v-if="!expanded" class="cs-rl-tip">
          {{ t('COMBOBOX.SEARCH_PLACEHOLDER') }}
        </span>
      </RouterLink>
    </div>

    <!-- tabs -->
    <nav class="cs-rl-nav">
      <template v-for="item in mainItems" :key="item.name">
        <RouterLink
          v-if="!item.children"
          :to="item.to"
          class="cs-rl-item"
          :class="{ on: isActive(item) }"
          @click="onLeafClick"
        >
          <span class="cs-rl-ic" :class="item.icon" />
          <span v-if="expanded" class="cs-rl-lbl">{{ item.label }}</span>
          <span v-if="item.count && item.count() > 0" class="cs-rl-badge">
            {{ item.count() > 99 ? '99+' : item.count() }}
          </span>
          <span v-if="item.dot && item.dot()" class="cs-rl-dot" />
          <span v-if="!expanded" class="cs-rl-tip">{{ item.label }}</span>
        </RouterLink>

        <div v-else class="cs-rl-wrap">
          <button
            type="button"
            class="cs-rl-item"
            :class="{ on: isActive(item), fly: openFly === item.name }"
            @click.stop="toggleFly(item.name, $event)"
          >
            <span class="cs-rl-ic" :class="item.icon" />
            <span v-if="expanded" class="cs-rl-lbl">{{ item.label }}</span>
            <span
              v-if="expanded"
              class="cs-rl-arw i-lucide-chevron-down"
              :class="{ up: openFly === item.name }"
            />
            <span v-if="!expanded" class="cs-rl-tip">{{ item.label }}</span>
          </button>
          <div
            v-if="openFly === item.name"
            class="cs-rl-sub"
            :class="{ inline: expanded }"
            :style="
              expanded ? null : { top: flyPos.top + 'px', left: flyPos.left + 'px' }
            "
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
    </nav>

    <!-- neeche ka group: theme · settings · profile -->
    <div class="cs-rl-foot">
      <button type="button" class="cs-rl-item" @click.stop="toggleTheme">
        <span
          class="cs-rl-ic"
          :class="isDark ? 'i-lucide-moon' : 'i-lucide-sun'"
        />
        <span v-if="expanded" class="cs-rl-lbl">
          {{ isDark ? 'Dark mode' : 'Light mode' }}
        </span>
        <span v-if="!expanded" class="cs-rl-tip">
          {{ isDark ? 'Dark mode' : 'Light mode' }}
        </span>
      </button>

      <div class="cs-rl-wrap">
        <button
          type="button"
          class="cs-rl-item"
          :class="{
            on: isActive(settingsItem),
            fly: openFly === settingsItem.name,
          }"
          @click.stop="toggleFly(settingsItem.name, $event)"
        >
          <span class="cs-rl-ic" :class="settingsItem.icon" />
          <span v-if="expanded" class="cs-rl-lbl">{{ settingsItem.label }}</span>
          <span
            v-if="expanded"
            class="cs-rl-arw i-lucide-chevron-down"
            :class="{ up: openFly === settingsItem.name }"
          />
          <span v-if="!expanded" class="cs-rl-tip">{{ settingsItem.label }}</span>
        </button>
        <div
          v-if="openFly === settingsItem.name"
          class="cs-rl-sub"
          :class="{ inline: expanded }"
          :style="
            expanded ? null : { top: flyPos.top + 'px', left: flyPos.left + 'px' }
          "
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
</template>

<style scoped>
.cs-rail {
  --rl-bg: #0f1a21;
  --rl-ic: #8696a0;
  --rl-hov: #1f2c33;
  --rl-on-bg: #103529;
  --rl-on: #00a884;
  --rl-ln: #1f2c33;
  --rl-menu: #233138;
  --rl-tx: #e9edef;
  --rl-tx3: #8696a0;
  --rl-badge: #00a884;
  --rl-badge-tx: #06120f;

  position: relative;
  z-index: 40;
  flex-shrink: 0;
  width: 62px;
  height: 100%;
  background: var(--rl-bg);
  border-inline-end: 1px solid var(--rl-ln);
  display: flex;
  flex-direction: column;
  font-size: 14px;
  color: var(--rl-tx);
  transition: width 0.16s ease;
}
:global(html:not(.dark)) .cs-rail {
  --rl-bg: #f0f3f4;
  --rl-ic: #4a5c64;
  --rl-hov: #dde4e7;
  --rl-on-bg: #c8e8db;
  --rl-on: #00755f;
  --rl-ln: #d3dbde;
  --rl-menu: #ffffff;
  --rl-tx: #0a1519;
  --rl-tx3: #55666e;
  --rl-badge: #00a884;
  --rl-badge-tx: #ffffff;
}
.cs-rail * {
  box-sizing: border-box;
}
.cs-rail.open {
  width: 272px;
}

/* brand */
.cs-rl-top {
  flex-shrink: 0;
  padding: 12px 10px 8px;
  display: grid;
  gap: 8px;
  justify-items: center;
  border-bottom: 1px solid var(--rl-ln);
}
.cs-rail.open .cs-rl-top {
  justify-items: stretch;
}
.cs-rl-brand {
  display: flex;
  align-items: center;
  gap: 11px;
  min-width: 0;
  padding-bottom: 4px;
}
.cs-rl-mark {
  width: 34px;
  height: 34px;
  border-radius: 50%;
  background: #1d7bf5;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}
.cs-rl-logo {
  width: 18px;
  height: 18px;
  color: #fff;
}
.cs-rl-name {
  font-size: 15px;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* nav */
.cs-rl-nav {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: 8px 10px 12px;
  display: flex;
  flex-direction: column;
  gap: 6px;
  scrollbar-width: none;
}
.cs-rl-nav::-webkit-scrollbar {
  display: none;
}
.cs-rl-wrap {
  position: relative;
}

/* item */
.cs-rl-item {
  position: relative;
  width: 40px;
  height: 40px;
  margin: 0 auto;
  border: 0;
  background: transparent;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 14px;
  color: var(--rl-ic);
  cursor: pointer;
  text-decoration: none;
  font-family: inherit;
  font-size: 14.5px;
  transition: background 0.13s, color 0.13s;
}
.cs-rail.open .cs-rl-item {
  width: 100%;
  height: 46px;
  margin: 0;
  border-radius: 11px;
  justify-content: flex-start;
  padding: 0 14px;
}
.cs-rl-item:hover {
  background: var(--rl-hov);
  color: var(--rl-tx);
}
.cs-rl-item.on,
.cs-rl-item.fly {
  background: var(--rl-on-bg);
  color: var(--rl-on);
}
.cs-rl-ic {
  width: 22px;
  height: 22px;
  flex-shrink: 0;
}
.cs-rl-lbl {
  flex: 1;
  min-width: 0;
  text-align: start;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-rl-arw {
  width: 15px;
  height: 15px;
  flex-shrink: 0;
  opacity: 0.7;
  transition: transform 0.15s;
}
.cs-rl-arw.up {
  transform: rotate(180deg);
}
.cs-rl-search {
  border: 1px solid var(--rl-ln);
}

/* badge + dot */
.cs-rl-badge {
  position: absolute;
  top: -2px;
  inset-inline-end: -2px;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 10px;
  background: var(--rl-badge);
  color: var(--rl-badge-tx);
  font-size: 10.5px;
  font-weight: 700;
  display: grid;
  place-items: center;
  border: 2px solid var(--rl-bg);
}
.cs-rail.open .cs-rl-badge {
  position: static;
  border: 0;
  margin-inline-start: auto;
}
.cs-rl-dot {
  position: absolute;
  top: 1px;
  inset-inline-end: 1px;
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: #22c55e;
  border: 2px solid var(--rl-bg);
}
.cs-rail.open .cs-rl-dot {
  position: static;
  margin-inline-start: auto;
  border: 0;
}

/* tooltip */
.cs-rl-tip {
  position: absolute;
  inset-inline-start: 50px;
  top: 50%;
  transform: translateY(-50%);
  background: var(--rl-menu);
  color: var(--rl-tx);
  padding: 6px 12px;
  border-radius: 8px;
  font-size: 12.5px;
  white-space: nowrap;
  opacity: 0;
  pointer-events: none;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
  transition: opacity 0.12s;
  z-index: 9999;
}
:global(html:not(.dark)) .cs-rl-tip {
  border: 1px solid var(--rl-ln);
}
.cs-rl-item:hover .cs-rl-tip {
  opacity: 1;
}

/* submenu */
.cs-rl-sub {
  position: fixed;
  min-width: 224px;
  background: var(--rl-menu);
  border-radius: 12px;
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.45);
  padding: 7px 0;
  z-index: 9998;
  max-height: 72vh;
  overflow-y: auto;
}
:global(html:not(.dark)) .cs-rl-sub {
  border: 1px solid var(--rl-ln);
}
.cs-rl-sub.inline {
  position: static;
  min-width: 0;
  box-shadow: none;
  border-radius: 10px;
  margin: 3px 0 5px;
  padding: 5px 0;
  background: var(--rl-hov);
  max-height: none;
}
.cs-rl-subh {
  font-size: 11.5px;
  color: var(--rl-tx3);
  padding: 4px 16px 8px;
}
.cs-rl-leaf {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 16px;
  color: var(--rl-tx);
  text-decoration: none;
  font-size: 13.5px;
  white-space: nowrap;
}
.cs-rail.open .cs-rl-leaf {
  padding-inline-start: 44px;
}
.cs-rl-leaf:hover {
  background: var(--rl-hov);
}
.cs-rl-leaf.router-link-active {
  color: var(--rl-on);
}
.cs-rl-lic {
  width: 17px;
  height: 17px;
  color: var(--rl-tx3);
  flex-shrink: 0;
}
.cs-rl-ltx {
  flex: 1;
  min-width: 0;
}

/* foot */
.cs-rl-foot {
  flex-shrink: 0;
  border-top: 1px solid var(--rl-ln);
  padding: 8px 10px calc(8px + env(safe-area-inset-bottom));
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.cs-rl-prof {
  display: flex;
  justify-content: center;
  padding-top: 4px;
}
.cs-rail.open .cs-rl-prof {
  justify-content: flex-start;
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
    box-shadow: 0 0 40px rgba(0, 0, 0, 0.5);
    transition: transform 0.18s ease;
  }
  .cs-rail--hidden {
    transform: translateX(-100%);
    box-shadow: none;
  }
  [dir='rtl'] .cs-rail--hidden {
    transform: translateX(100%);
  }
}
</style>

<style>
/* =====================================================================
   PURANI RAIL CSS KA TOR
   ChatsScreen/ContactsScreen ke non-scoped blocks mein "body aside ..."
   wale rules the jo !important ke saath icon gol 42px kar dete the aur
   naam chhupa dete the. Vite saari CSS ek hi file mein daalta hai, to
   woh component mount na ho tab bhi lagti rehti hai — isi wajah se
   Reports/Settings ke flyout mein sirf icons dikhte the.
   ===================================================================== */
body aside.cs-rail {
  width: 62px !important;
  min-width: 62px !important;
  max-width: 62px !important;
  padding: 0 !important;
  align-items: stretch !important;
  background: var(--rl-bg) !important;
}
body aside.cs-rail.open {
  width: 272px !important;
  min-width: 272px !important;
  max-width: 272px !important;
}
body aside.cs-rail nav {
  padding: 8px 10px 12px !important;
  width: auto !important;
}
body aside.cs-rail .cs-rl-item {
  width: 40px !important;
  height: 40px !important;
  margin: 0 auto !important;
  border-radius: 50% !important;
  display: flex !important;
  justify-content: center !important;
  padding: 0 !important;
  color: var(--rl-ic) !important;
  background: transparent !important;
}
body aside.cs-rail .cs-rl-item.on,
body aside.cs-rail .cs-rl-item.fly {
  background: var(--rl-on-bg) !important;
  color: var(--rl-on) !important;
}
body aside.cs-rail.open .cs-rl-item {
  width: 100% !important;
  height: 46px !important;
  margin: 0 !important;
  border-radius: 11px !important;
  justify-content: flex-start !important;
  padding: 0 14px !important;
}
body aside.cs-rail .cs-rl-leaf {
  width: auto !important;
  height: auto !important;
  margin: 0 !important;
  border-radius: 0 !important;
  display: flex !important;
  justify-content: flex-start !important;
  padding: 10px 16px !important;
  color: var(--rl-tx) !important;
  background: transparent !important;
}
body aside.cs-rail .cs-rl-leaf:hover {
  background: var(--rl-hov) !important;
}
/* naam wapas — purana rule inhe display:none kar deta tha */
body aside.cs-rail .cs-rl-ltx,
body aside.cs-rail .cs-rl-name,
body aside.cs-rail .cs-rl-subh,
body aside.cs-rail .cs-rl-arw {
  display: inline !important;
}
body aside.cs-rail .cs-rl-lbl,
body aside.cs-rail .cs-rl-tip {
  display: block !important;
}
body aside.cs-rail .cs-rl-badge,
body aside.cs-rail .cs-rl-mark {
  display: grid !important;
}
body aside.cs-rail .cs-rl-dot {
  display: block !important;
}
body aside.cs-rail .cs-rl-ic {
  width: 22px !important;
  height: 22px !important;
}
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
    z-index: 9997 !important;
    transform: translateX(0) !important;
  }
  body aside.cs-rail.cs-rail--hidden {
    transform: translateX(-100%) !important;
  }
}
</style>
