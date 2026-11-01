<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  days: { type: Array, required: true },
  today: { type: String, required: true },
  lastDay: { type: String, required: true },
  timezone: { type: String, default: '' },
});

const date = defineModel('date', { type: String, default: '' });
const time = defineModel('time', { type: String, default: '' });

const { t } = useI18n();

// Dates are plain YYYY-MM-DD strings in the business's time zone; UTC keeps them from shifting.
const toUTC = iso => new Date(`${iso}T12:00:00Z`);
const iso = d => d.toISOString().slice(0, 10);

const dayMap = computed(() =>
  Object.fromEntries(props.days.map(day => [day.date, day.times]))
);

const firstMonth = computed(() => props.today.slice(0, 7));
const lastMonth = computed(() => props.lastDay.slice(0, 7));
const month = ref(props.today.slice(0, 7));

const firstAvailable = computed(
  () => props.days.find(day => day.times.some(slot => slot.free))?.date || ''
);

watch(
  () => props.days,
  () => {
    if (!dayMap.value[date.value]?.some(slot => slot.free)) {
      date.value = firstAvailable.value;
      time.value = '';
    }
    if (date.value) month.value = date.value.slice(0, 7);
  },
  { immediate: true }
);

const monthTitle = computed(() =>
  new Intl.DateTimeFormat(undefined, {
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(toUTC(`${month.value}-15`))
);

const weekdays = computed(() =>
  [1, 2, 3, 4, 5, 6, 7].map(day =>
    new Intl.DateTimeFormat(undefined, {
      weekday: 'short',
      timeZone: 'UTC',
    }).format(new Date(Date.UTC(2024, 0, day)))
  )
);

const stateOf = value => {
  const slots = dayMap.value[value];
  if (value < props.today || value > props.lastDay || !slots) return 'closed';
  return slots.some(slot => slot.free) ? 'free' : 'full';
};

// Monday-first grid of the shown month, with empty cells before the 1st.
const cells = computed(() => {
  const first = toUTC(`${month.value}-01`);
  const lead = (first.getUTCDay() + 6) % 7;
  const result = Array.from({ length: lead }, (_, index) => ({
    key: `blank-${index}`,
  }));
  const cursor = new Date(first);
  while (iso(cursor).slice(0, 7) === month.value) {
    const value = iso(cursor);
    result.push({
      key: value,
      date: value,
      day: cursor.getUTCDate(),
      state: stateOf(value),
    });
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return result;
});

const shiftMonth = step => {
  const d = toUTC(`${month.value}-15`);
  d.setUTCMonth(d.getUTCMonth() + step);
  month.value = iso(d).slice(0, 7);
};

const pickDay = cell => {
  if (cell.state === 'closed') return;
  date.value = cell.date;
  time.value = '';
};

const slots = computed(() => dayMap.value[date.value] || []);

const dayTitle = computed(() =>
  date.value
    ? new Intl.DateTimeFormat(undefined, {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        timeZone: 'UTC',
      }).format(toUTC(date.value))
    : ''
);

const formatTime = value => {
  const [hours, minutes] = value.split(':').map(Number);
  const suffix = hours < 12 ? 'AM' : 'PM';
  return `${hours % 12 || 12}:${String(minutes).padStart(2, '0')} ${suffix}`;
};

const cellClass = cell => {
  if (cell.date === date.value) return 'bg-n-brand text-white font-semibold';
  if (cell.state === 'free')
    return 'bg-n-brand/10 text-n-blue-11 font-medium hover:bg-n-brand/20';
  if (cell.state === 'full') return 'text-n-slate-10 line-through';
  return 'text-n-slate-8 cursor-default';
};
</script>

<template>
  <div class="grid gap-4">
    <div class="flex items-center justify-between">
      <button
        class="size-9 grid place-items-center rounded-full hover:bg-n-alpha-1 disabled:opacity-30"
        :disabled="month <= firstMonth"
        :aria-label="t('PREV_MONTH')"
        @click="shiftMonth(-1)"
      >
        <span class="i-lucide-chevron-left size-5" />
      </button>
      <h2 class="font-semibold">{{ monthTitle }}</h2>
      <button
        class="size-9 grid place-items-center rounded-full hover:bg-n-alpha-1 disabled:opacity-30"
        :disabled="month >= lastMonth"
        :aria-label="t('NEXT_MONTH')"
        @click="shiftMonth(1)"
      >
        <span class="i-lucide-chevron-right size-5" />
      </button>
    </div>

    <div class="grid grid-cols-7 gap-1 text-center">
      <span
        v-for="weekday in weekdays"
        :key="weekday"
        class="text-xs font-medium text-n-slate-11 py-1"
      >
        {{ weekday }}
      </span>
      <template v-for="cell in cells" :key="cell.key">
        <span v-if="!cell.date" />
        <button
          v-else
          class="aspect-square rounded-full text-sm grid place-items-center transition-colors"
          :class="cellClass(cell)"
          :disabled="cell.state === 'closed'"
          @click="pickDay(cell)"
        >
          {{ cell.day }}
        </button>
      </template>
    </div>

    <div class="flex flex-wrap gap-4 text-xs text-n-slate-11">
      <span class="flex items-center gap-1.5">
        <span class="size-3 rounded-full bg-n-brand/20" />
        {{ t('LEGEND_FREE') }}
      </span>
      <span class="flex items-center gap-1.5 line-through">
        {{ t('LEGEND_FULL') }}
      </span>
      <span class="flex items-center gap-1.5 text-n-slate-8">
        {{ t('LEGEND_CLOSED') }}
      </span>
    </div>

    <div v-if="date" class="grid gap-3 pt-3 border-t border-n-weak">
      <h3 class="text-sm font-semibold">{{ dayTitle }}</h3>
      <p v-if="!slots.some(slot => slot.free)" class="text-sm text-n-slate-11">
        {{ t('NO_TIMES_DAY') }}
      </p>
      <div class="grid grid-cols-3 sm:grid-cols-4 gap-2">
        <button
          v-for="slot in slots"
          :key="slot.time"
          class="py-2 rounded-xl border text-sm transition-colors grid"
          :class="
            !slot.free
              ? 'border-n-weak bg-n-alpha-1 text-n-slate-9 cursor-not-allowed'
              : time === slot.time
                ? 'border-n-brand bg-n-brand text-white'
                : 'border-n-weak hover:bg-n-alpha-1'
          "
          :disabled="!slot.free"
          @click="time = slot.time"
        >
          <span :class="{ 'line-through': !slot.free }">
            {{ formatTime(slot.time) }}
          </span>
          <span v-if="!slot.free" class="text-[10px] leading-3">
            {{ t('BOOKED') }}
          </span>
        </button>
      </div>
      <span v-if="timezone" class="text-xs text-n-slate-11">
        {{ t('TIMEZONE', { zone: timezone }) }}
      </span>
    </div>
  </div>
</template>
