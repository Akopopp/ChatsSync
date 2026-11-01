<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import AppointmentsAPI from 'dashboard/api/appointments';
import ButtonV4 from 'next/button/Button.vue';

// appointment: an existing booking to change. prefill: { name, phone, conversationId, date } for a new one.
const props = defineProps({
  appointment: { type: Object, default: null },
  prefill: { type: Object, default: () => ({}) },
  services: { type: Array, default: () => [] },
  timezone: { type: String, default: 'Asia/Karachi' },
});

const emit = defineEmits(['close', 'saved']);
const { t } = useI18n();

const STATUSES = ['booked', 'done', 'no_show', 'cancelled'];
const OTHER = 'other';

const localParts = value => {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone: props.timezone,
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
  return {
    date: `${parts.year}-${parts.month}-${parts.day}`,
    time: `${parts.hour}:${parts.minute}`,
  };
};

const isEdit = computed(() => !!props.appointment);
const original = props.appointment
  ? localParts(props.appointment.starts_at)
  : null;

const form = ref({
  service: props.appointment?.service || props.services[0]?.name || '',
  date: original?.date || props.prefill.date || localParts(Date.now()).date,
  time: original?.time || '',
  otherTime: '',
  name: props.appointment?.customer_name || props.prefill.name || '',
  phone: props.appointment?.customer_phone || props.prefill.phone || '',
  notes: props.appointment?.notes || '',
  status: props.appointment?.status || 'booked',
});
const times = ref([]);
const isSaving = ref(false);

const loadTimes = async () => {
  const response = await AppointmentsAPI.freeTimes({
    date: form.value.date,
    service: form.value.service,
  });
  times.value = response.data.times;
  const free = times.value.filter(slot => slot.free).map(slot => slot.time);
  if (form.value.time && form.value.time !== OTHER) {
    if (!free.includes(form.value.time)) {
      // Keep a time outside the usual slots (like the booking's own time) as "other".
      form.value.otherTime = form.value.time;
      form.value.time = OTHER;
    }
  }
};

watch(() => [form.value.date, form.value.service], loadTimes);
onMounted(loadTimes);

const formatTime = value => {
  const [hours, minutes] = value.split(':').map(Number);
  return `${hours % 12 || 12}:${String(minutes).padStart(2, '0')} ${hours < 12 ? 'AM' : 'PM'}`;
};

const chosenTime = computed(() =>
  form.value.time === OTHER ? form.value.otherTime : form.value.time
);

const moved = computed(
  () =>
    !isEdit.value ||
    form.value.date !== original.date ||
    chosenTime.value !== original.time
);

const save = async () => {
  if (!chosenTime.value || (!isEdit.value && !form.value.name.trim())) {
    useAlert(t('APPOINTMENTS.FORM.MISSING'));
    return;
  }
  isSaving.value = true;
  try {
    const details = {
      service: form.value.service,
      customer_name: form.value.name,
      customer_phone: form.value.phone,
      notes: form.value.notes,
    };
    const when = moved.value
      ? { date: form.value.date, time: chosenTime.value }
      : {};
    if (isEdit.value) {
      await AppointmentsAPI.change(props.appointment.id, {
        ...when,
        appointment: { status: form.value.status, notes: form.value.notes },
      });
    } else {
      await AppointmentsAPI.book({
        ...when,
        conversation_id: props.prefill.conversationId,
        appointment: details,
      });
    }
    useAlert(t('APPOINTMENTS.FORM.SAVED'));
    emit('saved');
  } catch (error) {
    useAlert(error?.response?.data?.error || t('APPOINTMENTS.ERROR'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div
    class="fixed inset-0 z-50 grid place-items-center bg-n-alpha-black2 p-4"
    @click.self="emit('close')"
  >
    <div
      class="w-full max-w-md max-h-full overflow-y-auto rounded-xl bg-n-solid-2 border border-n-weak shadow-lg p-5 grid gap-3 text-sm text-n-slate-12"
    >
      <div class="flex items-center justify-between">
        <h2 class="text-base font-semibold">
          {{
            isEdit
              ? $t('APPOINTMENTS.FORM.EDIT_TITLE')
              : $t('APPOINTMENTS.FORM.NEW_TITLE')
          }}
        </h2>
        <button
          class="i-lucide-x size-5 text-n-slate-11"
          :aria-label="$t('APPOINTMENTS.FORM.CLOSE')"
          @click="emit('close')"
        />
      </div>

      <template v-if="!isEdit">
        <label class="grid gap-1">
          {{ $t('APPOINTMENTS.FORM.NAME') }}
          <input v-model="form.name" type="text" maxlength="120" class="!mb-0" />
        </label>
        <label class="grid gap-1">
          {{ $t('APPOINTMENTS.FORM.PHONE') }}
          <input v-model="form.phone" type="tel" maxlength="40" class="!mb-0" />
        </label>
        <label v-if="services.length" class="grid gap-1">
          {{ $t('APPOINTMENTS.FORM.SERVICE') }}
          <select v-model="form.service" class="!mb-0">
            <option
              v-for="service in services"
              :key="service.name"
              :value="service.name"
            >
              {{ service.name }}
            </option>
          </select>
        </label>
      </template>
      <div v-else class="grid gap-0.5">
        <span class="font-medium">{{ appointment.customer_name }}</span>
        <span class="text-xs text-n-slate-11">
          {{ [appointment.service, appointment.customer_phone].filter(Boolean).join(' · ') }}
        </span>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <label class="grid gap-1">
          {{ $t('APPOINTMENTS.FORM.DATE') }}
          <input v-model="form.date" type="date" class="!mb-0" />
        </label>
        <label class="grid gap-1">
          {{ $t('APPOINTMENTS.FORM.TIME') }}
          <select v-model="form.time" class="!mb-0">
            <option value="" disabled>
              {{ $t('APPOINTMENTS.FORM.PICK_TIME') }}
            </option>
            <option
              v-for="slot in times"
              :key="slot.time"
              :value="slot.time"
              :disabled="!slot.free"
            >
              {{ formatTime(slot.time) }}
              {{ slot.free ? '' : $t('APPOINTMENTS.FORM.FULL') }}
            </option>
            <option :value="OTHER">{{ $t('APPOINTMENTS.FORM.OTHER_TIME') }}</option>
          </select>
        </label>
      </div>
      <label v-if="form.time === OTHER" class="grid gap-1">
        {{ $t('APPOINTMENTS.FORM.OTHER_TIME') }}
        <input v-model="form.otherTime" type="time" class="!mb-0" />
      </label>

      <label v-if="isEdit" class="grid gap-1">
        {{ $t('APPOINTMENTS.FORM.STATUS') }}
        <select v-model="form.status" class="!mb-0">
          <option v-for="status in STATUSES" :key="status" :value="status">
            {{ $t(`APPOINTMENTS.STATUSES.${status.toUpperCase()}`) }}
          </option>
        </select>
      </label>
      <label class="grid gap-1">
        {{ $t('APPOINTMENTS.FORM.NOTES') }}
        <textarea v-model="form.notes" rows="2" maxlength="1000" class="!mb-0" />
      </label>

      <div class="flex justify-end gap-2 pt-1">
        <ButtonV4 sm faded slate @click="emit('close')">
          {{ $t('APPOINTMENTS.FORM.CANCEL') }}
        </ButtonV4>
        <ButtonV4 sm solid blue :is-loading="isSaving" @click="save">
          {{ $t('APPOINTMENTS.FORM.SAVE') }}
        </ButtonV4>
      </div>
    </div>
  </div>
</template>
