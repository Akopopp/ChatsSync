<script setup>
/* ChatsSync — ab sirf apna Contacts screen mount karta hai.
   Chatwoot ka ContactsListLayout / ContactsList use nahi hota. */
import ContactsScreen from '../ContactsScreen.vue';
</script>

<template>
  <div class="cs-mount">
    <ContactsScreen />
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
