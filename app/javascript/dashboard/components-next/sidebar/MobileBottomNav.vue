<script setup>
// Phones: the main places are one tap away at the bottom, and Menu opens the full sidebar.
// Hidden inside an open chat, where the reply box needs the space.
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import { CHAT_ROUTES } from './chatRoutes';

defineProps({
  isMobileSidebarOpen: { type: Boolean, default: false },
});

const emit = defineEmits(['toggle']);

const route = useRoute();
const { accountScopedRoute } = useAccount();

const items = computed(() => [
  {
    key: 'HOME',
    icon: 'i-lucide-layout-dashboard',
    to: accountScopedRoute('chatssync_dashboard'),
    activeOn: ['chatssync_dashboard'],
  },
  {
    key: 'CHATS',
    icon: 'i-lucide-message-circle',
    to: accountScopedRoute('home'),
    activeOn: ['home', 'inbox_view'],
  },
  {
    key: 'COPILOT',
    icon: 'i-lucide-sparkles',
    to: accountScopedRoute('chatssync_copilot'),
    activeOn: ['chatssync_copilot'],
  },
  {
    key: 'CONTACTS',
    icon: 'i-lucide-contact',
    to: accountScopedRoute('contacts_dashboard_index'),
    activeOn: ['contacts_dashboard_index'],
  },
]);
</script>

<template>
  <nav
    v-if="!CHAT_ROUTES.includes(route.name)"
    class="fixed bottom-0 inset-x-0 z-40 grid grid-cols-5 h-14 border-t border-n-weak bg-n-solid-1 md:hidden"
  >
    <router-link
      v-for="item in items"
      :key="item.key"
      :to="item.to"
      class="flex flex-col items-center justify-center gap-0.5 text-xs"
      :class="
        item.activeOn.includes(route.name)
          ? 'text-n-brand font-medium'
          : 'text-n-slate-11'
      "
    >
      <span :class="item.icon" class="size-5" />
      {{ $t(`MOBILE_NAV.${item.key}`) }}
    </router-link>
    <button
      type="button"
      class="flex flex-col items-center justify-center gap-0.5 text-xs"
      :class="
        isMobileSidebarOpen ? 'text-n-brand font-medium' : 'text-n-slate-11'
      "
      @click="emit('toggle')"
    >
      <span class="i-lucide-menu size-5" />
      {{ $t('MOBILE_NAV.MENU') }}
    </button>
  </nav>
</template>
