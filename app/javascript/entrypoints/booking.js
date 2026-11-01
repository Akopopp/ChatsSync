import { createApp } from 'vue';
import { createI18n } from 'vue-i18n';
import App from '../booking/App.vue';
import en from '../booking/i18n/en.json';

const app = createApp(App);
app.use(createI18n({ legacy: false, locale: 'en', messages: { en } }));

window.onload = () => {
  app.mount('#app');
};
