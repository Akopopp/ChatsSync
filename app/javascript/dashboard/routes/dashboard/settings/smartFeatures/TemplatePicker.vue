<script setup>
// The WhatsApp number and approved template a smart feature sends from
// (COD confirmation, repeat reminders).
import { computed } from 'vue';

const props = defineProps({
  inboxes: { type: Array, default: () => [] },
  templates: { type: Array, default: () => [] },
  inboxId: { type: Number, default: 0 },
  template: { type: String, default: '' },
  language: { type: String, default: '' },
  emptyText: { type: String, default: '' },
  helpText: { type: String, default: '' },
});

const emit = defineEmits(['update']);

const templateValue = computed(() =>
  props.template ? `${props.template}|${props.language}` : ''
);

const chooseInbox = id =>
  emit('update', { inboxId: Number(id), template: '', language: '' });

const chooseTemplate = value => {
  const [template, language] = value.split('|');
  emit('update', {
    inboxId: props.inboxId,
    template: template || '',
    language: language || '',
  });
};
</script>

<template>
  <div class="grid gap-3">
    <label class="grid gap-1 text-n-slate-11">
      {{ $t('SMART_FEATURES.TEMPLATE_PICKER.NUMBER') }}
      <select
        :value="inboxId || ''"
        class="!mb-0 text-sm"
        @change="chooseInbox($event.target.value)"
      >
        <option value="" disabled>
          {{ $t('SMART_FEATURES.TEMPLATE_PICKER.NUMBER_PLACEHOLDER') }}
        </option>
        <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
          {{ inbox.name }}
        </option>
      </select>
    </label>
    <label v-if="inboxId" class="grid gap-1 text-n-slate-11">
      {{ $t('SMART_FEATURES.TEMPLATE_PICKER.TEMPLATE') }}
      <select
        v-if="templates.length"
        :value="templateValue"
        class="!mb-0 text-sm"
        @change="chooseTemplate($event.target.value)"
      >
        <option value="" disabled>
          {{ $t('SMART_FEATURES.TEMPLATE_PICKER.TEMPLATE_PLACEHOLDER') }}
        </option>
        <option
          v-for="item in templates"
          :key="`${item.name}|${item.language}`"
          :value="`${item.name}|${item.language}`"
        >
          {{ `${item.name} (${item.language})` }}
        </option>
      </select>
      <span v-else class="px-3 py-2 rounded-lg bg-n-amber-2 text-n-amber-11">
        {{ emptyText }}
      </span>
      <span v-if="helpText" class="text-xs text-n-slate-10">
        {{ helpText }}
      </span>
    </label>
  </div>
</template>
