<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

// Builder app ka URL (aapka deployed chatssync-builder)
const BUILDER_URL = 'http://zpzybpz68hsj0wvbpnar61in.5.75.237.171.sslip.io';

const accountId = useMapGetter('getCurrentAccountId');

// Account id builder ko bhejo (taake har account apna flow dekhe — 5.6 ke liye taiyaar)
const builderSrc = computed(
  () => `${BUILDER_URL}/?account_id=${accountId.value || ''}`
);
</script>

<template>
  <div class="flex flex-col w-full h-full bg-n-background">
    <iframe
      :src="builderSrc"
      class="w-full h-full border-0"
      title="ChatsSync Chatbot Builder"
      allow="clipboard-write"
    />
  </div>
</template>
