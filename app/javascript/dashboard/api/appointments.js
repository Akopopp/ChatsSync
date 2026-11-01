/* global axios */

import ApiClient from './ApiClient';

class AppointmentsAPI extends ApiClient {
  constructor() {
    super('appointments', { accountScoped: true });
  }

  getSetting() {
    return axios.get(`${this.baseUrl()}/appointment_setting`);
  }

  updateSetting(setting) {
    return axios.patch(`${this.baseUrl()}/appointment_setting`, {
      appointment_setting: setting,
    });
  }

  list(params = {}) {
    return axios.get(this.url, { params });
  }

  setStatus(id, status) {
    return axios.patch(`${this.url}/${id}`, { appointment: { status } });
  }
}

export default new AppointmentsAPI();
