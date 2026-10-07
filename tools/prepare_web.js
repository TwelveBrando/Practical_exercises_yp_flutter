'use strict';
const fs = require('node:fs');
const path = require('node:path');

function prepareWeb(directory, { optimize = false } = {}) {
  const root = fs.realpathSync(directory);
  const index = path.join(root, 'index.html');
  const bootstrap = path.join(root, 'flutter_bootstrap.js');
  if (!fs.existsSync(index) || !fs.existsSync(bootstrap) || !fs.existsSync(path.join(root, 'main.dart.js'))) {
    throw new Error('Каталог не содержит релизную веб-сборку Flutter.');
  }
  const removed = [];
  const remove = relative => {
    const target = path.resolve(root, relative);
    if (!target.startsWith(root + path.sep)) throw new Error('Недопустимый путь.');
    if (!fs.existsSync(target)) return;
    const resolved = fs.realpathSync(target);
    if (!resolved.startsWith(root + path.sep)) throw new Error('Путь выходит за пределы сборки.');
    fs.rmSync(target, { recursive: true });
    removed.push(relative);
  };
  if (optimize) {
    if (!fs.readFileSync(bootstrap, 'utf8').includes('canvasKitVariant:"full"') &&
        !fs.readFileSync(bootstrap, 'utf8').includes("canvasKitVariant: 'full'")) {
      throw new Error('Для оптимизации нужен полный вариант CanvasKit.');
    }
    remove('canvaskit/chromium');
    const wasm = fs.existsSync(path.join(root, 'main.dart.wasm'));
    for (const name of fs.readdirSync(path.join(root, 'canvaskit'))) {
      if (name.endsWith('.symbols') || (!wasm && /^(skwasm|wimp)/.test(name))) remove('canvaskit/' + name);
    }
  }
  fs.copyFileSync(index, path.join(root, '404.html'));
  fs.writeFileSync(path.join(root, '.nojekyll'), '');
  return removed;
}

if (require.main === module) {
  const directory = process.argv[2] ?? path.join('build', 'web');
  const removed = prepareWeb(directory, { optimize: process.argv.includes('--optimize') });
  console.log(`Сборка готова; удалено неиспользуемых ресурсов: ${removed.length}.`);
}
module.exports = { prepareWeb };
