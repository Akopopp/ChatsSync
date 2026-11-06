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
}

export default new SmartFeaturesAPI();
