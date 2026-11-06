import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/whatsapp-forms'),
      meta: {
        permissions: ['administrator'],
      },
      component: SettingsWrapper,
      props: {
        headerTitle: 'WHATSAPP_FORMS.TITLE',
        icon: 'clipboard-list',
        showNewButton: false,
      },
      children: [
        {
          path: '',
          name: 'whatsapp_forms_settings',
          component: Index,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
