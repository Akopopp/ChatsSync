<script setup>
import { onMounted, computed } from 'vue';

const BUILDER_URL = 'https://zpzybpz68hsj0wvbpnar61in.5.75.237.171.sslip.io';

// Multi-account: pull the current ChatsSync account id from the URL (/accounts/<id>/...)
// and hand it to the builder, so each account loads ITS OWN chatbots.
const accountId = (() => {
  const m = (window.location.pathname || '').match(/\/accounts\/(\d+)/);
  return m ? m[1] : '';
})();
const src = computed(() => accountId ? `${BUILDER_URL}/?account_id=${accountId}` : BUILDER_URL);

// On mobile, nudge the side nav to collapse so the iframe is fully visible.
function collapseNavOnMobile() {
  if (typeof window === 'undefined' || window.innerWidth >= 1024) return;
  try { window.dispatchEvent(new Event('resize')); } catch (e) {}
  try { document.documentElement.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true })); } catch (e) {}
}
onMounted(() => { collapseNavOnMobile(); setTimeout(collapseNavOnMobile, 250); });
</script>

<template>
  <div style="width: 100%; height: 100%; display: flex; flex-direction: column;">
    <iframe
      :src="src"
      style="width: 100%; height: 100%; border: 0;"
      title="ChatsSync Chatbot Builder"
      allow="clipboard-write"
    />
  </div>
</template>
