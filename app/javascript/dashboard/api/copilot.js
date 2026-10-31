/* global axios */

import ApiClient from './ApiClient';

class CopilotAPI extends ApiClient {
  constructor() {
    super('copilot', { accountScoped: true });
  }

  chat(messages) {
    return axios.post(`${this.url}/chat`, { messages });
  }

  confirm(action) {
    return axios.post(`${this.url}/confirm`, {
      tool: action.tool,
      args: action.args,
    });
  }
}

export default new CopilotAPI();
