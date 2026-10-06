'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createApi } = require('./mock-server');
const { permits } = require('./permissions');

async function fixture(t, options = {}) {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'alibi-auth-test-'));
  const authFile = path.join(folder, 'auth.json');
  const server = createApi({ dataFile: path.join(folder, 'data.json'), authFile, log: () => {}, ...options });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}/api`;
  t.after(async () => {
    await new Promise(resolve => server.close(resolve));
    if (path.dirname(folder) === os.tmpdir() && path.basename(folder).startsWith('alibi-auth-test-')) fs.rmSync(folder, { recursive: true });
  });
  async function call(url, method = 'GET', body, token) {
    const response = await fetch(base + url, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, ...(body !== undefined ? { body: JSON.stringify(body) } : {}) });
    return { status: response.status, body: response.status === 204 ? null : await response.json() };
  }
  const login = async username => (await call('/auth/login', 'POST', { username, password: 'Alibi123!' })).body;
  return { call, login, authFile };
}

test('role matrix has separate client, employee and admin functions', () => {
  for (const role of ['client', 'employee', 'admin']) {
    assert.equal(permits(role, 'catalog'), true);
    assert.equal(permits(role, 'ownRequests'), role === 'client');
    assert.equal(permits(role, 'reschedule'), role === 'client');
    assert.equal(permits(role, 'work'), role === 'employee');
    assert.equal(permits(role, 'users'), role === 'admin');
    assert.equal(permits(role, 'hardDelete'), role === 'admin');
    assert.equal(permits(role, 'restore'), role === 'admin');
    assert.equal(permits(role, 'write'), role !== 'client');
  }
  assert.equal(permits('unknown', 'catalog'), false);
});

test('protected API needs bearer token; wrong credentials return 401', async t => {
  const api = await fixture(t);
  assert.equal((await api.call('/services')).status, 401);
  assert.equal((await api.call('/auth/login', 'POST', { username: 1, password: [] })).status, 422);
  assert.equal((await api.call('/auth/login', 'POST', { username: 'client', password: 'wrong' })).status, 401);
  const session = await api.login('client');
  assert.equal((await api.call('/auth/me', 'GET', undefined, session.accessToken)).body.role, 'client');
  assert.equal((await api.call('/services', 'GET', undefined, session.accessToken)).status, 200);
});

test('registration validates password, ignores supplied admin role and stores only password hash', async t => {
  const api = await fixture(t);
  const draft = { name: 'Новый клиент', username: 'new-client', email: 'new@alibi.example', password: 'short', role: 'admin' };
  assert.equal((await api.call('/auth/register', 'POST', draft)).status, 422);
  draft.password = 'NewClient123!';
  const registered = await api.call('/auth/register', 'POST', draft);
  assert.equal(registered.status, 201); assert.equal(registered.body.role, 'client');
  assert.equal((await api.call('/auth/register', 'POST', draft)).status, 422);
  const persisted = JSON.parse(fs.readFileSync(api.authFile));
  assert.ok(!JSON.stringify(persisted).includes(draft.password));
  const session = (await api.call('/auth/login', 'POST', { username: draft.username, password: draft.password })).body;
  assert.equal((await api.call('/my/requests', 'GET', undefined, session.accessToken)).body.total, 0);
});

test('client sees only own requests and can reschedule only own eligible request', async t => {
  const api = await fixture(t); const { accessToken } = await api.login('client');
  const own = await api.call('/my/requests', 'GET', undefined, accessToken);
  assert.ok(own.body.items.every(item => item.client.id === 1));
  assert.equal((await api.call('/requests', 'GET', undefined, accessToken)).status, 403);
  assert.equal((await api.call('/requests/2', 'GET', undefined, accessToken)).status, 403);
  assert.equal((await api.call('/requests/1', 'GET', undefined, accessToken)).status, 200);
  assert.equal((await api.call('/my/requests/2/reschedule', 'POST', { eventDate: '2026-12-31' }, accessToken)).status, 403);
  const moved = await api.call('/my/requests/1/reschedule', 'POST', { eventDate: '2026-12-31' }, accessToken);
  assert.equal(moved.status, 200, JSON.stringify(moved.body));
});

test('server denies forged UI role and modified JWT', async t => {
  const api = await fixture(t); const { accessToken } = await api.login('client');
  assert.equal((await api.call('/admin/users', 'GET', undefined, accessToken)).status, 403);
  assert.equal((await api.call('/services/1?hard=true', 'DELETE', { role: 'admin' }, accessToken)).status, 403);
  const parts = accessToken.split('.');
  const claim = JSON.parse(Buffer.from(parts[1], 'base64url')); claim.role = 'admin';
  parts[1] = Buffer.from(JSON.stringify(claim)).toString('base64url');
  assert.equal((await api.call('/admin/users', 'GET', undefined, parts.join('.'))).status, 401);
});

test('each role has exclusive endpoint and employee cannot restore or hard-delete', async t => {
  const api = await fixture(t);
  const client = await api.login('client'), employee = await api.login('employee'), admin = await api.login('admin');
  for (const [session, work, own, users] of [[client, 403, 200, 403], [employee, 200, 403, 403], [admin, 403, 403, 200]]) {
    assert.equal((await api.call('/work', 'GET', undefined, session.accessToken)).status, work);
    assert.equal((await api.call('/my/requests', 'GET', undefined, session.accessToken)).status, own);
    assert.equal((await api.call('/admin/users', 'GET', undefined, session.accessToken)).status, users);
  }
  assert.equal((await api.call('/requests/1/restore', 'POST', {}, employee.accessToken)).status, 403);
  assert.equal((await api.call('/requests/1?hard=true', 'DELETE', undefined, employee.accessToken)).status, 403);
});

test('expired access is refreshed once, rotates refresh token and preserves session lifetime', async t => {
  let current = Date.now(); const api = await fixture(t, { ttl: 60, now: () => current });
  const initial = await api.login('client'); current += 61000;
  assert.equal((await api.call('/services', 'GET', undefined, initial.accessToken)).status, 401);
  const updated = await api.call('/auth/refresh', 'POST', { refreshToken: initial.refreshToken });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.sessionStartedAt, initial.sessionStartedAt);
  assert.equal(updated.body.sessionExpiresAt, initial.sessionExpiresAt);
  assert.equal((await api.call('/services', 'GET', undefined, updated.body.accessToken)).status, 200);
  assert.equal((await api.call('/auth/refresh', 'POST', { refreshToken: initial.refreshToken })).status, 401);
  assert.equal((await api.call('/auth/refresh', 'POST', { refreshToken: 'invalid' })).status, 401);
  current += 3600000;
  assert.equal((await api.call('/auth/refresh', 'POST', { refreshToken: updated.body.refreshToken })).status, 401);
});

test('logout revokes access and refresh; changing role revokes existing user sessions', async t => {
  const api = await fixture(t); const client = await api.login('client');
  await api.call('/auth/logout', 'POST', { refreshToken: client.refreshToken });
  assert.equal((await api.call('/services', 'GET', undefined, client.accessToken)).status, 401);
  assert.equal((await api.call('/auth/refresh', 'POST', { refreshToken: client.refreshToken })).status, 401);
  const employee = await api.login('employee'), admin = await api.login('admin');
  assert.equal((await api.call('/admin/users/2', 'PUT', { role: 'client', active: true, clientId: 1 }, admin.accessToken)).status, 200);
  assert.equal((await api.call('/work', 'GET', undefined, employee.accessToken)).status, 401);
  assert.equal((await api.call('/admin/users/3', 'PUT', { role: 'client', active: false, clientId: 1 }, admin.accessToken)).status, 409);
});
