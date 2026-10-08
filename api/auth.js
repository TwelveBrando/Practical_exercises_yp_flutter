'use strict';
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { HttpError } = require('./validation');
const { roles, permits } = require('./permissions');

const passwordProblems = password => {
  const errors = [];
  if (typeof password !== 'string' || password.length < 8) errors.push('Не менее 8 символов');
  if (!/\d/.test(password ?? '')) errors.push('Хотя бы одна цифра');
  if (!/[^\p{L}\p{N}\s]/u.test(password ?? '')) errors.push('Хотя бы один специальный символ');
  return errors;
};
const digest = value => crypto.createHash('sha256').update(value).digest('hex');
const passwordHash = (password, salt) => crypto.scryptSync(password, salt, 64).toString('hex');
function equal(a, b) {
  const left = Buffer.from(a, 'hex'), right = Buffer.from(b, 'hex');
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}
function openAuth(file, store, { ttl = 900, refreshTtl = 604800, sessionTtl = 3600, now = () => Date.now(), persistence = null } = {}) {
  for (const value of [ttl, refreshTtl, sessionTtl]) if (!Number.isFinite(value) || value <= 0) throw new Error('Сроки сессии должны быть положительными числами');
  function makeUser(id, username, name, role, clientId = null) {
    const salt = crypto.randomBytes(16).toString('hex');
    return { id, username, name, role, clientId, active: true, salt, passwordHash: passwordHash('Alibi123!', salt) };
  }
  const raw = persistence ? persistence.read('auth') : fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : null;
  let data = raw ?? {
    version: 1, secret: crypto.randomBytes(48).toString('hex'), nextId: 4, sessions: [],
    users: [makeUser(1, 'client', 'Иван Петров', 'client', store.records('clients')[0]?.id ?? null), makeUser(2, 'employee', 'Сотрудник агентства', 'employee'), makeUser(3, 'admin', 'Администратор', 'admin')],
  };
  if (data.version !== 1 || !Array.isArray(data.users) || !Array.isArray(data.sessions)) throw new Error('Неверный формат базы пользователей');
  function save() {
    if (persistence) { persistence.write('auth', data); return; }
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file + '.tmp', JSON.stringify(data, null, 2), 'utf8');
    fs.renameSync(file + '.tmp', file);
  }
  if (!raw) save();
  const userView = user => ({ id: user.id, username: user.username, name: user.name, role: user.role, clientId: user.clientId, active: user.active });
  const seconds = () => Math.floor(now() / 1000);
  function signature(value) { return crypto.createHmac('sha256', data.secret).update(value).digest('hex'); }
  function accessFor(user, session) {
    const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
    const payload = Buffer.from(JSON.stringify({ sub: user.id, role: user.role, sid: session.id, iat: seconds(), exp: Math.min(seconds() + ttl, session.endsAt) })).toString('base64url');
    const input = `${header}.${payload}`;
    return `${input}.${Buffer.from(signature(input), 'hex').toString('base64url')}`;
  }
  function issue(user, session) {
    const refreshToken = crypto.randomBytes(48).toString('base64url');
    session.refreshHash = digest(refreshToken);
    session.refreshUntil = Math.min(seconds() + refreshTtl, session.endsAt);
    save();
    return { user: userView(user), accessToken: accessFor(user, session), refreshToken, sessionStartedAt: session.startedAt * 1000, sessionExpiresAt: session.endsAt * 1000, accessExpiresAt: Math.min(seconds() + ttl, session.endsAt) * 1000 };
  }
  function authenticate(header) {
    const token = /^Bearer (\S+)$/.exec(header ?? '')?.[1];
    if (!token) throw new HttpError(401, 'Требуется вход в систему.');
    let claim;
    try {
      const parts = token.split('.');
      if (parts.length !== 3) throw new Error();
      const head = JSON.parse(Buffer.from(parts[0], 'base64url').toString());
      if (head.alg !== 'HS256' || head.typ !== 'JWT' || !equal(signature(`${parts[0]}.${parts[1]}`), Buffer.from(parts[2], 'base64url').toString('hex'))) throw new Error();
      claim = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
      if (!Number.isInteger(claim.exp) || claim.exp <= seconds()) throw new Error();
    } catch { throw new HttpError(401, 'Токен недействителен или срок его действия истёк.'); }
    const session = data.sessions.find(item => item.id === claim.sid && item.userId === claim.sub && item.endsAt > seconds());
    const user = data.users.find(item => item.id === claim.sub && item.active);
    if (!session || !user) throw new HttpError(401, 'Сессия завершена. Войдите снова.');
    return { user, session };
  }
  function requirePermission(user, operation) {
    if (!permits(user.role, operation)) throw new HttpError(403, 'Недостаточно прав для этого действия.');
  }
  function login(body) {
    const username = typeof body.username === 'string' ? body.username.trim() : '';
    const validPassword = typeof body.password === 'string' && body.password.length > 0;
    if (!username || !validPassword) throw new HttpError(422, 'Заполните логин и пароль.', { username: !username ? 'Введите логин' : undefined, password: !validPassword ? 'Введите пароль' : undefined });
    const user = data.users.find(item => item.username.toLowerCase() === username.toLowerCase());
    const salt = user?.salt ?? 'invalid-user-password-salt';
    const hash = passwordHash(body.password, salt);
    if (!user || !user.active || !equal(hash, user.passwordHash)) throw new HttpError(401, 'Неверный логин или пароль.');
    data.sessions = data.sessions.filter(item => item.endsAt > seconds());
    const session = { id: crypto.randomUUID(), userId: user.id, startedAt: seconds(), endsAt: seconds() + sessionTtl };
    data.sessions.push(session);
    return issue(user, session);
  }
  function register(body) {
    const name = typeof body.name === 'string' ? body.name.trim() : '';
    const username = typeof body.username === 'string' ? body.username.trim() : '';
    const email = typeof body.email === 'string' ? body.email.trim() : '';
    const errors = {};
    if (name.length < 2 || name.length > 120) errors.name = 'Имя: от 2 до 120 символов';
    if (!/^[a-zA-Z0-9_.-]{3,40}$/.test(username)) errors.username = 'Логин: 3–40 латинских букв, цифр, точек, дефисов или подчёркиваний';
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 120) errors.email = 'Введите корректную электронную почту';
    if (data.users.some(user => user.username.toLowerCase() === username.toLowerCase())) errors.username = 'Логин уже занят';
    if (store.records('clients').some(client => client.email.toLowerCase() === email.toLowerCase())) errors.email = 'Электронная почта уже используется';
    const problems = passwordProblems(body.password);
    if (problems.length) errors.password = problems.join('. ');
    if (Object.keys(errors).length) throw new HttpError(422, 'Исправьте поля регистрации.', errors);
    const salt = crypto.randomBytes(16).toString('hex');
    const hash = passwordHash(body.password, salt);
    const client = store.change(next => {
      const id = next.nextIds.clients++;
      const date = new Date(now()).toISOString();
      const record = { id, name, email, city: 'Не указан', joinedAt: date, deletedAt: null, card: { number: `CARD-${String(id).padStart(4, '0')}`, issuedAt: date, points: 0 } };
      while (next.records.cards.some(item => item.number === record.card.number)) record.card.number = `CARD-${String(crypto.randomInt(10000, 99999999))}`;
      next.records.clients.push(record);
      next.records.cards.push({ id: next.nextIds.cards++, name: `Карта ${name}`, clientId: id, number: record.card.number, issuedAt: date, points: 0, deletedAt: null });
      return record;
    });
    const user = { id: data.nextId++, username, name, role: 'client', clientId: client.id, active: true, salt, passwordHash: hash };
    data.users.push(user); save();
    return userView(user);
  }
  function refresh(body) {
    if (typeof body.refreshToken !== 'string') throw new HttpError(401, 'Сессия завершена. Войдите снова.');
    const session = data.sessions.find(item => item.refreshHash === digest(body.refreshToken) && item.refreshUntil > seconds() && item.endsAt > seconds());
    const user = session && data.users.find(item => item.id === session.userId && item.active);
    if (!session || !user) throw new HttpError(401, 'Обновление сессии невозможно. Войдите снова.');
    return issue(user, session);
  }
  function logout(body) {
    if (typeof body.refreshToken === 'string') {
      data.sessions = data.sessions.filter(item => item.refreshHash !== digest(body.refreshToken)); save();
    }
  }
  function updateUser(actor, id, body) {
    requirePermission(actor, 'users');
    const user = data.users.find(item => item.id === id);
    if (!user) throw new HttpError(404, 'Пользователь не найден.');
    if (!roles.includes(body.role) || typeof body.active !== 'boolean') throw new HttpError(422, 'Укажите корректную роль и состояние учётной записи.', { role: 'Допустимы client, employee, admin' });
    if (actor.id === id && (body.role !== user.role || body.active !== user.active)) throw new HttpError(409, 'Нельзя изменить роль или отключить собственную учётную запись.');
    if (user.role === 'admin' && user.active && (body.role !== 'admin' || !body.active) && data.users.filter(item => item.role === 'admin' && item.active).length <= 1) throw new HttpError(409, 'Нельзя отключить последнего администратора.');
    if (body.role === 'client' && !store.records('clients').some(item => item.id === Number(body.clientId) && !item.deletedAt)) throw new HttpError(422, 'Для роли клиента выберите активную запись клиента.', { clientId: 'Выберите клиента' });
    user.role = body.role; user.active = body.active; user.clientId = body.role === 'client' ? Number(body.clientId) : null;
    data.sessions = data.sessions.filter(item => item.userId !== user.id); save();
    return userView(user);
  }
  return { reload: () => { data = persistence.read('auth'); }, authenticate, requirePermission, login, register, refresh, logout, updateUser, userView, users: () => data.users.map(userView) };
}
module.exports = { openAuth, passwordProblems };
