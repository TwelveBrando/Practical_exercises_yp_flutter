'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createApi } = require('./mock-server');

async function fixture(t) {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'alibi-api-test-'));
  const file = path.join(folder, 'data.json');
  let server = createApi({ dataFile: file, log: () => {} });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let base = `http://127.0.0.1:${server.address().port}/api`;
  let token = (await (await fetch(base + '/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ username: 'admin', password: 'Alibi123!' }) })).json()).accessToken;
  t.after(async () => {
    await new Promise(resolve => server.close(resolve));
    if (path.dirname(folder) === os.tmpdir() && path.basename(folder).startsWith('alibi-api-test-')) fs.rmSync(folder, { recursive: true });
  });
  return {
    file,
    async restart() {
      await new Promise(resolve => server.close(resolve));
      server = createApi({ dataFile: file, log: () => {} });
      await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
      base = `http://127.0.0.1:${server.address().port}/api`;
      token = (await (await fetch(base + '/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ username: 'admin', password: 'Alibi123!' }) })).json()).accessToken;
    },
    async call(url, method = 'GET', body, headers = {}) {
      const response = await fetch(base + url, { method, headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, ...headers }, ...(body !== undefined ? { body: JSON.stringify(body) } : {}) });
      return { status: response.status, headers: response.headers, body: response.status === 204 ? null : await response.json() };
    },
  };
}
const drafts = {
  clients: { name: 'Тестовый клиент', email: 'test@alibi.example', city: 'Москва', joinedAt: '2026-01-01', card: { number: 'CARD-9999', issuedAt: '2026-01-01', points: 0 } },
  employees: { name: 'Тестовый сотрудник', email: 'test-employee@alibi.example', phone: '+7 900 123-45-67', specialty: 'Консультации', hiredAt: '2026-01-01', experienceYears: 3 },
  services: { name: 'Тестовая услуга', description: 'Описание тестовой услуги', category: 'Стандартная', price: 800, createdAt: '2026-01-01' },
  scenarios: { name: 'Тестовый сценарий', description: 'Описание тестового сценария', serviceId: 1, durationMinutes: 30, createdAt: '2026-01-01' },
  requests: { code: 'ALI-9999', title: 'Тестовая заявка', type: 'lateForWork', status: 'newRequest', eventDate: '2026-01-01', urgency: 1, clientId: 1, serviceId: 1, employeeIds: [1], scenarioIds: [1] },
};
test('health, CORS preflight and rejection of another origin', async t => {
  const api = await fixture(t);
  assert.equal((await api.call('/__health')).body.status, 'ok');
  const preflight = await api.call('/requests', 'OPTIONS', undefined, { Origin: 'http://localhost:5555', 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'content-type' });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), 'http://localhost:5555');
  assert.match(preflight.headers.get('access-control-allow-methods'), /DELETE/);
  assert.equal((await api.call('/requests', 'GET', undefined, { Origin: 'http://localhost:5556' })).status, 403);
});
test('server pagination, search, filters and sorting', async t => {
  const api = await fixture(t);
  const first = await api.call('/requests?size=10&page=1&sort=name,asc');
  const second = await api.call('/requests?size=10&page=2&sort=name,asc');
  assert.equal(first.body.total, 24); assert.equal(second.body.items.length, 10);
  assert.ok(first.body.filters.some(option => option.value === 'lateForWork' && option.label === 'Опоздание'));
  assert.ok(first.body.items.every(item => !second.body.items.some(other => other.id === item.id)));
  assert.equal((await api.call('/requests?search=ALI-0001')).body.items[0].id, 1);
  assert.equal((await api.call('/requests?search=несуществующее')).body.total, 0);
  const filtered = await api.call('/requests?category=lateForWork&status=newRequest&dateFrom=2026-01-01&dateTo=2026-12-31');
  assert.ok(filtered.body.items.length > 0);
  assert.ok(filtered.body.items.every(item => item.type === 'lateForWork' && item.status === 'newRequest'));
});
test('full CRUD, soft/hard deletion and restore for all five entities', async t => {
  const api = await fixture(t);
  for (const [kind, draft] of Object.entries(drafts)) {
    const created = await api.call(`/${kind}`, 'POST', draft);
    assert.equal(created.status, 201, JSON.stringify(created.body));
    const id = created.body.id;
    assert.equal((await api.call(`/${kind}/${id}`)).status, 200);
    assert.equal((await api.call(`/${kind}/${id}`, 'PUT', draft)).status, 200);
    assert.equal((await api.call(`/${kind}/${id}`, 'DELETE')).status, 204);
    assert.ok(!(await api.call(`/${kind}?search=9999`)).body.items.some(item => item.id === id));
    assert.equal((await api.call(`/${kind}/${id}/restore`, 'POST', {})).status, 200);
    assert.equal((await api.call(`/${kind}/${id}?hard=true`, 'DELETE')).status, 204);
    assert.equal((await api.call(`/${kind}/${id}`)).status, 404);
  }
});
test('422 checks uniqueness, foreign keys, nested card and real dates', async t => {
  const api = await fixture(t);
  const duplicate = await api.call('/requests', 'POST', { ...drafts.requests, code: 'ALI-0001' });
  assert.equal(duplicate.status, 422); assert.ok(duplicate.body.errors.code);
  const invalid = await api.call('/requests', 'POST', { ...drafts.requests, clientId: 99999, scenarioIds: [2], eventDate: '2026-02-30' });
  assert.equal(invalid.status, 422);
  assert.ok(invalid.body.errors.clientId); assert.ok(invalid.body.errors.scenarioIds); assert.ok(invalid.body.errors.eventDate);
  const card = await api.call('/clients', 'POST', { ...drafts.clients, card: { ...drafts.clients.card, number: 'CARD-0001' } });
  assert.equal(card.status, 422); assert.ok(card.body.errors.cardNumber);
});
test('calendar dates from Flutter are independent of the server timezone', async t => {
  const api = await fixture(t);
  const result = await api.call('/clients', 'POST', { ...drafts.clients, joinedAt: '2026-01-01T00:00:00.000', card: { ...drafts.clients.card, issuedAt: '2026-01-01T00:00:00+03:00' } });
  assert.equal(result.status, 201);
  assert.equal(result.body.joinedAt, '2026-01-01T00:00:00.000Z');
  assert.equal(result.body.card.issuedAt, '2026-01-01T00:00:00.000Z');
});
test('409 protects dependencies including trashed requests; bulk delete is atomic', async t => {
  const api = await fixture(t);
  assert.equal((await api.call('/clients/1', 'DELETE')).status, 409);
  const created = await api.call('/clients', 'POST', drafts.clients);
  const id = created.body.id;
  assert.equal((await api.call('/clients/bulk-delete', 'POST', { ids: [id, 1] })).status, 409);
  assert.equal((await api.call(`/clients/${id}`)).body.deletedAt, null);
  await api.call('/requests/1', 'DELETE'); await api.call('/requests/13', 'DELETE');
  assert.equal((await api.call('/clients/1?hard=true', 'DELETE')).status, 409);
});
test('bulk deletion, deliberate 500, delay and persistence after restart', async t => {
  const api = await fixture(t);
  const a = (await api.call('/requests', 'POST', drafts.requests)).body;
  const b = (await api.call('/requests', 'POST', { ...drafts.requests, code: 'ALI-9998' })).body;
  const bulk = await api.call('/requests/bulk-delete', 'POST', { ids: [a.id, b.id] });
  assert.equal(bulk.body.deleted, 2);
  assert.equal((await api.call('/requests?__fail=500')).status, 500);
  const start = Date.now(); await api.call('/requests?__delay=150');
  assert.ok(Date.now() - start >= 140);
  await api.restart();
  assert.ok((await api.call(`/requests/${a.id}`)).body.deletedAt);
  assert.equal((await api.call('/requests/bulk-delete', 'POST', { ids: [a.id, b.id], hard: true })).body.deleted, 2);
});
