/*
 * Realtron: dựng phần còn lại của file Figma bằng Plugin API.
 *
 * Cách chạy: mở file Realtron trên trình duyệt (quyền edit), mở DevTools > Console,
 * dán toàn bộ file này rồi Enter. Chạy khoảng 1-3 phút. Có thể chạy lại:
 * page 01, 02, 04, 05 được dựng lại từ đầu, các bước sửa khác sẽ bỏ qua phần đã làm.
 *
 * Việc script làm:
 *   1. Page 04: Variables, Text styles, Effect styles và bảng trình bày.
 *   2. Page 03 + 06: sửa chữ và cấu trúc còn sót.
 *   3. Page 02: wireframe xám của 12 màn.
 *   4. Page 05: component kèm variant.
 *   5. Page 03 + 06: gắn màu, chữ, bóng, bo góc, khoảng cách vào token.
 *   6. Page 03: thay Bottom nav bằng instance.
 *   7. Page 06: sửa tương tác sai, đặt điểm bắt đầu.
 *   8. Page 01: sitemap và sơ đồ 3 flow.
 */
(async () => {
  const log = [];
  const step = async (name, fn) => {
    const started = Date.now();
    try {
      const result = await fn();
      log.push(`OK   ${name} (${((Date.now() - started) / 1000).toFixed(1)}s)${result ? ': ' + result : ''}`);
    } catch (e) {
      log.push(`LOI  ${name}: ${e && e.message}`);
      console.error(name, e);
    }
    console.log(log[log.length - 1]);
  };

  await figma.loadAllPagesAsync();
  const page = (n) => figma.root.children.find((p) => p.name.startsWith(n));
  const p1 = page('01'), p2 = page('02'), p3 = page('03'), p4 = page('04'), p5 = page('05'), p6 = page('06');
  for (const p of [p1, p2, p4, p5]) [...p.children].forEach((c) => c.remove());

  // ---------------------------------------------------------------- Tokens
  const COLORS = {
    'primary': '#1E3A8A', 'on-primary': '#FFFFFF',
    'primary-container': '#DCE1FF', 'on-primary-container': '#00164E',
    'background': '#F8FAFC', 'surface': '#FFFFFF',
    'surface-container': '#F1F5F9', 'surface-container-high': '#E2E8F0',
    'outline': '#64748B', 'outline-variant': '#E2E8F0',
    'text-primary': '#0F172A', 'text-secondary': '#475569', 'text-muted': '#64748B',
    'hallucinated': '#7E22CE', 'hallucinated-container': '#FAF5FF', 'hallucinated-border': '#E9D5FF',
    'error': '#B91C1C', 'error-container': '#FEF2F2', 'error-border': '#FECACA',
    'warning': '#92400E', 'warning-icon': '#D97706', 'warning-container': '#FFFBEB', 'warning-border': '#FDE68A',
    'verified': '#15803D', 'verified-container': '#F0FDF4', 'verified-border': '#BBF7D0',
    'unverified': '#475569', 'unverified-container': '#F8FAFC', 'unverified-border': '#E2E8F0',
  };
  const SPACE = { xs: 4, sm: 8, md: 16, lg: 24, xl: 32 };
  const RADIUS = { sm: 6, md: 8, lg: 12, xl: 24 };
  const SIZE = { 'min-tap': 48, 'input-height': 56 };

  // Màu Stitch đã dán (giá trị cứng) -> token của DESIGN.md.
  const COLOR_MAP = {
    '131B2E': 'text-primary', '0D1C2E': 'text-primary', '283044': 'text-primary', '0F172A': 'text-primary', '000000': 'text-primary',
    '515F74': 'text-secondary', '57657A': 'text-secondary', '444651': 'text-secondary', '3A485B': 'text-secondary', '475569': 'text-secondary',
    '757682': 'text-muted', '64748B': 'text-muted',
    '00236F': 'primary', '1E3A8A': 'primary',
    'FFFFFF': 'surface', 'FAF8FF': 'background', 'F8FAFC': 'background',
    'F2F3FF': 'surface-container', 'EAEDFF': 'surface-container', 'F1F5F9': 'surface-container',
    'E2E7FF': 'primary-container', 'DAE2FD': 'primary-container', 'D5E3FC': 'primary-container', 'DCE1FF': 'primary-container',
    '00164E': 'on-primary-container', 'C5C5D3': 'outline-variant', 'E2E8F0': 'outline-variant',
    'BA1A1A': 'error', '991B1B': 'error', 'B91C1C': 'error', '93000A': 'error', 'DC2626': 'error', 'E11D48': 'error',
    'FFDAD6': 'error-container', 'FEF2F2': 'error-container', 'FEE2E2': 'error-container', 'FCA5A5': 'error-border', 'FECACA': 'error-border',
    '6E2C00': 'hallucinated', '4B1C00': 'hallucinated', '341100': 'hallucinated', '7E22CE': 'hallucinated', '581C87': 'hallucinated', '6B21A8': 'hallucinated', '3B0764': 'hallucinated',
    'FFDBCB': 'hallucinated-container', 'FAF5FF': 'hallucinated-container',
    '92400E': 'warning', 'F39461': 'warning-icon', 'F59E0B': 'warning-icon', 'D97706': 'warning-icon',
    'FEF3C7': 'warning-container', 'FFFBEB': 'warning-container', 'FCD34D': 'warning-border', 'FDE68A': 'warning-border',
    '15803D': 'verified', '4059AA': 'verified', '047857': 'verified', '059669': 'verified', '065F46': 'verified', '064E3B': 'verified', '022C22': 'verified',
    'ECFDF5': 'verified-container', 'F0FDF4': 'verified-container',
    '94A3B8': 'unverified',
  };
  const BRAND_KEEP = new Set(['4285F4', '34A853', 'FBBC05', 'EA4335']); // logo Google

  const rgb = (hex) => {
    const h = hex.replace('#', '');
    return { r: parseInt(h.slice(0, 2), 16) / 255, g: parseInt(h.slice(2, 4), 16) / 255, b: parseInt(h.slice(4, 6), 16) / 255 };
  };
  const toHex = (c) => [c.r, c.g, c.b].map((v) => Math.round(v * 255).toString(16).padStart(2, '0')).join('').toUpperCase();

  const V = {};
  const TS = {};
  const FX = {};

  const FONTS = [
    { family: 'Inter', style: 'Regular' }, { family: 'Inter', style: 'Medium' }, { family: 'Inter', style: 'Semi Bold' }, { family: 'Inter', style: 'Bold' },
    { family: 'Source Serif 4', style: 'SemiBold' }, { family: 'JetBrains Mono', style: 'Regular' },
  ];
  for (const f of FONTS) await figma.loadFontAsync(f);

  await step('Tao Variables', async () => {
    const collections = await figma.variables.getLocalVariableCollectionsAsync();
    const col = collections.find((c) => c.name === 'Realtron tokens') || figma.variables.createVariableCollection('Realtron tokens');
    if (col.modes[0].name !== 'Light') col.renameMode(col.modes[0].modeId, 'Light');
    const mode = col.modes[0].modeId;
    const existing = await figma.variables.getLocalVariablesAsync();
    const make = (name, type, value, scopes) => {
      const v = existing.find((x) => x.name === name) || figma.variables.createVariable(name, col, type);
      v.setValueForMode(mode, value);
      if (scopes) v.scopes = scopes;
      V[name] = v;
    };
    for (const [k, hex] of Object.entries(COLORS)) make('color/' + k, 'COLOR', rgb(hex));
    for (const [k, n] of Object.entries(SPACE)) make('space/' + k, 'FLOAT', n, ['GAP']);
    for (const [k, n] of Object.entries(RADIUS)) make('radius/' + k, 'FLOAT', n, ['CORNER_RADIUS']);
    for (const [k, n] of Object.entries(SIZE)) make('size/' + k, 'FLOAT', n, ['WIDTH_HEIGHT']);
    return Object.keys(V).length + ' bien';
  });

  const P = (tok, opacity = 1) => figma.variables.setBoundVariableForPaint({ type: 'SOLID', color: rgb(COLORS[tok]), opacity }, 'color', V['color/' + tok]);

  await step('Tao Text styles', async () => {
    const defs = {
      'headline-lg': ['Source Serif 4', 'SemiBold', 28, 125, 0],
      'headline-md': ['Source Serif 4', 'SemiBold', 22, 130, 0],
      'paper-title': ['Source Serif 4', 'SemiBold', 18, 130, 0],
      'title-md': ['Inter', 'Semi Bold', 16, 140, 0],
      'body-lg': ['Inter', 'Regular', 16, 150, 0],
      'body-md': ['Inter', 'Regular', 14, 145, 0],
      'label': ['Inter', 'Semi Bold', 14, 140, 0],
      'overline': ['Inter', 'Semi Bold', 12, 130, 0.8],
      'chip': ['Inter', 'Semi Bold', 12, 130, 0],
      'mono': ['JetBrains Mono', 'Regular', 13, 140, 0],
    };
    const existing = await figma.getLocalTextStylesAsync();
    for (const [name, [family, style, size, lh, ls]] of Object.entries(defs)) {
      const s = existing.find((x) => x.name === name) || figma.createTextStyle();
      s.name = name;
      s.fontName = { family, style };
      s.fontSize = size;
      s.lineHeight = { unit: 'PERCENT', value: lh };
      s.letterSpacing = { unit: 'PIXELS', value: ls };
      TS[name] = s;
    }
    return Object.keys(TS).length + ' style';
  });

  await step('Tao Effect styles', async () => {
    const existing = await figma.getLocalEffectStylesAsync();
    const shadow = (a, y, r) => ({ type: 'DROP_SHADOW', color: { r: 15 / 255, g: 23 / 255, b: 42 / 255, a }, offset: { x: 0, y }, radius: r, spread: 0, visible: true, blendMode: 'NORMAL' });
    const defs = { 'elevation/1': shadow(0.05, 1, 3), 'elevation/2': shadow(0.08, 4, 12) };
    for (const [name, e] of Object.entries(defs)) {
      const s = existing.find((x) => x.name === name) || figma.createEffectStyle();
      s.name = name;
      s.effects = [e];
      FX[name] = s;
    }
    return '2 style';
  });

  // ---------------------------------------------------------------- Dựng node
  const ICONS = {
    check_circle: 'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z',
    error: 'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z',
    warning: 'M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z',
    help: 'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 17h-2v-2h2v2zm2.07-7.75l-.9.92C13.45 12.9 13 13.5 13 15h-2v-.5c0-1.1.45-2.1 1.17-2.83l1.24-1.26c.37-.36.59-.86.59-1.41 0-1.1-.9-2-2-2s-2 .9-2 2H8c0-2.21 1.79-4 4-4s4 1.79 4 4c0 .88-.36 1.68-.93 2.25z',
    gpp_bad: 'M12 2 4 5v6.09c0 5.05 3.41 9.76 8 10.91 4.59-1.15 8-5.86 8-10.91V5l-8-3zm3.5 12.09-1.41 1.41L12 13.42 9.91 15.5 8.5 14.09 10.59 12 8.5 9.91 9.91 8.5 12 10.59l2.09-2.09 1.41 1.41L13.42 12l2.08 2.09z',
    notifications: 'M12 22c1.1 0 2-.9 2-2h-4c0 1.1.9 2 2 2zm6-6v-5c0-3.07-1.63-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.64 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z',
    arrow_back: 'M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z',
    chevron_right: 'M10 6 8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z',
    expand_more: 'M16.59 8.59 12 13.17 7.41 8.59 6 10l6 6 6-6z',
    search: 'M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z',
    history: 'M13 3a9 9 0 0 0-9 9H1l3.89 3.89.07.14L9 12H6c0-3.87 3.13-7 7-7s7 3.13 7 7-3.13 7-7 7c-1.93 0-3.68-.79-4.94-2.06l-1.42 1.42A8.954 8.954 0 0 0 13 21a9 9 0 0 0 0-18zm-1 5v5l4.28 2.54.72-1.21-3.5-2.08V8H12z',
    person: 'M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z',
    description: 'M14 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z',
    more_vert: 'M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z',
    refresh: 'M17.65 6.35A7.958 7.958 0 0 0 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08A5.99 5.99 0 0 1 12 18c-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z',
    menu_book: 'M21 5c-1.11-.35-2.33-.5-3.5-.5-1.95 0-4.05.4-5.5 1.5-1.45-1.1-3.55-1.5-5.5-1.5S2.45 4.9 1 6v14.65c0 .25.25.5.5.5.1 0 .15-.05.25-.05C3.1 20.45 5.05 20 6.5 20c1.95 0 4.05.4 5.5 1.5 1.35-.85 3.8-1.5 5.5-1.5 1.65 0 3.35.3 4.75 1.05.1.05.15.05.25.05.25 0 .5-.25.5-.5V6c-.6-.45-1.25-.75-2-1zm0 13.5c-1.1-.35-2.3-.5-3.5-.5-1.7 0-4.15.65-5.5 1.5V8c1.35-.85 3.8-1.5 5.5-1.5 1.2 0 2.4.15 3.5.5v11.5z',
  };
  const STATUS = {
    Hallucinated: { fg: 'hallucinated', icon: 'hallucinated', bg: 'hallucinated-container', bd: 'hallucinated-border', i: 'gpp_bad' },
    Error: { fg: 'error', icon: 'error', bg: 'error-container', bd: 'error-border', i: 'error' },
    Warning: { fg: 'warning', icon: 'warning-icon', bg: 'warning-container', bd: 'warning-border', i: 'warning' },
    Unverified: { fg: 'unverified', icon: 'unverified', bg: 'unverified-container', bd: 'unverified-border', i: 'help' },
    Verified: { fg: 'verified', icon: 'verified', bg: 'verified-container', bd: 'verified-border', i: 'check_circle' },
  };

  const icon = (name, size = 16, color = 'text-secondary') => {
    const n = figma.createNodeFromSvg(`<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="${ICONS[name]}"/></svg>`);
    n.name = 'icon/' + name;
    n.fills = [];
    n.findAll((x) => x.type === 'VECTOR').forEach((v) => { v.fills = [P(color)]; });
    n.rescale(size / 24);
    return n;
  };
  const text = async (s, style = 'body-md', color = 'text-primary') => {
    const t = figma.createText();
    await t.setTextStyleIdAsync(TS[style].id);
    t.characters = s;
    t.fills = [P(color)];
    t.name = s.slice(0, 32);
    return t;
  };
  const bindRadius = (f, key) => {
    f.cornerRadius = RADIUS[key];
    for (const prop of ['topLeftRadius', 'topRightRadius', 'bottomLeftRadius', 'bottomRightRadius']) f.setBoundVariable(prop, V['radius/' + key]);
  };
  const fw = (n) => ({ __fw: true, n });
  const box = async (o = {}, kids = []) => {
    const f = figma.createFrame();
    const dir = o.dir || 'VERTICAL';
    f.name = o.name || 'Box';
    f.layoutMode = dir;
    f.fills = o.fill ? [P(o.fill, o.op === undefined ? 1 : o.op)] : [];
    f.clipsContent = false;
    const [pt, pr, pb, pl] = o.pad || [0, 0, 0, 0];
    f.paddingTop = pt; f.paddingRight = pr; f.paddingBottom = pb; f.paddingLeft = pl;
    f.itemSpacing = o.gap || 0;
    f.primaryAxisAlignItems = o.just || 'MIN';
    f.counterAxisAlignItems = o.align || 'MIN';
    f.primaryAxisSizingMode = 'AUTO';
    f.counterAxisSizingMode = 'AUTO';
    if (o.w || o.h) {
      f.resize(o.w || 10, o.h || 10);
      if (o.w) { if (dir === 'VERTICAL') f.counterAxisSizingMode = 'FIXED'; else f.primaryAxisSizingMode = 'FIXED'; }
      if (o.h) { if (dir === 'VERTICAL') f.primaryAxisSizingMode = 'FIXED'; else f.counterAxisSizingMode = 'FIXED'; }
    }
    if (o.stroke) { f.strokes = [P(o.stroke)]; f.strokeWeight = o.sw || 1; f.strokeAlign = 'INSIDE'; }
    if (o.r) bindRadius(f, o.r);
    if (o.pill) f.cornerRadius = 9999;
    if (o.fx) await f.setEffectStyleIdAsync(FX[o.fx].id);
    for (const k of kids) {
      if (!k) continue;
      const node = k.__fw ? k.n : k;
      f.appendChild(node);
      if (k.__fw) {
        if (node.type === 'TEXT') node.textAutoResize = 'HEIGHT';
        node.layoutSizingHorizontal = 'FILL';
      }
    }
    return f;
  };
  const row = (o, kids) => box({ dir: 'HORIZONTAL', align: 'CENTER', ...o }, kids);
  const swap = (node, withNode) => {
    const parent = node.parent;
    const i = parent.children.indexOf(node);
    parent.insertChild(i, withNode);
    node.remove();
  };
  const frameOn = (pg, name) => pg.findOne((n) => n.name === name && n.parent && n.parent.type === 'SECTION');
  const kid = (f, name) => f.children.find((c) => c.name === name);
  const textIn = (f, s) => f.findOne((n) => n.type === 'TEXT' && n.characters === s);
  const loadFontsOf = async (root) => {
    const seen = new Set();
    for (const t of root.findAll((n) => n.type === 'TEXT')) {
      if (t.hasMissingFont) continue;
      if (!t.characters.length) continue;
      for (const f of t.getRangeAllFontNames(0, t.characters.length)) {
        const k = f.family + '/' + f.style;
        if (!seen.has(k)) { seen.add(k); await figma.loadFontAsync(f); }
      }
    }
  };

  // ---------------------------------------------------------------- Page 04
  await step('Trinh bay page 04', async () => {
    await figma.setCurrentPageAsync(p4);
    const heading = async (s) => text(s, 'headline-md');
    const swatches = [];
    for (const [k, hex] of Object.entries(COLORS)) {
      const chip = await box({ name: 'swatch', w: 150, h: 64, fill: k, r: 'md', stroke: 'outline-variant' });
      swatches.push(await box({ name: k, gap: 4, w: 150 }, [chip, await text(k, 'chip'), await text(hex, 'mono', 'text-secondary')]));
    }
    const colorGrid = await box({ name: 'Colors', dir: 'HORIZONTAL', gap: 16, w: 1300 }, swatches);
    colorGrid.layoutWrap = 'WRAP';
    colorGrid.counterAxisSpacing = 24;
    const samples = [['headline-lg', 'Realtron'], ['headline-md', 'Paper Overview'], ['paper-title', 'Attention Is All You Need'], ['title-md', '9 topics · 2 weak'], ['body-lg', 'Know what a paper stands on.'], ['body-md', 'May be wrong — check the source.'], ['label', 'Analyze'], ['overline', 'TODAY'], ['chip', 'Hallucinated'], ['mono', 'arXiv:1706.03762']];
    const typeRows = [];
    for (const [s, sample] of samples) typeRows.push(await row({ name: s, gap: 24 }, [await box({ name: 'key', w: 160 }, [await text(s, 'chip', 'text-secondary')]), await text(sample, s)]));
    const spacing = [];
    for (const [k, n] of Object.entries(SPACE)) spacing.push(await box({ name: 'space/' + k, gap: 8, align: 'CENTER' }, [await box({ name: 'bar', w: n, h: 48, fill: 'primary' }), await text(`${k} ${n}`, 'chip', 'text-secondary')]));
    const radii = [];
    for (const [k, n] of Object.entries(RADIUS)) radii.push(await box({ name: 'radius/' + k, gap: 8, align: 'CENTER' }, [await box({ name: 'shape', w: 72, h: 72, fill: 'primary-container', r: k }), await text(`${k} ${n}`, 'chip', 'text-secondary')]));
    const elev = [];
    for (const k of Object.keys(FX)) elev.push(await box({ name: k, w: 200, h: 96, fill: 'surface', r: 'lg', fx: k, just: 'CENTER', align: 'CENTER' }, [await text(k, 'chip', 'text-secondary')]));
    const root = await box({ name: 'Design System', fill: 'background', pad: [48, 48, 48, 48], gap: 40, w: 1400 }, [
      await text('Academic Verifier', 'headline-lg'),
      await heading('Color variables'), colorGrid,
      await heading('Text styles'), await box({ name: 'Type', gap: 16 }, typeRows),
      await heading('Spacing'), await row({ name: 'Spacing', gap: 32 }, spacing),
      await heading('Radius'), await row({ name: 'Radius', gap: 32 }, radii),
      await heading('Elevation'), await row({ name: 'Elevation', gap: 32 }, elev),
    ]);
    p4.appendChild(root);
  });

  // ---------------------------------------------------------------- Sửa page 03 + 06
  const BELL_FRAMES = ['Analyze', 'Analyze — First use', 'Analyze — Invalid', 'Analyze — Server unreachable'];
  const EXPORT_FRAMES = ['Export: Creating PDF', 'Export: Uploading 64%', 'Export: Uploaded', 'Export — Upload failed'];

  for (const pg of [p3, p6]) {
    const tag = pg === p3 ? 'p03' : 'p06';
    await step(`Sua chu va cau truc ${tag}`, async () => {
      await figma.setCurrentPageAsync(pg);
      const done = [];

      const signIn = frameOn(pg, 'Sign In');
      const signHeader = signIn && kid(signIn, 'Header');
      if (signHeader) { signHeader.remove(); done.push('Sign In app bar'); }
      for (const name of ['Sign In', 'Sign In — Cancelled']) {
        const f = frameOn(pg, name);
        const logo = f && f.findOne((n) => n.name === 'Realtron Logo' && n.type === 'FRAME' && n.children.length === 0 && Math.abs(n.width - 56) < 1);
        if (logo) {
          logo.fills = [P('primary')];
          logo.layoutMode = 'HORIZONTAL';
          logo.primaryAxisAlignItems = 'CENTER';
          logo.counterAxisAlignItems = 'CENTER';
          logo.appendChild(icon('menu_book', 32, 'on-primary'));
          done.push('Logo ' + name);
        }
      }

      const noResults = frameOn(pg, 'History — No results');
      const longLine = noResults && noResults.findOne((n) => n.type === 'TEXT' && n.characters.startsWith('No papers or analyses'));
      if (longLine) { longLine.remove(); done.push('No results'); }

      // App bar: bỏ avatar, vì đã có tab Profile. Analyze dùng chuông, Overview dùng nút Report.
      const frames = pg.findAll((n) => n.parent && n.parent.type === 'SECTION' && n.type === 'FRAME');
      let avatars = 0;
      for (const f of frames) {
        const header = kid(f, 'Header');
        if (!header) continue;
        const circles = header.findAll((n) => n.type === 'FRAME' && Math.abs(n.width - 32) < 1 && Math.abs(n.height - 32) < 1 && n.name === 'Background');
        const avatar = circles[circles.length - 1];
        if (!avatar) continue;
        let top = avatar;
        while (top.parent.id !== header.id && top.parent.children.length === 1) top = top.parent;
        if (BELL_FRAMES.includes(f.name)) {
          const bell = await row({ name: 'Bell', w: 48, h: 48, just: 'CENTER' }, [icon('notifications', 24, 'text-secondary')]);
          swap(top, bell);
        } else if (f.name === 'Paper Overview') {
          const report = await row({ name: 'Report', h: 48, pad: [0, 8, 0, 8], just: 'CENTER' }, [await text('Report', 'label', 'primary')]);
          swap(top, report);
        } else {
          top.remove();
        }
        avatars++;
      }
      if (avatars) done.push(avatars + ' avatar');

      // Dialog phải phủ mờ hết frame.
      for (const name of ['History — Delete dialog', 'History — Rename dialog']) {
        const f = frameOn(pg, name);
        const modal = f && f.children.find((c) => c.name.startsWith('MODAL'));
        if (modal && Math.abs(modal.height - f.height) > 1) { modal.y = 0; modal.resize(modal.width, f.height); done.push('Scrim ' + name); }
      }

      // Nền của sheet Export: dùng đúng màn Paper Overview, bỏ chữ Stitch tự thêm.
      const overview = frameOn(pg, 'Paper Overview');
      for (const name of EXPORT_FRAMES) {
        const f = frameOn(pg, name);
        if (!f || kid(f, 'Main (Overview)')) continue;
        const main = kid(f, 'Main');
        const header = kid(f, 'Header');
        const sheet = f.children.find((c) => c.id !== main.id && c.id !== header.id);
        const clone = kid(overview, 'Main').clone();
        clone.name = 'Main (Overview)';
        for (const n of [clone, ...clone.findAll((x) => 'reactions' in x && x.reactions.length > 0)]) {
          if ('reactions' in n && n.reactions.length) await n.setReactionsAsync([]);
        }
        f.insertChild(0, clone);
        main.remove();
        f.primaryAxisSizingMode = 'FIXED';
        f.resize(390, 884);
        f.clipsContent = true;
        f.insertChild(1, header);
        const wrongTitle = textIn(header, 'Paper Verification Audit');
        if (wrongTitle) { await figma.loadFontAsync(wrongTitle.fontName); wrongTitle.characters = 'Paper Overview'; }
        if (sheet.height < 883) {
          const scrim = figma.createRectangle();
          scrim.name = 'Scrim';
          scrim.fills = [P('text-primary', 0.4)];
          f.insertChild(2, scrim);
          scrim.layoutPositioning = 'ABSOLUTE';
          scrim.x = 0; scrim.y = 0;
          scrim.resize(390, 884);
          sheet.y = 884 - sheet.height;
        }
        f.appendChild(sheet);
        done.push(name);
      }
      return done.join(', ') || 'khong con gi de sua';
    });
  }

  // ---------------------------------------------------------------- Page 02
  // Goi Spark khong co bucket: sheet Export ket thuc o "Saved on device".
  for (const pg of [p3, p6]) {
    await step(`Khung Export Saved ${pg === p3 ? 'p03' : 'p06'}`, async () => {
      await figma.setCurrentPageAsync(pg);
      const retext = async (frame, from, to) => {
        const t = frame && textIn(frame, from);
        if (!t) return false;
        await figma.loadFontAsync(t.fontName);
        t.characters = to;
        return true;
      };
      const done = [];
      if (await retext(frameOn(pg, 'Export — Upload failed'), 'Upload failed', 'Export failed')) done.push('Export failed');
      const uploaded = frameOn(pg, 'Export: Uploaded');
      if (uploaded && !frameOn(pg, 'Export: Saved')) {
        const section = uploaded.parent;
        const right = Math.max(...section.children.map((c) => c.x + c.width));
        const saved = uploaded.clone();
        section.appendChild(saved);
        saved.name = 'Export: Saved';
        saved.x = right + 80;
        saved.y = uploaded.y;
        section.resizeWithoutConstraints(Math.max(section.width, saved.x + saved.width + 80), section.height);
        for (const n of [saved, ...saved.findAll((x) => 'reactions' in x && x.reactions.length > 0)]) {
          if ('reactions' in n && n.reactions.length) await n.setReactionsAsync([]);
        }
        await retext(saved, 'Uploaded', 'Saved on device');
        await retext(saved, 'Copy link', 'Open');
        done.push('Export: Saved');
      }
      return done.join(', ');
    });
  }

  await step('Wireframe page 02', async () => {
    await figma.setCurrentPageAsync(p2);
    const screens = [['Connect Server', 0], ['Sign In', 1], ['Analyze', 2], ['Analysis in Progress', 3], ['Paper Overview', 4], ['Topic Map', 5], ['Topic Detail', 6], ['Reference List', 7], ['Reference Detail', 8], ['History', 9], ['Notifications', 10], ['Profile', 11]];
    const gray = (c) => {
      const l = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
      const v = l > 0.85 ? 0.97 : l > 0.6 ? 0.88 : l > 0.3 ? 0.62 : 0.35;
      return { r: v, g: v, b: v };
    };
    const strip = (arr) => arr.map((p) => {
      if (p.type !== 'SOLID') return p;
      const q = { type: 'SOLID', color: gray(p.color), opacity: p.opacity, visible: p.visible };
      return q;
    });
    let x = 0, y = 0, i = 0;
    for (const [name, n] of screens) {
      const src = frameOn(p3, name);
      if (!src) continue;
      const c = src.clone();
      p2.appendChild(c);
      c.name = `[${n}] ${name}`;
      c.x = x; c.y = y;
      for (const node of [c, ...c.findAll(() => true)]) {
        if ('fills' in node && Array.isArray(node.fills)) node.fills = strip(node.fills);
        if ('strokes' in node && Array.isArray(node.strokes)) node.strokes = strip(node.strokes);
        if ('effects' in node && node.effects.length) node.effects = [];
      }
      x += 450;
      if (++i % 6 === 0) { x = 0; y += 1400; }
    }
    return i + ' man';
  });

  // ---------------------------------------------------------------- Page 05
  let navComponents = {};
  await step('Component page 05', async () => {
    await figma.setCurrentPageAsync(p5);
    let cursor = 0;
    const place = (n) => { n.x = 0; n.y = cursor; cursor += n.height + 80; };
    const single = async (name, build) => { const c = figma.createComponentFromNode(await build()); c.name = name; p5.appendChild(c); place(c); return c; };
    const set = async (name, items, width = 1400) => {
      const comps = [];
      for (const [props, build] of items) {
        const c = figma.createComponentFromNode(await build());
        c.name = props;
        comps.push(c);
      }
      const s = figma.combineAsVariants(comps, p5);
      s.name = name;
      s.layoutMode = 'HORIZONTAL';
      s.layoutWrap = 'WRAP';
      s.itemSpacing = 24;
      s.counterAxisSpacing = 24;
      s.paddingTop = s.paddingRight = s.paddingBottom = s.paddingLeft = 24;
      s.primaryAxisSizingMode = 'FIXED';
      s.counterAxisSizingMode = 'AUTO';
      s.resize(width, s.height);
      place(s);
      return s;
    };

    const BUTTON = { Filled: ['primary', null, 'on-primary'], Outlined: [null, 'primary', 'primary'], Text: [null, null, 'primary'], Destructive: ['error', null, 'on-primary'] };
    const buttonItems = [];
    for (const [kind, [bg, bd, fg]] of Object.entries(BUTTON)) {
      for (const state of ['Default', 'Disabled', 'Loading']) {
        buttonItems.push([`Variant=${kind}, State=${state}`, async () => {
          const off = state === 'Disabled';
          const color = off ? 'text-muted' : fg;
          const fill = off && bg ? 'surface-container-high' : bg;
          const kids = state === 'Loading' ? [icon('refresh', 18, color)] : [await text('Analyze', 'label', color)];
          return row({ name: 'Button', fill, stroke: off && bd ? 'outline-variant' : bd, r: 'md', h: 48, w: 160, just: 'CENTER', pad: [0, 16, 0, 16], gap: 8 }, kids);
        }]);
      }
    }
    await set('Button', buttonItems);

    const fieldItem = (state, stroke, sw, helper, hColor) => [`State=${state}`, async () => box({ name: 'Text field', gap: 4, w: 320 }, [
      await row({ name: 'Input', h: 56, fill: 'surface', stroke, sw, r: 'md', pad: [0, 16, 0, 16], w: 320 }, [await text(state === 'Error' ? 'hello-world' : 'e.g. 1706.03762', 'mono', state === 'Error' ? 'text-primary' : 'text-muted')]),
      helper ? await text(helper, 'body-md', hColor) : null,
    ])];
    await set('Text field', [fieldItem('Default', 'outline', 1), fieldItem('Focused', 'primary', 2), fieldItem('Error', 'error', 2, 'Not a valid arXiv ID', 'error')]);

    await single('Card', async () => box({ name: 'Card', fill: 'surface', r: 'lg', fx: 'elevation/1', stroke: 'outline-variant', pad: [16, 16, 16, 16], w: 320, gap: 8 }, [await text('Card title', 'title-md'), await text('Card content', 'body-md', 'text-secondary')]));

    const chip = async (label) => {
      const s = STATUS[label];
      return row({ name: 'Status chip', fill: s.bg, stroke: s.bd, r: 'sm', pad: [4, 8, 4, 8], gap: 4 }, [icon(s.i, 14, s.icon), await text(label, 'chip', s.fg)]);
    };
    const chipItems = Object.keys(STATUS).map((k) => [`Status=${k}`, () => chip(k)]);
    chipItems.push(['Status=Checking', async () => row({ name: 'Status chip', fill: 'surface-container', stroke: 'outline-variant', r: 'sm', pad: [4, 8, 4, 8], gap: 4 }, [icon('refresh', 14, 'text-secondary'), await text('Checking', 'chip', 'text-secondary')])]);
    await set('Status chip', chipItems);

    await single('Weak tag', async () => row({ name: 'Weak tag', fill: 'error-container', stroke: 'error-border', r: 'sm', pad: [4, 8, 4, 8], gap: 4 }, [icon('warning', 14, 'error'), await text('Weak', 'chip', 'error')]));
    await set('Filter chip', [
      ['State=Selected', async () => row({ name: 'Filter chip', fill: 'primary', r: 'sm', h: 48, pad: [0, 16, 0, 16], gap: 8 }, [await text('All', 'label', 'on-primary'), await text('41', 'chip', 'on-primary')])],
      ['State=Unselected', async () => row({ name: 'Filter chip', fill: 'surface', stroke: 'outline-variant', r: 'sm', h: 48, pad: [0, 16, 0, 16], gap: 8 }, [await text('Weak', 'label', 'text-secondary'), await text('2', 'chip', 'text-secondary')])],
    ]);
    await single('Topic chip', async () => row({ name: 'Topic chip', fill: 'surface-container', r: 'sm', h: 48, pad: [0, 16, 0, 16], gap: 8 }, [await text('Attention mechanisms', 'label', 'text-primary')]));

    const tabs = [['Analyze', 'search'], ['History', 'history'], ['Profile', 'person']];
    const navItems = tabs.map(([active]) => [`Tab=${active}`, async () => {
      const kids = [];
      for (const [label, ic] of tabs) {
        const on = label === active;
        const pill = await row({ name: 'Indicator', w: 64, h: 32, just: 'CENTER', fill: on ? 'primary-container' : null, r: 'lg' }, [icon(ic, 24, on ? 'primary' : 'text-secondary')]);
        kids.push(await box({ name: label, w: 119, h: 64, align: 'CENTER', just: 'CENTER', gap: 2 }, [pill, await text(label, 'chip', on ? 'primary' : 'text-secondary')]));
      }
      return row({ name: 'Bottom nav', w: 390, h: 64, fill: 'surface', fx: 'elevation/2', just: 'CENTER', gap: 4 }, kids);
    }]);
    const navSet = await set('Bottom nav', navItems);
    navSet.children.forEach((c) => { navComponents[c.name.replace('Tab=', '')] = c; });

    const appBar = (kind) => async () => {
      const left = [];
      if (kind !== 'Title') left.push(await row({ name: 'Back', w: 48, h: 48, just: 'CENTER' }, [icon('arrow_back', 24, 'text-primary')]));
      left.push(await text('Paper Overview', 'title-md'));
      const kids = [await row({ name: 'Leading', gap: 4 }, left)];
      if (kind === 'Action') kids.push(await row({ name: 'Report', h: 48, pad: [0, 8, 0, 8], just: 'CENTER' }, [await text('Report', 'label', 'primary')]));
      return row({ name: 'App bar', w: 390, h: 56, fill: 'surface', just: 'SPACE_BETWEEN', pad: [0, 8, 0, kind === 'Title' ? 16 : 8] }, kids);
    };
    await set('App bar', [['Type=Title', appBar('Title')], ['Type=Back', appBar('Back')], ['Type=Action', appBar('Action')]]);
    await single('Section header', async () => row({ name: 'Section header', w: 358, just: 'SPACE_BETWEEN' }, [await text('TODAY', 'overline', 'text-secondary'), await text('2 analyses', 'chip', 'text-secondary')]));
    await single('Dialog', async () => box({ name: 'Dialog', w: 320, fill: 'surface', r: 'xl', fx: 'elevation/2', pad: [24, 24, 24, 24], gap: 16 }, [
      await text('Delete check?', 'headline-md'), await text('Removed from your history.', 'body-md', 'text-secondary'),
      await row({ name: 'Actions', w: 272, just: 'MAX', gap: 8 }, [await row({ h: 48, pad: [0, 12, 0, 12], name: 'Cancel' }, [await text('Cancel', 'label', 'primary')]), await row({ h: 48, pad: [0, 16, 0, 16], fill: 'error', r: 'md', name: 'Delete' }, [await text('Delete', 'label', 'on-primary')])]),
    ]));

    const banner = (kind, label, bg, bd, fg, ic, iconColor) => [`Tone=${kind}`, async () => row({ name: 'Banner', w: 358, fill: bg, stroke: bd, r: 'md', pad: [12, 12, 12, 12], gap: 8 }, [icon(ic, 20, iconColor || fg), await text(label, 'label', fg)])];
    await set('Banner', [
      banner('Error', "Can't reach server", 'error-container', 'error-border', 'error', 'error'),
      banner('Warning', 'Publication year mismatch', 'warning-container', 'warning-border', 'warning', 'warning', 'warning-icon'),
      banner('Success', 'Uploaded', 'verified-container', 'verified-border', 'verified', 'check_circle'),
      banner('Info', 'Weak: ≥ 50% refs have issues', 'surface-container', 'outline-variant', 'text-secondary', 'help'),
      banner('Offline', 'Offline · will resume', 'primary-container', 'primary-container', 'on-primary-container', 'refresh'),
    ]);

    const skeleton = async (w) => box({ name: 'Skeleton', w, h: 16, fill: 'surface-container-high', r: 'sm' });
    const stateView = (kind) => async () => {
      if (kind === 'Loading') return box({ name: 'State view', w: 358, gap: 12, pad: [24, 16, 24, 16] }, [await skeleton(240), await skeleton(326), await skeleton(280), await skeleton(326)]);
      const isError = kind === 'Error';
      const circle = await row({ name: 'Icon', w: 96, h: 96, just: 'CENTER', fill: isError ? 'error-container' : 'surface-container', pill: true }, [icon(isError ? 'error' : 'history', 44, isError ? 'error' : 'text-secondary')]);
      const action = await row({ name: 'Action', h: 48, fill: 'primary', r: 'md', pad: [0, 16, 0, 16] }, [await text(isError ? 'Retry' : 'Analyze a paper', 'label', 'on-primary')]);
      return box({ name: 'State view', w: 358, gap: 16, align: 'CENTER', pad: [24, 16, 24, 16] }, [circle, await text(isError ? "Couldn't load" : 'No checks yet', 'headline-md'), action]);
    };
    await set('State view', [['State=Loading', stateView('Loading')], ['State=Empty', stateView('Empty')], ['State=Error', stateView('Error')]]);

    const stacked = (w = 326) => row({ name: 'Stacked bar', w, h: 8, gap: 2 }, []).then(async (bar) => {
      for (const [tok, part] of [['hallucinated', 0.1], ['error', 0.15], ['warning-icon', 0.15], ['verified', 0.6]]) bar.appendChild(await box({ name: tok, w: Math.round(w * part) - 2, h: 8, fill: tok }));
      return bar;
    });
    await single('Stacked bar', () => stacked());

    const refCard = (kind) => async () => {
      const status = kind === 'Flagged' ? 'Hallucinated' : 'Verified';
      const kids = [await row({ name: 'Top', w: 326, just: 'SPACE_BETWEEN' }, [await chip(status), await text('[28]', 'mono', 'text-secondary')]), fw(await text('Generating sequences with recurrent neural networks', 'paper-title'))];
      if (kind !== 'Compact') kids.push(fw(await text('Graves · 2013', 'body-md', 'text-secondary')));
      if (kind === 'Flagged') kids.push(fw(await text('No matching publication found.', 'body-md', 'hallucinated')));
      if (kind === 'Full') kids.push(await text('arXiv:1308.0850', 'mono', 'text-secondary'));
      return box({ name: 'Reference card', w: 358, fill: 'surface', r: 'lg', stroke: 'outline-variant', fx: 'elevation/1', pad: [16, 16, 16, 16], gap: 8 }, kids);
    };
    await set('Reference card', [['Type=Full', refCard('Full')], ['Type=Compact', refCard('Compact')], ['Type=Flagged', refCard('Flagged')]]);

    const histCard = (kind) => async () => {
      const top = kind === 'Full' ? await chip('Verified') : kind === 'Failed' ? await chip('Error') : await row({ name: 'Running', fill: 'surface-container', r: 'sm', pad: [4, 8, 4, 8], gap: 4 }, [icon('refresh', 14, 'text-secondary'), await text('Running', 'chip', 'text-secondary')]);
      const kids = [await row({ name: 'Top', w: 326, just: 'SPACE_BETWEEN' }, [top, await row({ name: 'Menu', w: 48, h: 48, just: 'CENTER' }, [icon('more_vert', 24, 'text-secondary')])]), fw(await text('Attention Is All You Need', 'paper-title')), await text('arXiv:1706.03762', 'mono', 'text-secondary')];
      if (kind === 'Full') kids.push(await stacked());
      if (kind === 'In progress') kids.push(await text('18/41 refs', 'body-md', 'text-secondary'));
      if (kind === 'Failed') kids.push(await text('Analysis failed', 'body-md', 'error'));
      return box({ name: 'History card', w: 358, fill: 'surface', r: 'lg', stroke: 'outline-variant', fx: 'elevation/1', pad: [8, 16, 16, 16], gap: 8 }, kids);
    };
    await set('History card', [['State=Full', histCard('Full')], ['State=In progress', histCard('In progress')], ['State=Failed', histCard('Failed')]]);

    const topicNode = (kind) => async () => {
      const lead = kind === 'Collapsed' || kind === 'Weak' ? 'chevron_right' : kind === 'Expanded' ? 'expand_more' : kind === 'Unclassified' ? 'help' : null;
      const title = kind === 'Unclassified' ? 'Unclassified · 3' : kind === 'Leaf' ? 'Recurrent networks' : 'Neural networks';
      const head = [lead ? await row({ name: 'Toggle', w: 48, h: 48, just: 'CENTER' }, [icon(lead, 24, 'text-secondary')]) : null, await text(title, 'title-md')];
      const kids = [await row({ name: 'Head', w: 326, just: 'SPACE_BETWEEN' }, [await row({ name: 'Leading', gap: 4 }, head), kind === 'Weak' ? await row({ name: 'Weak tag', fill: 'error-container', stroke: 'error-border', r: 'sm', pad: [4, 8, 4, 8], gap: 4 }, [icon('warning', 14, 'error'), await text('Weak', 'chip', 'error')]) : null])];
      if (kind === 'Unclassified') kids.push(await text('No readable text', 'body-md', 'text-secondary'));
      else kids.push(await stacked());
      if (kind === 'Expanded') kids.push(await row({ name: 'Child', w: 326, fill: 'surface-container', r: 'md', pad: [8, 12, 8, 12] }, [await text('Attention mechanisms · 5 refs', 'body-md', 'text-secondary')]));
      return box({ name: 'Topic tree node', w: 358, fill: 'surface', r: 'lg', stroke: 'outline-variant', pad: [8, 16, 16, 16], gap: 8 }, kids);
    };
    await set('Topic tree node', ['Collapsed', 'Expanded', 'Weak', 'Leaf', 'Unclassified'].map((k) => [`State=${k}`, topicNode(k)]));

    const stepItem = (state) => async () => {
      const map = { Pending: ['surface-container', 'help', 'text-secondary', 'text-secondary'], Active: ['primary-container', 'refresh', 'primary', 'text-primary'], Done: ['verified-container', 'check_circle', 'verified', 'text-primary'], Failed: ['error-container', 'error', 'error', 'error'] }[state];
      return row({ name: 'Stepper step', w: 326, gap: 12 }, [await row({ name: 'Dot', w: 32, h: 32, just: 'CENTER', fill: map[0], pill: true }, [icon(map[1], 18, map[2])]), await text('Fabrication check', state === 'Pending' ? 'body-md' : 'label', map[3])]);
    };
    await set('Stepper step', ['Pending', 'Active', 'Done', 'Failed'].map((k) => [`State=${k}`, stepItem(k)]));

    const tile = (unread) => async () => row({ name: 'Notification tile', w: 358, fill: unread ? 'primary-container' : 'surface', r: 'lg', pad: [16, 16, 16, 16], gap: 12 }, [
      await box({ name: 'Unread dot', w: 10, h: 10, fill: unread ? 'primary' : null, pill: true }),
      await box({ name: 'Body', w: 296, gap: 4 }, [await text('Analysis done', 'title-md'), await text('Attention Is All You Need · 2 flagged', 'body-md', 'text-secondary')]),
    ]);
    await set('Notification tile', [['State=Unread', tile(true)], ['State=Read', tile(false)]]);

    const sheet = (kind) => async () => {
      const map = {
        Generating: ['Creating PDF…', 'description', 'primary'],
        Uploading: ['Uploading 64%', 'refresh', 'primary'],
        Success: ['Uploaded', 'check_circle', 'verified'],
        Saved: ['Saved on device', 'check_circle', 'verified'],
        Error: ['Export failed', 'error', 'error'],
      }[kind];
      const kids = [await text('Export report', 'title-md'), await row({ name: 'Status', gap: 8 }, [icon(map[1], 24, map[2]), await text(map[0], 'title-md', kind === 'Error' ? 'error' : 'text-primary')])];
      if (kind !== 'Generating' && kind !== 'Uploading') kids.push(await text('realtron_1706.03762.pdf · 214 KB', 'mono', 'text-secondary'));
      if (kind === 'Uploading') kids.push(await box({ name: 'Progress', w: 326, h: 8, fill: 'surface-container-high', r: 'sm' }));
      if (kind === 'Success') kids.push(await row({ name: 'Actions', gap: 8 }, [await row({ name: 'Copy link', h: 48, pad: [0, 16, 0, 16], stroke: 'primary', r: 'md' }, [await text('Copy link', 'label', 'primary')]), await row({ name: 'Share', h: 48, pad: [0, 16, 0, 16], fill: 'primary', r: 'md' }, [await text('Share', 'label', 'on-primary')])]));
      if (kind === 'Saved') kids.push(await row({ name: 'Actions', gap: 8 }, [await row({ name: 'Open', h: 48, pad: [0, 16, 0, 16], stroke: 'primary', r: 'md' }, [await text('Open', 'label', 'primary')]), await row({ name: 'Share', h: 48, pad: [0, 16, 0, 16], fill: 'primary', r: 'md' }, [await text('Share', 'label', 'on-primary')])]));
      if (kind === 'Error') kids.push(await row({ name: 'Retry', h: 48, pad: [0, 16, 0, 16], fill: 'primary', r: 'md' }, [await text('Retry', 'label', 'on-primary')]));
      return box({ name: 'Export sheet', w: 390, fill: 'surface', r: 'xl', fx: 'elevation/2', pad: [24, 16, 24, 16], gap: 16 }, kids);
    };
    await set('Export sheet', ['Generating', 'Uploading', 'Success', 'Saved', 'Error'].map((k) => [`State=${k}`, sheet(k)]));

    await single('Remote Config row', async () => row({ name: 'Remote Config row', w: 358, fill: 'surface-container', r: 'md', pad: [12, 12, 12, 12], just: 'SPACE_BETWEEN' }, [await text('weak_topic_threshold', 'mono', 'text-secondary'), await text('0.5', 'mono')]));
    await single('Cited / Actual row', async () => box({ name: 'Cited / Actual row', w: 358, fill: 'warning-container', stroke: 'warning-border', r: 'md', pad: [12, 12, 12, 12], gap: 8 }, [
      await text('YEAR', 'overline', 'warning'),
      await row({ name: 'Values', w: 334, just: 'SPACE_BETWEEN' }, [await row({ name: 'Cited', gap: 4 }, [await text('Cited', 'chip', 'text-secondary'), await text('2017', 'mono')]), await row({ name: 'Actual', gap: 4 }, [await text('Actual', 'chip', 'text-secondary'), await text('2016', 'mono')])]),
    ]));
    return `cao ${Math.round(cursor)}px`;
  });

  // ---------------------------------------------------------------- Gắn token cho page 03 + 06
  const textToken = (node, family, style, size) => {
    if (family === 'Source Serif 4') return size >= 26 ? 'headline-lg' : size >= 20 ? 'headline-md' : 'paper-title';
    if (family === 'JetBrains Mono') return 'mono';
    const s = node.characters.trim();
    const heavy = /Semi|Bold/.test(style);
    if (size <= 12 && s.length > 2 && s === s.toUpperCase() && /[A-Z]/.test(s)) return 'overline';
    if (size >= 15) return heavy || style === 'Medium' ? 'title-md' : 'body-lg';
    if (size >= 13) return heavy ? 'label' : 'body-md';
    if (size === 12 && !heavy) return 'body-md';
    return 'chip';
  };

  for (const pg of [p3, p6]) {
    const tag = pg === p3 ? 'p03' : 'p06';
    await step(`Gan token ${tag}`, async () => {
      await figma.setCurrentPageAsync(pg);
      for (const section of pg.children) await loadFontsOf(section);
      const unmapped = {};
      const count = { paint: 0, text: 0, effect: 0, radius: 0, space: 0, fail: 0 };
      const mapPaints = (paints, node) => {
        let changed = false;
        const next = paints.map((p) => {
          if (p.type !== 'SOLID' || (p.boundVariables && p.boundVariables.color)) return p;
          const key = toHex(p.color);
          if (BRAND_KEEP.has(key)) return p;
          let tok = COLOR_MAP[key];
          if (!tok) { unmapped[key] = (unmapped[key] || 0) + 1; return p; }
          if (node.type === 'TEXT' && tok === 'warning-icon') tok = 'warning'; // Amber không đạt 4.5:1 cho chữ
          if (node.type === 'TEXT' && /Verified/.test(node.characters) && key === '0D1C2E') tok = 'verified';
          if (node.type === 'FRAME' && key === 'D5E3FC' && node.findOne((n) => n.type === 'TEXT' && /Verified/.test(n.characters))) tok = 'verified-container';
          changed = true;
          count.paint++;
          return figma.variables.setBoundVariableForPaint(p, 'color', V['color/' + tok]);
        });
        return changed ? next : null;
      };
      const spaceKey = { 4: 'xs', 8: 'sm', 16: 'md', 24: 'lg', 32: 'xl' };
      for (const section of pg.children) {
        if (section.type !== 'SECTION') continue;
        for (const n of section.findAll(() => true)) {
          try {
            if ('fills' in n) {
              if (Array.isArray(n.fills)) { const f = mapPaints(n.fills, n); if (f) n.fills = f; }
              else if (n.type === 'TEXT') {
                for (const seg of n.getStyledTextSegments(['fills'])) { const f = mapPaints(seg.fills, n); if (f) n.setRangeFills(seg.start, seg.end, f); }
              }
            }
            if ('strokes' in n && Array.isArray(n.strokes) && n.strokes.length) { const f = mapPaints(n.strokes, n); if (f) n.strokes = f; }
            if (n.type === 'TEXT' && !n.textStyleId && !n.hasMissingFont) {
              const seg = n.getStyledTextSegments(['fontName', 'fontSize'])[0];
              await n.setTextStyleIdAsync(TS[textToken(n, seg.fontName.family, seg.fontName.style, seg.fontSize)].id);
              count.text++;
            }
            if ('effects' in n && n.effects.length && !n.effectStyleId) {
              const types = n.effects.map((e) => e.type);
              if (types.includes('DROP_SHADOW') && !types.includes('LAYER_BLUR')) {
                const r = Math.max(...n.effects.filter((e) => e.type === 'DROP_SHADOW').map((e) => e.radius));
                await n.setEffectStyleIdAsync(FX[r <= 4 ? 'elevation/1' : 'elevation/2'].id);
                count.effect++;
              }
            }
            if (typeof n.cornerRadius === 'number' && n.cornerRadius > 0 && 'setBoundVariable' in n) {
              const c = n.cornerRadius;
              let key = null;
              if (c === 4 || c === 6) key = 'sm';
              else if (c === 8) key = 'md';
              else if (c === 12) key = 'lg';
              else if (c === 16 || c === 24) key = 'xl';
              else if (c >= 999 && Math.abs(n.width - n.height) > 1 && n.height > 12) key = n.height <= 34 ? 'sm' : 'md';
              if (key) {
                for (const prop of ['topLeftRadius', 'topRightRadius', 'bottomLeftRadius', 'bottomRightRadius']) n.setBoundVariable(prop, V['radius/' + key]);
                count.radius++;
              }
            }
            if ('layoutMode' in n && n.layoutMode !== 'NONE') {
              for (const prop of ['itemSpacing', 'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft']) {
                const key = spaceKey[n[prop]];
                if (key) { n.setBoundVariable(prop, V['space/' + key]); count.space++; }
              }
            }
          } catch (e) {
            count.fail++;
            if (count.fail <= 5) console.warn(n.name, e && e.message);
          }
        }
      }
      return JSON.stringify(count) + (Object.keys(unmapped).length ? ' | mau chua gan: ' + JSON.stringify(unmapped) : '');
    });
  }

  // ---------------------------------------------------------------- Instance ở page 03
  await step('Bottom nav instance p03', async () => {
    await figma.setCurrentPageAsync(p3);
    const pick = (name) => (name.startsWith('History') ? 'History' : name.startsWith('Profile') ? 'Profile' : 'Analyze');
    let n = 0;
    for (const f of p3.findAll((x) => x.parent && x.parent.type === 'SECTION' && x.type === 'FRAME')) {
      const nav = kid(f, 'Nav');
      if (!nav || !navComponents[pick(f.name)]) continue;
      const inst = navComponents[pick(f.name)].createInstance();
      const { x, y } = nav;
      const i = f.children.indexOf(nav);
      f.insertChild(i, inst);
      inst.layoutPositioning = 'ABSOLUTE';
      inst.x = x; inst.y = y;
      inst.name = 'Nav';
      nav.remove();
      n++;
    }
    return n + ' instance';
  });

  // ---------------------------------------------------------------- Prototype
  await step('Sua prototype p06', async () => {
    await figma.setCurrentPageAsync(p6);
    const nav = (dest, trigger = { type: 'ON_CLICK' }) => [{ trigger, actions: [{ type: 'NODE', destinationId: dest.id, navigation: 'NAVIGATE', transition: null, resetVideoPosition: false }] }];
    const f = (name) => frameOn(p6, name);
    const done = [];
    const seeAll = textIn(f('Analyze'), 'See all');
    if (seeAll) { await seeAll.setReactionsAsync(nav(f('Analyze — Server unreachable'))); done.push('See all'); }
    await f('History — Loading').setReactionsAsync(nav(f('History'), { type: 'AFTER_TIMEOUT', timeout: 1.5 }));
    await f('Export: Creating PDF').setReactionsAsync(nav(f('Export: Saved') || f('Export: Uploading 64%'), { type: 'AFTER_TIMEOUT', timeout: 1.5 }));
    done.push('Loading', 'Creating PDF');
    const savedDone = f('Export: Saved') && textIn(f('Export: Saved'), 'Done');
    if (savedDone) { await savedDone.setReactionsAsync(nav(f('Paper Overview'))); done.push('Saved Done'); }
    const creatingCancel = textIn(f('Export: Creating PDF'), 'Cancel');
    if (creatingCancel) { await creatingCancel.setReactionsAsync(nav(f('Export — Upload failed'))); done.push('Creating Cancel'); }
    const bell = f('Analyze').findOne((n) => n.name === 'Bell');
    if (bell) { await bell.setReactionsAsync(nav(f('Notifications'))); done.push('Bell'); }
    const overview = f('Paper Overview');
    const report = overview.findOne((n) => n.name === 'Report');
    if (report) {
      for (const n of overview.findAll((x) => x.id !== report.id && 'reactions' in x && x.reactions.some((r) => r.actions && r.actions[0] && r.actions[0].destinationId === f('Export: Creating PDF').id))) await n.setReactionsAsync([]);
      await report.setReactionsAsync(nav(f('Export: Creating PDF')));
      done.push('Report');
    }
    const unclassified = f('Topic Map').findOne((n) => n.type === 'TEXT' && n.characters === 'Unclassified');
    if (unclassified) { await unclassified.setReactionsAsync(nav(f('Reference List'))); done.push('Unclassified'); }
    p6.flowStartingPoints = [
      { nodeId: f('Sign In').id, name: 'Entry' },
      { nodeId: f('Analyze').id, name: 'Flow A: Analyze a paper' },
      { nodeId: overview.id, name: 'Flow B: Find weak topics' },
      { nodeId: f('History').id, name: 'Flow C: History and report' },
    ];
    done.push('4 starting points');
    return done.join(', ');
  });

  // ---------------------------------------------------------------- Page 01
  await step('User flow page 01', async () => {
    await figma.setCurrentPageAsync(p1);
    const W = 200, H = 72, GX = 70, GY = 56;
    const EDGE = { happy: 'primary', alt: 'warning-icon', error: 'error' };
    const arrow = async (pts, kind) => {
      const minX = Math.min(...pts.map((p) => p[0]));
      const minY = Math.min(...pts.map((p) => p[1]));
      const v = figma.createVector();
      await v.setVectorNetworkAsync({
        vertices: pts.map((p, i) => ({ x: p[0] - minX, y: p[1] - minY, strokeCap: i === pts.length - 1 ? 'ARROW_LINES' : 'NONE' })),
        segments: pts.slice(1).map((_, i) => ({ start: i, end: i + 1 })),
        regions: [],
      });
      v.strokes = [P(EDGE[kind])];
      v.strokeWeight = 2;
      if (kind === 'alt') v.dashPattern = [8, 4];
      if (kind === 'error') v.dashPattern = [2, 4];
      v.x = minX; v.y = minY;
      v.name = 'arrow/' + kind;
      p1.appendChild(v);
    };
    const drawFlow = async (title, ox, oy, nodes, edges) => {
      const t = await text(title, 'headline-md');
      p1.appendChild(t);
      t.x = ox; t.y = oy;
      const at = {};
      for (const [id, label, col, rowIdx, kind] of nodes) {
        const fill = kind === 'error' ? 'error-container' : kind === 'alt' ? 'warning-container' : 'surface';
        const stroke = kind === 'error' ? 'error-border' : kind === 'alt' ? 'warning-border' : 'primary';
        const b = await box({ name: id, w: W, h: H, fill, stroke, r: 'md', just: 'CENTER', pad: [8, 12, 8, 12] }, [fw(await text(label, 'label'))]);
        p1.appendChild(b);
        b.x = ox + col * (W + GX);
        b.y = oy + 56 + rowIdx * (H + GY);
        at[id] = b;
      }
      for (const [a, b, kind, label] of edges) {
        const s = at[a], d = at[b];
        let pts;
        if (Math.abs(s.y - d.y) < 1 && d.x > s.x) pts = [[s.x + W, s.y + H / 2], [d.x, d.y + H / 2]];
        else if (Math.abs(s.y - d.y) < 1) { const y = s.y + H + 16; pts = [[s.x + W / 2, s.y + H], [s.x + W / 2, y], [d.x + W / 2, y], [d.x + W / 2, d.y + H]]; }
        else if (d.y > s.y) { const y = d.y - GY / 2; pts = [[s.x + W / 2, s.y + H], [s.x + W / 2, y], [d.x + W / 2, y], [d.x + W / 2, d.y]]; }
        else { const y = d.y + H + GY / 2; pts = [[s.x + W / 2, s.y], [s.x + W / 2, y], [d.x + W / 2, y], [d.x + W / 2, d.y + H]]; }
        await arrow(pts, kind);
        if (label) {
          const tag = await row({ name: 'label', fill: 'background', pad: [2, 6, 2, 6] }, [await text(label, 'chip', 'text-secondary')]);
          p1.appendChild(tag);
          const m = pts[Math.floor((pts.length - 1) / 2)], n = pts[Math.floor((pts.length - 1) / 2) + 1];
          tag.x = (m[0] + n[0]) / 2 - tag.width / 2;
          tag.y = (m[1] + n[1]) / 2 - tag.height / 2;
        }
      }
    };

    const legend = await row({ name: 'Legend', gap: 24 }, [
      await text('Happy: solid', 'label', 'primary'), await text('Alternate: dashed', 'label', 'warning'), await text('Error: dotted', 'label', 'error'),
    ]);
    const heading = await text('Realtron: Sitemap and user flows', 'headline-lg');
    p1.appendChild(heading); heading.x = 0; heading.y = 0;
    p1.appendChild(legend); legend.x = 0; legend.y = 56;

    await drawFlow('Sitemap', 0, 130, [
      ['s1', '[1] Sign-in', 0, 0], ['s0', '[0] Connect server', 1, 0], ['s2', '[2] Analyze', 2, 0], ['s9', '[9] History', 3, 0], ['s11', '[11] Profile', 4, 0],
      ['s10', '[10] Notifications', 2, 1], ['s3', '[3] Analyzing', 1, 1], ['s4', '[4] Paper Overview', 3, 1],
      ['s5', '[5] Topics', 2, 2], ['s7', '[7] References', 4, 2], ['s6', '[6] Topic', 2, 3], ['s8', '[8] Reference', 4, 3],
    ], [
      ['s1', 's0', 'happy'], ['s0', 's2', 'happy'], ['s2', 's9', 'happy'], ['s9', 's11', 'happy'], ['s2', 's10', 'happy'], ['s2', 's3', 'happy'], ['s9', 's4', 'happy'],
      ['s4', 's5', 'happy'], ['s4', 's7', 'happy'], ['s5', 's6', 'happy'], ['s7', 's8', 'happy'],
    ]);

    await drawFlow('Flow A: Analyze a paper', 0, 800, [
      ['a2', '[2] Analyze', 0, 1], ['a3', '[3] Analyzing', 1, 1], ['a3d', '[3] Done', 2, 1], ['a4', '[4] Paper Overview', 3, 1],
      ['a1', 'A1 Already analyzed', 2, 0, 'alt'], ['as', 'A2 Share from browser', 0, 0, 'alt'], ['ab', 'A3 Run in background', 1, 0, 'alt'], ['ap', 'Analysis done (push)', 3, 0, 'alt'],
      ['e1', 'A-E1 Not a valid arXiv ID', 0, 2, 'error'], ['e5', "A-E5 Can't reach server", 0, 3, 'error'], ['s0', '[0] Connect server', 1, 3, 'alt'],
      ['e2', 'A-E2 Analysis failed', 1, 2, 'error'], ['e3', 'A-E3 Offline · will resume', 2, 2, 'error'], ['e4', 'A-E4 Stop analysis?', 3, 2, 'error'],
    ], [
      ['a2', 'a3', 'happy', 'Analyze'], ['a3', 'a3d', 'happy'], ['a3d', 'a4', 'happy', 'View results'],
      ['as', 'a2', 'alt'], ['a3', 'ab', 'alt', 'Run in background'], ['ab', 'a1', 'alt'], ['a1', 'ap', 'alt'], ['ap', 'a4', 'alt', 'Tap'],
      ['a2', 'e1', 'error'], ['e1', 'e5', 'error'], ['e5', 's0', 'alt', 'Change server'], ['a3', 'e2', 'error'], ['a3', 'e3', 'error'], ['a3', 'e4', 'error', 'Stop'],
    ]);

    await drawFlow('Flow B: Find weak topics', 0, 1500, [
      ['b4', '[4] Paper Overview', 0, 1], ['b5', '[5] Topics', 1, 1], ['b6', '[6] Topic', 2, 1], ['b8', '[8] Reference', 3, 1], ['bfix', 'Fix copied', 4, 1],
      ['b1', 'B1 Tap a weak topic', 1, 0, 'alt'], ['b2', 'B2 Subtopic', 2, 0, 'alt'], ['b4c', 'B4 Topic chip', 3, 0, 'alt'], ['b3', 'B3 Likely fabricated', 4, 0, 'alt'],
      ['be1', 'B-E1 No weak topics', 1, 2, 'error'], ['be2', 'B-E2 Unclassified · 3', 0, 2, 'error'], ['b7', '[7] References', 0, 3, 'alt'], ['be3', "B-E3 Couldn't load", 2, 2, 'error'],
    ], [
      ['b4', 'b5', 'happy', 'Explore'], ['b5', 'b6', 'happy', 'Weak'], ['b6', 'b8', 'happy'], ['b8', 'bfix', 'happy', 'Copy fix'],
      ['b1', 'b2', 'alt'], ['b2', 'b6', 'alt'], ['b4c', 'b6', 'alt'], ['b8', 'b3', 'alt'],
      ['b5', 'be1', 'error'], ['b5', 'be2', 'error'], ['be2', 'b7', 'alt'], ['b6', 'be3', 'error'],
    ]);

    await drawFlow('Flow C: History and report', 0, 2200, [
      ['c9', '[9] History', 0, 1], ['c4', '[4] Paper Overview', 1, 1], ['cp', 'Creating PDF…', 2, 1], ['cs', 'Saved on device', 3, 1], ['cu', 'Uploading 64% (upload on)', 4, 0, 'alt'], ['cd', 'Uploaded', 4, 1, 'alt'],
      ['c1', 'C1 No results', 0, 0, 'alt'], ['c2', 'C2 Rename', 1, 0, 'alt'], ['c3', 'C3 [10] Analysis done', 2, 0, 'alt'], ['c4r', 'C4 Running: [3]', 3, 0, 'alt'],
      ['ce1', 'C-E1 Export failed', 3, 2, 'error'], ['ce2', "C-E2 Couldn't load", 0, 2, 'error'], ['ce3', 'C-E3 No checks yet', 1, 2, 'error'], ['ce4', 'C-E4 Delete check?', 2, 2, 'error'],
    ], [
      ['c9', 'c4', 'happy'], ['c4', 'cp', 'happy', 'Report'], ['cp', 'cs', 'happy'], ['cp', 'cu', 'alt'], ['cu', 'cd', 'alt'],
      ['c9', 'c1', 'alt', 'Search'], ['c9', 'c2', 'alt'], ['c3', 'c4', 'alt'], ['c9', 'c4r', 'alt'],
      ['cp', 'ce1', 'error'], ['c9', 'ce2', 'error'], ['c9', 'ce3', 'error'], ['c9', 'ce4', 'error'],
    ]);
  });

  await figma.setCurrentPageAsync(p6);
  console.log('=== REALTRON XONG ===\n' + log.join('\n'));
  figma.notify('Realtron: xong. Xem kết quả trong Console.');
  return log;
})();
