<script setup>
import { ref, computed, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useEmitter } from 'dashboard/composables/emitter';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import {
  isAConversationRoute,
  isAInboxViewRoute,
  isNotificationRoute,
} from 'dashboard/helper/routeHelpers';
import { useEventListener } from '@vueuse/core';

import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const route = useRoute();

const RECONNECTED_BANNER_TIMEOUT = 2000;

/* ===== BANNER KAB DIKHE =====
   PEHLE websocket toot-te hi FORAN banner aa jaata tha, aur jur-ne ke
   baad "Reconnected" 2 second aur dikhta tha. Yani ek second ka toot-na
   bhi 3-4 second ka banner ban jaata tha — awam ko yahi bura lagta tha.

   Chatwoot khud maanta hai ke websocket ka toot-na 3 second tak pata
   hi nahi chalta (ReconnectService.js mein DISCONNECT_DELAY_THRESHOLD
   = 15), yani halka sa toot-na aam baat hai.

   Ab websocket wale waqeaat par 8 second ka intezaar. Us se pehle jur
   gaya to banner dikhta hi nahi — WhatsApp ki tarah khamoshi se kaam
   ho jaata hai. Data phir bhi taaza hota hai, woh ReconnectService ke
   onReconnect mein hota hai; is banner se uska koi taalluq nahi.

   Browser ka ASLI offline (net band) foran dikhta hai — woh sahi hai. */
const WS_BANNER_DELAY = 8000;
let wsBannerTimer = null;

const clearWsBannerTimer = () => {
  clearTimeout(wsBannerTimer);
  wsBannerTimer = null;
};

const showBannerAfterDelay = () => {
  if (wsBannerTimer) return;
  wsBannerTimer = setTimeout(() => {
    wsBannerTimer = null;
    showNotification.value = true;
  }, WS_BANNER_DELAY);
};

const showNotification = ref(!navigator.onLine);
const isDisconnected = ref(false);
const isReconnecting = ref(false);
const isReconnected = ref(false);
let reconnectTimeout = null;

const bannerText = computed(() => {
  if (isReconnecting.value) return t('NETWORK.NOTIFICATION.RECONNECTING');
  if (isReconnected.value) return t('NETWORK.NOTIFICATION.RECONNECT_SUCCESS');
  return t('NETWORK.NOTIFICATION.OFFLINE');
});

const iconName = computed(() => (isReconnected.value ? 'wifi' : 'wifi-off'));
const canRefresh = computed(
  () => !isReconnecting.value && !isReconnected.value
);

const refreshPage = () => {
  window.location.reload();
};

const closeNotification = () => {
  showNotification.value = false;
  isReconnected.value = false;
  clearTimeout(reconnectTimeout);
  clearWsBannerTimer();
};

const isInAnyOfTheRoutes = routeName => {
  return (
    isAConversationRoute(routeName, true) ||
    isAInboxViewRoute(routeName, true) ||
    isNotificationRoute(routeName, true)
  );
};

const updateWebsocketStatus = () => {
  isDisconnected.value = true;
  // foran nahi — 8 second se pehle jur gaya to banner dikhega hi nahi
  showBannerAfterDelay();
};

const handleReconnectionCompleted = () => {
  clearWsBannerTimer();
  isDisconnected.value = false;
  isReconnecting.value = false;
  // banner dikha hi nahi tha to "Reconnected" bhi mat dikhao —
  // khamoshi se kaam ho gaya
  if (!showNotification.value) {
    isReconnected.value = false;
    return;
  }
  isReconnected.value = true;
  showNotification.value = true;
  reconnectTimeout = setTimeout(closeNotification, RECONNECTED_BANNER_TIMEOUT);
};

const handleReconnecting = () => {
  if (isInAnyOfTheRoutes(route.name)) {
    isReconnecting.value = true;
    isReconnected.value = false;
    showBannerAfterDelay();
  } else {
    handleReconnectionCompleted();
  }
};

const updateOnlineStatus = event => {
  // Case: Websocket is not disconnected
  // If the app goes offline, show the notification
  // If the app goes online, close the notification

  // Case: Websocket is disconnected
  // If the app goes offline, show the notification
  // If the app goes online but the websocket is disconnected, don't close the notification
  // If the app goes online and the websocket is not disconnected, close the notification

  if (event.type === 'offline') {
    showNotification.value = true;
  } else if (event.type === 'online' && !isDisconnected.value) {
    handleReconnectionCompleted();
  }
};

useEventListener('online', updateOnlineStatus);
useEventListener('offline', updateOnlineStatus);
useEmitter(BUS_EVENTS.WEBSOCKET_DISCONNECT, updateWebsocketStatus);
useEmitter(
  BUS_EVENTS.WEBSOCKET_RECONNECT_COMPLETED,
  handleReconnectionCompleted
);
useEmitter(BUS_EVENTS.WEBSOCKET_RECONNECT, handleReconnecting);

onBeforeUnmount(() => {
  clearWsBannerTimer();
  clearTimeout(reconnectTimeout);
});
</script>

<template>
  <transition name="network-notification-fade" tag="div">
    <div v-show="showNotification" class="fixed z-50 top-2 left-2 group">
      <div
        class="relative flex items-center justify-between w-full px-2 py-1 bg-n-amber-4 dark:bg-n-amber-8 rounded-lg shadow-lg"
      >
        <fluent-icon :icon="iconName" class="text-n-amber-12" size="18" />
        <span class="px-2 text-xs font-medium tracking-wide text-n-amber-12">
          {{ bannerText }}
        </span>
        <Button
          v-if="canRefresh"
          ghost
          sm
          amber
          icon="i-lucide-refresh-ccw"
          :title="$t('NETWORK.BUTTON.REFRESH')"
          class="!text-n-amber-12 dark:!text-n-amber-9"
          @click="refreshPage"
        />

        <Button
          ghost
          sm
          amber
          icon="i-lucide-x"
          class="!text-n-amber-12 dark:!text-n-amber-9"
          @click="closeNotification"
        />
      </div>
    </div>
  </transition>
</template>
