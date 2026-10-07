'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

function createPreview(directory, { basePath = '/' } = {}) {
  const root = fs.realpathSync(directory);
  if (!basePath.startsWith('/') || !basePath.endsWith('/')) throw new Error('Базовый путь должен начинаться и заканчиваться /.');
  const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png', '.ico': 'image/x-icon', '.ttf': 'font/ttf', '.otf': 'font/otf' };
  return http.createServer((request, response) => {
    let url;
    try { url = new URL(request.url, 'http://localhost'); } catch { response.writeHead(400); return response.end(); }
    if (url.pathname === basePath.slice(0, -1)) { response.writeHead(308, { Location: basePath }); return response.end(); }
    if (!url.pathname.startsWith(basePath)) { response.writeHead(404); return response.end(); }
    let relative;
    try { relative = decodeURIComponent(url.pathname.slice(basePath.length)); } catch { response.writeHead(400); return response.end(); }
    let file = path.resolve(root, relative || 'index.html');
    if (!file.startsWith(root + path.sep)) { response.writeHead(403); return response.end(); }
    if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      if (path.extname(relative)) { response.writeHead(404); return response.end(); }
      file = path.join(root, 'index.html');
    }
    if (!fs.realpathSync(file).startsWith(root + path.sep)) { response.writeHead(403); return response.end(); }
    response.setHeader('Content-Type', types[path.extname(file)] ?? 'application/octet-stream');
    response.setHeader('Cache-Control', 'no-cache');
    fs.createReadStream(file).pipe(response);
  });
}

if (require.main === module) {
  const directory = process.argv[2] ?? path.join('build', 'web');
  const port = Number(process.argv[3] ?? '8000');
  const basePath = process.argv[4] ?? '/';
  const server = createPreview(directory, { basePath });
  server.on('error', error => { console.error(error.message); process.exitCode = 1; });
  server.listen(port, '127.0.0.1', () => console.log(`Alibi: http://127.0.0.1:${port}${basePath}`));
}
module.exports = { createPreview };
