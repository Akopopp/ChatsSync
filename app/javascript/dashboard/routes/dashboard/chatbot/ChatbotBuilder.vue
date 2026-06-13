<template>
  <div class="chatbot-container">
    <iframe
      :src="typebotUrl"
      frameborder="0"
      width="100%"
      height="100%"
      allow="clipboard-read; clipboard-write"
    />
  </div>
</template>

<script>
export default {
  computed: {
    typebotUrl() {
      return 'https://typebot.5.75.237.171.sslip.io';
    },
  },
};
</script>

<style scoped>
.chatbot-container {
  width: 100%;
  height: 100vh;
  overflow: hidden;
}
</style>
