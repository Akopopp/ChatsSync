<script setup>
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import { onMounted } from 'vue';
import { useStore } from 'vuex';

const store = useStore();

const toggleSupportWidgetVisibility = () => {
  if (window.$chatwoot) {
    window.$chatwoot.toggleBubbleVisibility('show');
  }
};

const setupListenerForWidgetEvent = () => {
  window.addEventListener('chatwoot:on-message', () => {
    toggleSupportWidgetVisibility();
  });
};

/* Plan expire hone par banda is page par phas jaata tha — na koi
   button, na nikalne ka rasta. Ab neeche Logout hai.

   PEHLE sirf store.dispatch('logout') aur phir /app/login par bhej
   dete the. Masla ye tha ke session ki cookie baaqi reh jaati thi, to
   Chatwoot login page par dekh kar wapas account par bhej deta tha —
   aur account suspended hai, to ghoom kar wahi page.

   Ab teen cheezein: server par sign_out, phir cookies khud saaf, phir
   redirect. Cookie mit gayi to Chatwoot wapas nahi bhej sakta. */
const clearSession = () => {
  ['cw_d_session_info', 'auth_data', 'user'].forEach(name => {
    try {
      document.cookie =
        name + '=; Max-Age=0; path=/; SameSite=Lax';
      document.cookie =
        name + '=; Max-Age=0; path=/; domain=' + window.location.hostname;
    } catch (e) {
      /* ignore */
    }
  });
  try {
    localStorage.clear();
    sessionStorage.clear();
  } catch (e) {
    /* ignore */
  }
};

const doLogout = () => {
  const go = () => {
    clearSession();
    // replace() taake back button wapas yahin na le aaye
    window.location.replace('/app/login');
  };

  // Chatwoot ka apna endpoint — session server par bhi khatam ho
  fetch('/auth/sign_out', {
    method: 'DELETE',
    credentials: 'same-origin',
    headers: { 'Content-Type': 'application/json' },
  })
    .catch(() => {})
    .finally(() => {
      try {
        const r = store.dispatch('logout');
        if (r && typeof r.then === 'function') {
          r.then(go).catch(go);
          return;
        }
      } catch (e) {
        /* ignore */
      }
      go();
    });
};

onMounted(() => {
  toggleSupportWidgetVisibility();
  setupListenerForWidgetEvent();
});
</script>

<template>
  <div class="items-center bg-n-slate-2 flex justify-center h-full w-full">
    <div class="flex flex-col items-center gap-6">
      <EmptyState
        :title="$t('APP_GLOBAL.ACCOUNT_SUSPENDED.TITLE')"
        :message="$t('APP_GLOBAL.ACCOUNT_SUSPENDED.MESSAGE')"
      />
      <button type="button" class="cs-logout" @click="doLogout">
        <span class="i-lucide-log-out" />
        <span>Logout</span>
      </button>
    </div>
  </div>
</template>

<style scoped>
.cs-logout {
  display: inline-flex;
  align-items: center;
  gap: 9px;
  border: 0;
  border-radius: 22px;
  background: #00a884;
  color: #fff;
  font-family: inherit;
  font-size: 14px;
  font-weight: 500;
  padding: 10px 26px;
  cursor: pointer;
  transition: filter 0.13s ease;
}
.cs-logout:hover {
  filter: brightness(1.08);
}
.cs-logout span[class*='i-'] {
  width: 17px;
  height: 17px;
}
</style>
