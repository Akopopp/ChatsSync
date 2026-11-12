<script setup>
// The small "?" next to a feature: hover it, tap it or tab to it to read how the feature works.
import { computed } from 'vue';

const props = defineProps({
  text: { type: String, required: true },
});

const ESCAPES = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;',
};
// The note is wrapped so it stays a readable width and keeps its line breaks.
const content = computed(
  () =>
    `<div class="max-w-[18rem] py-1 text-xs leading-relaxed whitespace-pre-line">${props.text.replace(/[&<>"']/g, c => ESCAPES[c])}</div>`
);
</script>

<template>
  <button
    v-tooltip="{
      content,
      html: true,
      triggers: ['hover', 'focus', 'click'],
      placement: 'top',
    }"
    type="button"
    class="inline-flex items-center justify-center flex-shrink-0 align-middle rounded-full size-5 text-n-slate-10 hover:text-n-brand focus-visible:text-n-brand"
    :aria-label="text"
    @click.stop.prevent
  >
    <span class="i-lucide-circle-help size-4" />
  </button>
</template>
