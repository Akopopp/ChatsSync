/* global axios */

import ApiClient from './ApiClient';

class AiKnowledgeItemsAPI extends ApiClient {
  constructor() {
    super('ai_knowledge_items', { accountScoped: true });
  }

  createWithImage({ question, answer, image }) {
    const formData = new FormData();
    formData.append('kind', 'image');
    formData.append('question', question);
    formData.append('answer', answer || '');
    formData.append('image', image);
    return axios.post(this.url, formData);
  }
}

export default new AiKnowledgeItemsAPI();
