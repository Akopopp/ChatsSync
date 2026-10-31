<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { format } from 'date-fns';
import { useAccount } from 'dashboard/composables/useAccount';
import PlanUsageAPI from 'dashboard/api/planUsage';

import BillingCard from '../billing/components/BillingCard.vue';
import BillingMeter from '../billing/components/BillingMeter.vue';
import DetailItem from '../billing/components/DetailItem.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import ButtonV4 from 'next/button/Button.vue';
import {
  LIMIT_KEYS,
  PACK_KEYS,
  usagePercent,
  whatsappLink,
} from './usageLimits';

const { t } = useI18n();
const { currentAccount } = useAccount();

const data = ref(null);
const isLoading = ref(true);

const fetchUsage = async () => {
  try {
    const response = await PlanUsageAPI.get();
    data.value = response.data;
  } finally {
    isLoading.value = false;
  }
};

const accountTag = computed(
  () => `${currentAccount.value?.name} (#${currentAccount.value?.id})`
);

const contactLink = text =>
  whatsappLink(
    data.value?.support_whatsapp,
    `${text} ${t('PLAN_USAGE.ACCOUNT')}: ${accountTag.value}`
  );

const endsOn = computed(() =>
  data.value?.ends_at ? format(new Date(data.value.ends_at), 'dd MMM, yyyy') : '-'
);

const daysLeft = computed(() => {
  if (!data.value?.ends_at) return '-';
  const ms = new Date(data.value.ends_at).getTime() - Date.now();
  return String(Math.max(0, Math.ceil(ms / 86400000)));
});

const rows = computed(() =>
  LIMIT_KEYS.filter(key => data.value?.usage?.[key]).map(key => ({
    key,
    label: t(`PLAN_USAGE.LIMITS.${key.toUpperCase()}`),
    used: data.value.usage[key].used ?? 0,
    limit: data.value.usage[key].limit,
    canBuyMore:
      PACK_KEYS.includes(key) && usagePercent(data.value.usage[key]) >= 80,
  }))
);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('ATTRIBUTES_MGMT.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('PLAN_USAGE.TITLE')"
        :description="$t('PLAN_USAGE.DESCRIPTION')"
      />
    </template>
    <template #body>
      <section v-if="data" class="grid gap-4">
        <BillingCard
          :title="data.plan ? data.plan.name : $t('PLAN_USAGE.NO_PLAN')"
          :description="$t('PLAN_USAGE.PLAN_DESCRIPTION')"
        >
          <template #action>
            <a
              :href="contactLink($t('PLAN_USAGE.RENEW_MESSAGE'))"
              target="_blank"
              rel="noopener noreferrer"
            >
              <ButtonV4 sm solid blue>
                {{ $t('PLAN_USAGE.RENEW_BUTTON') }}
              </ButtonV4>
            </a>
          </template>
          <div
            class="grid lg:grid-cols-3 sm:grid-cols-3 grid-cols-1 gap-2 divide-x divide-n-weak"
          >
            <DetailItem
              :label="$t('PLAN_USAGE.PRICE')"
              :value="data.plan ? `Rs ${data.plan.price}` : '-'"
            />
            <DetailItem :label="$t('PLAN_USAGE.ENDS_ON')" :value="endsOn" />
            <DetailItem :label="$t('PLAN_USAGE.DAYS_LEFT')" :value="daysLeft" />
          </div>
        </BillingCard>

        <BillingCard
          :title="$t('PLAN_USAGE.USAGE_TITLE')"
          :description="$t('PLAN_USAGE.USAGE_DESCRIPTION')"
        >
          <div
            v-if="data.locked_conversations"
            class="mx-5 px-3 py-2 rounded-lg bg-n-ruby-3 text-n-ruby-11 text-sm"
          >
            {{
              $t('PLAN_USAGE.LOCKED_CHATS', {
                count: data.locked_conversations,
              })
            }}
          </div>
          <div class="px-5 grid gap-5">
            <div v-for="row in rows" :key="row.key" class="grid gap-2">
              <BillingMeter
                v-if="row.limit"
                :title="row.label"
                :consumed="row.used"
                :total-count="row.limit"
              />
              <div
                v-else
                class="flex gap-5 items-center justify-between text-xs uppercase text-n-slate-10"
              >
                <div class="font-medium tracking-wider">{{ row.label }}</div>
                <div class="tabular-nums">
                  {{ row.used }} / {{ $t('PLAN_USAGE.UNLIMITED') }}
                </div>
              </div>
              <a
                v-if="row.canBuyMore"
                class="text-sm text-n-blue-11 hover:underline w-fit"
                :href="
                  contactLink(
                    $t('PLAN_USAGE.BUY_MORE_MESSAGE', { item: row.label })
                  )
                "
                target="_blank"
                rel="noopener noreferrer"
              >
                {{ $t('PLAN_USAGE.BUY_MORE') }}
              </a>
            </div>
          </div>
        </BillingCard>

        <p class="text-xs text-n-slate-11">
          {{ $t('PLAN_USAGE.META_NOTE') }}
        </p>
      </section>
    </template>
  </SettingsLayout>
</template>
