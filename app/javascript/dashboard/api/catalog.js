/* global axios */

import ApiClient from './ApiClient';

const productForm = product => {
  const form = new FormData();
  Object.entries(product).forEach(([key, value]) => {
    if (value !== null && value !== undefined) form.append(key, value);
  });
  return form;
};

class CatalogAPI extends ApiClient {
  constructor() {
    super('products', { accountScoped: true });
  }

  getSetting() {
    return axios.get(`${this.baseUrl()}/catalog_setting`);
  }

  updateSetting(setting) {
    return axios.patch(`${this.baseUrl()}/catalog_setting`, {
      catalog_setting: setting,
    });
  }

  createProduct(product) {
    return axios.post(this.url, productForm(product));
  }

  updateProduct(id, product) {
    return axios.patch(`${this.url}/${id}`, productForm(product));
  }

  getOrders(params = {}) {
    return axios.get(`${this.baseUrl()}/orders`, { params });
  }

  setOrderStatus(id, status) {
    return axios.patch(`${this.baseUrl()}/orders/${id}`, { order: { status } });
  }
}

export default new CatalogAPI();
