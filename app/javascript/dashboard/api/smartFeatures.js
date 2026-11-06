/* global axios */

import ApiClient from './ApiClient';

class SmartFeaturesAPI extends ApiClient {
  constructor() {
    super('smart_features', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  update(smartFeatures) {
    return axios.patch(this.url, { smart_features: smartFeatures });
  }

  // params: { inbox_id, label_ids: [], segments: [], category }
  broadcastEstimate(params = {}) {
    return axios.get(`${this.url}/broadcast_estimate`, { params });
  }
}

export default new SmartFeaturesAPI();
