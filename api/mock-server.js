'use strict';
const http = require('node:http');
const path = require('node:path');
const { kinds, openStore } = require('./store');
const { HttpError, validate, dependentCounts } = require('./validation');
const { page, expand, relations } = require('./query');
const { openAuth } = require('./auth');

function createApi({ origin = 'http://localhost:5555', dataFile = path.join(__dirname, 'data', 'alibi.json'), authFile = path.join(path.dirname(dataFile), 'auth.json'), ttl = 900, refreshTtl = 604800, sessionTtl = 3600, now, log = console.log, persistence = null } = {}) {
  const store = openStore(dataFile, persistence);
  const auth = openAuth(authFile, store, { ttl, refreshTtl, sessionTtl, persistence, ...(now ? { now } : {}) });
  let queue = Promise.resolve();
  const server = http.createServer((request, response) => {
    queue = queue.then(() => handle(request, response)).catch(error => { console.error(error.message); if (!response.writableEnded) response.end(); });
  });
  async function handle(request, response) {
    let result;
    try {
      if (persistence && request.method !== 'OPTIONS') { await persistence.reload(); store.reload(); auth.reload(); }
      await route(request, response, (status, body) => { result = { status, body }; });
      if (persistence) {
        if (result.status >= 400) { await persistence.reload(); store.reload(); auth.reload(); }
        else await persistence.flush();
      }
    } catch (error) {
        console.error('Ошибка базы:', error.code ?? error.name);
        result = { status: error.code === '40001' ? 409 : 503, body: { message: error.code === '40001' ? 'Данные изменились. Повторите действие.' : 'База данных недоступна. Попробуйте ещё раз.' } };
        response.setHeader('Access-Control-Allow-Origin', origin);
        response.setHeader('Vary', 'Origin');
        try { await persistence.reload(); store.reload(); auth.reload(); } catch {}
    }
    response.statusCode = result.status;
    if (result.status === 204) return response.end();
    response.setHeader('Content-Type', 'application/json; charset=utf-8');
    response.end(JSON.stringify(result.body));
  }
  async function route(request, response, send) {
    response.setHeader('Access-Control-Allow-Origin', origin);
    response.setHeader('Vary', 'Origin');
    response.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    response.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    response.setHeader('Access-Control-Max-Age', '86400');
    response.on('finish', () => log(`${request.method} ${request.url} → ${response.statusCode}`));
    try {
      if (request.headers.origin && request.headers.origin !== origin) throw new HttpError(403, 'Источник клиента не разрешён. Проверьте --origin и порт Flutter.');
      if (request.method === 'OPTIONS') return send(204);
      const url = new URL(request.url, 'http://localhost');
      const delay = Math.min(10000, Math.max(0, Number(url.searchParams.get('__delay')) || 0));
      if (delay) await new Promise(resolve => setTimeout(resolve, delay));
      if (url.pathname === '/api/__health' && request.method === 'GET') return send(200, { status: 'ok', service: 'Alibi', schemaVersion: 3, storage: persistence ? 'PostgreSQL' : 'JSON' });
      if (url.pathname.startsWith('/api/auth/')) {
        const command = url.pathname.slice('/api/auth/'.length);
        if (command === 'me' && request.method === 'GET') return send(200, auth.userView(auth.authenticate(request.headers.authorization).user));
        if (request.method !== 'POST') throw new HttpError(405, 'Метод не поддерживается');
        const input = await readBody(request);
        if (command === 'login') return send(200, auth.login(input));
        if (command === 'register') return send(201, auth.register(input));
        if (command === 'refresh') return send(200, auth.refresh(input));
        if (command === 'logout') { auth.logout(input); return send(204); }
        throw new HttpError(404, 'Адрес API не найден');
      }
      const { user } = auth.authenticate(request.headers.authorization);
      const records = store.data.records;
      if (url.pathname === '/api/admin/users' && request.method === 'GET') {
        auth.requirePermission(user, 'users'); return send(200, auth.users());
      }
      const userId = /^\/api\/admin\/users\/(\d+)$/.exec(url.pathname)?.[1];
      if (userId && request.method === 'PUT') return send(200, auth.updateUser(user, Number(userId), await readBody(request)));
      if (url.pathname === '/api/admin/statistics' && request.method === 'GET') {
        auth.requirePermission(user, 'statistics');
        return send(200, { users: auth.users().length, catalogs: kinds.map(kind => ({ kind, active: records[kind].filter(item => !item.deletedAt).length, deleted: records[kind].filter(item => item.deletedAt).length })) });
      }
      if (url.pathname === '/api/work' && request.method === 'GET') {
        auth.requirePermission(user, 'work');
        return send(200, ['newRequest', 'inProgress', 'ready', 'closed'].map(status => ({ status, count: records.requests.filter(item => !item.deletedAt && item.status === status).length })));
      }
      if (url.pathname === '/api/my/requests' && request.method === 'GET') {
        auth.requirePermission(user, 'ownRequests');
        const owned = { ...records, requests: records.requests.filter(item => item.clientId === user.clientId) };
        const result = page('requests', owned, url.searchParams);
        result.items = result.items.map(item => expand('requests', item, records)); return send(200, result);
      }
      const rescheduleId = /^\/api\/my\/requests\/(\d+)\/reschedule$/.exec(url.pathname)?.[1];
      if (rescheduleId && request.method === 'POST') {
        auth.requirePermission(user, 'reschedule');
        const record = records.requests.find(item => item.id === Number(rescheduleId));
        if (!record || record.clientId !== user.clientId) throw new HttpError(403, 'Можно переносить только собственные заявки.');
        if (record.deletedAt || !['newRequest', 'inProgress'].includes(record.status)) throw new HttpError(409, 'Перенос доступен только для новых заявок и заявок в работе.');
        const body = await readBody(request);
        const normalized = validate('requests', { ...record, eventDate: body.eventDate }, record.id, records);
        if (new Date(normalized.eventDate) <= new Date(record.eventDate)) throw new HttpError(422, 'Новая дата должна быть позже текущей.', { eventDate: 'Выберите более позднюю дату' });
        const updated = store.change(next => {
          const item = next.records.requests.find(item => item.id === record.id); item.eventDate = normalized.eventDate; return item;
        });
        return send(200, expand('requests', updated, store.data.records));
      }
      const quoteId = /^\/api\/requests\/(\d+)\/quote$/.exec(url.pathname)?.[1];
      if (quoteId && request.method === 'GET') {
        const item = records.requests.find(record => record.id === Number(quoteId) && !record.deletedAt);
        if (!item) throw new HttpError(404, 'Заявка не найдена.');
        if (user.role === 'client' && item.clientId !== user.clientId) throw new HttpError(403, 'Можно смотреть расчёт только своих заявок.');
        const { quote } = require('./pricing');
        return send(200, quote(item, records, Number(url.searchParams.get('discount') ?? 0)));
      }
      const parts = url.pathname.split('/').filter(Boolean);
      const [prefix, kind, segment, action] = parts;
      if (prefix !== 'api' || !kinds.includes(kind) || parts.length > 4) throw new HttpError(404, 'Адрес API не найден');
      let body;
      if (request.method === 'POST' || request.method === 'PUT') body = await readBody(request);
      const isCatalog = ['services', 'scenarios'].includes(kind);
      if (request.method === 'GET') {
        if (!isCatalog) {
          const ownedDetail = kind === 'requests' && /^\d+$/.test(segment ?? '') && !action && records.requests.some(item => item.id === Number(segment) && item.clientId === user.clientId);
          if (!(user.role === 'client' && ownedDetail)) auth.requirePermission(user, 'records');
        }
        if (segment === 'options' || url.searchParams.get('includeDeleted') === 'true') auth.requirePermission(user, 'records');
      } else if (action === 'restore') auth.requirePermission(user, 'restore');
      else if (request.method === 'DELETE' || segment === 'bulk-delete') auth.requirePermission(user, url.searchParams.get('hard') === 'true' || body?.hard === true ? 'hardDelete' : 'softDelete');
      else auth.requirePermission(user, 'write');
      const fail = Number(url.searchParams.get('__fail'));
      if ([400, 401, 403, 404, 409, 422, 500, 503].includes(fail)) throw new HttpError(fail, `Тестовая ошибка сервера (${fail})`, fail === 422 ? { code: 'Тестовая ошибка номера заявки' } : undefined);
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
          if (kind === 'clients') next.records.cards.push({ id: next.nextIds.cards++, name: `Карта ${record.name}`, clientId: id, number: record.card.number, issuedAt: record.card.issuedAt, points: record.card.points, deletedAt: null });
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
      if (!action && request.method === 'GET') {
        if (user.role === 'client' && record.deletedAt) throw new HttpError(404, 'Запись не найдена');
        return send(200, { ...expand(kind, record, records), relations: user.role === 'client' ? {} : relations(kind, record, records) });
      }
      if (!action && request.method === 'PUT') {
        if (record.deletedAt) throw new HttpError(409, 'Сначала восстановите запись из корзины.');
        const input = validate(kind, body, id, records);
        const updated = store.change(next => {
          const index = next.records[kind].findIndex(item => item.id === id);
          const updated = { ...input, id, deletedAt: null };
          next.records[kind][index] = updated;
          if (kind === 'clients') {
            const card = next.records.cards.find(item => item.clientId === id);
            if (card) Object.assign(card, { number: updated.card.number, issuedAt: updated.card.issuedAt, points: updated.card.points });
            else next.records.cards.push({ id: next.nextIds.cards++, name: `Карта ${updated.name}`, clientId: id, ...updated.card, deletedAt: null });
          }
          return updated;
        });
        return send(200, expand(kind, updated, store.data.records));
      }
      if (!action && request.method === 'DELETE') {
        deleteRecords(kind, [id], url.searchParams.get('hard') === 'true');
        return send(204);
      }
      if (action === 'restore' && request.method === 'POST') {
        const parent = { cards: ['clients', 'clientId'], contracts: ['requests', 'requestId'], payments: ['contracts', 'contractId'] }[kind];
        if (parent && !records[parent[0]].some(item => item.id === record[parent[1]] && !item.deletedAt)) throw new HttpError(409, 'Сначала восстановите связанную запись.');
        if (kind === 'payments' && record.status === 'paid') {
          const { paidFor } = require('./pricing');
          const contract = records.contracts.find(item => item.id === record.contractId);
          if (!contract || contract.deletedAt || contract.status === 'cancelled' || paidFor(contract.id, records, id) + record.amount > contract.amount) throw new HttpError(409, 'Восстановление платежа превышает остаток или договор недоступен.');
        }
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
  }
  function deleteRecords(kind, ids, hard) {
    for (const id of ids) {
      if (!store.records(kind).some(item => item.id === id)) throw new HttpError(404, `Запись #${id} не найдена`);
      if (kind === 'clients' && auth.users().some(user => user.clientId === id)) throw new HttpError(409, 'Клиент связан с учётной записью. Удаление невозможно.');
      const counts = dependentCounts(kind, id, store.data.records);
      if (Object.keys(counts).length) throw new HttpError(409, `Удаление невозможно: связанные записи — ${Object.entries(counts).map(([name, count]) => `${name}: ${count}`).join(', ')}. Сначала измените или удалите эти связи. Учитываются также записи в корзине.`);
    }
    store.change(next => {
      if (kind === 'clients') {
        if (hard) next.records.cards = next.records.cards.filter(item => !ids.includes(item.clientId));
        else for (const card of next.records.cards) if (ids.includes(card.clientId)) card.deletedAt ??= new Date().toISOString();
      }
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
  const port = Number(argument('--port', process.env.PORT ?? '8080'));
  const host = argument('--host', process.env.HOST ?? '127.0.0.1');
  const origin = argument('--origin', process.env.FRONTEND_ORIGIN ?? 'http://localhost:5555');
  const dataFile = argument('--data', process.env.DATA_FILE ?? path.join(__dirname, 'data', 'alibi.json'));
  const ttl = Number(argument('--ttl', '900'));
  const sessionTtl = Number(argument('--session-ttl', '3600'));
  async function start() {
    if (process.env.RENDER && !process.env.DATABASE_URL) throw new Error('Укажите DATABASE_URL в настройках Render.');
    const persistence = process.env.DATABASE_URL ? await require('./postgres').openPostgres(process.env.DATABASE_URL) : null;
    const server = createApi({ origin, dataFile, ttl, sessionTtl, persistence });
    if (persistence) await persistence.flush();
    server.on('error', error => { console.error(`Не удалось запустить сервер: ${error.message}`); process.exitCode = 1; });
    server.listen(port, host, () => console.log(`Alibi API: порт ${port}; хранилище ${persistence ? 'PostgreSQL' : 'локальный JSON'}`));
    for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => server.close(async () => { if (persistence) await persistence.close(); process.exit(0); }));
  }
  start().catch(error => { console.error(`Запуск не удался: ${error.code ?? error.message}`); process.exitCode = 1; });
}
module.exports = { createApi };
