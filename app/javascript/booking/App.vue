<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import MonthCalendar from './MonthCalendar.vue';

const { t } = useI18n();
// /book/:token or /book/:token/manage/:manageToken
const [, , token, , manageToken] = window.location.pathname.split('/');
const endpoint = `/public/api/v1/bookings/${token}`;
const manageEndpoint = `${endpoint}/manage/${manageToken}`;

const isLoading = ref(true);
const isSaving = ref(false);
const notAvailable = ref(false);
const info = ref(null);
const service = ref('');
const date = ref('');
const time = ref('');
const name = ref('');
const phone = ref('');
const error = ref('');
const done = ref(null);

// Changing or cancelling an existing booking.
const booking = ref(null);
const mode = ref(manageToken ? 'manage' : 'book');
const confirmCancel = ref(false);

const needsService = computed(
  () => mode.value === 'book' && info.value?.services.length > 1
);
const showCalendar = computed(
  () =>
    mode.value !== 'manage' &&
    info.value?.days &&
    (!needsService.value || service.value)
);

const loadDays = async () => {
  const query = service.value
    ? `?service=${encodeURIComponent(service.value)}`
    : '';
  const response = await fetch(`${endpoint}${query}`);
  if (!response.ok) {
    notAvailable.value = true;
    return;
  }
  info.value = await response.json();
};

const load = async () => {
  try {
    await loadDays();
    if (manageToken && !notAvailable.value) {
      const response = await fetch(manageEndpoint);
      if (response.ok) {
        booking.value = await response.json();
        // Free times are shown for the length of the booked service.
        if (booking.value.service) {
          service.value = booking.value.service;
          await loadDays();
        }
      } else {
        error.value = t('MANAGE.NOT_FOUND');
      }
    }
  } finally {
    isLoading.value = false;
  }
};

const chooseService = serviceName => {
  service.value = serviceName;
  loadDays();
};

const post = async (url, body) => {
  isSaving.value = true;
  error.value = '';
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const data = await response.json().catch(() => ({}));
    if (response.ok) return data;
    if (response.status === 409) {
      error.value = t('SLOT_TAKEN');
      await loadDays();
    } else if (data.error === 'not_changeable') {
      error.value = t('MANAGE.NOT_CHANGEABLE');
    } else {
      error.value = t(response.status === 422 ? 'MISSING' : 'ERROR');
    }
    return null;
  } catch {
    error.value = t('ERROR');
    return null;
  } finally {
    isSaving.value = false;
  }
};

const book = async () => {
  if (!name.value.trim() || phone.value.replace(/\D/g, '').length < 7) {
    error.value = t('MISSING');
    return;
  }
  const data = await post(endpoint, {
    date: date.value,
    time: time.value,
    service: service.value,
    name: name.value,
    phone: phone.value,
  });
  if (data) done.value = { ...data, moved: false };
};

const moveBooking = async () => {
  const data = await post(`${manageEndpoint}/reschedule`, {
    date: date.value,
    time: time.value,
  });
  if (data) done.value = { ...data, moved: true };
};

const cancelBooking = async () => {
  const data = await post(`${manageEndpoint}/cancel`, {});
  if (data) {
    booking.value = { ...booking.value, status: 'cancelled' };
    confirmCancel.value = false;
  }
};

const bookAnother = () => {
  done.value = null;
  time.value = '';
  loadDays();
};

const canChange = computed(
  () => booking.value?.status === 'booked' && booking.value?.upcoming
);

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
          <span class="text-sm text-n-slate-11">
            {{ mode === 'book' ? t('TITLE') : t('MANAGE.TITLE') }}
          </span>
        </div>
      </header>

      <p v-if="isLoading" class="text-sm text-n-slate-11">{{ t('LOADING') }}</p>

      <div
        v-else-if="notAvailable"
        class="p-5 rounded-2xl bg-n-solid-1 shadow-sm text-sm text-n-slate-11"
      >
        {{ t('NOT_AVAILABLE') }}
      </div>

      <div
        v-else-if="done"
        class="p-6 rounded-2xl bg-n-solid-1 shadow-sm grid gap-3 text-center"
      >
        <div
          class="size-14 mx-auto rounded-full bg-n-teal-3 text-n-teal-11 grid place-items-center"
        >
          <span class="i-lucide-check size-7" />
        </div>
        <h2 class="text-lg font-semibold">
          {{ done.moved ? t('MANAGE.MOVED_TITLE') : t('DONE_TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11">
          {{
            done.moved
              ? t('MANAGE.MOVED_TEXT', { label: done.label })
              : t('DONE_TEXT', { label: done.label })
          }}
        </p>
        <p
          v-if="info?.notes"
          class="text-sm text-n-slate-11 whitespace-pre-line"
        >
          {{ info.notes }}
        </p>
        <a
          v-if="done.manage_url"
          :href="done.manage_url"
          class="text-sm text-n-blue-11"
        >
          {{ t('CHANGE_OR_CANCEL') }}
        </a>
        <button
          v-if="!done.moved"
          class="text-sm text-n-slate-11"
          @click="bookAnother"
        >
          {{ t('BOOK_ANOTHER') }}
        </button>
      </div>

      <template v-else-if="info">
        <section
          v-if="mode === 'manage'"
          class="p-5 rounded-2xl bg-n-solid-1 shadow-sm grid gap-4"
        >
          <p v-if="!booking" class="text-sm text-n-slate-11">{{ error }}</p>
          <template v-else>
            <div class="grid gap-1">
              <span class="text-lg font-semibold">{{ booking.label }}</span>
              <span class="text-sm text-n-slate-11">{{ booking.name }}</span>
            </div>
            <p
              v-if="booking.status === 'cancelled'"
              class="text-sm text-n-ruby-11"
            >
              {{ t('MANAGE.CANCELLED') }}
            </p>
            <p v-else-if="!canChange" class="text-sm text-n-slate-11">
              {{ t('MANAGE.NOT_CHANGEABLE') }}
            </p>
            <div v-else-if="confirmCancel" class="grid gap-2">
              <p class="text-sm font-medium">
                {{ t('MANAGE.CANCEL_CONFIRM') }}
              </p>
              <div class="grid grid-cols-2 gap-2">
                <button
                  class="py-3 rounded-xl bg-n-ruby-9 text-white text-sm font-medium disabled:opacity-60"
                  :disabled="isSaving"
                  @click="cancelBooking"
                >
                  {{ t('MANAGE.YES_CANCEL') }}
                </button>
                <button
                  class="py-3 rounded-xl border border-n-weak text-sm"
                  @click="confirmCancel = false"
                >
                  {{ t('MANAGE.KEEP') }}
                </button>
              </div>
            </div>
            <div v-else class="grid grid-cols-2 gap-2">
              <button
                class="py-3 rounded-xl bg-n-brand text-white text-sm font-medium"
                @click="mode = 'reschedule'"
              >
                {{ t('MANAGE.CHANGE') }}
              </button>
              <button
                class="py-3 rounded-xl border border-n-weak text-sm text-n-ruby-11"
                @click="confirmCancel = true"
              >
                {{ t('MANAGE.CANCEL') }}
              </button>
            </div>
            <p v-if="error" class="text-sm text-n-ruby-11">{{ error }}</p>
          </template>
        </section>

        <section
          v-if="needsService"
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
          v-if="showCalendar"
          class="p-5 rounded-2xl bg-n-solid-1 shadow-sm grid gap-4"
        >
          <div v-if="mode === 'reschedule'" class="flex items-center gap-2">
            <button
              class="size-8 grid place-items-center rounded-full hover:bg-n-alpha-1"
              :aria-label="t('MANAGE.BACK')"
              @click="mode = 'manage'"
            >
              <span class="i-lucide-arrow-left size-4" />
            </button>
            <h2 class="text-sm font-semibold">{{ t('MANAGE.CHOOSE_NEW') }}</h2>
          </div>
          <p v-if="!info.days.length" class="text-sm text-n-slate-11">
            {{ t('NO_TIMES') }}
          </p>
          <MonthCalendar
            v-else
            v-model:date="date"
            v-model:time="time"
            :days="info.days"
            :today="info.today"
            :last-day="info.last_day"
            :timezone="info.timezone"
          />
        </section>

        <section
          v-if="showCalendar && time"
          class="p-5 rounded-2xl bg-n-solid-1 shadow-sm grid gap-3"
        >
          <template v-if="mode === 'book'">
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
          </template>
          <p v-if="error" class="text-sm text-n-ruby-11">{{ error }}</p>
          <button
            class="w-full py-3 rounded-xl bg-n-brand text-white font-medium text-sm disabled:opacity-60"
            :disabled="isSaving"
            @click="mode === 'book' ? book() : moveBooking()"
          >
            {{
              isSaving
                ? t('BOOKING')
                : mode === 'book'
                  ? t('BOOK')
                  : t('MANAGE.SAVE_NEW')
            }}
          </button>
        </section>
      </template>
    </div>
  </div>
</template>
