<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAccount } from 'dashboard/composables/useAccount';
import PlanUsageAPI from 'dashboard/api/planUsage';
import Banner from 'dashboard/components/ui/Banner.vue';
import { usagePercent } from 'dashboard/routes/dashboard/settings/plan/usageLimits';

const WATCHED_KEYS = ['contacts_monthly', 'ai_replies_monthly'];

const { t } = useI18n();
const router = useRouter();
const { isAdmin } = useAdmin();
const { accountId } = useAccount();

const data = ref(null);

onMounted(async () => {
  try {
    const response = await PlanUsageAPI.get();
    data.value = response.data;
  } catch (e) {
    // The banner is optional; the app works without it.
  }
});

const fullKey = computed(() =>
  WATCHED_KEYS.find(key => usagePercent(data.value?.usage?.[key] || {}) >= 100)
);

const nearKey = computed(() =>
  WATCHED_KEYS.find(key => usagePercent(data.value?.usage?.[key] || {}) >= 80)
);

const message = computed(() => {
  if (!data.value) return '';
  if (data.value.locked_conversations) {
    return t('PLAN_USAGE.BANNER.LOCKED', {
      count: data.value.locked_conversations,
    });
  }
  if (fullKey.value) {
    return t('PLAN_USAGE.BANNER.FULL', {
      item: t(`PLAN_USAGE.LIMITS.${fullKey.value.toUpperCase()}`),
    });
  }
  if (nearKey.value) {
    return t('PLAN_USAGE.BANNER.NEAR', {
      item: t(`PLAN_USAGE.LIMITS.${nearKey.value.toUpperCase()}`),
    });
  }
  return '';
});

const isCritical = computed(
  () => !!data.value?.locked_conversations || !!fullKey.value
);

const openPlan = () => {
  router.push({
    name: 'plan_usage_index',
    params: { accountId: accountId.value },
  });
};
</script>

<template>
  <Banner
    v-if="message"
    :color-scheme="isCritical ? 'alert' : 'warning'"
    :banner-message="message"
    :action-button-label="$t('PLAN_USAGE.BANNER.ACTION')"
    :has-action-button="isAdmin"
    @primary-action="openPlan"
  />
</template>
