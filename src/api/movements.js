import { request } from './client';

export const movementsApi = {
  createForProduct: (productId, payload) =>
    request(`/api/products/${productId}/movements`, { method: 'POST', body: payload }),
  listForProduct: (productId, { page = 1, pageSize = 20 } = {}) =>
    request(
      `/api/products/${productId}/movements?page=${page}&pageSize=${pageSize}`,
    ),
  listAll: ({ page = 1, pageSize = 20 } = {}) =>
    request(`/api/stock-movements?page=${page}&pageSize=${pageSize}`),
};
