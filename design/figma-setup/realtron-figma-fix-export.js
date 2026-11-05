/*
 * Realtron: sửa prototype của sheet Export trên page 06.
 * Chỉ chạy sau realtron-figma-setup.js. Dán vào Console như script đó. Có thể chạy lại.
 *
 *   1. Export: Saved > Done về Paper Overview. Khung này chưa có đường ra.
 *   2. Export: Creating PDF > Cancel sang Export failed, để Present thấy được nhánh C-E1.
 */
(async () => {
  await figma.loadAllPagesAsync();
  const p6 = figma.root.children.find((p) => p.name.startsWith('06'));
  await figma.setCurrentPageAsync(p6);
  const frame = (name) => p6.findOne((n) => n.name === name && n.parent && n.parent.type === 'SECTION');
  const textIn = (f, s) => f.findOne((n) => n.type === 'TEXT' && n.characters === s);
  const nav = (dest) => [{ trigger: { type: 'ON_CLICK' }, actions: [{ type: 'NODE', destinationId: dest.id, navigation: 'NAVIGATE', transition: null, resetVideoPosition: false }] }];

  await textIn(frame('Export: Saved'), 'Done').setReactionsAsync(nav(frame('Paper Overview')));
  await textIn(frame('Export: Creating PDF'), 'Cancel').setReactionsAsync(nav(frame('Export — Upload failed')));

  console.log('=== REALTRON EXPORT XONG ===');
  figma.notify('Realtron: đã sửa prototype Export.');
})();
