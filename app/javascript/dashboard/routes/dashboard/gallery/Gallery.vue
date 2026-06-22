<script setup>
import { onMounted, computed } from 'vue';

const BUILDER_URL = 'https://builder.chatssync.online';

// Multi-account: pull the current ChatsSync account id from the URL (/accounts/<id>/...)
// so each account sees ITS OWN media gallery.
const accountId = (() => {
  const m = (window.location.pathname || '').match(/\/accounts\/(\d+)/);
  return m ? m[1] : '';
})();
const src = computed(() => {
  const base = `${BUILDER_URL}/?view=gallery`;
  return accountId ? `${base}&account_id=${accountId}` : base;
});

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
      title="ChatsSync Gallery"
      allow="clipboard-write"
    />
  </div>
</template>
