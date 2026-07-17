import { test, expect } from '@playwright/test';

test.describe('Subscription API E2E', () => {

  test('GET /ping returns alive', async ({ request }) => {
    const response = await request.get('/ping');
    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(body.status).toBe('alive');
  });

  test('POST /api/subscriptions creates a subscription', async ({ request }) => {
    const response = await request.post('/api/subscriptions', {
      data: {
        customerName: 'E2E User',
        email: 'e2e@test.com',
        plan: 'Premium',
        amount: 99.99,
      },
    });
    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.customerName).toBe('E2E User');
  });

  test('GET /api/subscriptions returns list', async ({ request }) => {
    const response = await request.get('/api/subscriptions');
    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(Array.isArray(body)).toBeTruthy();
  });

});