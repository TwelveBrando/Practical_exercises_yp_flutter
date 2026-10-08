'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { kinds } = require('./store');

async function openPostgres(connectionString, { pool: suppliedPool } = {}) {
  const pool = suppliedPool ?? new (require('pg').Pool)({ connectionString, max: 2, connectionTimeoutMillis: 10000, idleTimeoutMillis: 30000, query_timeout: 10000, statement_timeout: 10000 });
  pool.on?.('error', error => console.error('Соединение с базой:', error.code ?? error.name));
  let state = {}, committed = {}, revision = 0;
  const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  await pool.query(schema);
  async function reload() {
    const client = await pool.connect();
    try {
      await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
      const meta = (await client.query('SELECT * FROM app_state WHERE id=1')).rows[0];
      revision = Number(meta.revision);
      const records = {};
      for (const kind of kinds) records[kind] = (await client.query(`SELECT payload FROM ${kind} ORDER BY id`)).rows.map(item => item.payload);
      state = { records: revision ? { schemaVersion: 3, records, nextIds: meta.next_ids } : null, auth: null };
      if (meta.auth_settings) {
        const users = (await client.query('SELECT payload FROM users ORDER BY id')).rows.map(item => item.payload);
        const sessions = (await client.query('SELECT payload FROM sessions ORDER BY id')).rows.map(item => item.payload);
        state.auth = { ...meta.auth_settings, users, sessions };
      }
      await client.query('COMMIT');
      committed = structuredClone(state);
    } catch (error) { await client.query('ROLLBACK'); throw error; }
    finally { client.release(); }
  }
  await reload();
  async function flush() {
    const recordsChanged = JSON.stringify(state.records) !== JSON.stringify(committed.records);
    const authChanged = JSON.stringify(state.auth) !== JSON.stringify(committed.auth);
    if (!recordsChanged && !authChanged) return;
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const current = (await client.query('SELECT revision FROM app_state WHERE id=1 FOR UPDATE')).rows[0];
      if (Number(current.revision) !== revision) throw Object.assign(new Error('Конфликт версии данных'), { code: '40001' });
      if (recordsChanged) {
        for (const table of ['request_scenarios', 'request_employees', 'payments', 'contracts', 'cards', 'requests', 'scenarios', 'employees', 'services', 'clients']) await client.query(`DELETE FROM ${table}`);
        for (const table of ['clients', 'employees', 'services', 'scenarios', 'requests', 'cards', 'contracts', 'payments']) {
          for (const item of state.records.records[table]) await client.query(`INSERT INTO ${table}(id,payload) VALUES ($1,$2)`, [item.id, item]);
        }
        for (const item of state.records.records.requests) {
          for (const id of item.employeeIds) await client.query('INSERT INTO request_employees VALUES ($1,$2)', [item.id, id]);
          for (const id of item.scenarioIds) await client.query('INSERT INTO request_scenarios VALUES ($1,$2)', [item.id, id]);
        }
      }
      if (authChanged) {
        await client.query('DELETE FROM sessions'); await client.query('DELETE FROM users');
        for (const user of state.auth.users) await client.query('INSERT INTO users(id,payload) VALUES ($1,$2)', [user.id, user]);
        for (const session of state.auth.sessions) await client.query('INSERT INTO sessions(id,payload) VALUES ($1,$2)', [session.id, session]);
      }
      const { users, sessions, ...settings } = state.auth;
      await client.query('UPDATE app_state SET revision=revision+1,next_ids=$1,auth_settings=$2 WHERE id=1', [state.records.nextIds, settings]);
      await client.query('COMMIT');
      revision++;
      committed = structuredClone(state);
    } catch (error) { await client.query('ROLLBACK'); throw error; }
    finally { client.release(); }
  }
  return { read: key => structuredClone(state[key]), write: (key, value) => { state[key] = structuredClone(value); }, reload, flush, close: () => pool.end() };
}
module.exports = { openPostgres };
