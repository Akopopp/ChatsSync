<script setup>
import { onMounted } from 'vue';

const BUILDER_URL = 'https://zpzybpz68hsj0wvbpnar61in.5.75.237.171.sslip.io';

// On mobile, Chatwoot's side nav can stay open over this iframe (the iframe
// swallows taps, so the normal "tap outside to close" never fires).
// On mount we nudge the layout + simulate an outside tap so the nav collapses.
function collapseNavOnMobile() {
  if (typeof window === 'undefined' || window.innerWidth >= 1024) return;
  try { window.dispatchEvent(new Event('resize')); } catch (e) {}
  try { document.documentElement.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true })); } catch (e) {}
}

onMounted(() => {
  collapseNavOnMobile();
  setTimeout(collapseNavOnMobile, 250);
});
</script>

<template>
  <div style="width: 100%; height: 100%; display: flex; flex-direction: column;">
    <iframe
      :src="`${BUILDER_URL}/?view=gallery`"
      style="width: 100%; height: 100%; border: 0;"
      title="ChatsSync Gallery"
      allow="clipboard-write"
    />
  </div>
</template>
