import { request } from './client';

export const dashboardApi = {
  summary: () => request('/api/dashboard/summary'),
};
