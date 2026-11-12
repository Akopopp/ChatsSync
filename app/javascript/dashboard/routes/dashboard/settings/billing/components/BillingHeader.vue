<script setup>
import HelpTip from 'dashboard/components-next/helpTip/HelpTip.vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    required: true,
  },
  // How to use this section, shown by the "?" next to the title.
  help: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div class="grid grid-cols-[minmax(0,1fr)_auto] gap-5">
    <div>
      <span
        class="flex items-center gap-1.5 text-base font-medium text-n-slate-12"
      >
        {{ title }}
        <HelpTip v-if="help" :text="help" />
      </span>
      <p class="text-sm mt-1 text-n-slate-11">
        {{ description }}
      </p>
    </div>
    <slot />
  </div>
</template>
