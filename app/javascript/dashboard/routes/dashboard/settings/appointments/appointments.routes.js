import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/appointments'),
      meta: {
        permissions: ['administrator'],
      },
      component: SettingsWrapper,
      props: {
        headerTitle: 'APPOINTMENTS.TITLE',
        icon: 'calendar',
        showNewButton: false,
      },
      children: [
        {
          path: '',
          name: 'appointments_settings',
          component: Index,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
