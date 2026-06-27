<script setup>
import { onMounted, computed } from 'vue';
import { useStore } from 'vuex';

const BUILDER_URL = 'https://builder.chatssync.online';
const store = useStore();

const accountId = (() => {
  const m = (window.location.pathname || '').match(/\/accounts\/(\d+)/);
  return m ? m[1] : '';
})();

const csToken = computed(() => {
  const u = store.getters.getCurrentUser;
  return (u && u.access_token) || '';
});

const src = computed(() => {
  let u = `${BUILDER_URL}/?view=templates`;
  if (accountId) u += `&account_id=${accountId}`;
  if (csToken.value) u += '&token=' + encodeURIComponent(csToken.value);
  return u;
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
      title="ChatsSync Templates"
      allow="clipboard-write"
    />
  </div>
</template>
