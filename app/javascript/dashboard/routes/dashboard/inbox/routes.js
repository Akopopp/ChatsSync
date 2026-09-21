import { frontendURL } from 'dashboard/helper/URLHelper';
import InboxListView from './InboxList.vue';
import InboxDetailView from './InboxView.vue';
import InboxEmptyStateView from './InboxEmptyState.vue';
// ChatsSync ka apna Dashboard tab
import DashboardScreen from '../dashboard-cs/DashboardScreen.vue';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/inbox-view'),
    component: InboxListView,
    children: [
      {
        path: '',
        name: 'inbox_view',
        component: InboxEmptyStateView,
        meta: {
          permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
        },
      },
      {
        path: ':type/:id',
        name: 'inbox_view_conversation',
        component: InboxDetailView,
        meta: {
          permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
        },
      },
    ],
  },
  // Dashboard yahan isliye hai ke routes.js files khud-ba-khud merge
  // hoti hain. Baad mein apni routes.js mein le jaa sakte hain.
  {
    path: frontendURL('accounts/:accountId/insights'),
    name: 'chatssync_dashboard',
    component: DashboardScreen,
    meta: {
      permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
    },
  },
];
