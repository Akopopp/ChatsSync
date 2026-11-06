<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SmartFeaturesAPI from 'dashboard/api/smartFeatures';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Switch from 'next/switch/Switch.vue';

const { t } = useI18n();

const isLoading = ref(true);
const features = ref({});
const numbers = ref([]);
const reviewLink = ref('');

// Each group is a card; every item has its own on/off switch.
const GROUPS = [
  {
    key: 'AI',
    icon: 'i-lucide-sparkles',
    items: [
      'typing_indicator',
      'returning_customers',
      'payment_check',
      'follow_up',
    ],
  },
  { key: 'CUSTOMERS', icon: 'i-lucide-star', items: ['review_request'] },
  { key: 'OWNER', icon: 'i-lucide-mail', items: ['daily_report'] },
  {
    key: 'SAFETY',
    icon: 'i-lucide-shield-check',
    items: ['health_guard', 'stop_opt_out'],
  },
];
const FOLLOW_UP_HOURS = [1, 2, 3, 4, 6, 8, 12, 20];
const QUALITY_CLASS = {
  GREEN: 'bg-n-teal-3 text-n-teal-11',
  YELLOW: 'bg-n-amber-3 text-n-amber-11',
  RED: 'bg-n-ruby-3 text-n-ruby-11',
};

const featureKey = key => key.toUpperCase();
const onCount = computed(
  () =>
    GROUPS.flatMap(group => group.items).filter(key => features.value[key])
      .length
);

const load = async () => {
  try {
    const { data } = await SmartFeaturesAPI.get();
    features.value = data.features;
    numbers.value = data.numbers;
    reviewLink.value = data.features.review_link || '';
  } catch (error) {
    useAlert(t('SMART_FEATURES.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const save = async changes => {
  const before = { ...features.value };
  features.value = { ...features.value, ...changes };
  try {
    const { data } = await SmartFeaturesAPI.update(changes);
    features.value = data.features;
    numbers.value = data.numbers;
    reviewLink.value = data.features.review_link || '';
    useAlert(t('SMART_FEATURES.SAVED'));
  } catch (error) {
    features.value = before;
    useAlert(t('SMART_FEATURES.ERROR'));
  }
};

const toggle = key => save({ [key]: !features.value[key] });

const saveReviewLink = () => {
  const link = reviewLink.value.trim();
  if (link === (features.value.review_link || '')) return;
  if (link && !/^https?:\/\/\S+$/.test(link)) {
    useAlert(t('SMART_FEATURES.REVIEW_LINK_INVALID'));
    return;
  }
  save({ review_link: link });
};

const qualityLabel = quality =>
  quality
    ? t(`SMART_FEATURES.QUALITY.${quality}`, quality)
    : t('SMART_FEATURES.QUALITY.UNKNOWN');

const checkedAt = number =>
  number.checked_at
    ? new Date(number.checked_at).toLocaleString([], {
        dateStyle: 'medium',
        timeStyle: 'short',
      })
    : t('SMART_FEATURES.NUMBERS.NOT_CHECKED');

onMounted(load);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('SMART_FEATURES.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('SMART_FEATURES.TITLE')"
        :description="$t('SMART_FEATURES.DESCRIPTION')"
      />
    </template>
    <template #body>
      <section class="grid gap-5 pb-20">
        <div
          class="flex items-center gap-2 px-4 py-3 rounded-xl bg-n-alpha-2 text-sm text-n-slate-11"
        >
          <span class="i-lucide-info size-4 shrink-0" />
          {{ $t('SMART_FEATURES.ALL_OPTIONAL', { count: onCount }) }}
        </div>

        <div
          v-for="group in GROUPS"
          :key="group.key"
          class="rounded-2xl outline outline-1 outline-n-weak bg-n-solid-1"
        >
          <div class="flex items-center gap-2 px-5 pt-4 pb-2">
            <span :class="group.icon" class="size-4 text-n-slate-11" />
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ $t(`SMART_FEATURES.GROUPS.${group.key}`) }}
            </h3>
          </div>

          <div class="divide-y divide-n-weak">
            <div
              v-for="key in group.items"
              :key="key"
              class="grid gap-3 px-5 py-4"
            >
              <div class="flex items-start justify-between gap-4">
                <div class="grid gap-1 min-w-0">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ $t(`SMART_FEATURES.ITEMS.${featureKey(key)}.TITLE`) }}
                  </span>
                  <span class="text-sm text-n-slate-11">
                    {{ $t(`SMART_FEATURES.ITEMS.${featureKey(key)}.HINT`) }}
                  </span>
                </div>
                <Switch
                  :model-value="!!features[key]"
                  :aria-label="
                    $t(`SMART_FEATURES.ITEMS.${featureKey(key)}.TITLE`)
                  "
                  class="mt-1"
                  @change="toggle(key)"
                />
              </div>

              <!-- Options shown only when the feature is on -->
              <label
                v-if="key === 'follow_up' && features.follow_up"
                class="flex flex-wrap items-center gap-2 text-sm text-n-slate-11"
              >
                {{ $t('SMART_FEATURES.FOLLOW_UP_AFTER') }}
                <select
                  :value="features.follow_up_hours"
                  class="!mb-0 !w-auto !py-1 text-sm"
                  @change="
                    save({ follow_up_hours: Number($event.target.value) })
                  "
                >
                  <option
                    v-for="hours in FOLLOW_UP_HOURS"
                    :key="hours"
                    :value="hours"
                  >
                    {{ $t('SMART_FEATURES.HOURS', { count: hours }, hours) }}
                  </option>
                </select>
              </label>

              <div
                v-if="key === 'review_request' && features.review_request"
                class="grid gap-1"
              >
                <span class="text-sm text-n-slate-11">
                  {{ $t('SMART_FEATURES.REVIEW_LINK') }}
                </span>
                <input
                  v-model="reviewLink"
                  type="url"
                  class="!mb-0"
                  :placeholder="$t('SMART_FEATURES.REVIEW_LINK_PLACEHOLDER')"
                  @blur="saveReviewLink"
                  @keyup.enter="saveReviewLink"
                />
              </div>

              <div
                v-if="key === 'health_guard' && features.health_guard"
                class="grid gap-2"
              >
                <p
                  v-if="!numbers.length"
                  class="text-sm text-n-slate-11 px-3 py-2 rounded-lg bg-n-alpha-1"
                >
                  {{ $t('SMART_FEATURES.NUMBERS.EMPTY') }}
                </p>
                <div
                  v-for="number in numbers"
                  :key="number.inbox_id"
                  class="flex flex-wrap items-center gap-x-4 gap-y-1 px-3 py-2 rounded-lg bg-n-alpha-1 text-sm"
                >
                  <span class="font-medium text-n-slate-12">
                    {{ number.phone || number.inbox_name }}
                  </span>
                  <span
                    class="px-2 py-0.5 rounded-full text-xs font-medium"
                    :class="
                      QUALITY_CLASS[number.quality_rating] ||
                      'bg-n-alpha-2 text-n-slate-11'
                    "
                  >
                    {{ qualityLabel(number.quality_rating) }}
                  </span>
                  <span v-if="number.daily_limit" class="text-n-slate-11">
                    {{
                      $t('SMART_FEATURES.NUMBERS.LIMIT', {
                        limit: number.daily_limit,
                      })
                    }}
                  </span>
                  <span class="text-xs text-n-slate-10 ltr:ml-auto rtl:mr-auto">
                    {{ checkedAt(number) }}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </template>
  </SettingsLayout>
</template>
