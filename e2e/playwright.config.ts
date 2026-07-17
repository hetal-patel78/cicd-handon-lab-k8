import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 30000,
  retries: 1,
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:5210',
    extraHTTPHeaders: {
      'Content-Type': 'application/json',
    },
  },
});