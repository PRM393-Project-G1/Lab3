import { expect, test } from '@playwright/test';

test('selected and all-user announcements require confirmation and show simulated history', async ({ page, isMobile }) => {
  const errors: string[] = [];
  const outside: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('request', (request) => { if (!request.url().startsWith('http://127.0.0.1:5174/')) outside.push(request.url()); });
  await page.goto('/demo/notifications');
  await expect(page.getByRole('heading', { name: 'Notifications.' })).toBeVisible();
  await expect(page.getByText('No announcements yet', { exact: true })).toBeVisible();
  await page.getByRole('textbox', { name: /^Title/ }).fill('Release notice');
  await page.getByRole('textbox', { name: /^Message/ }).fill('Realtron has a new update.');
  await page.getByRole('button', { name: 'Review message' }).click();
  await expect(page.getByRole('alert')).toHaveText('Select at least one user.');
  await page.getByRole('checkbox', { name: /Linh Nguyen/ }).check();
  await page.getByRole('button', { name: 'Review message' }).click();
  const dialog = page.getByRole('dialog', { name: 'Confirm announcement' });
  await expect(dialog.getByText('Send to 1 selected user?', { exact: true })).toBeVisible();
  await expect(dialog.getByText('Linh Nguyen', { exact: true })).toBeVisible();
  await dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
  await expect(page.getByText('No announcements yet', { exact: true })).toBeVisible();
  if (!isMobile) {
    await page.evaluate(async () => { await document.fonts.ready; window.scrollTo(0, 0); });
    await page.screenshot({ path: '../docs/images/admin-notifications-web-preview.png', fullPage: true });
  }
  await page.getByRole('button', { name: 'Review message' }).click();
  await dialog.getByRole('button', { name: 'Confirm send' }).click();
  await expect(page.getByRole('status')).toHaveText('Demo message simulated. No notifications were sent.');
  const selected = page.locator('.announcement-item').filter({ hasText: 'Release notice' });
  await expect(selected.getByText('Completed', { exact: true })).toBeVisible();
  await expect(selected.locator('dl > div').filter({ hasText: 'Inbox stored' }).locator('dd')).toHaveText('1');

  await page.getByRole('radio', { name: /All users/ }).check();
  await page.getByRole('textbox', { name: /^Title/ }).fill('Broadcast update');
  await page.getByRole('textbox', { name: /^Message/ }).fill('This message is for everyone.');
  await page.getByRole('button', { name: 'Review message' }).click();
  await expect(dialog.getByText('Send to all users (3 currently listed)?', { exact: true })).toBeVisible();
  await dialog.getByRole('button', { name: 'Confirm send' }).click();
  const all = page.locator('.announcement-item').filter({ hasText: 'Broadcast update' });
  await expect(all.locator('dl > div').filter({ hasText: 'Inbox stored' }).locator('dd')).toHaveText('3');
  await expect(all.locator('dl > div').filter({ hasText: 'FCM accepted' }).locator('dd')).toHaveText('2');
  await expect(all.locator('dl > div').filter({ hasText: 'Without device' }).locator('dd')).toHaveText('1');
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(page.viewportSize()!.width);
  expect(errors).toEqual([]);
  expect(outside).toEqual([]);
});
