<script setup>
import { onMounted, onBeforeUnmount, ref, computed } from 'vue';
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

/* ===== THEME =====
   Chatwoot ka apna --slate-1 parhte hain. Woh _next-colors.scss mein
   `.dark` ke neeche badal jaata hai (light: "252 252 253",
   dark: "17 17 19"), isliye ye har tareeqe ke saath sahi rehta hai —
   chahe .dark class html par ho ya kisi wrapper par.
   Builder alag domain par hai, to CSS wahan nahi pahunchti. Theme do
   tareeqon se bhejte hain: pehli baar URL mein, aur baad mein badle to
   postMessage se. */
const isDarkNow = () => {
  try {
    const v = getComputedStyle(document.documentElement)
      .getPropertyValue('--slate-1')
      .trim();
    const first = Number((v.split(/[\s,]+/)[0] || '255').replace(/[^\d.]/g, ''));
    if (Number.isFinite(first)) return first < 128;
  } catch (e) {
    /* ignore */
  }
  return document.documentElement.classList.contains('dark');
};

const theme = ref(isDarkNow() ? 'dark' : 'light');
const frame = ref(null);
let themeObs = null;

const pushTheme = () => {
  const next = isDarkNow() ? 'dark' : 'light';
  if (next === theme.value) return;
  theme.value = next;
  try {
    frame.value?.contentWindow?.postMessage(
      { type: 'chatssync:theme', theme: next },
      BUILDER_URL
    );
  } catch (e) {
    /* ignore */
  }
};

const src = computed(() => {
  let u = `${BUILDER_URL}/?view=gallery`;
  if (accountId) u += (u.includes('?') ? '&' : '?') + `account_id=${accountId}`;
  if (csToken.value)
    u += (u.includes('?') ? '&' : '?') + 'token=' + encodeURIComponent(csToken.value);
  u += (u.includes('?') ? '&' : '?') + 'theme=' + theme.value;
  return u;
});

function collapseNavOnMobile() {
  if (typeof window === 'undefined' || window.innerWidth >= 1024) return;
  try { window.dispatchEvent(new Event('resize')); } catch (e) {}
  try { document.documentElement.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true })); } catch (e) {}
}

onMounted(() => {
  collapseNavOnMobile();
  setTimeout(collapseNavOnMobile, 250);
  themeObs = new MutationObserver(pushTheme);
  themeObs.observe(document.documentElement, { attributes: true });
  themeObs.observe(document.body, { attributes: true });
  // frame load hone ke baad ek baar aur — shayad woh pehla message miss kar de
  setTimeout(() => {
    try {
      frame.value?.contentWindow?.postMessage(
        { type: 'chatssync:theme', theme: theme.value },
        BUILDER_URL
      );
    } catch (e) {}
  }, 1200);
});

onBeforeUnmount(() => {
  if (themeObs) {
    themeObs.disconnect();
    themeObs = null;
  }
});
</script>

<template>
  <div style="width: 100%; height: 100%; display: flex; flex-direction: column">
    <iframe
      ref="frame"
      :src="src"
      style="width: 100%; height: 100%; border: 0"
      title="ChatsSync Gallery"
      allow="clipboard-write"
    />
  </div>
</template>
