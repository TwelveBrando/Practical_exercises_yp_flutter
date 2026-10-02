'use strict';
const http = require('node:http');
const path = require('node:path');
const { kinds, openStore } = require('./store');
const { HttpError, validate, dependentCounts } = require('./validation');
const { page, expand, relations } = require('./query');

function createApi({ origin = 'http://localhost:5555', dataFile = path.join(__dirname, 'data', 'alibi.json'), log = console.log } = {}) {
  const store = openStore(dataFile);
  const server = http.createServer(async (request, response) => {
    response.setHeader('Access-Control-Allow-Origin', origin);
    response.setHeader('Vary', 'Origin');
    response.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    response.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    response.setHeader('Access-Control-Max-Age', '86400');
    response.on('finish', () => log(`${request.method} ${request.url} → ${response.statusCode}`));
    function send(status, body) {
      response.statusCode = status;
      if (status === 204) return response.end();
      response.setHeader('Content-Type', 'application/json; charset=utf-8');
      response.end(JSON.stringify(body));
    }
    try {
      if (request.headers.origin && request.headers.origin !== origin) throw new HttpError(403, 'Источник клиента не разрешён. Проверьте --origin и порт Flutter.');
      if (request.method === 'OPTIONS') return send(204);
      const url = new URL(request.url, 'http://localhost');
      const delay = Math.min(10000, Math.max(0, Number(url.searchParams.get('__delay')) || 0));
      if (delay) await new Promise(resolve => setTimeout(resolve, delay));
      const fail = Number(url.searchParams.get('__fail'));
      if ([400, 401, 403, 404, 409, 422, 500, 503].includes(fail)) throw new HttpError(fail, `Тестовая ошибка сервера (${fail})`, fail === 422 ? { code: 'Тестовая ошибка номера заявки' } : undefined);
      if (url.pathname === '/api/__health' && request.method === 'GET') return send(200, { status: 'ok', service: 'Alibi', schemaVersion: 2 });
      const parts = url.pathname.split('/').filter(Boolean);
      const [prefix, kind, segment, action] = parts;
      if (prefix !== 'api' || !kinds.includes(kind) || parts.length > 4) throw new HttpError(404, 'Адрес API не найден');
      const records = store.data.records;
      let body;
      if (request.method === 'POST' || request.method === 'PUT') body = await readBody(request);
      if (!segment && request.method === 'GET') {
        const result = page(kind, records, url.searchParams);
        result.items = result.items.map(item => expand(kind, item, records));
        return send(200, result);
      }
      if (segment === 'options' && !action && request.method === 'GET') {
        return send(200, records[kind].map(item => expand(kind, item, records)));
      }
      if (!segment && request.method === 'POST') {
        const input = validate(kind, body, null, records);
        const created = store.change(next => {
          const id = next.nextIds[kind]++;
          const record = { ...input, id, deletedAt: null };
          next.records[kind].push(record);
          return record;
        });
        return send(201, expand(kind, created, store.data.records));
      }
      if (segment === 'bulk-delete' && !action && request.method === 'POST') {
        if (!Array.isArray(body.ids) || !body.ids.length || body.ids.some(id => !Number.isInteger(id) || id <= 0)) throw new HttpError(400, 'Передайте непустой массив идентификаторов');
        const ids = [...new Set(body.ids)];
        deleteRecords(kind, ids, body.hard === true);
        return send(200, { deleted: ids.length });
      }
      const id = /^\d+$/.test(segment ?? '') ? Number(segment) : 0;
      const record = records[kind].find(item => item.id === id);
      if (!record) throw new HttpError(404, 'Запись не найдена');
      if (!action && request.method === 'GET') return send(200, { ...expand(kind, record, records), relations: relations(kind, record, records) });
      if (!action && request.method === 'PUT') {
        if (record.deletedAt) throw new HttpError(409, 'Сначала восстановите запись из корзины.');
        const input = validate(kind, body, id, records);
        const updated = store.change(next => {
          const index = next.records[kind].findIndex(item => item.id === id);
          const updated = { ...input, id, deletedAt: null };
          next.records[kind][index] = updated;
          return updated;
        });
        return send(200, expand(kind, updated, store.data.records));
      }
      if (!action && request.method === 'DELETE') {
        deleteRecords(kind, [id], url.searchParams.get('hard') === 'true');
        return send(204);
      }
      if (action === 'restore' && request.method === 'POST') {
        const restored = store.change(next => {
          const item = next.records[kind].find(item => item.id === id);
          item.deletedAt = null;
          return item;
        });
        return send(200, expand(kind, restored, store.data.records));
      }
      throw new HttpError(405, 'Метод для этого адреса не поддерживается');
    } catch (error) {
      if (!(error instanceof HttpError)) console.error(error);
      send(error.status ?? 500, { message: error instanceof HttpError ? error.message : 'Ошибка сохранения на сервере.', ...(error.errors ? { errors: error.errors } : {}) });
    }
  });
  function deleteRecords(kind, ids, hard) {
    for (const id of ids) {
      if (!store.records(kind).some(item => item.id === id)) throw new HttpError(404, `Запись #${id} не найдена`);
      const counts = dependentCounts(kind, id, store.data.records);
      if (Object.keys(counts).length) throw new HttpError(409, `Удаление невозможно: связанные записи — ${Object.entries(counts).map(([name, count]) => `${name}: ${count}`).join(', ')}. Сначала измените или удалите эти связи. Учитываются также записи в корзине.`);
    }
    store.change(next => {
      if (hard) next.records[kind] = next.records[kind].filter(item => !ids.includes(item.id));
      else for (const item of next.records[kind]) {
        if (ids.includes(item.id) && !item.deletedAt) item.deletedAt = new Date().toISOString();
      }
    });
  }
  return server;
}
async function readBody(request) {
  if (!(request.headers['content-type'] ?? '').includes('application/json')) throw new HttpError(400, 'Требуется Content-Type: application/json');
  let text = '';
  for await (const chunk of request) {
    text += chunk;
    if (Buffer.byteLength(text) > 1024 * 1024) throw new HttpError(400, 'Слишком большой запрос');
  }
  if (!text) return {};
  let body;
  try { body = JSON.parse(text); } catch { throw new HttpError(400, 'Некорректный JSON'); }
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw new HttpError(400, 'Тело запроса должно быть объектом');
  return body;
}
if (require.main === module) {
  function argument(name, fallback) {
    const index = process.argv.indexOf(name);
    return index >= 0 ? process.argv[index + 1] : fallback;
  }
  const port = Number(argument('--port', '8080'));
  const origin = argument('--origin', 'http://localhost:5555');
  const dataFile = argument('--data', path.join(__dirname, 'data', 'alibi.json'));
  const server = createApi({ origin, dataFile });
  server.on('error', error => { console.error(`Не удалось запустить сервер: ${error.message}`); process.exitCode = 1; });
  server.listen(port, '127.0.0.1', () => console.log(`Alibi API: http://localhost:${port}/api; разрешённый источник: ${origin}`));
}
module.exports = { createApi };
