import { createApp } from 'vue';
import { createI18n } from 'vue-i18n';
import App from '../booking/App.vue';
import Menu from '../booking/Menu.vue';
import en from '../booking/i18n/en.json';
import '../survey/assets/scss/woot.scss';

// One small public app for both pages: /book/:token and /menu/:token.
const isMenu = window.location.pathname.startsWith('/menu/');
const app = createApp(isMenu ? Menu : App);
app.use(createI18n({ legacy: false, locale: 'en', messages: { en } }));

window.onload = () => {
  app.mount('#app');
};
