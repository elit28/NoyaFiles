// Renders Design/AppIcon.svg into docs/images/icon.png for the README and, with
// --icon-set, into every size of the app's icon set.
//
// Usage: node Design/render-icon.js [--icon-set]     (needs Playwright with Chromium)
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const root = path.join(__dirname, '..');
const iconSet = path.join(root, 'NoyaFiles/Resources/Assets.xcassets/AppIcon.appiconset');

// The SVG refers to noya360-n.png; it is inlined so the browser can draw it.
const ribbon = fs.readFileSync(path.join(__dirname, 'noya360-n.png')).toString('base64');
const svg = fs
  .readFileSync(path.join(__dirname, 'AppIcon.svg'), 'utf8')
  .replace('href="noya360-n.png"', `href="data:image/png;base64,${ribbon}"`);

const iconSetOutputs = [
  ['icon_16x16.png', 16], ['icon_16x16@2x.png', 32],
  ['icon_32x32.png', 32], ['icon_32x32@2x.png', 64],
  ['icon_128x128.png', 128], ['icon_128x128@2x.png', 256],
  ['icon_256x256.png', 256], ['icon_256x256@2x.png', 512],
  ['icon_512x512.png', 512], ['icon_512x512@2x.png', 1024],
].map(([name, size]) => [path.join(iconSet, name), size]);
const outputs = [[path.join(root, 'docs/images/icon.png'), 256]];
if (process.argv.includes('--icon-set')) outputs.push(...iconSetOutputs);

(async () => {
  const browser = await chromium.launch();
  for (const [file, size] of outputs) {
    const page = await browser.newPage({ viewport: { width: size, height: size } });
    const sized = svg.replace('width="1024" height="1024"', `width="${size}" height="${size}"`);
    await page.setContent(`<html><body style="margin:0;background:transparent">${sized}</body></html>`);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    await page.locator('svg').screenshot({ path: file, omitBackground: true });
    await page.close();
    console.log(`Wrote ${path.relative(root, file)} (${size}×${size})`);
  }
  await browser.close();
})();
