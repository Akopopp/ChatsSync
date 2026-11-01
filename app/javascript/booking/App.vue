<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
const token = window.location.pathname.split('/').filter(Boolean).pop();
const endpoint = `/public/api/v1/bookings/${token}`;

const isLoading = ref(true);
const isBooking = ref(false);
const notAvailable = ref(false);
const info = ref(null);
const service = ref('');
const date = ref('');
const time = ref('');
const name = ref('');
const phone = ref('');
const error = ref('');
const bookedLabel = ref('');

const times = computed(
  () => info.value?.days.find(day => day.date === date.value)?.times || []
);

const formatDay = value => {
  const day = new Date(`${value}T12:00:00Z`);
  const part = options =>
    new Intl.DateTimeFormat(undefined, { ...options, timeZone: 'UTC' }).format(
      day
    );
  return {
    weekday: part({ weekday: 'short' }),
    day: part({ day: 'numeric' }),
    month: part({ month: 'short' }),
  };
};

const formatTime = value => {
  const [hours, minutes] = value.split(':').map(Number);
  const suffix = hours < 12 ? 'AM' : 'PM';
  return `${hours % 12 || 12}:${String(minutes).padStart(2, '0')} ${suffix}`;
};

const load = async () => {
  isLoading.value = true;
  try {
    const query = service.value
      ? `?service=${encodeURIComponent(service.value)}`
      : '';
    const response = await fetch(`${endpoint}${query}`);
    if (!response.ok) {
      notAvailable.value = true;
      return;
    }
    info.value = await response.json();
    if (!info.value.days.some(day => day.date === date.value)) {
      date.value = info.value.days[0]?.date || '';
    }
    time.value = '';
  } finally {
    isLoading.value = false;
  }
};

const chooseService = serviceName => {
  service.value = serviceName;
  load();
};

const chooseDate = value => {
  date.value = value;
  time.value = '';
  error.value = '';
};

const book = async () => {
  error.value = '';
  if (!name.value.trim() || phone.value.replace(/\D/g, '').length < 7) {
    error.value = t('MISSING');
    return;
  }
  isBooking.value = true;
  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        date: date.value,
        time: time.value,
        service: service.value,
        name: name.value,
        phone: phone.value,
      }),
    });
    const data = await response.json().catch(() => ({}));
    if (response.ok) {
      bookedLabel.value = data.label;
    } else if (response.status === 409) {
      error.value = t('SLOT_TAKEN');
      await load();
    } else {
      error.value = t(response.status === 422 ? 'MISSING' : 'ERROR');
    }
  } catch {
    error.value = t('ERROR');
  } finally {
    isBooking.value = false;
  }
};

const bookAnother = () => {
  bookedLabel.value = '';
  load();
};

onMounted(load);
</script>

<template>
  <div class="min-h-screen bg-n-slate-2 px-4 py-8 text-n-slate-12">
    <div class="max-w-lg mx-auto grid gap-5">
      <header class="flex items-center gap-3">
        <div
          class="size-12 rounded-full bg-n-brand text-white grid place-items-center text-xl font-semibold"
        >
          {{ (info?.business_name || '?').charAt(0).toUpperCase() }}
        </div>
        <div class="grid">
          <h1 class="text-lg font-semibold">{{ info?.business_name }}</h1>
          <span class="text-sm text-n-slate-11">{{ t('TITLE') }}</span>
        </div>
      </header>

      <div
        v-if="notAvailable"
        class="p-5 rounded-2xl bg-n-solid-1 shadow-sm text-sm text-n-slate-11"
      >
        {{ t('NOT_AVAILABLE') }}
      </div>

      <div
        v-else-if="bookedLabel"
        class="p-6 rounded-2xl bg-n-solid-1 shadow-sm grid gap-3 text-center"
      >
        <div
          class="size-14 mx-auto rounded-full bg-n-teal-3 text-n-teal-11 grid place-items-center"
        >
          <span class="i-lucide-check size-7" />
        </div>
        <h2 class="text-lg font-semibold">{{ t('DONE_TITLE') }}</h2>
        <p class="text-sm text-n-slate-11">
          {{ t('DONE_TEXT', { label: bookedLabel }) }}
        </p>
        <p
          v-if="info?.notes"
          class="text-sm text-n-slate-11 whitespace-pre-line"
        >
          {{ info.notes }}
        </p>
        <button class="text-sm text-n-blue-11" @click="bookAnother">
          {{ t('BOOK_ANOTHER') }}
        </button>
      </div>

      <template v-else-if="info">
        <section
          v-if="info.services.length > 1"
          class="p-5 rounded-2xl bg-n-solid-1 shadow-sm grid gap-3"
        >
          <h2 class="text-sm font-semibold">{{ t('SERVICE') }}</h2>
          <div class="grid gap-2">
            <button
              v-for="item in info.services"
              :key="item.name"
              class="flex items-center justify-between gap-3 px-4 py-3 rounded-xl border text-left text-sm transition-colors"
              :class="
                service === item.name
                  ? 'border-n-brand bg-n-brand/10'
                  : 'border-n-weak hover:bg-n-alpha-1'
              "
              @click="chooseService(item.name)"
            >
              <span class="font-medium">{{ item.name }}</span>
              <span class="text-n-slate-11">
                {{
                  [
                    item.minutes ? t('MINUTES', { count: item.minutes }) : '',
                    item.price,
                  ]
                    .filter(Boolean)
                    .join(' · ')
                }}
              </span>
            </button>
          </div>
        </section>

        <section
          v-if="info.services.length <= 1 || service"
          class="p-5 rounded-2xl bg-n-solid-1 shadow-sm grid gap-4"
        >
          <p v-if="isLoading" class="text-sm text-n-slate-11">
            {{ t('LOADING') }}
          </p>
          <p v-else-if="!info.days.length" class="text-sm text-n-slate-11">
            {{ t('NO_TIMES') }}
          </p>
          <template v-else>
            <h2 class="text-sm font-semibold">{{ t('DATE') }}</h2>
            <div class="flex gap-2 overflow-x-auto pb-1 -mx-1 px-1">
              <button
                v-for="day in info.days"
                :key="day.date"
                class="shrink-0 w-16 py-2 rounded-xl border grid text-center transition-colors"
                :class="
                  date === day.date
                    ? 'border-n-brand bg-n-brand text-white'
                    : 'border-n-weak hover:bg-n-alpha-1'
                "
                @click="chooseDate(day.date)"
              >
                <span class="text-xs">{{ formatDay(day.date).weekday }}</span>
                <span class="text-lg font-semibold leading-6">
                  {{ formatDay(day.date).day }}
                </span>
                <span class="text-xs">{{ formatDay(day.date).month }}</span>
              </button>
            </div>
            <h2 class="text-sm font-semibold">{{ t('TIME') }}</h2>
            <div class="grid grid-cols-3 sm:grid-cols-4 gap-2">
              <button
                v-for="slot in times"
                :key="slot"
                class="py-2 rounded-xl border text-sm transition-colors"
                :class="
                  time === slot
                    ? 'border-n-brand bg-n-brand text-white'
                    : 'border-n-weak hover:bg-n-alpha-1'
                "
                @click="time = slot"
              >
                {{ formatTime(slot) }}
              </button>
            </div>
            <span class="text-xs text-n-slate-11">
              {{ t('TIMEZONE', { zone: info.timezone }) }}
            </span>
          </template>
        </section>

        <section
          v-if="time"
          class="p-5 rounded-2xl bg-n-solid-1 shadow-sm grid gap-3"
        >
          <h2 class="text-sm font-semibold">{{ t('DETAILS') }}</h2>
          <input
            v-model="name"
            type="text"
            maxlength="120"
            autocomplete="name"
            class="w-full px-3 py-2.5 rounded-xl border border-n-weak bg-n-solid-1 text-sm outline-none focus:border-n-brand"
            :placeholder="t('NAME')"
          />
          <input
            v-model="phone"
            type="tel"
            maxlength="40"
            autocomplete="tel"
            class="w-full px-3 py-2.5 rounded-xl border border-n-weak bg-n-solid-1 text-sm outline-none focus:border-n-brand"
            :placeholder="t('PHONE')"
          />
          <p v-if="error" class="text-sm text-n-ruby-11">{{ error }}</p>
          <button
            class="w-full py-3 rounded-xl bg-n-brand text-white font-medium text-sm disabled:opacity-60"
            :disabled="isBooking"
            @click="book"
          >
            {{ isBooking ? t('BOOKING') : t('BOOK') }}
          </button>
        </section>
        <p v-else-if="error" class="text-sm text-n-ruby-11">{{ error }}</p>
      </template>

      <p v-else class="text-sm text-n-slate-11">{{ t('LOADING') }}</p>
    </div>
  </div>
</template>

<style lang="scss">
@import '../survey/assets/scss/woot.scss';
</style>
