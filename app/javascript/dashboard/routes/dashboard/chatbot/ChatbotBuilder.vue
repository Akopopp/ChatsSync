<script setup>
import { onMounted, computed } from 'vue';
import { useStore } from 'vuex';

const BUILDER_URL = 'https://builder.chatssync.online';
const store = useStore();

// Multi-account: pull the current ChatsSync account id from the URL (/accounts/<id>/...)
const accountId = (() => {
  const m = (window.location.pathname || '').match(/\/accounts\/(\d+)/);
  return m ? m[1] : '';
})();

// The logged-in user's Chatwoot access token. The builder forwards this to the bot
// API so the server can verify the user actually belongs to this account.
const csToken = computed(() => {
  const u = store.getters.getCurrentUser;
  return (u && u.access_token) || '';
});

const src = computed(() => {
  let u = accountId ? `${BUILDER_URL}/?account_id=${accountId}` : `${BUILDER_URL}/`;
  if (csToken.value) u += (u.includes('?') ? '&' : '?') + 'token=' + encodeURIComponent(csToken.value);
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
      title="ChatsSync Chatbot Builder"
      allow="clipboard-write"
    />
  </div>
</template>
