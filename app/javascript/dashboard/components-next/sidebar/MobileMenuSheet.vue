<script setup>
// Phones: Menu opens this sheet from the bottom, like an app. Every page is a tile, one tap away.
// "Full menu" still opens the sidebar for profile, theme and log out.
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store.js';

defineProps({
  show: { type: Boolean, default: false },
});

const emit = defineEmits(['close', 'fullMenu']);

const { t } = useI18n();
const router = useRouter();
const { accountScopedRoute, currentAccount } = useAccount();
const currentRole = useMapGetter('getCurrentRole');
const isAdmin = computed(() => currentRole.value === 'administrator');

const tile = (label, icon, name) => ({ label, icon, name });

const sections = computed(() => {
  const work = [
    tile(t('SIDEBAR.INBOX'), 'i-lucide-inbox', 'inbox_view'),
    ...(currentAccount.value?.appointments_enabled
      ? [
          tile(
            t('SIDEBAR.APPOINTMENTS'),
            'i-lucide-calendar-days',
            'appointments_calendar'
          ),
        ]
      : []),
    tile(
      t('SIDEBAR.CAMPAIGNS'),
      'i-lucide-megaphone',
      'campaigns_whatsapp_index'
    ),
    tile(
      t('SIDEBAR.REPORTS'),
      'i-lucide-chart-spline',
      'account_overview_reports'
    ),
  ];
  if (!isAdmin.value) return [{ key: 'WORK', items: work }];

  return [
    { key: 'WORK', items: work },
    {
      key: 'AUTOMATE',
      items: [
        tile(t('SIDEBAR.AI_AGENT'), 'i-lucide-sparkles', 'ai_agent_settings'),
        tile(t('MOBILE_NAV.CHATBOT'), 'i-lucide-bot', 'chatbot_builder'),
        tile(
          t('SIDEBAR.SMART_FEATURES'),
          'i-lucide-wand-sparkles',
          'smart_features_settings'
        ),
        tile(
          t('SIDEBAR.ONLINE_STORE'),
          'i-lucide-store',
          'online_store_settings'
        ),
        tile(t('SIDEBAR.CATALOG'), 'i-lucide-shopping-bag', 'catalog_settings'),
        tile(
          t('MOBILE_NAV.TEMPLATES'),
          'i-lucide-layout-template',
          'templates_index'
        ),
        tile(t('MOBILE_NAV.GALLERY'), 'i-lucide-image', 'gallery_index'),
        tile(t('SIDEBAR.AUTOMATION'), 'i-lucide-repeat', 'automation_list'),
      ],
    },
    {
      key: 'SETTINGS',
      items: [
        tile(t('SIDEBAR.INBOXES'), 'i-lucide-inbox', 'settings_inbox_list'),
        tile(t('SIDEBAR.AGENTS'), 'i-lucide-square-user', 'agent_list'),
        tile(t('SIDEBAR.TEAMS'), 'i-lucide-users', 'settings_teams_list'),
        tile(t('SIDEBAR.LABELS'), 'i-lucide-tags', 'labels_list'),
        tile(
          t('SIDEBAR.CANNED_RESPONSES'),
          'i-lucide-message-square-quote',
          'canned_list'
        ),
        tile(
          t('SIDEBAR.APPOINTMENTS'),
          'i-lucide-calendar-cog',
          'appointments_settings'
        ),
        tile(t('SIDEBAR.PLAN_USAGE'), 'i-lucide-gauge', 'plan_usage_index'),
        tile(
          t('SIDEBAR.ACCOUNT_SETTINGS'),
          'i-lucide-briefcase',
          'general_settings_index'
        ),
      ],
    },
  ];
});

const open = name => {
  emit('close');
  router.push(accountScopedRoute(name)).catch(() => {});
};
</script>

<template>
  <Teleport to="body">
    <transition
      enter-from-class="opacity-0"
      leave-to-class="opacity-0"
      enter-active-class="transition-opacity duration-200"
      leave-active-class="transition-opacity duration-200"
    >
      <div
        v-if="show"
        class="fixed inset-0 z-[60] bg-n-alpha-black1 backdrop-blur-[2px] md:hidden"
        @click="emit('close')"
      />
    </transition>
    <transition
      enter-from-class="translate-y-full"
      leave-to-class="translate-y-full"
      enter-active-class="transition-transform duration-200 ease-out"
      leave-active-class="transition-transform duration-200 ease-in"
    >
      <section
        v-if="show"
        role="dialog"
        aria-modal="true"
        :aria-label="t('MOBILE_NAV.MENU')"
        class="fixed inset-x-0 bottom-0 z-[61] flex flex-col max-h-[85vh] rounded-t-3xl bg-n-solid-1 shadow-xl md:hidden"
      >
        <div class="flex justify-center pt-2.5">
          <span class="w-10 h-1 rounded-full bg-n-slate-6" />
        </div>
        <div class="flex items-center justify-between px-5 pt-3 pb-2">
          <h2 class="m-0 text-base font-semibold text-n-slate-12">
            {{ t('MOBILE_NAV.MENU') }}
          </h2>
          <button
            type="button"
            class="flex items-center justify-center rounded-full size-9 bg-n-alpha-2 text-n-slate-11"
            :aria-label="t('MOBILE_NAV.CLOSE')"
            @click="emit('close')"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </div>

        <div class="grid gap-5 px-4 pb-4 overflow-y-auto">
          <div
            v-for="section in sections"
            :key="section.key"
            class="grid gap-2"
          >
            <h3
              class="m-0 px-1 text-xs font-semibold tracking-wide uppercase text-n-slate-10"
            >
              {{ t(`MOBILE_NAV.SECTIONS.${section.key}`) }}
            </h3>
            <div class="grid grid-cols-4 gap-2">
              <button
                v-for="item in section.items"
                :key="item.name"
                type="button"
                class="flex flex-col items-center gap-1.5 px-1 py-3 rounded-2xl bg-n-alpha-1 active:bg-n-alpha-2"
                @click="open(item.name)"
              >
                <span
                  class="flex items-center justify-center rounded-xl size-10 bg-n-brand/10 text-n-brand"
                >
                  <span :class="item.icon" class="size-5" />
                </span>
                <span
                  class="text-[11px] leading-tight text-center text-n-slate-12 line-clamp-2"
                >
                  {{ item.label }}
                </span>
              </button>
            </div>
          </div>
        </div>

        <div class="px-4 pt-2 pb-5 border-t border-n-weak">
          <button
            type="button"
            class="flex items-center justify-center w-full gap-2 py-3 text-sm font-medium rounded-xl bg-n-alpha-2 text-n-slate-12"
            @click="emit('fullMenu')"
          >
            <span class="i-lucide-panel-left-open size-4" />
            {{ t('MOBILE_NAV.FULL_MENU') }}
          </button>
        </div>
      </section>
    </transition>
  </Teleport>
</template>
