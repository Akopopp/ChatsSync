<script setup>
/* =====================================================================
   Sidebar.vue  —  ChatsSync ka rail
   Pehle look ChatsScreen ke global CSS se thopi ja rahi thi. Har item
   ka markup alag tha isliye kuch par lagti thi kuch par nahi — mobile
   drawer mein aadhe naam ghayab rehte the. Ab markup yahin apna hai.

   Tabs ki list wahi hai jo pehle thi + ek naya "Dashboard".
   Rail: 62px · 42px gol icons · active par hara tint · search icon.
   ===================================================================== */
import { ref, computed, onMounted, watch } from 'vue';
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

const { width: windowWidth } = useWindowSize();
const isMobile = computed(() => windowWidth.value < 768);
/* mobile par drawer poora khulta hai, desktop par hamesha rail */
const expanded = computed(() => isMobile.value && props.isMobileSidebarOpen);

/* SidebarProfileMenu waghera context inject karte hain — dena zaroori hai */
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

onMounted(() => {
  store.dispatch('labels/get');
  store.dispatch('inboxes/get');
  store.dispatch('notifications/unReadCount');
  store.dispatch('teams/get');
  store.dispatch('attributes/get');
  store.dispatch('customViews/get', 'conversation');
  store.dispatch('customViews/get', 'contact');
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
  if (!props.isMobileSidebarOpen) return;
  emit('closeMobileSidebar');
};

/* ---------------- tabs ----------------
   Tarteeb wahi, sirf Dashboard naya hai. Kuch hataya nahi gaya. */
const menuItems = computed(() => [
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
        to: accountScopedRoute('campaigns_whatsapp_index'),
      },
      {
        label: t('SIDEBAR.LIVE_CHAT'),
        to: accountScopedRoute('campaigns_livechat_index'),
      },
      {
        label: t('SIDEBAR.SMS'),
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
        to: accountScopedRoute('account_overview_reports'),
      },
      {
        label: t('SIDEBAR.REPORTS_CONVERSATION'),
        to: accountScopedRoute('conversation_reports'),
      },
      {
        label: t('SIDEBAR.REPORTS_AGENT'),
        to: accountScopedRoute('agent_reports_index'),
      },
      {
        label: t('SIDEBAR.REPORTS_LABEL'),
        to: accountScopedRoute('label_reports_index'),
      },
      {
        label: t('SIDEBAR.REPORTS_INBOX'),
        to: accountScopedRoute('inbox_reports_index'),
      },
      {
        label: t('SIDEBAR.REPORTS_TEAM'),
        to: accountScopedRoute('team_reports_index'),
      },
      { label: t('SIDEBAR.CSAT'), to: accountScopedRoute('csat_reports') },
      {
        label: t('SIDEBAR.REPORTS_BOT'),
        to: accountScopedRoute('bot_reports'),
      },
    ],
  },
  {
    name: 'Settings',
    label: t('SIDEBAR.SETTINGS'),
    icon: 'i-lucide-bolt',
    activeOn: [
      'general_settings_index',
      'agent_list',
      'settings_teams_list',
      'settings_teams_new',
      'settings_teams_finish',
      'settings_teams_add_agents',
      'settings_teams_show',
      'settings_teams_edit',
      'settings_teams_edit_members',
      'settings_teams_edit_finish',
      'settings_inbox_list',
      'settings_inbox_show',
      'settings_inbox_new',
      'settings_inbox_finish',
      'settings_inboxes_page_channel',
      'settings_inboxes_add_agents',
      'labels_list',
      'attributes_list',
      'automation_list',
      'agent_bots',
      'macros_wrapper',
      'canned_list',
      'settings_applications',
      'security_settings_index',
      'billing_settings_index',
    ],
    children: [
      {
        label: t('SIDEBAR.ACCOUNT_SETTINGS'),
        icon: 'i-lucide-briefcase',
        to: accountScopedRoute('general_settings_index'),
      },
      {
        label: t('SIDEBAR.AGENTS'),
        icon: 'i-lucide-square-user',
        to: accountScopedRoute('agent_list'),
      },
      {
        label: t('SIDEBAR.TEAMS'),
        icon: 'i-lucide-users',
        to: accountScopedRoute('settings_teams_list'),
      },
      {
        label: t('SIDEBAR.INBOXES'),
        icon: 'i-lucide-inbox',
        to: accountScopedRoute('settings_inbox_list'),
      },
      {
        label: t('SIDEBAR.LABELS'),
        icon: 'i-lucide-tags',
        to: accountScopedRoute('labels_list'),
      },
      {
        label: t('SIDEBAR.CUSTOM_ATTRIBUTES'),
        icon: 'i-lucide-code',
        to: accountScopedRoute('attributes_list'),
      },
      {
        label: t('SIDEBAR.AUTOMATION'),
        icon: 'i-lucide-repeat',
        to: accountScopedRoute('automation_list'),
      },
      {
        label: t('SIDEBAR.AGENT_BOTS'),
        icon: 'i-lucide-bot',
        to: accountScopedRoute('agent_bots'),
      },
      {
        label: t('SIDEBAR.MACROS'),
        icon: 'i-lucide-toy-brick',
        to: accountScopedRoute('macros_wrapper'),
      },
      {
        label: t('SIDEBAR.CANNED_RESPONSES'),
        icon: 'i-lucide-message-square-quote',
        to: accountScopedRoute('canned_list'),
      },
      {
        label: t('SIDEBAR.INTEGRATIONS'),
        icon: 'i-lucide-blocks',
        to: accountScopedRoute('settings_applications'),
      },
      {
        label: t('SIDEBAR.SECURITY'),
        icon: 'i-lucide-shield',
        to: accountScopedRoute('security_settings_index'),
      },
      {
        label: t('SIDEBAR.BILLING'),
        icon: 'i-lucide-credit-card',
        to: accountScopedRoute('billing_settings_index'),
      },
    ],
  },
]);

const isActive = item => (item.activeOn || []).includes(route.name);

/* rail par children ka flyout, drawer mein andar hi khulta hai */
const openFly = ref(null);
const toggleFly = name => {
  openFly.value = openFly.value === name ? null : name;
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
    :class="{
      open: expanded,
      'cs-rail--hidden': isMobile && !isMobileSidebarOpen,
    }"
  >
    <!-- brand + search -->
    <div class="cs-rl-top">
      <div class="cs-rl-brand">
        <Logo class="cs-rl-logo" />
        <span v-if="expanded" class="cs-rl-name">ChatsSync</span>
      </div>
      <RouterLink
        :to="{ name: 'search' }"
        class="cs-rl-search"
        :title="t('COMBOBOX.SEARCH_PLACEHOLDER')"
        @click="closeMobileSidebar"
      >
        <span class="i-lucide-search" />
        <span v-if="expanded" class="cs-rl-stxt">
          {{ t('COMBOBOX.SEARCH_PLACEHOLDER') }}
        </span>
      </RouterLink>
    </div>

    <!-- tabs -->
    <nav class="cs-rl-nav">
      <template v-for="item in menuItems" :key="item.name">
        <!-- bina children -->
        <RouterLink
          v-if="!item.children"
          :to="item.to"
          class="cs-rl-item"
          :class="{ on: isActive(item) }"
          :title="expanded ? null : item.label"
          @click="onLeafClick"
        >
          <span class="cs-rl-ic" :class="item.icon" />
          <span v-if="expanded" class="cs-rl-lbl">{{ item.label }}</span>
          <span v-if="item.count && item.count()" class="cs-rl-badge">
            {{ item.count() }}
          </span>
          <span v-if="!expanded" class="cs-rl-tip">{{ item.label }}</span>
        </RouterLink>

        <!-- children ke saath -->
        <div v-else class="cs-rl-wrap">
          <button
            type="button"
            class="cs-rl-item"
            :class="{ on: isActive(item), fly: openFly === item.name }"
            :title="expanded ? null : item.label"
            @click.stop="toggleFly(item.name)"
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
              <span v-if="c.icon" class="cs-rl-lic" :class="c.icon" />
              <span>{{ c.label }}</span>
            </RouterLink>
          </div>
        </div>
      </template>
    </nav>

    <!-- profile -->
    <div class="cs-rl-foot">
      <SidebarProfileMenu
        :is-collapsed="!expanded"
        @open-key-shortcut-modal="emit('openKeyShortcutModal')"
      />
    </div>
  </aside>
</template>

<style scoped>
.cs-rail {
  --rl-bg: #202c33;
  --rl-ic: #aebac1;
  --rl-hov: #2a3942;
  --rl-on-bg: #103529;
  --rl-on: #00a884;
  --rl-ln: #2a3942;
  --rl-menu: #233138;
  --rl-tx: #e9edef;
  --rl-tx3: #8696a0;

  position: relative;
  z-index: 40;
  flex-shrink: 0;
  width: 62px;
  height: 100%;
  background: var(--rl-bg);
  display: flex;
  flex-direction: column;
  font-size: 14px;
  color: var(--rl-tx);
  transition: width 0.16s ease;
}
:global(html:not(.dark)) .cs-rail {
  --rl-bg: #eff3f4;
  --rl-ic: #3d4f57;
  --rl-hov: #dde4e7;
  --rl-on-bg: #c8e8db;
  --rl-on: #00755f;
  --rl-ln: #c7d1d6;
  --rl-menu: #ffffff;
  --rl-tx: #0a1519;
  --rl-tx3: #55666e;
  border-right: 1px solid var(--rl-ln);
}
.cs-rail * {
  box-sizing: border-box;
}
.cs-rail.open {
  width: 272px;
}

/* top */
.cs-rl-top {
  flex-shrink: 0;
  padding: 12px 10px 10px;
  display: grid;
  gap: 10px;
  justify-items: center;
}
.cs-rail.open .cs-rl-top {
  justify-items: stretch;
}
.cs-rl-brand {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}
.cs-rl-logo {
  width: 22px;
  height: 22px;
  flex-shrink: 0;
}
.cs-rl-name {
  font-size: 15px;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-rl-search {
  width: 42px;
  height: 38px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 9px;
  color: var(--rl-ic);
  text-decoration: none;
  background: transparent;
  border: 1px solid var(--rl-ln);
}
.cs-rail.open .cs-rl-search {
  width: 100%;
  justify-content: flex-start;
  padding: 0 12px;
}
.cs-rl-search:hover {
  background: var(--rl-hov);
}
.cs-rl-search span[class*='i-'] {
  width: 17px;
  height: 17px;
  flex-shrink: 0;
}
.cs-rl-stxt {
  font-size: 13.5px;
  color: var(--rl-tx3);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* nav */
.cs-rl-nav {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  overflow-x: visible;
  padding: 4px 10px 14px;
  display: flex;
  flex-direction: column;
  gap: 4px;
  scrollbar-width: none;
}
.cs-rl-nav::-webkit-scrollbar {
  display: none;
}
.cs-rl-wrap {
  position: relative;
}
.cs-rl-item {
  position: relative;
  width: 42px;
  height: 42px;
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
  border-radius: 10px;
  justify-content: flex-start;
  padding: 0 14px;
}
.cs-rl-item:hover {
  background: var(--rl-hov);
}
.cs-rl-item.on,
.cs-rl-item.fly {
  background: var(--rl-on-bg);
  color: var(--rl-on);
}
.cs-rl-ic {
  width: 21px;
  height: 21px;
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
.cs-rl-badge {
  position: absolute;
  top: 3px;
  right: 3px;
  min-width: 17px;
  height: 17px;
  padding: 0 5px;
  border-radius: 9px;
  background: #00a884;
  color: #fff;
  font-size: 10.5px;
  font-weight: 600;
  display: grid;
  place-items: center;
}
.cs-rail.open .cs-rl-badge {
  position: static;
  margin-inline-start: auto;
}

/* tooltip (sirf rail mode) */
.cs-rl-tip {
  position: absolute;
  inset-inline-start: 52px;
  top: 50%;
  transform: translateY(-50%);
  background: var(--rl-menu);
  color: var(--rl-tx);
  padding: 5px 11px;
  border-radius: 7px;
  font-size: 12.5px;
  white-space: nowrap;
  opacity: 0;
  pointer-events: none;
  box-shadow: 0 3px 14px rgba(0, 0, 0, 0.35);
  transition: opacity 0.12s;
  z-index: 60;
}
.cs-rl-item:hover .cs-rl-tip {
  opacity: 1;
}

/* submenu */
.cs-rl-sub {
  position: absolute;
  inset-inline-start: 52px;
  top: -4px;
  min-width: 216px;
  background: var(--rl-menu);
  border-radius: 10px;
  box-shadow: 0 6px 26px rgba(0, 0, 0, 0.45);
  padding: 7px 0;
  z-index: 70;
  max-height: 70vh;
  overflow-y: auto;
}
:global(html:not(.dark)) .cs-rl-sub {
  border: 1px solid var(--rl-ln);
}
.cs-rl-sub.inline {
  position: static;
  min-width: 0;
  box-shadow: none;
  border-radius: 8px;
  margin: 2px 0 4px;
  padding: 4px 0;
  background: rgba(127, 127, 127, 0.1);
  max-height: none;
}
.cs-rl-subh {
  font-size: 11.5px;
  color: var(--rl-tx3);
  padding: 4px 15px 8px;
}
.cs-rl-leaf {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 9px 15px;
  color: var(--rl-tx);
  text-decoration: none;
  font-size: 13.5px;
  white-space: nowrap;
}
.cs-rail.open .cs-rl-leaf {
  padding-inline-start: 46px;
}
.cs-rl-leaf:hover {
  background: var(--rl-hov);
}
.cs-rl-leaf.router-link-active {
  color: var(--rl-on);
}
.cs-rl-lic {
  width: 16px;
  height: 16px;
  color: var(--rl-tx3);
  flex-shrink: 0;
}

/* foot */
.cs-rl-foot {
  flex-shrink: 0;
  border-top: 1px solid var(--rl-ln);
  padding: 7px;
  display: flex;
  justify-content: center;
}
.cs-rail.open .cs-rl-foot {
  justify-content: flex-start;
}

/* mobile: drawer */
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
    padding-bottom: env(safe-area-inset-bottom);
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
