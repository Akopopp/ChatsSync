/* global axios */

import ApiClient from './ApiClient';

// Settings > Online store > "Your store": website, API key and product import.
class OnlineStoreAPI extends ApiClient {
  constructor() {
    super('online_store', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  // { platform, url, token, secret, remove_key }
  update(store) {
    return axios.patch(this.url, store);
  }

  importProducts() {
    return axios.post(`${this.url}/import_products`);
  }
}

export default new OnlineStoreAPI();
