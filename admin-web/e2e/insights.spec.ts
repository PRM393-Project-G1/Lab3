import { expect, test } from '@playwright/test';

test('demo insights: ranges, chart hover and table view fit the viewport', async ({ page, isMobile }) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.goto('/demo/insights');
  await expect(page.getByRole('heading', { name: 'Insights.' })).toBeVisible();
  await expect(page.getByLabel('Analyses requested: 12')).toBeVisible();
  const columns = page.getByRole('group', { name: 'Analyses requested per day' }).getByRole('button');
  await expect(columns).toHaveCount(30);
  await columns.last().hover();
  await expect(page.locator('.chart-tooltip')).toContainText('requested');
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(page.viewportSize()!.width);
  if (!isMobile) {
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: '../docs/images/admin-insights-web-preview.png', fullPage: true });
  }
  await page.getByRole('button', { name: 'Last 7 days' }).click();
  await expect(columns).toHaveCount(7);
  await page.getByText('View as table').first().click();
  await expect(page.getByRole('columnheader', { name: 'Requested' })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(page.viewportSize()!.width);
  expect(errors).toEqual([]);
});
