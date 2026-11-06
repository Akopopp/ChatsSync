/* global axios */

import ApiClient from './ApiClient';

class AiAgentAPI extends ApiClient {
  constructor() {
    super('ai_agent', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  update(aiAgent) {
    return axios.patch(this.url, { ai_agent: aiAgent });
  }

  preview(message) {
    return axios.post(`${this.url}/preview`, { message });
  }

  generateFaqs() {
    return axios.post(`${this.url}/generate_faqs`);
  }

  // Draft business name and info from one public page; nothing is saved.
  importWebsite(url) {
    return axios.post(`${this.url}/import_website`, { url });
  }
}

export default new AiAgentAPI();
