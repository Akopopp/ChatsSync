import Templates from './Templates.vue';
import { frontendURL } from '../../../helper/URLHelper';
const routes = [
  {
    path: frontendURL('accounts/:accountId/templates'),
    name: 'templates_index',
    meta: {
      permissions: ['administrator'],
    },
    component: Templates,
  },
];
export default routes;
