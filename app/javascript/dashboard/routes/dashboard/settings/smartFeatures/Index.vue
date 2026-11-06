<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import SmartFeaturesAPI from 'dashboard/api/smartFeatures';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Switch from 'next/switch/Switch.vue';

const { t } = useI18n();

const isLoading = ref(true);
const features = ref({});
const numbers = ref([]);
const ads = ref(null);
const cod = ref(null);
const currency = ref('Rs');
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
      'photo_search',
      'follow_up',
    ],
  },
  {
    key: 'CUSTOMERS',
    icon: 'i-lucide-star',
    items: ['review_request', 'broadcast_tools'],
  },
  { key: 'STORE', icon: 'i-lucide-shopping-bag', items: ['cod_confirm'] },
  {
    key: 'ADS',
    icon: 'i-lucide-megaphone',
    items: ['ad_report', 'meta_sales'],
  },
  { key: 'OWNER', icon: 'i-lucide-mail', items: ['daily_report'] },
  {
    key: 'SAFETY',
    icon: 'i-lucide-shield-check',
    items: ['health_guard', 'stop_opt_out'],
  },
];
const FOLLOW_UP_HOURS = [1, 2, 3, 4, 6, 8, 12, 20];
const META_SALES_WHEN = ['new', 'confirmed', 'delivered'];
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

const apply = data => {
  features.value = data.features;
  numbers.value = data.numbers;
  ads.value = data.ads;
  cod.value = data.cod;
  currency.value = data.currency || 'Rs';
  reviewLink.value = data.features.review_link || '';
};

const load = async () => {
  try {
    const { data } = await SmartFeaturesAPI.get();
    apply(data);
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
    apply(data);
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

const codTemplateValue = computed(() =>
  features.value.cod_template
    ? `${features.value.cod_template}|${features.value.cod_template_language}`
    : ''
);

const chooseCodInbox = id =>
  save({
    cod_inbox_id: Number(id),
    cod_template: '',
    cod_template_language: '',
  });

const chooseCodTemplate = value => {
  const [name, language] = value.split('|');
  save({ cod_template: name || '', cod_template_language: language || '' });
};

const copyCodLink = async () => {
  await copyTextToClipboard(cod.value.url);
  useAlert(t('SMART_FEATURES.COD.COPIED'));
};

const money = amount => {
  const value = Number(amount || 0);
  return `${currency.value} ${Math.round(value).toLocaleString('en-US')}`;
};

const adName = ad => {
  if (ad.headline) return ad.headline;
  if (ad.source === 'post') return t('SMART_FEATURES.ADS.POST');
  return ad.ad_id
    ? t('SMART_FEATURES.ADS.AD_ID', { id: ad.ad_id })
    : t('SMART_FEATURES.ADS.UNKNOWN');
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

              <label
                v-if="key === 'meta_sales' && features.meta_sales"
                class="flex flex-wrap items-center gap-2 text-sm text-n-slate-11"
              >
                {{ $t('SMART_FEATURES.META_SALES_WHEN') }}
                <select
                  :value="features.meta_sales_when"
                  class="!mb-0 !w-auto !py-1 text-sm"
                  @change="save({ meta_sales_when: $event.target.value })"
                >
                  <option
                    v-for="status in META_SALES_WHEN"
                    :key="status"
                    :value="status"
                  >
                    {{
                      $t(
                        `SMART_FEATURES.META_SALES_STATUS.${status.toUpperCase()}`
                      )
                    }}
                  </option>
                </select>
              </label>

              <div
                v-if="key === 'cod_confirm' && features.cod_confirm && cod"
                class="grid gap-3 text-sm"
              >
                <label class="grid gap-1 text-n-slate-11">
                  {{ $t('SMART_FEATURES.COD.NUMBER') }}
                  <select
                    :value="features.cod_inbox_id || ''"
                    class="!mb-0 text-sm"
                    @change="chooseCodInbox($event.target.value)"
                  >
                    <option value="" disabled>
                      {{ $t('SMART_FEATURES.COD.NUMBER_PLACEHOLDER') }}
                    </option>
                    <option
                      v-for="inbox in cod.inboxes"
                      :key="inbox.id"
                      :value="inbox.id"
                    >
                      {{ inbox.name }}
                    </option>
                  </select>
                </label>
                <label
                  v-if="features.cod_inbox_id"
                  class="grid gap-1 text-n-slate-11"
                >
                  {{ $t('SMART_FEATURES.COD.TEMPLATE') }}
                  <select
                    v-if="cod.templates.length"
                    :value="codTemplateValue"
                    class="!mb-0 text-sm"
                    @change="chooseCodTemplate($event.target.value)"
                  >
                    <option value="" disabled>
                      {{ $t('SMART_FEATURES.COD.TEMPLATE_PLACEHOLDER') }}
                    </option>
                    <option
                      v-for="item in cod.templates"
                      :key="`${item.name}|${item.language}`"
                      :value="`${item.name}|${item.language}`"
                    >
                      {{ `${item.name} (${item.language})` }}
                    </option>
                  </select>
                  <span
                    v-else
                    class="px-3 py-2 rounded-lg bg-n-amber-2 text-n-amber-11"
                  >
                    {{ $t('SMART_FEATURES.COD.NO_TEMPLATES') }}
                  </span>
                  <span class="text-xs text-n-slate-10">
                    {{ $t('SMART_FEATURES.COD.TEMPLATE_HELP') }}
                  </span>
                </label>
                <div class="flex items-center justify-between gap-4">
                  <span class="text-n-slate-12">
                    {{ $t('SMART_FEATURES.COD.COD_ONLY') }}
                  </span>
                  <Switch
                    :model-value="!!features.cod_only"
                    :aria-label="$t('SMART_FEATURES.COD.COD_ONLY')"
                    @change="save({ cod_only: !features.cod_only })"
                  />
                </div>
                <div class="grid gap-1">
                  <span class="text-n-slate-11">
                    {{ $t('SMART_FEATURES.COD.LINK') }}
                  </span>
                  <div class="flex items-center gap-2">
                    <input
                      :value="cod.url"
                      readonly
                      class="!mb-0 flex-1 min-w-0 text-xs"
                      @focus="$event.target.select()"
                    />
                    <button
                      class="px-3 py-1.5 rounded-lg text-sm outline outline-1 outline-n-weak text-n-slate-12 hover:outline-n-strong"
                      @click="copyCodLink"
                    >
                      {{ $t('SMART_FEATURES.COD.COPY') }}
                    </button>
                  </div>
                  <ul
                    class="grid gap-1 ltr:pl-4 rtl:pr-4 list-disc text-xs text-n-slate-11"
                  >
                    <li>{{ $t('SMART_FEATURES.COD.HELP_SHOPIFY') }}</li>
                    <li>{{ $t('SMART_FEATURES.COD.HELP_WOO') }}</li>
                    <li>{{ $t('SMART_FEATURES.COD.LINK_PRIVATE') }}</li>
                  </ul>
                </div>
              </div>

              <div
                v-if="key === 'ad_report' && features.ad_report && ads"
                class="grid gap-2 text-sm"
              >
                <p
                  v-if="!ads.ads.length"
                  class="px-3 py-2 rounded-lg bg-n-alpha-1 text-n-slate-11"
                >
                  {{ $t('SMART_FEATURES.ADS.EMPTY', { days: ads.days }) }}
                </p>
                <template v-else>
                  <div class="flex flex-wrap gap-x-4 gap-y-1 text-n-slate-11">
                    <span>{{
                      $t('SMART_FEATURES.ADS.TOTAL', { days: ads.days })
                    }}</span>
                    <span>{{
                      $t('SMART_FEATURES.ADS.CHATS', { count: ads.chats })
                    }}</span>
                    <span>{{
                      $t('SMART_FEATURES.ADS.ORDERS', { count: ads.orders })
                    }}</span>
                    <span>{{
                      $t('SMART_FEATURES.ADS.BOOKINGS', { count: ads.bookings })
                    }}</span>
                    <span class="font-medium text-n-slate-12">
                      {{ money(ads.sales) }}
                    </span>
                  </div>
                  <div
                    v-for="ad in ads.ads"
                    :key="`${ad.ad_id}-${ad.headline}`"
                    class="grid gap-1 px-3 py-2 rounded-lg bg-n-alpha-1"
                  >
                    <div class="flex items-center gap-2 min-w-0">
                      <span class="font-medium text-n-slate-12 truncate">
                        {{ adName(ad) }}
                      </span>
                      <a
                        v-if="ad.url"
                        :href="ad.url"
                        target="_blank"
                        rel="noopener noreferrer"
                        class="text-xs text-n-blue-11 shrink-0"
                      >
                        {{ $t('SMART_FEATURES.ADS.OPEN') }}
                      </a>
                      <span
                        class="ltr:ml-auto rtl:mr-auto font-medium text-n-slate-12 shrink-0"
                      >
                        {{ money(ad.sales) }}
                      </span>
                    </div>
                    <div class="flex flex-wrap gap-x-4 text-xs text-n-slate-11">
                      <span>{{
                        $t('SMART_FEATURES.ADS.CHATS', { count: ad.chats })
                      }}</span>
                      <span>{{
                        $t('SMART_FEATURES.ADS.ORDERS', { count: ad.orders })
                      }}</span>
                      <span>{{
                        $t('SMART_FEATURES.ADS.BOOKINGS', {
                          count: ad.bookings,
                        })
                      }}</span>
                    </div>
                  </div>
                </template>
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
