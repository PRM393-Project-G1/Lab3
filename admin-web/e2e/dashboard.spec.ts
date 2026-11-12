import { expect, test } from '@playwright/test';

test('demo dashboard, filters, pagination and reference details', async ({ page, isMobile }) => {
  const errors: string[] = [];
  const externalRequests: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('request', (request) => {
    if (!request.url().startsWith('http://127.0.0.1:5174/')) externalRequests.push(request.url());
  });
  await page.goto('/');
  await page.getByRole('link', { name: 'Explore demo workspace' }).click();
  await expect(page.getByRole('heading', { name: 'Analysis overview.' })).toBeVisible();
  await expect(page.getByLabel('Total analyses: 12')).toBeVisible();
  await expect(page.getByText('Sample data', { exact: true })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(page.viewportSize()!.width);
  if (!isMobile) {
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: '../docs/images/admin-dashboard-web-preview.png', fullPage: true });
  }
  await page.getByRole('button', { name: 'Failed 2', exact: true }).click();
  if (isMobile) await expect(page.locator('.mobile-analysis-card')).toHaveCount(2);
  else await expect(page.getByRole('table').getByRole('row')).toHaveCount(3);
  await page.getByRole('textbox').fill('does not exist');
  await expect(page.getByRole('heading', { name: 'No matching analyses' })).toBeVisible();
  await page.getByRole('button', { name: 'Clear filters' }).click();
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(page.viewportSize()!.width);
  await page.getByRole('button', { name: 'Next page' }).click();
  await expect(page.getByText('Page 2 of 2')).toBeVisible();
  await page.getByRole('textbox').fill('1706.03762');
  await page.getByRole('link', { name: 'Attention Is All You Need', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Attention Is All You Need', exact: true })).toBeVisible();
  await expect(page.getByText('Attention mechanisms', { exact: true })).toBeVisible();
  await expect(page.getByText('Weak', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'References 41', exact: true }).click();
  await page.getByLabel('Reference status', { exact: true }).selectOption('error');
  await page.locator('.reference-item summary').first().click();
  await expect(page.locator('.reference-item[open]').getByText('Cited', { exact: true })).toBeVisible();
  await expect(page.locator('.reference-item[open]').getByText('Actual', { exact: true })).toBeVisible();
  await page.getByRole('link', { name: 'Back to analyses' }).click();
  if (isMobile) await page.getByRole('button', { name: 'Open navigation' }).click();
  await page.getByRole('link', { name: 'Exit demo', exact: true }).click();
  await expect(page.getByText('Connect your Firebase Web app', { exact: true })).toBeVisible();
  expect(errors).toEqual([]);
  expect(externalRequests).toEqual([]);
});

test('direct links, browser reload, failed detail and unknown pages work', async ({ page }) => {
  await page.goto('/demo/analyses/1508.04025');
  await expect(page.getByRole('heading', { name: 'Analysis status', exact: true })).toBeVisible();
  await expect(page.getByText(/Couldn't extract topics/)).toBeVisible();
  await page.reload();
  await expect(page.getByText(/Couldn't extract topics/)).toBeVisible();
  await page.goto('/demo/analyses/malformed');
  await expect(page.getByText('This analysis ID is not valid.')).toBeVisible();
  await page.goto('/demo/unknown');
  await expect(page.getByRole('heading', { name: 'Page not found' })).toBeVisible();
  await page.getByRole('link', { name: 'Go to overview' }).click();
  await expect(page.getByRole('heading', { name: 'Analysis overview.' })).toBeVisible();
});
