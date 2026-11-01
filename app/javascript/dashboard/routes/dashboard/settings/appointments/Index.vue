<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import AppointmentsAPI from 'dashboard/api/appointments';
import TEMPLATES from './templates';

import BillingCard from '../billing/components/BillingCard.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import ButtonV4 from 'next/button/Button.vue';

const { t } = useI18n();
const store = useStore();
const { accountScopedRoute, accountId } = useAccount();

// Monday first; keys match the server (Sunday = 0).
const DAYS = ['1', '2', '3', '4', '5', '6', '0'];
const SLOT_OPTIONS = [10, 15, 20, 30, 45, 60, 90, 120];
const TIMEZONES = Intl.supportedValuesOf
  ? Intl.supportedValuesOf('timeZone')
  : ['Asia/Karachi'];

const isLoading = ref(true);
const isSaving = ref(false);
const setting = ref(null);
const days = ref({});
const newClosedDate = ref('');

const timezones = computed(() =>
  TIMEZONES.includes(setting.value?.timezone)
    ? TIMEZONES
    : [setting.value?.timezone, ...TIMEZONES].filter(Boolean)
);

const errorMessage = error =>
  error?.response?.data?.message ||
  error?.response?.data?.error ||
  t('APPOINTMENTS.ERROR');

// Server ranges -> one row per day: open time, close time and an optional break.
const loadDays = hours => {
  days.value = Object.fromEntries(
    DAYS.map(day => {
      const ranges = hours?.[day] || [];
      const first = ranges[0] || [];
      const last = ranges[ranges.length - 1] || [];
      return [
        day,
        {
          open: ranges.length > 0,
          from: first[0] || '10:00',
          to: last[1] || '18:00',
          hasBreak: ranges.length > 1,
          breakFrom: ranges.length > 1 ? first[1] : '13:00',
          breakTo: ranges.length > 1 ? last[0] : '14:00',
        },
      ];
    })
  );
};

const hoursFromDays = () =>
  Object.fromEntries(
    DAYS.filter(day => days.value[day].open).map(day => {
      const row = days.value[day];
      return [
        day,
        row.hasBreak
          ? [
              [row.from, row.breakFrom],
              [row.breakTo, row.to],
            ]
          : [[row.from, row.to]],
      ];
    })
  );

const fetchSetting = async () => {
  try {
    const response = await AppointmentsAPI.getSetting();
    setting.value = response.data;
    loadDays(response.data.hours);
  } finally {
    isLoading.value = false;
  }
};

const save = async () => {
  isSaving.value = true;
  try {
    const { enabled, timezone, slot_minutes, capacity } = setting.value;
    const { days_ahead, min_notice_minutes, notes, services } = setting.value;
    const response = await AppointmentsAPI.updateSetting({
      enabled,
      timezone,
      slot_minutes,
      capacity,
      days_ahead,
      min_notice_minutes,
      notes,
      services: services.filter(service => service.name),
      closed_dates: setting.value.closed_dates,
      hours: hoursFromDays(),
    });
    setting.value = response.data;
    loadDays(response.data.hours);
    // The main menu shows the calendar only when appointments are on.
    store.dispatch('accounts/get');
    useAlert(t('APPOINTMENTS.SAVED'));
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isSaving.value = false;
  }
};

const applyTemplate = template => {
  const { hours, ...rest } = template.setting;
  setting.value = {
    ...setting.value,
    ...rest,
    services: rest.services.map(service => ({ ...service })),
  };
  loadDays(hours);
  useAlert(t('APPOINTMENTS.TEMPLATES.APPLIED'));
};

const addService = () => {
  setting.value.services.push({ name: '', minutes: '', price: '' });
};

const removeService = index => {
  setting.value.services.splice(index, 1);
};

const addClosedDate = () => {
  if (!newClosedDate.value) return;
  setting.value.closed_dates = [
    ...new Set([...setting.value.closed_dates, newClosedDate.value]),
  ].sort();
  newClosedDate.value = '';
};

const removeClosedDate = value => {
  setting.value.closed_dates = setting.value.closed_dates.filter(
    date => date !== value
  );
};

const formatDate = value =>
  new Intl.DateTimeFormat(undefined, {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(new Date(`${value}T12:00:00Z`));

const copy = async (text, message) => {
  await navigator.clipboard.writeText(text);
  useAlert(message);
};

const calendarRoute = computed(() =>
  accountScopedRoute('appointments_calendar', { accountId: accountId.value })
);

onMounted(fetchSetting);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('APPOINTMENTS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('APPOINTMENTS.TITLE')"
        :description="$t('APPOINTMENTS.DESCRIPTION')"
      />
    </template>
    <template #body>
      <section v-if="setting" class="grid gap-4">
        <div
          v-if="!setting.feature_available"
          class="px-4 py-3 rounded-lg bg-n-amber-3 text-n-amber-11 text-sm"
        >
          {{ $t('APPOINTMENTS.NOT_IN_PLAN') }}
        </div>

        <BillingCard
          :title="$t('APPOINTMENTS.TEMPLATES.TITLE')"
          :description="$t('APPOINTMENTS.TEMPLATES.DESCRIPTION')"
        >
          <div class="px-5 grid grid-cols-2 sm:grid-cols-5 gap-2 text-sm">
            <button
              v-for="template in TEMPLATES"
              :key="template.key"
              class="flex flex-col items-center gap-2 p-3 rounded-lg border border-n-weak hover:bg-n-alpha-1 text-n-slate-12"
              @click="applyTemplate(template)"
            >
              <span class="size-5 text-n-blue-11" :class="template.icon" />
              {{ $t(`APPOINTMENTS.TEMPLATES.${template.key}`) }}
            </button>
          </div>
        </BillingCard>

        <BillingCard
          :title="$t('APPOINTMENTS.STATUS.TITLE')"
          :description="$t('APPOINTMENTS.STATUS.DESCRIPTION')"
        >
          <template #action>
            <ButtonV4 sm solid blue :is-loading="isSaving" @click="save">
              {{ $t('APPOINTMENTS.SAVE') }}
            </ButtonV4>
          </template>
          <div class="px-5 grid gap-4 text-sm text-n-slate-12">
            <label class="flex items-center gap-2">
              <input v-model="setting.enabled" type="checkbox" />
              {{ $t('APPOINTMENTS.STATUS.ENABLED') }}
            </label>
            <router-link
              :to="calendarRoute"
              class="flex items-center gap-2 text-n-blue-11 w-fit"
            >
              <span class="i-lucide-calendar-days size-4" />
              {{ $t('APPOINTMENTS.STATUS.OPEN_CALENDAR') }}
            </router-link>
            <div class="grid gap-1">
              <span class="font-medium">
                {{ $t('APPOINTMENTS.STATUS.PAGE') }}
              </span>
              <span class="text-xs text-n-slate-11">
                {{ $t('APPOINTMENTS.STATUS.PAGE_NOTE') }}
              </span>
              <div class="flex items-center gap-2">
                <a
                  :href="setting.booking_page_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-n-blue-11 break-all"
                >
                  {{ setting.booking_page_url }}
                </a>
                <ButtonV4
                  xs
                  faded
                  slate
                  @click="
                    copy(
                      setting.booking_page_url,
                      $t('APPOINTMENTS.STATUS.COPIED')
                    )
                  "
                >
                  {{ $t('APPOINTMENTS.STATUS.COPY') }}
                </ButtonV4>
              </div>
            </div>
            <div class="grid gap-1">
              <span class="font-medium">
                {{ $t('APPOINTMENTS.STATUS.GOOGLE') }}
              </span>
              <span class="text-xs text-n-slate-11">
                {{ $t('APPOINTMENTS.STATUS.GOOGLE_NOTE') }}
              </span>
              <div class="flex items-center gap-2">
                <code class="text-xs text-n-slate-11 break-all">
                  {{ setting.calendar_feed_url }}
                </code>
                <ButtonV4
                  xs
                  faded
                  slate
                  @click="
                    copy(
                      setting.calendar_feed_url,
                      $t('APPOINTMENTS.STATUS.COPIED')
                    )
                  "
                >
                  {{ $t('APPOINTMENTS.STATUS.COPY') }}
                </ButtonV4>
              </div>
            </div>
          </div>
        </BillingCard>

        <BillingCard
          :title="$t('APPOINTMENTS.HOURS.TITLE')"
          :description="$t('APPOINTMENTS.HOURS.DESCRIPTION')"
        >
          <template #action>
            <ButtonV4 sm solid blue :is-loading="isSaving" @click="save">
              {{ $t('APPOINTMENTS.SAVE') }}
            </ButtonV4>
          </template>
          <div class="px-5 grid gap-3 text-sm text-n-slate-12">
            <div
              v-for="day in DAYS"
              :key="day"
              class="flex flex-wrap items-center gap-x-3 gap-y-2"
            >
              <label class="flex items-center gap-2 w-28">
                <input v-model="days[day].open" type="checkbox" />
                {{ $t(`APPOINTMENTS.DAYS.D${day}`) }}
              </label>
              <template v-if="days[day].open">
                <input
                  v-model="days[day].from"
                  type="time"
                  class="!w-28 !mb-0"
                />
                <span class="text-n-slate-11">{{ $t('APPOINTMENTS.TO') }}</span>
                <input v-model="days[day].to" type="time" class="!w-28 !mb-0" />
                <label class="flex items-center gap-2 text-n-slate-11">
                  <input v-model="days[day].hasBreak" type="checkbox" />
                  {{ $t('APPOINTMENTS.HOURS.BREAK') }}
                </label>
                <template v-if="days[day].hasBreak">
                  <input
                    v-model="days[day].breakFrom"
                    type="time"
                    class="!w-28 !mb-0"
                  />
                  <span class="text-n-slate-11">
                    {{ $t('APPOINTMENTS.TO') }}
                  </span>
                  <input
                    v-model="days[day].breakTo"
                    type="time"
                    class="!w-28 !mb-0"
                  />
                </template>
              </template>
              <span v-else class="text-n-slate-11">
                {{ $t('APPOINTMENTS.HOURS.CLOSED') }}
              </span>
            </div>

            <div class="grid gap-2 pt-3 border-t border-n-weak">
              <span class="font-medium">
                {{ $t('APPOINTMENTS.HOURS.DAYS_OFF') }}
              </span>
              <span class="text-xs text-n-slate-11">
                {{ $t('APPOINTMENTS.HOURS.DAYS_OFF_NOTE') }}
              </span>
              <div class="flex items-center gap-2">
                <input
                  v-model="newClosedDate"
                  type="date"
                  class="!w-44 !mb-0"
                />
                <ButtonV4 sm faded slate @click="addClosedDate">
                  {{ $t('APPOINTMENTS.HOURS.ADD_DAY_OFF') }}
                </ButtonV4>
              </div>
              <div class="flex flex-wrap gap-2">
                <span
                  v-for="value in setting.closed_dates"
                  :key="value"
                  class="flex items-center gap-1 px-2 py-1 rounded-md bg-n-alpha-2 text-xs"
                >
                  {{ formatDate(value) }}
                  <button
                    class="i-lucide-x size-3 text-n-slate-11"
                    :aria-label="$t('APPOINTMENTS.DELETE')"
                    @click="removeClosedDate(value)"
                  />
                </span>
              </div>
            </div>
          </div>
        </BillingCard>

        <BillingCard
          :title="$t('APPOINTMENTS.RULES.TITLE')"
          :description="$t('APPOINTMENTS.RULES.DESCRIPTION')"
        >
          <template #action>
            <ButtonV4 sm solid blue :is-loading="isSaving" @click="save">
              {{ $t('APPOINTMENTS.SAVE') }}
            </ButtonV4>
          </template>
          <div class="px-5 grid sm:grid-cols-2 gap-3 text-sm">
            <label class="grid gap-1">
              {{ $t('APPOINTMENTS.RULES.SLOT') }}
              <select v-model.number="setting.slot_minutes" class="w-full">
                <option
                  v-for="minutes in SLOT_OPTIONS"
                  :key="minutes"
                  :value="minutes"
                >
                  {{ $t('APPOINTMENTS.MINUTES', { count: minutes }) }}
                </option>
              </select>
            </label>
            <label class="grid gap-1">
              {{ $t('APPOINTMENTS.RULES.CAPACITY') }}
              <input
                v-model.number="setting.capacity"
                type="number"
                min="1"
                max="100"
                class="w-full"
              />
            </label>
            <label class="grid gap-1">
              {{ $t('APPOINTMENTS.RULES.DAYS_AHEAD') }}
              <input
                v-model.number="setting.days_ahead"
                type="number"
                min="1"
                max="90"
                class="w-full"
              />
            </label>
            <label class="grid gap-1">
              {{ $t('APPOINTMENTS.RULES.NOTICE') }}
              <input
                v-model.number="setting.min_notice_minutes"
                type="number"
                min="0"
                step="15"
                class="w-full"
              />
            </label>
            <label class="grid gap-1 sm:col-span-2">
              {{ $t('APPOINTMENTS.RULES.TIMEZONE') }}
              <select v-model="setting.timezone" class="w-full">
                <option v-for="zone in timezones" :key="zone" :value="zone">
                  {{ zone }}
                </option>
              </select>
            </label>
          </div>
        </BillingCard>

        <BillingCard
          :title="$t('APPOINTMENTS.SERVICES.TITLE')"
          :description="$t('APPOINTMENTS.SERVICES.DESCRIPTION')"
        >
          <template #action>
            <ButtonV4 sm solid blue :is-loading="isSaving" @click="save">
              {{ $t('APPOINTMENTS.SAVE') }}
            </ButtonV4>
          </template>
          <div class="px-5 grid gap-2 text-sm">
            <div
              v-for="(service, index) in setting.services"
              :key="index"
              class="grid grid-cols-[1fr_6rem_6rem_auto] gap-2 items-center"
            >
              <input
                v-model="service.name"
                type="text"
                maxlength="80"
                class="!mb-0"
                :placeholder="$t('APPOINTMENTS.SERVICES.NAME')"
              />
              <input
                v-model.number="service.minutes"
                type="number"
                min="0"
                class="!mb-0"
                :placeholder="$t('APPOINTMENTS.SERVICES.MINUTES')"
              />
              <input
                v-model="service.price"
                type="text"
                maxlength="30"
                class="!mb-0"
                :placeholder="$t('APPOINTMENTS.SERVICES.PRICE')"
              />
              <button class="text-n-ruby-11" @click="removeService(index)">
                {{ $t('APPOINTMENTS.DELETE') }}
              </button>
            </div>
            <ButtonV4 sm faded slate class="w-fit" @click="addService">
              {{ $t('APPOINTMENTS.SERVICES.ADD') }}
            </ButtonV4>
            <label class="grid gap-1 mt-2">
              {{ $t('APPOINTMENTS.NOTES') }}
              <textarea
                v-model="setting.notes"
                rows="2"
                maxlength="1000"
                class="w-full"
                :placeholder="$t('APPOINTMENTS.NOTES_PLACEHOLDER')"
              />
            </label>
          </div>
        </BillingCard>
      </section>
    </template>
  </SettingsLayout>
</template>
