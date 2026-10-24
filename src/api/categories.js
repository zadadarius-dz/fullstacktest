import { request } from './client';

export const categoriesApi = {
  list: () => request('/api/categories'),
  get: (id) => request(`/api/categories/${id}`),
  create: (payload) => request('/api/categories', { method: 'POST', body: payload }),
  update: (id, payload) => request(`/api/categories/${id}`, { method: 'PUT', body: payload }),
  remove: (id) => request(`/api/categories/${id}`, { method: 'DELETE' }),
};
