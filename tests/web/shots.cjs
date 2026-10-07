// Loads the web export in headless Chromium and takes screenshots for presets.
// Usage: node shots.cjs <playwright-module-dir> <base-url> <out-dir> [preset ...]
const path = require('path');
const { chromium } = require(path.join(process.argv[2], 'playwright'));
const base = process.argv[3];
const out = process.argv[4];
const PRESETS = {
  title: { q: 'time=10&season=1&weather=0', wait: 9000 },
  overview: { q: 'time=11&season=1&weather=0&freeze=1&cam=-10,60,95,10,0,0', wait: 8000 },
  pond: { q: 'time=10&season=0&weather=0&freeze=1&cam=30,12,40,45,0,6', wait: 8000 },
  pavilion: { q: 'time=16&season=1&weather=0&freeze=1&cam=-14,4,-42,-24,2.5,-52', wait: 8000 },
  food: { q: 'time=13&season=1&weather=0&freeze=1&cam=6,7,30,6,1,48', wait: 8000 },
  bridge: { q: 'time=9&season=2&weather=0&freeze=1&cam=-2,4,6,-8,0,-8', wait: 8000 },
  night: { q: 'time=22.5&season=1&weather=0&freeze=1&cam=-40,10,30,-56,1,18', wait: 8000 },
  winter: { q: 'time=12&season=3&weather=4&freeze=1&cam=60,20,-20,90,4,-58', wait: 9000 },
  play_jens: { q: 'time=10&season=1&weather=0&control=jens', wait: 9000 },
  play_dog: { q: 'time=11&season=1&weather=0&control=bello', wait: 9000 },
  play_duck: { q: 'time=11&season=0&weather=0&control=erwin', wait: 9000 },
  rain: { q: 'time=15&season=2&weather=2&control=peggy', wait: 9000 },
  mg_boule: { q: 'time=11&season=1&weather=0&control=jens&minigame=boule', wait: 12000 },
  mg_minigolf: { q: 'time=11&season=1&weather=0&control=jens&minigame=minigolf', wait: 10000 },
  mg_shell: { q: 'time=14&season=1&weather=0&control=jens&minigame=shell', wait: 9000 },
  mg_ttt: { q: 'time=14&season=1&weather=0&control=jens&minigame=ttt', wait: 9000 },
  mg_photo: { q: 'time=14&season=1&weather=0&control=jens&minigame=photo', wait: 9000 },
  mg_ducks: { q: 'time=14&season=1&weather=0&control=jens&minigame=ducks', wait: 12000 },
  mg_frisbee: { q: 'time=14&season=1&weather=0&control=jens&minigame=frisbee', wait: 9000 },
  map: { q: 'time=14&season=1&weather=0&control=jens&ui=map', wait: 8000 },
  tasks: { q: 'time=14&season=1&weather=0&control=jens&ui=tasks', wait: 8000 },
  start: { q: 'time=9&season=0&weather=0', wait: 9000 },
  people1: { q: 'time=12&season=1&weather=0&freeze=1&lineup=jens,herbert,peggy,heinz,dora,kemal', wait: 7000 },
  people2: { q: 'time=12&season=1&weather=0&freeze=1&lineup=mia,boris,pierre,thorsten,gertrud,lena,sabine', wait: 7000 },
  people3: { q: 'time=12&season=1&weather=0&freeze=1&lineup=kalle,lukas,jacques,harry,ricarda,yvonne,bruno', wait: 7000 },
  animals1: { q: 'time=12&season=1&weather=0&freeze=1&lineup=bello,luna,rex,kruemel,fiffi,balu', wait: 7000 },
  animals2: { q: 'time=12&season=1&weather=0&freeze=1&lineup=minka,mikesch,pieps,nussi,stachel,fridolin', wait: 7000 },
  animals3: { q: 'time=12&season=1&weather=0&freeze=1&lineup=erwin,frieda,klecks,gustav,gurrmann,rudi,eulalia', wait: 7000 },
};
(async () => {
  const names = process.argv.slice(5).length ? process.argv.slice(5) : Object.keys(PRESETS);
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  let failed = 0;
  for (const name of names) {
    const p = PRESETS[name];
    const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
    const errors = [];
    page.on('console', m => { const t = m.text(); if (/ERROR|SCRIPT ERROR/.test(t)) errors.push(t); });
    page.on('pageerror', e => errors.push('pageerror: ' + e.message));
    await page.goto(`${base}/index.html?${p.q}`);
    // Wait until the game reports it is running, then let it settle.
    try {
      await page.waitForFunction(() => document.title !== '' && !document.querySelector('#status')?.offsetParent, null, { timeout: 120000 });
    } catch (e) { errors.push('timeout waiting for start'); }
    await page.waitForTimeout(p.wait);
    await page.screenshot({ path: path.join(out, `${name}.png`) });
    console.log(`${name}: ${errors.length ? 'ERRORS\n  ' + errors.slice(0, 8).join('\n  ') : 'ok'}`);
    if (errors.length) failed++;
    await page.close();
  }
  await browser.close();
  process.exit(failed ? 1 : 0);
})();
