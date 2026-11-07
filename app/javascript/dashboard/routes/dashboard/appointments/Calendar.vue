<script setup>
import { computed, onMounted, ref } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import { downloadCsvFile } from 'dashboard/helper/downloadHelper';
import AppointmentsAPI from 'dashboard/api/appointments';
import ExportsAPI from 'dashboard/api/exports';
import ButtonV4 from 'next/button/Button.vue';
import AppointmentModal from './AppointmentModal.vue';

const { isAdmin } = useAdmin();
const accountId = useMapGetter('getCurrentAccountId');
const isDownloading = ref(false);

const downloadCsv = async () => {
  isDownloading.value = true;
  try {
    const { data } = await ExportsAPI.csv('appointments');
    downloadCsvFile(
      `appointments-${new Date().toISOString().slice(0, 10)}.csv`,
      data
    );
  } finally {
    isDownloading.value = false;
  }
};

// Phones show one day at a time; a week of narrow columns does not fit.
const view = ref(
  window.matchMedia('(max-width: 640px)').matches ? 'day' : 'week'
);
const timezone = ref('Asia/Karachi');
const services = ref([]);
const appointments = ref([]);
const isLoading = ref(true);
const modal = ref(null);

// Dates are YYYY-MM-DD strings in the business's time zone; UTC math keeps them from shifting.
const toUTC = value => new Date(`${value}T12:00:00Z`);
const iso = date => date.toISOString().slice(0, 10);
const addDays = (value, count) => {
  const date = toUTC(value);
  date.setUTCDate(date.getUTCDate() + count);
  return iso(date);
};
const zoneParts = value =>
  Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone.value,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    })
      .formatToParts(new Date(value))
      .map(part => [part.type, part.value])
  );
const localDate = value => {
  const parts = zoneParts(value);
  return `${parts.year}-${parts.month}-${parts.day}`;
};
const localHour = value => Number(zoneParts(value).hour);

const today = ref(localDate(Date.now()));
const anchor = ref(today.value);

const weekStart = computed(() => {
  const day = (toUTC(anchor.value).getUTCDay() + 6) % 7;
  return addDays(anchor.value, -day);
});

const shownDays = computed(() =>
  view.value === 'week'
    ? Array.from({ length: 7 }, (_, index) => addDays(weekStart.value, index))
    : [anchor.value]
);

const dayLabel = (value, options) =>
  new Intl.DateTimeFormat(undefined, { ...options, timeZone: 'UTC' }).format(
    toUTC(value)
  );

const rangeTitle = computed(() => {
  const days = shownDays.value;
  if (days.length === 1)
    return dayLabel(days[0], {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });
  return `${dayLabel(days[0], { day: 'numeric', month: 'short' })} – ${dayLabel(
    days[6],
    { day: 'numeric', month: 'short', year: 'numeric' }
  )}`;
});

const fetchAppointments = async () => {
  isLoading.value = true;
  try {
    const days = shownDays.value;
    const response = await AppointmentsAPI.list({
      from: days[0],
      to: days[days.length - 1],
    });
    appointments.value = response.data.payload;
    timezone.value = response.data.timezone;
    services.value = response.data.services;
    today.value = localDate(Date.now());
  } finally {
    isLoading.value = false;
  }
};

const byDay = computed(() =>
  appointments.value.reduce((groups, appointment) => {
    (groups[localDate(appointment.starts_at)] ||= []).push(appointment);
    return groups;
  }, {})
);

// Day view: one row per hour, from the earliest to the latest booking (at least 9 am to 8 pm).
const hours = computed(() => {
  const list = byDay.value[anchor.value] || [];
  const starts = list.map(item => localHour(item.starts_at));
  const first = Math.min(9, ...starts);
  const last = Math.max(20, ...starts);
  return Array.from({ length: last - first + 1 }, (_, index) => first + index);
});

const atHour = hour =>
  (byDay.value[anchor.value] || []).filter(
    item => localHour(item.starts_at) === hour
  );

const formatTime = value =>
  new Intl.DateTimeFormat(undefined, {
    hour: 'numeric',
    minute: '2-digit',
    timeZone: timezone.value,
  }).format(new Date(value));

const formatHour = hour => `${hour % 12 || 12} ${hour < 12 ? 'AM' : 'PM'}`;

const STATUS_CLASS = {
  booked: 'border-l-n-blue-9 bg-n-blue-2',
  done: 'border-l-n-teal-9 bg-n-teal-2',
  no_show: 'border-l-n-amber-9 bg-n-amber-2',
  cancelled: 'border-l-n-ruby-9 bg-n-ruby-2 opacity-60 line-through',
};

const move = step => {
  anchor.value = addDays(anchor.value, step * (view.value === 'week' ? 7 : 1));
  fetchAppointments();
};

const goToday = () => {
  anchor.value = localDate(Date.now());
  fetchAppointments();
};

const setView = value => {
  view.value = value;
  fetchAppointments();
};

const openDay = value => {
  anchor.value = value;
  setView('day');
};

const chatLink = appointment =>
  frontendURL(
    conversationUrl({
      accountId: accountId.value,
      id: appointment.conversation_id,
    })
  );

const onSaved = () => {
  modal.value = null;
  fetchAppointments();
};

const bookedCount = computed(
  () => appointments.value.filter(item => item.status === 'booked').length
);

onMounted(fetchAppointments);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden bg-n-background">
    <header
      class="flex flex-wrap items-center gap-3 px-6 py-4 border-b border-n-weak"
    >
      <div class="grid">
        <h1 class="text-lg font-semibold text-n-slate-12">
          {{ $t('APPOINTMENTS.CALENDAR.TITLE') }}
        </h1>
        <span class="text-xs text-n-slate-11">
          {{ $t('APPOINTMENTS.CALENDAR.COUNT', { count: bookedCount }) }}
        </span>
      </div>
      <div class="flex items-center gap-1 ml-auto">
        <ButtonV4 sm faded slate @click="goToday">
          {{ $t('APPOINTMENTS.CALENDAR.TODAY') }}
        </ButtonV4>
        <button
          class="size-8 grid place-items-center rounded-lg hover:bg-n-alpha-2 text-n-slate-11"
          :aria-label="$t('APPOINTMENTS.CALENDAR.PREVIOUS')"
          @click="move(-1)"
        >
          <span class="i-lucide-chevron-left size-5" />
        </button>
        <button
          class="size-8 grid place-items-center rounded-lg hover:bg-n-alpha-2 text-n-slate-11"
          :aria-label="$t('APPOINTMENTS.CALENDAR.NEXT')"
          @click="move(1)"
        >
          <span class="i-lucide-chevron-right size-5" />
        </button>
        <span class="text-sm font-medium text-n-slate-12 min-w-44 text-center">
          {{ rangeTitle }}
        </span>
      </div>
      <div class="flex rounded-lg border border-n-weak overflow-hidden text-sm">
        <button
          v-for="option in ['day', 'week']"
          :key="option"
          class="px-3 py-1.5"
          :class="
            view === option
              ? 'bg-n-brand text-white'
              : 'text-n-slate-11 hover:bg-n-alpha-1'
          "
          @click="setView(option)"
        >
          {{ $t(`APPOINTMENTS.CALENDAR.${option.toUpperCase()}`) }}
        </button>
      </div>
      <ButtonV4
        v-if="isAdmin"
        sm
        faded
        slate
        icon="i-lucide-download"
        :is-loading="isDownloading"
        @click="downloadCsv"
      >
        {{ $t('APPOINTMENTS.CALENDAR.DOWNLOAD') }}
      </ButtonV4>
      <ButtonV4
        sm
        solid
        blue
        icon="i-lucide-plus"
        @click="modal = { prefill: { date: anchor } }"
      >
        {{ $t('APPOINTMENTS.CALENDAR.NEW') }}
      </ButtonV4>
    </header>

    <div class="flex-1 overflow-auto p-6">
      <div
        v-if="view === 'week'"
        class="grid grid-cols-7 gap-2 min-w-[56rem] h-full"
      >
        <div
          v-for="day in shownDays"
          :key="day"
          class="flex flex-col rounded-xl border border-n-weak bg-n-solid-1 min-h-80"
          :class="{ 'ring-2 ring-n-brand': day === today }"
        >
          <button
            class="px-3 py-2 border-b border-n-weak text-left hover:bg-n-alpha-1 rounded-t-xl"
            @click="openDay(day)"
          >
            <span class="block text-xs text-n-slate-11">
              {{ dayLabel(day, { weekday: 'short' }) }}
            </span>
            <span class="text-lg font-semibold text-n-slate-12">
              {{ dayLabel(day, { day: 'numeric' }) }}
            </span>
          </button>
          <div class="flex flex-col gap-1.5 p-2">
            <button
              v-for="item in byDay[day] || []"
              :key="item.id"
              class="text-left px-2 py-1.5 rounded-md border-l-4 text-xs text-n-slate-12"
              :class="STATUS_CLASS[item.status]"
              @click="modal = { appointment: item }"
            >
              <span class="block font-semibold">
                {{ formatTime(item.starts_at) }}
              </span>
              <span class="block truncate">{{
                item.customer_name || '-'
              }}</span>
              <span v-if="item.service" class="block truncate text-n-slate-11">
                {{ item.service }}
              </span>
            </button>
            <button
              class="text-xs text-n-slate-10 hover:text-n-blue-11 py-1"
              @click="modal = { prefill: { date: day } }"
            >
              {{ $t('APPOINTMENTS.CALENDAR.ADD') }}
            </button>
          </div>
        </div>
      </div>

      <div
        v-else
        class="rounded-xl border border-n-weak bg-n-solid-1 divide-y divide-n-weak max-w-3xl"
      >
        <div
          v-for="hour in hours"
          :key="hour"
          class="grid grid-cols-[5rem_1fr] min-h-14"
        >
          <span class="px-3 py-2 text-xs text-n-slate-11">
            {{ formatHour(hour) }}
          </span>
          <div class="flex flex-wrap gap-2 p-2">
            <div
              v-for="item in atHour(hour)"
              :key="item.id"
              class="flex flex-wrap items-center gap-x-3 gap-y-1 px-3 py-2 rounded-md border-l-4 text-sm text-n-slate-12 flex-1 min-w-60"
              :class="STATUS_CLASS[item.status]"
            >
              <button
                class="text-left grid"
                @click="modal = { appointment: item }"
              >
                <span class="font-semibold">
                  {{ formatTime(item.starts_at) }} –
                  {{ item.customer_name || '-' }}
                </span>
                <span class="text-xs text-n-slate-11">
                  {{
                    [item.service, item.customer_phone]
                      .filter(Boolean)
                      .join(' · ')
                  }}
                </span>
              </button>
              <span class="text-xs text-n-slate-11 ml-auto">
                {{ $t(`APPOINTMENTS.STATUSES.${item.status.toUpperCase()}`) }}
              </span>
              <router-link
                v-if="item.conversation_id"
                :to="chatLink(item)"
                class="text-xs text-n-blue-11"
              >
                {{ $t('APPOINTMENTS.LIST.OPEN_CHAT') }}
              </router-link>
            </div>
          </div>
        </div>
      </div>

      <p
        v-if="!isLoading && !appointments.length"
        class="mt-4 text-sm text-n-slate-11"
      >
        {{ $t('APPOINTMENTS.LIST.EMPTY') }}
      </p>
    </div>

    <AppointmentModal
      v-if="modal"
      :appointment="modal.appointment"
      :prefill="modal.prefill"
      :services="services"
      :timezone="timezone"
      @close="modal = null"
      @saved="onSaved"
    />
  </div>
</template>
