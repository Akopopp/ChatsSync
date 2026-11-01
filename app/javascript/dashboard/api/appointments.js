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

  freeTimes(params) {
    return axios.get(`${this.url}/free_times`, { params });
  }

  // data: { date, time, conversation_id, appointment: { service, customer_name, customer_phone, notes } }
  book(data) {
    return axios.post(this.url, data);
  }

  // data: { date, time } to move it, and/or { appointment: { status, notes } }
  change(id, data) {
    return axios.patch(`${this.url}/${id}`, data);
  }
}

export default new AppointmentsAPI();
