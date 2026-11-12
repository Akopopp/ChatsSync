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
import HelpTip from 'dashboard/components-next/helpTip/HelpTip.vue';

// The Online store page shows only the store group; Smart features shows the rest.
const props = defineProps({
  store: { type: Boolean, default: false },
});

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
const codTexts = ref({ cod_confirmed_text: '', cod_cancelled_text: '' });
const sheetUrl = ref('');
const sheetScript = ref('');
const appLink = ref('');

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
  {
    key: 'APPS',
    icon: 'i-lucide-plug',
    items: ['app_webhook'],
  },
];
// Example other apps send to the link (shown on the card).
const APP_EXAMPLE = JSON.stringify(
  {
    phone: '923001234567',
    name: 'Ali',
    template: 'order_update',
    values: ['Ali', '#1024'],
    label: 'from-website',
  },
  null,
  2
);
// Features that have their own page: the card shows a button to it.
const PAGES = { broadcast_tools: 'campaigns_whatsapp_index' };
const FOLLOW_UP_HOURS = [1, 2, 3, 4, 6, 8, 12, 20];
const META_SALES_WHEN = ['new', 'confirmed', 'delivered'];
const REMINDER_DAYS = [7, 14, 21, 30, 45, 60, 90, 180];
const CART_DELAY_HOURS = [1, 2, 3, 6, 12, 24];
const COD_REMINDER_HOURS = [2, 6, 12, 24];
const COD_TEXTS = ['cod_confirmed_text', 'cod_cancelled_text'];
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
// What the "?" shows: what the feature does, then how to use it.
const helpText = key =>
  `${t(`SMART_FEATURES.ITEMS.${featureKey(key)}.HINT`)}\n\n${t('SMART_FEATURES.HOW_TO', { how: t(`SMART_FEATURES.ITEMS.${featureKey(key)}.HOW`) })}`;
const visibleGroups = computed(() =>
  GROUPS.filter(group => (group.key === 'STORE') === props.store)
);
// Filter chips on top of the cards: All, or one group.
const activeGroup = ref('ALL');
const shownGroups = computed(() =>
  visibleGroups.value.filter(
    group => activeGroup.value === 'ALL' || group.key === activeGroup.value
  )
);
const ICONS = {
  typing_indicator: 'i-lucide-message-circle-more',
  returning_customers: 'i-lucide-user-check',
  payment_check: 'i-lucide-receipt',
  photo_search: 'i-lucide-scan-search',
  follow_up: 'i-lucide-bell-ring',
  review_request: 'i-lucide-star',
  repeat_reminder: 'i-lucide-repeat',
  broadcast_tools: 'i-lucide-megaphone',
  whatsapp_forms: 'i-lucide-clipboard-list',
  cod_confirm: 'i-lucide-badge-check',
  ship_updates: 'i-lucide-truck',
  cart_recovery: 'i-lucide-shopping-cart',
  ad_report: 'i-lucide-chart-column',
  meta_sales: 'i-lucide-target',
  daily_report: 'i-lucide-mail',
  email_alerts: 'i-lucide-bell',
  google_sheet: 'i-lucide-sheet',
  health_guard: 'i-lucide-shield-check',
  stop_opt_out: 'i-lucide-ban',
  app_webhook: 'i-lucide-webhook',
};
// Features with settings: when on, their card takes the whole row so the settings have room.
const WITH_OPTIONS = [
  'follow_up',
  'email_alerts',
  'google_sheet',
  'review_request',
  'whatsapp_forms',
  'meta_sales',
  'cod_confirm',
  'ship_updates',
  'cart_recovery',
  'ad_report',
  'health_guard',
  'app_webhook',
];
const wide = key => features.value[key] && WITH_OPTIONS.includes(key);
const page = computed(() => (props.store ? 'STORE_PAGE' : 'PAGE'));
const onCount = computed(
  () =>
    visibleGroups.value
      .flatMap(group => group.items)
      .filter(key => features.value[key]).length
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
  codTexts.value = {
    cod_confirmed_text: data.features.cod_confirmed_text || '',
    cod_cancelled_text: data.features.cod_cancelled_text || '',
  };
  sheetUrl.value = data.features.sheet_url || '';
  sheetScript.value = data.sheet_script || '';
  appLink.value = data.app_link || '';
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

const saveCodText = key => {
  const text = codTexts.value[key].trim();
  if (text !== (features.value[key] || '')) save({ [key]: text });
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
        :title="$t(`SMART_FEATURES.${page}.TITLE`)"
        :description="$t(`SMART_FEATURES.${page}.DESCRIPTION`)"
        :help="$t(`SMART_FEATURES.${page}.HELP`)"
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

        <ol v-if="store" class="grid gap-3 p-0 m-0 list-none sm:grid-cols-3">
          <li
            v-for="step in 3"
            :key="step"
            class="flex gap-3 p-4 rounded-2xl outline outline-1 outline-n-weak bg-n-solid-1"
          >
            <span
              class="flex items-center justify-center text-sm font-semibold rounded-full size-7 shrink-0 bg-n-teal-3 text-n-teal-11"
            >
              {{ step }}
            </span>
            <span class="text-sm text-n-slate-11">
              {{ $t(`SMART_FEATURES.STORE_PAGE.STEP_${step}`) }}
            </span>
          </li>
        </ol>
        <router-link
          v-else
          :to="{ name: 'online_store_settings' }"
          class="flex items-center gap-3 px-5 py-4 rounded-2xl outline outline-1 outline-n-weak bg-n-solid-1 hover:bg-n-alpha-1"
        >
          <span class="i-lucide-store size-5 text-n-teal-11 shrink-0" />
          <span class="grid flex-1 min-w-0 gap-0.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ $t('SMART_FEATURES.STORE_PAGE.TITLE') }}
            </span>
            <span class="text-sm text-n-slate-11">
              {{ $t('SMART_FEATURES.STORE_PAGE.LINK') }}
            </span>
          </span>
          <span class="i-lucide-chevron-right size-4 text-n-slate-11" />
        </router-link>

        <div
          v-if="visibleGroups.length > 1"
          class="flex gap-2 pb-1 -mx-1 px-1 overflow-x-auto"
          role="tablist"
        >
          <button
            v-for="chip in ['ALL', ...visibleGroups.map(group => group.key)]"
            :key="chip"
            type="button"
            role="tab"
            :aria-selected="activeGroup === chip"
            class="px-4 py-2 text-sm font-medium border rounded-full shrink-0 whitespace-nowrap"
            :class="
              activeGroup === chip
                ? 'bg-n-slate-12 border-n-slate-12 text-n-solid-1'
                : 'bg-n-solid-1 border-n-weak text-n-slate-12 hover:bg-n-alpha-1'
            "
            @click="activeGroup = chip"
          >
            {{
              chip === 'ALL'
                ? $t('SMART_FEATURES.ALL')
                : $t(`SMART_FEATURES.GROUPS.${chip}`)
            }}
          </button>
        </div>

        <div v-for="group in shownGroups" :key="group.key" class="grid gap-3">
          <div class="grid gap-0.5">
            <h3
              class="flex items-center gap-2 m-0 text-base font-semibold text-n-slate-12"
            >
              <span :class="group.icon" class="size-4 text-n-slate-11" />
              {{ $t(`SMART_FEATURES.GROUPS.${group.key}`) }}
            </h3>
            <p class="m-0 text-sm text-n-slate-11">
              {{ $t(`SMART_FEATURES.GROUP_TEXT.${group.key}`) }}
            </p>
          </div>

          <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
            <div
              v-for="key in group.items"
              :key="key"
              class="flex flex-col gap-3 p-4 rounded-2xl outline outline-1 bg-n-solid-1"
              :class="[
                features[key] ? 'outline-n-teal-6' : 'outline-n-weak',
                wide(key) ? 'sm:col-span-2 xl:col-span-3' : '',
              ]"
            >
              <div class="flex items-start gap-3">
                <span
                  class="flex items-center justify-center rounded-xl size-10 shrink-0 bg-n-brand/10 text-n-brand"
                >
                  <span :class="ICONS[key]" class="size-5" />
                </span>
                <div class="grid flex-1 min-w-0 gap-1">
                  <span
                    class="flex items-center gap-1.5 text-sm font-semibold text-n-slate-12"
                  >
                    {{ $t(`SMART_FEATURES.ITEMS.${featureKey(key)}.TITLE`) }}
                    <HelpTip :text="helpText(key)" />
                  </span>
                  <span class="text-sm text-n-slate-11">
                    {{ $t(`SMART_FEATURES.ITEMS.${featureKey(key)}.SHORT`) }}
                  </span>
                </div>
              </div>
              <div class="flex items-center justify-between gap-3 mt-auto">
                <span
                  class="px-2.5 py-1 text-xs font-semibold rounded-full"
                  :class="
                    features[key]
                      ? 'bg-n-teal-3 text-n-teal-11'
                      : 'bg-n-alpha-2 text-n-slate-11'
                  "
                >
                  {{
                    features[key]
                      ? $t('SMART_FEATURES.STATUS_ON')
                      : $t('SMART_FEATURES.STATUS_OFF')
                  }}
                </span>
                <span class="flex items-center gap-3">
                  <router-link
                    v-if="PAGES[key] && features[key]"
                    :to="{ name: PAGES[key] }"
                    class="text-sm font-medium text-n-brand"
                  >
                    {{ $t('SMART_FEATURES.OPEN_PAGE') }}
                  </router-link>
                  <Switch
                    :model-value="!!features[key]"
                    :aria-label="
                      $t(`SMART_FEATURES.ITEMS.${featureKey(key)}.TITLE`)
                    "
                    @change="toggle(key)"
                  />
                </span>
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
                    'sheet_ai',
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
                <template v-if="key === 'cod_confirm'">
                  <div class="flex items-center justify-between gap-4">
                    <span class="text-n-slate-12">
                      {{ $t('SMART_FEATURES.COD.REMINDER') }}
                    </span>
                    <Switch
                      :model-value="!!features.cod_reminder"
                      :aria-label="$t('SMART_FEATURES.COD.REMINDER')"
                      @change="save({ cod_reminder: !features.cod_reminder })"
                    />
                  </div>
                  <label
                    v-if="features.cod_reminder"
                    class="flex items-center justify-between gap-4"
                  >
                    <span class="text-n-slate-11">
                      {{ $t('SMART_FEATURES.COD.REMINDER_AFTER') }}
                    </span>
                    <select
                      :value="features.cod_reminder_hours"
                      class="!mb-0 !w-auto text-sm"
                      @change="
                        save({
                          cod_reminder_hours: Number($event.target.value),
                        })
                      "
                    >
                      <option
                        v-for="hours in COD_REMINDER_HOURS"
                        :key="hours"
                        :value="hours"
                      >
                        {{
                          $t('SMART_FEATURES.HOURS', { count: hours }, hours)
                        }}
                      </option>
                    </select>
                  </label>
                  <label
                    v-for="textKey in COD_TEXTS"
                    :key="textKey"
                    class="grid gap-1"
                  >
                    <span class="text-n-slate-12">
                      {{ $t(`SMART_FEATURES.COD.${featureKey(textKey)}`) }}
                    </span>
                    <textarea
                      v-model="codTexts[textKey]"
                      rows="2"
                      maxlength="500"
                      class="!mb-0 text-sm"
                      :placeholder="
                        $t(
                          `SMART_FEATURES.COD.${featureKey(textKey)}_PLACEHOLDER`
                        )
                      "
                      @blur="saveCodText(textKey)"
                    />
                  </label>
                  <span class="text-xs text-n-slate-11">
                    {{ $t('SMART_FEATURES.COD.TEXT_HELP') }}
                  </span>
                </template>
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
                v-if="key === 'app_webhook' && features.app_webhook"
                class="grid gap-3 text-sm"
              >
                <label class="grid gap-1">
                  <span class="font-medium text-n-slate-12">
                    {{ $t('SMART_FEATURES.APP_WEBHOOK.NUMBER') }}
                  </span>
                  <select
                    :value="features.app_webhook_inbox_id"
                    class="!mb-0 text-sm"
                    @change="
                      save({
                        app_webhook_inbox_id: Number($event.target.value),
                      })
                    "
                  >
                    <option :value="0">
                      {{ $t('SMART_FEATURES.APP_WEBHOOK.PICK') }}
                    </option>
                    <option
                      v-for="number in numbers"
                      :key="number.inbox_id"
                      :value="number.inbox_id"
                    >
                      {{ number.phone || number.inbox_name }}
                    </option>
                  </select>
                </label>
                <div v-if="appLink" class="grid gap-1">
                  <span class="font-medium text-n-slate-12">
                    {{ $t('SMART_FEATURES.APP_WEBHOOK.LINK') }}
                  </span>
                  <div class="flex items-center gap-2">
                    <code
                      class="flex-1 min-w-0 px-3 py-2 overflow-x-auto text-xs rounded-lg bg-n-alpha-1 whitespace-nowrap"
                    >
                      {{ appLink }}
                    </code>
                    <button
                      class="px-3 py-1.5 rounded-lg text-sm outline outline-1 outline-n-weak text-n-slate-12 hover:outline-n-strong"
                      @click="copyStoreLink(appLink)"
                    >
                      {{ $t('SMART_FEATURES.COD.COPY') }}
                    </button>
                  </div>
                  <span class="text-xs text-n-slate-11">
                    {{ $t('SMART_FEATURES.APP_WEBHOOK.PRIVATE') }}
                  </span>
                </div>
                <div class="grid gap-1">
                  <span class="font-medium text-n-slate-12">
                    {{ $t('SMART_FEATURES.APP_WEBHOOK.EXAMPLE') }}
                  </span>
                  <pre
                    class="px-3 py-2 m-0 overflow-x-auto text-xs rounded-lg bg-n-alpha-1"
                    >{{ APP_EXAMPLE }}</pre
                  >
                  <span class="text-xs text-n-slate-11">
                    {{ $t('SMART_FEATURES.APP_WEBHOOK.EXAMPLE_NOTE') }}
                  </span>
                </div>
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
