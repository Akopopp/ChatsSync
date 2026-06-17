<script setup>
const BUILDER_URL = 'https://zpzybpz68hsj0wvbpnar61in.5.75.237.171.sslip.io';
</script>

<template>
  <div style="width: 100%; height: 100%; display: flex; flex-direction: column;">
    <iframe
      :src="`${BUILDER_URL}/?view=gallery`"
      style="width: 100%; height: 100%; border: 0;"
      title="ChatsSync Gallery"
      allow="clipboard-write"
    />
  </div>
</template>
