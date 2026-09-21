<script setup>
/* ChatsSync — ab sirf apna Inbox screen mount karta hai.
   Chatwoot ka purana notifications list use nahi hota. */
import InboxScreen from './InboxScreen.vue';
</script>

<template>
  <div class="cs-mount">
    <InboxScreen />
  </div>
</template>

<style scoped>
.cs-mount {
  display: flex;
  flex: 1;
  width: 100%;
  height: 100%;
  min-width: 0;
  min-height: 0;
}
</style>
