import { request } from './client';

export const productsApi = {
  list: ({ page = 1, pageSize = 10, search = '', categoryId = '', lowStock = false } = {}) => {
    const params = new URLSearchParams({ page: String(page), pageSize: String(pageSize) });
    if (search) params.set('search', search);
    if (categoryId) params.set('categoryId', categoryId);
    if (lowStock) params.set('lowStock', 'true');
    return request(`/api/products?${params.toString()}`);
  },
  get: (id) => request(`/api/products/${id}`),
  create: (payload) => request('/api/products', { method: 'POST', body: payload }),
  update: (id, payload) => request(`/api/products/${id}`, { method: 'PUT', body: payload }),
  remove: (id) => request(`/api/products/${id}`, { method: 'DELETE' }),
};
