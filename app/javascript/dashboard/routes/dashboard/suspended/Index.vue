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
   button, na nikalne ka rasta. Ab neeche Logout hai taake woh doosre
   account se login kar sake.
   Chatwoot ka apna 'logout' action istemal hota hai (wahi jo profile
   menu mein hai). Kisi wajah se woh na chale to seedha login page. */
const doLogout = () => {
  const go = () => {
    window.location.href = '/app/login';
  };
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
