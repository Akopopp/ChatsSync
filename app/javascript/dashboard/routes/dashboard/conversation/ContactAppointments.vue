<script setup>
import { onMounted, ref, watch } from 'vue';
import AppointmentsAPI from 'dashboard/api/appointments';
import ButtonV4 from 'next/button/Button.vue';
import AppointmentModal from '../appointments/AppointmentModal.vue';

// The contact's coming appointments, and booking one for them from the chat.
const props = defineProps({
  contact: { type: Object, required: true },
  conversationId: { type: [Number, String], required: true },
});

const appointments = ref([]);
const services = ref([]);
const timezone = ref('Asia/Karachi');
const modal = ref(null);

const fetchAppointments = async () => {
  if (!props.contact.id) return;
  const response = await AppointmentsAPI.list({ contact_id: props.contact.id });
  appointments.value = response.data.payload;
  services.value = response.data.services;
  timezone.value = response.data.timezone;
};

const formatWhen = value =>
  new Intl.DateTimeFormat(undefined, {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: 'numeric',
    minute: '2-digit',
    timeZone: timezone.value,
  }).format(new Date(value));

const openNew = () => {
  modal.value = {
    prefill: {
      name: props.contact.name,
      phone: props.contact.phone_number,
      conversationId: props.conversationId,
    },
  };
};

const onSaved = () => {
  modal.value = null;
  fetchAppointments();
};

watch(() => props.contact.id, fetchAppointments);
onMounted(fetchAppointments);
</script>

<template>
  <div class="grid gap-2 px-2 pb-2 text-sm">
    <button
      v-for="item in appointments"
      :key="item.id"
      class="text-left px-3 py-2 rounded-lg border border-n-weak hover:bg-n-alpha-1"
      :class="{ 'opacity-60 line-through': item.status === 'cancelled' }"
      @click="modal = { appointment: item }"
    >
      <span class="block font-medium text-n-slate-12">
        {{ formatWhen(item.starts_at) }}
      </span>
      <span class="block text-xs text-n-slate-11">
        {{ item.service }}
        {{ $t(`APPOINTMENTS.STATUSES.${item.status.toUpperCase()}`) }}
      </span>
    </button>
    <p v-if="!appointments.length" class="text-xs text-n-slate-11 px-1">
      {{ $t('APPOINTMENTS.CHAT.NONE') }}
    </p>
    <ButtonV4 sm faded blue icon="i-lucide-calendar-plus" @click="openNew">
      {{ $t('APPOINTMENTS.CHAT.BOOK') }}
    </ButtonV4>
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
