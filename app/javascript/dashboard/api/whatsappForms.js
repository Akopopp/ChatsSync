/* global axios */

import ApiClient from './ApiClient';

// Settings > WhatsApp forms, and sending a form from a WhatsApp chat.
class WhatsappFormsAPI extends ApiClient {
  constructor() {
    super('whatsapp_forms', { accountScoped: true });
  }

  // All forms, for the settings page (admins).
  all() {
    return axios.get(this.url, { params: { all: 1 } });
  }

  // Forms that can be sent in a chat (only when the feature is on).
  available() {
    return axios.get(this.url);
  }

  create(form) {
    return axios.post(this.url, { whatsapp_form: form });
  }

  update(id, form) {
    return axios.patch(`${this.url}/${id}`, { whatsapp_form: form });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  deliver(id, conversationId) {
    return axios.post(`${this.url}/${id}/deliver`, {
      conversation_id: conversationId,
    });
  }

  responsesCsv(id) {
    return axios.get(`${this.url}/${id}/responses`, { responseType: 'text' });
  }
}

export default new WhatsappFormsAPI();
