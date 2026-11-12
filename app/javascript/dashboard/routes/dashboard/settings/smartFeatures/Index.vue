<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import SmartFeaturesAPI from 'dashboard/api/smartFeatures';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Switch from 'next/switch/Switch.vue';
import TemplatePicker from './TemplatePicker.vue';

const { t } = useI18n();

const isLoading = ref(true);
const features = ref({});
const numbers = ref([]);
const ads = ref(null);
const cod = ref(null);
const reminder = ref(null);
const ship = ref(null);
const cart = ref(null);
const currency = ref('Rs');
const reviewLink = ref('');
const alertRules = ref('');
const sheetUrl = ref('');
const sheetScript = ref('');

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
    items: [
      'review_request',
      'repeat_reminder',
      'broadcast_tools',
      'whatsapp_forms',
    ],
  },
  {
    key: 'STORE',
    icon: 'i-lucide-shopping-bag',
    items: ['cod_confirm', 'ship_updates', 'cart_recovery'],
  },
  {
    key: 'ADS',
    icon: 'i-lucide-megaphone',
    items: ['ad_report', 'meta_sales'],
  },
  {
    key: 'OWNER',
    icon: 'i-lucide-mail',
    items: ['daily_report', 'email_alerts', 'google_sheet'],
  },
  {
    key: 'SAFETY',
    icon: 'i-lucide-shield-check',
    items: ['health_guard', 'stop_opt_out'],
  },
];
const FOLLOW_UP_HOURS = [1, 2, 3, 4, 6, 8, 12, 20];
const META_SALES_WHEN = ['new', 'confirmed', 'delivered'];
const REMINDER_DAYS = [7, 14, 21, 30, 45, 60, 90, 180];
const CART_DELAY_HOURS = [1, 2, 3, 6, 12, 24];
// Online store features: the settings key prefix and the store events each one needs.
const STORE_ITEMS = {
  cod_confirm: { prefix: 'cod', data: cod },
  ship_updates: { prefix: 'ship', data: ship },
  cart_recovery: { prefix: 'cart', data: cart },
};
const storeData = key => STORE_ITEMS[key]?.data.value;
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
  reminder.value = data.reminder;
  ship.value = data.ship;
  cart.value = data.cart;
  currency.value = data.currency || 'Rs';
  reviewLink.value = data.features.review_link || '';
  alertRules.value = data.features.alert_rules || '';
  sheetUrl.value = data.features.sheet_url || '';
  sheetScript.value = data.sheet_script || '';
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

const saveSheetUrl = () => {
  const url = sheetUrl.value.trim();
  if (url === (features.value.sheet_url || '')) return;
  if (
    url &&
    !/^https:\/\/script\.google\.com\/macros\/s\/[\w-]+\/exec$/.test(url)
  ) {
    useAlert(t('SMART_FEATURES.SHEET.URL_INVALID'));
    return;
  }
  save({ sheet_url: url });
};

const copySheetScript = async () => {
  await copyTextToClipboard(sheetScript.value);
  useAlert(t('SMART_FEATURES.SHEET.COPIED'));
};

const saveAlertRules = () => {
  const rules = alertRules.value.trim();
  if (rules !== (features.value.alert_rules || ''))
    save({ alert_rules: rules });
};

const saveReviewLink = () => {
  const link = reviewLink.value.trim();
  if (link === (features.value.review_link || '')) return;
  if (link && !/^https?:\/\/\S+$/.test(link)) {
    useAlert(t('SMART_FEATURES.REVIEW_LINK_INVALID'));
    return;
  }
  save({ review_link: link });
};

// prefix: 'cod', 'ship', 'cart' or 'repeat_reminder'; saves the number and template the feature sends from.
const pickTemplate = (prefix, { inboxId, template, language }) =>
  save({
    [`${prefix}_inbox_id`]: inboxId,
    [`${prefix}_template`]: template,
    [`${prefix}_template_language`]: language,
  });

const copyStoreLink = async url => {
  await copyTextToClipboard(url);
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
                v-if="key === 'email_alerts' && features.email_alerts"
                class="grid gap-3 text-sm"
              >
                <div
                  v-for="alert in ['alert_order', 'alert_handoff']"
                  :key="alert"
                  class="flex items-center justify-between gap-4"
                >
                  <span class="text-n-slate-12">
                    {{ $t(`SMART_FEATURES.ALERTS.${featureKey(alert)}`) }}
                  </span>
                  <Switch
                    :model-value="!!features[alert]"
                    :aria-label="
                      $t(`SMART_FEATURES.ALERTS.${featureKey(alert)}`)
                    "
                    @change="save({ [alert]: !features[alert] })"
                  />
                </div>
                <label class="grid gap-1">
                  <span class="text-n-slate-12">
                    {{ $t('SMART_FEATURES.ALERTS.RULES') }}
                  </span>
                  <textarea
                    v-model="alertRules"
                    rows="3"
                    maxlength="500"
                    class="!mb-0 text-sm"
                    :placeholder="$t('SMART_FEATURES.ALERTS.RULES_PLACEHOLDER')"
                    @blur="saveAlertRules"
                  />
                  <span class="text-xs text-n-slate-11">
                    {{ $t('SMART_FEATURES.ALERTS.RULES_HELP') }}
                  </span>
                </label>
              </div>

              <div
                v-if="key === 'google_sheet' && features.google_sheet"
                class="grid gap-3 text-sm"
              >
                <ol class="grid gap-2 text-xs text-n-slate-12">
                  <li
                    v-for="step in [1, 2, 3, 4]"
                    :key="step"
                    class="flex items-start gap-2 px-3 py-2 rounded-lg bg-n-alpha-1"
                  >
                    <span
                      class="flex items-center justify-center flex-shrink-0 rounded-full size-5 bg-n-brand text-white"
                    >
                      {{ step }}
                    </span>
                    {{ $t(`SMART_FEATURES.SHEET.STEP_${step}`) }}
                  </li>
                </ol>
                <div class="grid gap-1">
                  <div class="flex items-center justify-between gap-2">
                    <span class="text-n-slate-11">
                      {{ $t('SMART_FEATURES.SHEET.SCRIPT') }}
                    </span>
                    <button
                      class="px-3 py-1.5 rounded-lg text-sm outline outline-1 outline-n-weak text-n-slate-12 hover:outline-n-strong"
                      @click="copySheetScript"
                    >
                      {{ $t('SMART_FEATURES.COD.COPY') }}
                    </button>
                  </div>
                  <pre
                    class="max-h-40 overflow-auto px-3 py-2 rounded-lg bg-n-alpha-1 text-xs text-n-slate-12 whitespace-pre"
                    >{{ sheetScript }}</pre
                  >
                </div>
                <label class="grid gap-1">
                  <span class="text-n-slate-11">
                    {{ $t('SMART_FEATURES.SHEET.URL') }}
                  </span>
                  <input
                    v-model="sheetUrl"
                    type="url"
                    class="!mb-0 text-sm"
                    :placeholder="$t('SMART_FEATURES.SHEET.URL_PLACEHOLDER')"
                    @blur="saveSheetUrl"
                    @keyup.enter="saveSheetUrl"
                  />
                </label>
                <div
                  v-for="kind in [
                    'sheet_leads',
                    'sheet_orders',
                    'sheet_bookings',
                  ]"
                  :key="kind"
                  class="flex items-center justify-between gap-4"
                >
                  <span class="text-n-slate-12">
                    {{ $t(`SMART_FEATURES.SHEET.${featureKey(kind)}`) }}
                  </span>
                  <Switch
                    :model-value="!!features[kind]"
                    :aria-label="$t(`SMART_FEATURES.SHEET.${featureKey(kind)}`)"
                    @change="save({ [kind]: !features[kind] })"
                  />
                </div>
              </div>

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

              <router-link
                v-if="key === 'whatsapp_forms' && features.whatsapp_forms"
                :to="{ name: 'whatsapp_forms_settings' }"
                class="inline-flex items-center gap-1 text-sm text-n-blue-11"
              >
                <span class="i-lucide-clipboard-list size-4" />
                {{ $t('SMART_FEATURES.MANAGE_FORMS') }}
              </router-link>

              <div
                v-if="
                  key === 'repeat_reminder' &&
                  features.repeat_reminder &&
                  reminder
                "
                class="grid gap-3 text-sm"
              >
                <label
                  class="flex flex-wrap items-center gap-2 text-n-slate-11"
                >
                  {{ $t('SMART_FEATURES.REMINDER.AFTER') }}
                  <select
                    :value="features.repeat_reminder_days"
                    class="!mb-0 !w-auto !py-1 text-sm"
                    @change="
                      save({
                        repeat_reminder_days: Number($event.target.value),
                      })
                    "
                  >
                    <option
                      v-for="days in REMINDER_DAYS"
                      :key="days"
                      :value="days"
                    >
                      {{ $t('SMART_FEATURES.REMINDER.DAYS', { count: days }) }}
                    </option>
                  </select>
                </label>
                <TemplatePicker
                  :inboxes="reminder.inboxes"
                  :templates="reminder.templates"
                  :inbox-id="features.repeat_reminder_inbox_id"
                  :template="features.repeat_reminder_template"
                  :language="features.repeat_reminder_template_language"
                  :empty-text="$t('SMART_FEATURES.REMINDER.NO_TEMPLATES')"
                  :help-text="$t('SMART_FEATURES.REMINDER.TEMPLATE_HELP')"
                  @update="pickTemplate('repeat_reminder', $event)"
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
                v-if="STORE_ITEMS[key] && features[key] && storeData(key)"
                class="grid gap-3 text-sm"
              >
                <ol class="grid gap-2 sm:grid-cols-3 text-xs text-n-slate-12">
                  <li
                    v-for="step in [1, 2, 3]"
                    :key="step"
                    class="flex items-start gap-2 px-3 py-2 rounded-lg bg-n-alpha-1"
                  >
                    <span
                      class="flex items-center justify-center flex-shrink-0 rounded-full size-5 bg-n-brand text-white"
                    >
                      {{ step }}
                    </span>
                    {{
                      $t(`SMART_FEATURES.STORE_HOW.${featureKey(key)}_${step}`)
                    }}
                  </li>
                </ol>
                <TemplatePicker
                  :inboxes="storeData(key).inboxes"
                  :templates="storeData(key).templates"
                  :inbox-id="features[`${STORE_ITEMS[key].prefix}_inbox_id`]"
                  :template="features[`${STORE_ITEMS[key].prefix}_template`]"
                  :language="
                    features[`${STORE_ITEMS[key].prefix}_template_language`]
                  "
                  :empty-text="
                    key === 'cod_confirm'
                      ? $t('SMART_FEATURES.COD.NO_TEMPLATES')
                      : $t('SMART_FEATURES.REMINDER.NO_TEMPLATES')
                  "
                  :help-text="
                    $t(`SMART_FEATURES.STORE_VARIABLES.${featureKey(key)}`)
                  "
                  @update="pickTemplate(STORE_ITEMS[key].prefix, $event)"
                />
                <div
                  v-if="key === 'cod_confirm'"
                  class="flex items-center justify-between gap-4"
                >
                  <span class="text-n-slate-12">
                    {{ $t('SMART_FEATURES.COD.COD_ONLY') }}
                  </span>
                  <Switch
                    :model-value="!!features.cod_only"
                    :aria-label="$t('SMART_FEATURES.COD.COD_ONLY')"
                    @change="save({ cod_only: !features.cod_only })"
                  />
                </div>
                <label
                  v-if="key === 'cart_recovery'"
                  class="flex items-center justify-between gap-4"
                >
                  <span class="text-n-slate-12">
                    {{ $t('SMART_FEATURES.CART.AFTER') }}
                  </span>
                  <select
                    :value="features.cart_delay_hours"
                    class="!mb-0 !w-auto text-sm"
                    @change="
                      save({ cart_delay_hours: Number($event.target.value) })
                    "
                  >
                    <option
                      v-for="hours in CART_DELAY_HOURS"
                      :key="hours"
                      :value="hours"
                    >
                      {{ $t('SMART_FEATURES.HOURS', { count: hours }, hours) }}
                    </option>
                  </select>
                </label>
                <div class="grid gap-1">
                  <span class="text-n-slate-11">
                    {{ $t('SMART_FEATURES.COD.LINK') }}
                  </span>
                  <div class="flex items-center gap-2">
                    <code
                      class="flex-1 min-w-0 px-3 py-2 rounded-lg bg-n-alpha-1 text-xs text-n-slate-12 break-all select-all"
                    >
                      {{ storeData(key).url }}
                    </code>
                    <button
                      class="px-3 py-1.5 rounded-lg text-sm outline outline-1 outline-n-weak text-n-slate-12 hover:outline-n-strong"
                      @click="copyStoreLink(storeData(key).url)"
                    >
                      {{ $t('SMART_FEATURES.COD.COPY') }}
                    </button>
                  </div>
                  <ul
                    class="grid gap-1 ltr:pl-4 rtl:pr-4 list-disc text-xs text-n-slate-11"
                  >
                    <li>
                      {{
                        $t(
                          `SMART_FEATURES.STORE_HELP.${featureKey(key)}_SHOPIFY`
                        )
                      }}
                    </li>
                    <li v-if="key !== 'cart_recovery'">
                      {{
                        $t(`SMART_FEATURES.STORE_HELP.${featureKey(key)}_WOO`)
                      }}
                    </li>
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
