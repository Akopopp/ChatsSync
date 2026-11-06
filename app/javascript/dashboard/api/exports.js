/* global axios */

import ApiClient from './ApiClient';

// "Download CSV" for orders and appointments.
class ExportsAPI extends ApiClient {
  constructor() {
    super('exports', { accountScoped: true });
  }

  // kind: 'orders' or 'appointments'; resolves to the CSV text.
  csv(kind) {
    return axios.get(`${this.url}/${kind}`, { responseType: 'text' });
  }
}

export default new ExportsAPI();
