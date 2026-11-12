import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/smart-features'),
      meta: {
        permissions: ['administrator'],
      },
      component: SettingsWrapper,
      props: {
        headerTitle: 'SMART_FEATURES.TITLE',
        icon: 'wand-sparkles',
        showNewButton: false,
      },
      children: [
        {
          path: '',
          name: 'smart_features_settings',
          component: Index,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
    {
      path: frontendURL('accounts/:accountId/settings/online-store'),
      meta: {
        permissions: ['administrator'],
      },
      component: SettingsWrapper,
      props: {
        headerTitle: 'SMART_FEATURES.STORE_PAGE.TITLE',
        icon: 'store',
        showNewButton: false,
      },
      children: [
        {
          path: '',
          name: 'online_store_settings',
          component: Index,
          props: { store: true },
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
