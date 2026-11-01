<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import AppointmentsAPI from 'dashboard/api/appointments';

import BillingCard from '../billing/components/BillingCard.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import ButtonV4 from 'next/button/Button.vue';

const { t } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');

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
const appointments = ref([]);

const timezones = computed(() =>
  TIMEZONES.includes(setting.value?.timezone)
    ? TIMEZONES
    : [setting.value?.timezone, ...TIMEZONES].filter(Boolean)
);

const errorMessage = error =>
  error?.response?.data?.message ||
  error?.response?.data?.error ||
  t('APPOINTMENTS.ERROR');

const loadDays = hours => {
  days.value = Object.fromEntries(
    DAYS.map(day => {
      const [from, to] = hours?.[day]?.[0] || [];
      return [day, { open: !!from, from: from || '10:00', to: to || '18:00' }];
    })
  );
};

const fetchAppointments = async () => {
  const response = await AppointmentsAPI.list();
  appointments.value = response.data.payload;
};

const fetchAll = async () => {
  try {
    const response = await AppointmentsAPI.getSetting();
    setting.value = response.data;
    loadDays(response.data.hours);
    await fetchAppointments();
  } finally {
    isLoading.value = false;
  }
};

const save = async () => {
  isSaving.value = true;
  try {
    const hours = Object.fromEntries(
      DAYS.filter(day => days.value[day].open).map(day => [
        day,
        [[days.value[day].from, days.value[day].to]],
      ])
    );
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
      hours,
    });
    setting.value = response.data;
    loadDays(response.data.hours);
    useAlert(t('APPOINTMENTS.SAVED'));
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isSaving.value = false;
  }
};

const addService = () => {
  setting.value.services.push({ name: '', minutes: '', price: '' });
};

const removeService = index => {
  setting.value.services.splice(index, 1);
};

const copyLink = async () => {
  await navigator.clipboard.writeText(setting.value.booking_page_url);
  useAlert(t('APPOINTMENTS.STATUS.COPIED'));
};

const setStatus = async (appointment, status) => {
  try {
    await AppointmentsAPI.setStatus(appointment.id, status);
    await fetchAppointments();
  } catch (error) {
    useAlert(errorMessage(error));
  }
};

const formatDay = value =>
  new Intl.DateTimeFormat(undefined, {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    timeZone: setting.value.timezone,
  }).format(new Date(value));

const formatTime = value =>
  new Intl.DateTimeFormat(undefined, {
    hour: 'numeric',
    minute: '2-digit',
    timeZone: setting.value.timezone,
  }).format(new Date(value));

const groupedAppointments = computed(() =>
  appointments.value.reduce((groups, appointment) => {
    const day = formatDay(appointment.starts_at);
    (groups[day] ||= []).push(appointment);
    return groups;
  }, {})
);

const chatLink = appointment =>
  frontendURL(
    conversationUrl({
      accountId: accountId.value,
      id: appointment.conversation_id,
    })
  );

const statusClass = status =>
  ({
    booked: 'bg-n-teal-3 text-n-teal-11',
    done: 'bg-n-slate-3 text-n-slate-11',
    cancelled: 'bg-n-ruby-3 text-n-ruby-11',
    no_show: 'bg-n-amber-3 text-n-amber-11',
  })[status];

onMounted(fetchAll);
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
          :title="$t('APPOINTMENTS.STATUS.TITLE')"
          :description="$t('APPOINTMENTS.STATUS.DESCRIPTION')"
        >
          <template #action>
            <ButtonV4 sm solid blue :is-loading="isSaving" @click="save">
              {{ $t('APPOINTMENTS.SAVE') }}
            </ButtonV4>
          </template>
          <div class="px-5 grid gap-3 text-sm text-n-slate-12">
            <label class="flex items-center gap-2">
              <input v-model="setting.enabled" type="checkbox" />
              {{ $t('APPOINTMENTS.STATUS.ENABLED') }}
            </label>
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
                <ButtonV4 xs faded slate @click="copyLink">
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
          <div class="px-5 grid gap-2 text-sm text-n-slate-12">
            <div
              v-for="day in DAYS"
              :key="day"
              class="flex flex-wrap items-center gap-3"
            >
              <label class="flex items-center gap-2 w-32">
                <input v-model="days[day].open" type="checkbox" />
                {{ $t(`APPOINTMENTS.DAYS.D${day}`) }}
              </label>
              <template v-if="days[day].open">
                <input
                  v-model="days[day].from"
                  type="time"
                  class="!w-32 !mb-0"
                />
                <span class="text-n-slate-11">{{ $t('APPOINTMENTS.TO') }}</span>
                <input v-model="days[day].to" type="time" class="!w-32 !mb-0" />
              </template>
              <span v-else class="text-n-slate-11">
                {{ $t('APPOINTMENTS.HOURS.CLOSED') }}
              </span>
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

        <BillingCard
          :title="$t('APPOINTMENTS.LIST.TITLE')"
          :description="$t('APPOINTMENTS.LIST.DESCRIPTION')"
        >
          <div class="px-5 grid gap-4 text-sm">
            <p v-if="!appointments.length" class="text-n-slate-11">
              {{ $t('APPOINTMENTS.LIST.EMPTY') }}
            </p>
            <div
              v-for="(items, day) in groupedAppointments"
              :key="day"
              class="grid gap-2"
            >
              <span class="font-medium text-n-slate-12">{{ day }}</span>
              <div
                v-for="appointment in items"
                :key="appointment.id"
                class="flex flex-wrap items-center gap-3 p-3 rounded-lg border border-n-weak"
              >
                <span class="font-medium text-n-slate-12 w-20">
                  {{ formatTime(appointment.starts_at) }}
                </span>
                <div class="grid flex-1 min-w-40">
                  <span class="text-n-slate-12">
                    {{ appointment.customer_name || '-' }}
                    <span v-if="appointment.service" class="text-n-slate-11">
                      · {{ appointment.service }}
                    </span>
                  </span>
                  <span class="text-xs text-n-slate-11">
                    {{ appointment.customer_phone }}
                  </span>
                </div>
                <span
                  class="px-2 py-0.5 rounded-md text-xs"
                  :class="statusClass(appointment.status)"
                >
                  {{
                    $t(`APPOINTMENTS.STATUSES.${appointment.status.toUpperCase()}`)
                  }}
                </span>
                <div class="flex gap-3 text-xs">
                  <router-link
                    v-if="appointment.conversation_id"
                    :to="chatLink(appointment)"
                    class="text-n-blue-11"
                  >
                    {{ $t('APPOINTMENTS.LIST.OPEN_CHAT') }}
                  </router-link>
                  <template v-if="appointment.status === 'booked'">
                    <button
                      class="text-n-teal-11"
                      @click="setStatus(appointment, 'done')"
                    >
                      {{ $t('APPOINTMENTS.LIST.DONE') }}
                    </button>
                    <button
                      class="text-n-amber-11"
                      @click="setStatus(appointment, 'no_show')"
                    >
                      {{ $t('APPOINTMENTS.LIST.NO_SHOW') }}
                    </button>
                    <button
                      class="text-n-ruby-11"
                      @click="setStatus(appointment, 'cancelled')"
                    >
                      {{ $t('APPOINTMENTS.LIST.CANCEL') }}
                    </button>
                  </template>
                </div>
              </div>
            </div>
          </div>
        </BillingCard>
      </section>
    </template>
  </SettingsLayout>
</template>
