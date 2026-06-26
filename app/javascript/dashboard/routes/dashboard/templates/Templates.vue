<script setup>
import { onMounted, computed } from 'vue';

const BUILDER_URL = 'https://builder.chatssync.online';

// Multi-account: current ChatsSync account id URL se nikaalo (/accounts/<id>/...)
const accountId = (() => {
  const m = (window.location.pathname || '').match(/\/accounts\/(\d+)/);
  return m ? m[1] : '';
})();
const src = computed(() => {
  const base = `${BUILDER_URL}/?view=templates`;
  return accountId ? `${base}&account_id=${accountId}` : base;
});

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
      title="ChatsSync WhatsApp Templates"
      allow="clipboard-write"
    />
  </div>
</template>
