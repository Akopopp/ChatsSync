/* global axios */

import ApiClient from './ApiClient';

class PlanUsageAPI extends ApiClient {
  constructor() {
    super('plan_usage', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }
}

export default new PlanUsageAPI();
