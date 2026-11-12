<script setup>
// The small "?" next to a feature: hover it, tap it or tab to it to read how the feature works.
defineProps({
  text: { type: String, required: true },
});
</script>

<template>
  <button
    v-tooltip="{
      content: text,
      triggers: ['hover', 'focus', 'click'],
      placement: 'top',
      popperClass:
        '[&_.v-popper__inner]:max-w-72 [&_.v-popper__inner]:!p-3 [&_.v-popper__inner]:!text-xs [&_.v-popper__inner]:leading-relaxed [&_.v-popper__inner]:whitespace-pre-line',
    }"
    type="button"
    class="inline-flex items-center justify-center flex-shrink-0 align-middle rounded-full size-5 text-n-slate-10 hover:text-n-brand focus-visible:text-n-brand"
    :aria-label="text"
    @click.stop.prevent
  >
    <span class="i-lucide-circle-help size-4" />
  </button>
</template>
