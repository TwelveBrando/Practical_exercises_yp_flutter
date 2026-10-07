'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { prepareWeb } = require('./prepare_web');
const { createPreview } = require('./serve_web');

function fixture(t, wasm = false) {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'alibi-web-test-'));
  const files = {
    'index.html': '<base href="/alibi/">Alibi',
    'main.dart.js': 'app',
    'flutter_bootstrap.js': "canvasKitVariant: 'full'",
    'canvaskit/canvaskit.wasm': 'renderer',
    'canvaskit/canvaskit.js': 'renderer',
    'canvaskit/canvaskit.js.symbols': 'debug',
    'canvaskit/chromium/canvaskit.wasm': 'alternate',
    'canvaskit/skwasm.wasm': 'wasm-renderer',
  };
  if (wasm) files['main.dart.wasm'] = 'wasm-app';
  for (const [relative, text] of Object.entries(files)) {
    const file = path.join(folder, relative);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, text);
  }
  t.after(() => {
    if (path.dirname(folder) !== os.tmpdir() || !path.basename(folder).startsWith('alibi-web-test-')) throw new Error('Unexpected test directory');
    fs.rmSync(folder, { recursive: true });
  });
  return folder;
}

test('publication includes the same entry page for deep links', t => {
  const folder = fixture(t);
  prepareWeb(folder);
  assert.equal(fs.readFileSync(path.join(folder, '404.html'), 'utf8'), fs.readFileSync(path.join(folder, 'index.html'), 'utf8'));
  assert.ok(fs.existsSync(path.join(folder, '.nojekyll')));
});
test('JS optimization removes only unused renderers and debug symbols', t => {
  const folder = fixture(t);
  prepareWeb(folder, { optimize: true });
  assert.ok(fs.existsSync(path.join(folder, 'canvaskit/canvaskit.wasm')));
  assert.ok(fs.existsSync(path.join(folder, 'main.dart.js')));
  assert.ok(!fs.existsSync(path.join(folder, 'canvaskit/chromium')));
  assert.ok(!fs.existsSync(path.join(folder, 'canvaskit/skwasm.wasm')));
  assert.ok(!fs.existsSync(path.join(folder, 'canvaskit/canvaskit.js.symbols')));
});
test('Wasm optimization retains both the Wasm app and its renderer', t => {
  const folder = fixture(t, true);
  prepareWeb(folder, { optimize: true });
  assert.ok(fs.existsSync(path.join(folder, 'main.dart.wasm')));
  assert.ok(fs.existsSync(path.join(folder, 'canvaskit/skwasm.wasm')));
  assert.ok(fs.existsSync(path.join(folder, 'main.dart.js')));
});
test('optimization rejects an unconfigured loader before removing resources', t => {
  const folder = fixture(t);
  fs.writeFileSync(path.join(folder, 'flutter_bootstrap.js'), 'auto');
  assert.throws(() => prepareWeb(folder, { optimize: true }));
  assert.ok(fs.existsSync(path.join(folder, 'canvaskit/chromium')));
});
test('local preview serves deep links in a subdirectory and returns missing asset errors', async t => {
  const folder = fixture(t);
  const server = createPreview(folder, { basePath: '/alibi/' });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;
  const card = await fetch(base + '/alibi/services/1');
  assert.equal(card.status, 200);
  assert.match(await card.text(), /Alibi/);
  assert.equal((await fetch(base + '/alibi/missing.js')).status, 404);
  assert.equal((await fetch(base + '/services')).status, 404);
  const script = await fetch(base + '/alibi/main.dart.js');
  assert.match(script.headers.get('content-type'), /javascript/);
  assert.equal(await script.text(), 'app');
});
