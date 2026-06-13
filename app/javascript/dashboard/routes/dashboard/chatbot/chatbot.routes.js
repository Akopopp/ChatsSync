import ChatbotBuilder from './ChatbotBuilder.vue';
import { frontendURL } from '../../../helper/URLHelper';

const routes = [
  {
    path: frontendURL('accounts/:accountId/chatbot'),
    name: 'chatbot_builder',
    meta: {
      permissions: ['administrator', 'agent'],
    },
    component: ChatbotBuilder,
  },
];

export default routes;
