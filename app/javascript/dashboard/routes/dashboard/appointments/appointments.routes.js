import { frontendURL } from '../../../helper/URLHelper';
import Calendar from './Calendar.vue';

export default [
  {
    path: frontendURL('accounts/:accountId/appointments'),
    name: 'appointments_calendar',
    meta: {
      permissions: ['administrator', 'agent'],
    },
    component: Calendar,
  },
];
