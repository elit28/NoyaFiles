// Renders background.html to background.png (1×) and background@2x.png (2×).
// Usage: node Design/dmg/render.js   (needs Playwright with Chromium)
const path = require('path');
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  for (const scale of [1, 2]) {
    const page = await browser.newPage({ viewport: { width: 660, height: 420 }, deviceScaleFactor: scale });
    await page.goto('file://' + path.join(__dirname, 'background.html'));
    const name = scale === 1 ? 'background.png' : 'background@2x.png';
    await page.screenshot({ path: path.join(__dirname, name) });
    await page.close();
    console.log('Wrote', name);
  }
  await browser.close();
})();
