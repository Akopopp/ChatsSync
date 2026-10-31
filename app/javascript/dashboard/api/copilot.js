/* global axios */

import ApiClient from './ApiClient';

class CopilotAPI extends ApiClient {
  constructor() {
    super('copilot', { accountScoped: true });
  }

  chat(messages, uploads = {}) {
    return axios.post(`${this.url}/chat`, { messages, uploads });
  }

  upload(file) {
    const formData = new FormData();
    formData.append('file', file);
    return axios.post(`${this.url}/upload`, formData);
  }

  confirm(action) {
    return axios.post(`${this.url}/confirm`, {
      tool: action.tool,
      args: action.args,
    });
  }
}

export default new CopilotAPI();
