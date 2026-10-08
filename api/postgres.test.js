'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { PGlite } = require('@electric-sql/pglite');
const { openPostgres } = require('./postgres');
const { createApi } = require('./mock-server');

async function fixture(t) {
  const db = new PGlite();
  await db.waitReady;
  const pool = {
    query: (sql, values) => values === undefined && sql.includes('CREATE TABLE') ? db.exec(sql) : db.query(sql, values),
    connect: async () => ({ query: (sql, values) => db.query(sql, values), release() {} }),
    end: async () => {},
  };
  let persistence = await openPostgres(null, { pool });
  let server = createApi({ persistence, log: () => {} });
  await persistence.flush();
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let base = `http://127.0.0.1:${server.address().port}/api`;
  t.after(async () => { await new Promise(resolve => server.close(resolve)); await db.close(); });
  const call = async (url, method = 'GET', body, token) => {
    const response = await fetch(base + url, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
    return { status: response.status, body: response.status === 204 ? null : await response.json() };
  };
  const login = async username => (await call('/auth/login', 'POST', { username, password: 'Alibi123!' })).body.accessToken;
  return {
    db, pool, call, login,
    async restart() {
      await new Promise(resolve => server.close(resolve));
      persistence = await openPostgres(null, { pool });
      server = createApi({ persistence, log: () => {} });
      await persistence.flush();
      await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
      base = `http://127.0.0.1:${server.address().port}/api`;
    },
  };
}

test('PostgreSQL preserves records, relations and an active session across API restart', async t => {
  const api = await fixture(t);
  const token = await api.login('admin');
  assert.equal((await api.call('/__health')).body.storage, 'PostgreSQL');
  const created = await api.call('/contracts', 'POST', { name: 'Договор по заявке', code: 'CON-9001', requestId: 1, status: 'signed', discountPercent: 10, createdAt: '2026-10-08', amount: 1 }, token);
  assert.equal(created.status, 201);
  assert.equal(created.body.amount, created.body.pricing.total);
  assert.ok(created.body.amount > 1);
  const payment = await api.call('/payments', 'POST', { name: 'Первый платёж', contractId: created.body.id, amount: 100, method: 'card', status: 'paid', paidAt: '2026-10-08' }, token);
  assert.equal(payment.status, 201);
  await api.restart();
  assert.equal((await api.call('/auth/me', 'GET', undefined, token)).status, 200);
  const detail = await api.call(`/contracts/${created.body.id}`, 'GET', undefined, token);
  assert.equal(detail.body.amount, created.body.amount);
  assert.equal(detail.body.relations.payments[0].id, payment.body.id);
  assert.ok((await api.db.query('SELECT * FROM request_employees')).rows.length > 0);
  assert.ok((await api.db.query('SELECT * FROM request_scenarios')).rows.length > 0);
  assert.equal((await api.db.query('SELECT request_id FROM contracts WHERE id=$1', [created.body.id])).rows[0].request_id, 1);
});

test('PostgreSQL enforces one card per client and foreign keys independently of HTTP validation', async t => {
  const api = await fixture(t);
  const card = (await api.db.query('SELECT payload FROM cards LIMIT 1')).rows[0].payload;
  await assert.rejects(api.db.query('INSERT INTO cards(id,payload) VALUES($1,$2)', [9001, { ...card, id: 9001, number: 'CARD-9001' }]), { code: '23505' });
  await assert.rejects(api.db.query('INSERT INTO contracts(id,payload) VALUES($1,$2)', [9001, { id: 9001, code: 'CON-9001', requestId: 999999, amount: 100 }]), { code: '23503' });
});

test('new entities support CRUD, restore and overpayment conflicts without losing stored data', async t => {
  const api = await fixture(t);
  const token = await api.login('admin');
  const client = await api.call('/clients', 'POST', { name: 'Новый клиент', email: 'new@alibi.example', city: 'Москва', joinedAt: '2026-10-08', card: { number: 'CARD-9001', issuedAt: '2026-10-08', points: 0 } }, token);
  assert.equal(client.status, 201);
  const cards = await api.call(`/cards?category=${client.body.id}`, 'GET', undefined, token);
  const id = cards.body.items[0].id;
  assert.equal((await api.call(`/cards/${id}?hard=true`, 'DELETE', undefined, token)).status, 204);
  const card = await api.call('/cards', 'POST', { name: 'Именная карта', clientId: client.body.id, number: 'CARD-9002', points: 20, issuedAt: '2026-10-08' }, token);
  assert.equal(card.status, 201);
  assert.equal((await api.call('/cards', 'POST', { ...card.body, number: 'CARD-9003' }, token)).status, 422);
  assert.equal((await api.call(`/cards/${card.body.id}`, 'PUT', { ...card.body, points: 40 }, token)).status, 200);
  assert.equal((await api.call(`/clients/${client.body.id}`, 'GET', undefined, token)).body.card.points, 40);
  assert.equal((await api.call(`/cards/${card.body.id}`, 'DELETE', undefined, token)).status, 204);
  assert.equal((await api.call(`/cards/${card.body.id}/restore`, 'POST', {}, token)).status, 200);
  const contract = await api.call('/contracts', 'POST', { name: 'Договор', code: 'CON-9002', requestId: 1, status: 'signed', discountPercent: 0, createdAt: '2026-10-08' }, token);
  assert.equal(contract.status, 201);
  const draft = { name: 'Оплата договора', contractId: contract.body.id, amount: contract.body.amount, method: 'transfer', status: 'paid', paidAt: '2026-10-08' };
  const payment = await api.call('/payments', 'POST', draft, token);
  assert.equal(payment.status, 201);
  assert.equal((await api.call('/payments', 'POST', { ...draft, amount: 1 }, token)).status, 409);
  assert.equal((await api.call(`/contracts/${contract.body.id}`, 'PUT', { ...contract.body, discountPercent: 30 }, token)).status, 409);
  assert.equal((await api.call(`/contracts/${contract.body.id}?hard=true`, 'DELETE', undefined, token)).status, 409);
  assert.equal((await api.call(`/payments/${payment.body.id}`, 'PUT', { ...draft, name: 'Оплачено' }, token)).status, 200);
  assert.equal((await api.call(`/payments/${payment.body.id}`, 'DELETE', undefined, token)).status, 204);
  const replacement = await api.call('/payments', 'POST', draft, token);
  assert.equal(replacement.status, 201);
  assert.equal((await api.call(`/payments/${payment.body.id}/restore`, 'POST', {}, token)).status, 409);
  assert.equal((await api.call('/payments/bulk-delete', 'POST', { ids: [payment.body.id, replacement.body.id], hard: true }, token)).status, 200);
  assert.equal((await api.call(`/contracts/${contract.body.id}`, 'PUT', { ...contract.body, discountPercent: 30 }, token)).status, 200);
  assert.equal((await api.call(`/contracts/${contract.body.id}`, 'DELETE', undefined, token)).status, 204);
  assert.equal((await api.call(`/contracts/${contract.body.id}/restore`, 'POST', {}, token)).status, 200);
  assert.equal((await api.call(`/contracts/${contract.body.id}?hard=true`, 'DELETE', undefined, token)).status, 204);
});

test('pricing checks ownership and rejects invalid discounts', async t => {
  const api = await fixture(t);
  const token = await api.login('client');
  const own = (await api.call('/my/requests', 'GET', undefined, token)).body.items[0].id;
  assert.equal((await api.call(`/requests/${own}/quote?discount=10`, 'GET', undefined, token)).status, 200);
  assert.equal((await api.call(`/requests/${own}/quote?discount=31`, 'GET', undefined, token)).status, 422);
  const admin = await api.login('admin');
  const other = (await api.call('/requests?size=100', 'GET', undefined, admin)).body.items.find(item => item.client.id !== 1).id;
  assert.equal((await api.call(`/requests/${other}/quote`, 'GET', undefined, token)).status, 403);
  assert.equal((await api.call('/clients/1?hard=true', 'DELETE', undefined, admin)).status, 409);
});

test('stale PostgreSQL writers cannot overwrite a newer transaction', async t => {
  const api = await fixture(t);
  const first = await openPostgres(null, { pool: api.pool });
  const second = await openPostgres(null, { pool: api.pool });
  const update = persistence => {
    const data = persistence.read('records');
    data.records.services[0].price += 10;
    persistence.write('records', data);
  };
  update(first); update(second);
  await first.flush();
  await assert.rejects(second.flush(), { code: '40001' });
  await second.reload();
  assert.equal(second.read('records').records.services[0].price, first.read('records').records.services[0].price);
});
