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
const brandLogo = computed(
  () => globalConfig.value?.logoThumbnail || globalConfig.value?.logo || ''
);

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
const probeEl = ref(null);
const probeDark = () => {
  const el = probeEl.value;
  if (el) {
    try {
      return getComputedStyle(el).display !== 'none';
    } catch (e) {
      /* ignore */
    }
  }
  return (
    document.documentElement.classList.contains('dark') ||
    document.body.classList.contains('dark')
  );
};
const readTheme = () => {
  isDark.value = probeDark();
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
  const next = !isDark.value;
  isDark.value = next;
  applyTheme(next);
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
  // sirf class nahi — data-theme waghera bhi pakdo
  themeObs.observe(document.documentElement, { attributes: true });
  themeObs.observe(document.body, { attributes: true });
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
        <img v-if="brandLogo" :src="brandLogo" alt="ChatsSync" />
        <svg v-else viewBox="0 0 512 512" aria-hidden="true">
          <rect x="34" y="30" width="444" height="392" rx="110" fill="#1A56DB" />
          <path d="M150 418 L238 362 L150 362 Z" fill="#1A56DB" />
          <path d="M168 240a88 88 0 0 1 150-64" fill="none" stroke="#fff" stroke-width="44" stroke-linecap="round" />
          <path d="M344 272a88 88 0 0 1-150 64" fill="none" stroke="#fff" stroke-width="44" stroke-linecap="round" />
          <path d="M312 126 L346 196 L272 190 Z" fill="#fff" />
          <path d="M200 386 L166 316 L240 322 Z" fill="#fff" />
        </svg>
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
.cs-rail {
  --rail: #202c33;
  --rail-hov: #2a3942;
  --rail-on: #103529;
  --rail-ic: #aebac1;
  --rail-ic-on: #00a884;
  --fld-b: #2a3942;
  --badge: #00a884;
  --badge-tx: #0b141a;
  --menu: #233138;
  --tx: #e9edef;
  --tx3: #8696a0;

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
:global(html:not(.dark)) .cs-rail {
  --rail: #f0f2f5;
  --rail-hov: #e3e6ea;
  --rail-on: #dcefe9;
  --rail-ic: #54656f;
  --rail-ic-on: #008069;
  --fld-b: #e4e7e9;
  --badge: #25d366;
  --badge-tx: #053e20;
  --menu: #ffffff;
  --tx: #111b21;
  --tx3: #667781;
  border-right: 1px solid var(--fld-b);
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
  background: #000;
  color: #fff;
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
:global(html:not(.dark)) .cs-rl-sub {
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
  #mobile-sidebar-launcher,
  [data-testid='mobile-sidebar-launcher'] {
    display: none !important;
  }
  body.cs-own-header .cs-rl-ham {
    display: none !important;
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
