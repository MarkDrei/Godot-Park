// Loads the web export in headless Chromium and takes screenshots for presets.
// Screenshots only: no clicks or key presses (simulated input is unreliable in headless
// Chromium). Behaviour is tested natively with scenario tests (doc/test-scenarios.md).
// Usage: node shots.cjs <playwright-module-dir> <base-url> <out-dir> [preset | scenario:<file>[:<test>] ...]
// scenario:<file> runs a scenario file (tests/scenarios, needs the WebTests export) in a
// phone-sized window with touch and saves a screenshot whenever the test calls shot().
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
  play_jens: { q: 'time=10&season=1&weather=0&control=jens&autotest=1', wait: 20000 },
  play_dog: { q: 'time=11&season=1&weather=0&control=bello', wait: 9000 },
  play_duck: { q: 'time=11&season=0&weather=0&control=erwin', wait: 9000 },
  rain: { q: 'time=15&season=2&weather=2&control=peggy', wait: 9000 },
  mg_boule: { q: 'time=11&season=1&weather=0&control=jens&minigame=boule', wait: 12000 },
  stand_hotdog: { q: 'time=13&season=1&weather=0&freeze=1&cam=-72,3.5,11,-72,1.5,21', wait: 8000 },
  stand_icecream: { q: 'time=13&season=1&weather=0&freeze=1&cam=5,3.5,-59,5,1.5,-49', wait: 8000 },
  stand_fries: { q: 'time=13&season=1&weather=0&freeze=1&cam=84,3.5,-2,92,1.5,6', wait: 8000 },
  sit_touch: { q: 'time=11&season=1&weather=0&control=herbert&sit=1&touch=1', wait: 12000 },
  sit: { q: 'time=11&season=1&weather=0&control=herbert&sit=1', wait: 12000 },
  mg_minigolf: { q: 'time=11&season=1&weather=0&control=jens&minigame=minigolf', wait: 10000 },
  mg_shell: { q: 'time=14&season=1&weather=0&control=jens&minigame=shell', wait: 9000 },
  mg_ttt: { q: 'time=14&season=1&weather=0&control=jens&minigame=ttt', wait: 9000 },
  mg_photo: { q: 'time=14&season=1&weather=0&control=jens&minigame=photo', wait: 9000 },
  mg_ducks: { q: 'time=14&season=1&weather=0&control=jens&minigame=ducks', wait: 12000 },
  mg_frisbee: { q: 'time=14&season=1&weather=0&control=jens&minigame=frisbee', wait: 9000 },
  map: { q: 'time=14&season=1&weather=0&control=jens&ui=map', wait: 8000 },
  map_forest: { q: 'time=14&season=1&weather=0&control=jens&at=-30,-150&ui=map', wait: 8000 },
  bag: { q: 'time=14&season=1&weather=0&control=jens&items=log:24,stone:7,berries:5,apple:3,stone_axe:1,iron_pickaxe:1,gem:2,jam:1,birdhouse:1,bread:5&ui=bag', wait: 8000 },
  bag_touch: { q: 'time=14&season=1&weather=0&control=jens&touch=1&items=log:8,twig:12,mushroom:4,fishing_rod:1&ui=chest', wait: 8000 },
  hud_items: { q: 'time=14&season=1&weather=0&control=jens&items=log:8,twig:12,mushroom:4', wait: 8000 },
  forest_overview: { q: 'time=11&season=1&weather=0&freeze=1&cam=0,70,-60,0,0,-180', wait: 9000 },
  forest_gate: { q: 'time=11&season=1&weather=0&freeze=1&cam=2,4,-74,0,2,-100', wait: 8000 },
  forest_inside: { q: 'time=11&season=1&weather=0&freeze=1&cam=0,3,-108,-30,2,-155', wait: 8000 },
  forest_mountain: { q: 'time=11&season=1&weather=0&freeze=1&cam=50,6,-222,74,6,-260', wait: 8000 },
  forest_pond: { q: 'time=16&season=1&weather=0&freeze=1&cam=-30,3,-214,-50,0,-226', wait: 8000 },
  forest_camp: { q: 'time=17&season=1&weather=0&freeze=1&cam=-30,5,-146,-42,1,-162', wait: 8000 },
  forest_inn: { q: 'time=12&season=1&weather=0&freeze=1&cam=10,4,-146,28,2,-152', wait: 8000 },
  forest_sawmill: { q: 'time=12&season=1&weather=0&freeze=1&cam=-70,3.5,-114,-72,1.5,-125', wait: 8000 },
  forest_dwarves: { q: 'time=12&season=1&weather=0&freeze=1&cam=46,7,-222,70,2,-246', wait: 8000 },
  forest_night: { q: 'time=22&season=1&weather=0&freeze=1&cam=16,4,-146,30,2,-152', wait: 8000 },
  forest_walk: { q: 'time=11&season=1&weather=0&control=jens&at=-3,-122', wait: 9000 },
  tasks: { q: 'time=14&season=1&weather=0&control=jens&ui=tasks', wait: 8000 },
  start: { q: 'time=9&season=0&weather=0', wait: 9000 },
  people1: { q: 'time=12&season=1&weather=0&freeze=1&lineup=jens,herbert,peggy,heinz,dora,kemal', wait: 7000 },
  people2: { q: 'time=12&season=1&weather=0&freeze=1&lineup=mia,boris,pierre,thorsten,gertrud,lena,sabine', wait: 7000 },
  people3: { q: 'time=12&season=1&weather=0&freeze=1&lineup=kalle,lukas,jacques,harry,ricarda,yvonne,bruno', wait: 7000 },
  animals1: { q: 'time=12&season=1&weather=0&freeze=1&lineup=bello,luna,rex,kruemel,fiffi,balu', wait: 7000 },
  animals2: { q: 'time=12&season=1&weather=0&freeze=1&lineup=minka,mikesch,pieps,nussi,stachel,fridolin', wait: 7000 },
  animals3: { q: 'time=12&season=1&weather=0&freeze=1&lineup=erwin,frieda,klecks,gustav,gurrmann,rudi,eulalia', wait: 7000 },
};
// Landscape phone: 844x390 CSS pixels (19.5:9) at device pixel ratio 2.
const PHONE = { viewport: { width: 844, height: 390 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true };

// Runs one scenario spec; the game prints "SHOT <label>" and waits for window.__shot.
async function runScenario(browser, spec) {
  const dir = path.join(out, spec.split(':')[0]);
  require('fs').mkdirSync(dir, { recursive: true });
  const page = await browser.newPage(PHONE);
  let failed = false, done = false, shots = 0, queue = Promise.resolve();
  page.on('console', m => {
    const t = m.text();
    if (t.startsWith('SHOT ')) {
      const label = t.slice(5).trim();
      queue = queue.then(async () => {
        await page.screenshot({ path: path.join(dir, `${label}.png`) });
        await page.evaluate(l => { window.__shot = l; }, label);
        shots++;
      });
    } else if (/^SCENARIO|^    |SCRIPT ERROR|^ERROR/.test(t)) {
      console.log(t);
      if (/^SCENARIO FAIL|SCRIPT ERROR/.test(t)) failed = true;
      if (t.startsWith('SCENARIO DONE')) done = true;
    }
  });
  // After SCENARIO DONE the game quits; the web audio then throws (currentTime of null).
  page.on('pageerror', e => { if (!done) { console.log('pageerror: ' + e.message); failed = true; } });
  await page.goto(`${base}/index.html?scenario=${spec}&seed=1&time=11&season=1&weather=0&touch=1`);
  const t0 = Date.now();
  while (!done && Date.now() - t0 < 1800000) await page.waitForTimeout(500);
  await queue;
  console.log(`${spec}: ${shots} screenshots in ${path.relative(process.cwd(), dir)}${done ? '' : ', TIMEOUT'}`);
  await page.close();
  return failed || !done;
}

(async () => {
  const names = process.argv.slice(5).length ? process.argv.slice(5) : Object.keys(PRESETS);
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  let failed = 0;
  for (const name of names) {
    if (name.startsWith('scenario:')) {
      if (await runScenario(browser, name.slice(9))) failed++;
      continue;
    }
    const p = PRESETS[name];
    const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
    const errors = [];
    page.on('console', m => { const t = m.text(); if (/ERROR|SCRIPT ERROR/.test(t)) errors.push(t); if (t.startsWith('AUTOTEST')) console.log('  ' + t); });
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
