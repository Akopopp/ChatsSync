import Gallery from './Gallery.vue';
import { frontendURL } from '../../../helper/URLHelper';

const routes = [
  {
    path: frontendURL('accounts/:accountId/gallery'),
    name: 'gallery_index',
    meta: {
      permissions: ['administrator', 'agent'],
    },
    component: Gallery,
  },
];

export default routes;
