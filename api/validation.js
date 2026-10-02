'use strict';

class HttpError extends Error {
  constructor(status, message, errors) { super(message); this.status = status; this.errors = errors; }
}
const dateKeys = { requests: 'eventDate', clients: 'joinedAt', employees: 'hiredAt', services: 'createdAt', scenarios: 'createdAt' };
function validate(kind, body, editingId, records) {
  const errors = {};
  const value = {};
  const old = records[kind].find(item => item.id === editingId);
  function text(key, min = 2, max = 120) {
    const input = typeof body[key] === 'string' ? body[key].trim() : '';
    value[key] = input;
    if (!input) errors[key] = 'Обязательное поле';
    else if (input.length < min || input.length > max) errors[key] = `Длина должна быть от ${min} до ${max} символов`;
  }
  function number(key, min, max) {
    const input = body[key];
    value[key] = input;
    if (!Number.isInteger(input) || input < min || input > max) errors[key] = `Введите целое число от ${min} до ${max}`;
  }
  function date(key) {
    const input = body[key];
    const prefix = typeof input === 'string' ? input.slice(0, 10) : '';
    const parsed = new Date(prefix + 'T00:00:00Z');
    const format = /^\d{4}-\d{2}-\d{2}(?:T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?)?$/;
    if (typeof input !== 'string' || !format.test(input) || !Number.isFinite(new Date(input).getTime()) || !Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== prefix || +prefix.slice(0, 4) < 1900 || +prefix.slice(0, 4) > 2100) {
      errors[key] = 'Введите существующую дату (1900–2100)';
    } else value[key] = parsed.toISOString();
  }
  function enumField(key, allowed) {
    value[key] = body[key];
    if (!allowed.includes(body[key])) errors[key] = 'Выберите допустимое значение';
  }
  function unique(key, get = item => item[key]) {
    const normalized = String(value[key] ?? '').toLowerCase();
    if (records[kind].some(item => item.id !== editingId && String(get(item) ?? '').toLowerCase() === normalized)) {
      errors[key] = 'Такое значение уже используется';
    }
  }
  function identifier(key, prefix) {
    text(key, 1);
    if (!new RegExp(`^${prefix}-[0-9]{4,8}$`).test(value[key])) errors[key] = `Формат: ${prefix}-0001 (4–8 цифр)`;
  }
  function reference(key, target, multiple = false) {
    const ids = multiple ? body[key] : [body[key]];
    const original = multiple ? old?.[key] ?? [] : [old?.[key]];
    if (!Array.isArray(ids) || !ids.length || ids.some(id => !Number.isInteger(id) || !records[target].some(item => item.id === id && (!item.deletedAt || original.includes(id))))) {
      errors[key] = 'Связанная запись не существует или находится в корзине';
    }
    value[key] = multiple && Array.isArray(ids) ? [...new Set(ids)] : body[key];
  }
  if (kind === 'requests') {
    identifier('code', 'ALI'); unique('code'); text('title', 3);
    enumField('type', ['lateForWork', 'missedMeeting', 'missedDeadline', 'awkwardEvent']);
    enumField('status', ['newRequest', 'inProgress', 'ready', 'closed']);
    date('eventDate'); number('urgency', 1, 3);
    reference('clientId', 'clients'); reference('serviceId', 'services');
    reference('employeeIds', 'employees', true); reference('scenarioIds', 'scenarios', true);
    if (!errors.scenarioIds && body.scenarioIds.some(id => records.scenarios.find(item => item.id === id)?.serviceId !== body.serviceId)) {
      errors.scenarioIds = 'Сценарии должны относиться к выбранной услуге';
    }
    value.createdAt = old?.createdAt ?? new Date().toISOString();
  } else {
    text('name', kind === 'clients' || kind === 'employees' ? 2 : 3);
    date(dateKeys[kind]);
    if (kind === 'clients' || kind === 'employees') {
      text('email', 1); unique('email');
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.email)) errors.email = 'Введите корректную электронную почту';
    }
    if (kind === 'clients') {
      text('city', 2, 80);
      const card = body.card && typeof body.card === 'object' && !Array.isArray(body.card) ? body.card : {};
      body = { ...body, cardNumber: card.number, cardIssuedAt: card.issuedAt, cardPoints: card.points };
      identifier('cardNumber', 'CARD'); unique('cardNumber', item => item.card?.number);
      date('cardIssuedAt'); number('cardPoints', 0, 100000);
      value.card = { number: value.cardNumber, issuedAt: value.cardIssuedAt, points: value.cardPoints };
      delete value.cardNumber; delete value.cardIssuedAt; delete value.cardPoints;
    } else if (kind === 'employees') {
      text('phone', 10, 25); text('specialty', 2, 80); number('experienceYears', 0, 60);
      if (!/^\+?[0-9 ()-]{10,25}$/.test(value.phone) || value.phone.replace(/\D/g, '').length < 10) errors.phone = 'Введите корректный телефон';
    } else {
      text('description', 5, 500);
      if (kind === 'services') {
        enumField('category', ['Стандартная', 'Срочная', 'Расширенная']); number('price', 1, 1000000);
      } else {
        reference('serviceId', 'services'); number('durationMinutes', 1, 1440);
        const count = records.requests.filter(item => item.scenarioIds.includes(editingId) && item.serviceId !== body.serviceId).length;
        if (count) errors.serviceId = `Услуга не совпадает с ${count} связанными заявками`;
      }
    }
  }
  if (Object.keys(errors).length) throw new HttpError(422, 'Ошибка валидации', errors);
  return value;
}
function dependentCounts(kind, id, records) {
  const keys = { clients: 'clientId', services: 'serviceId', employees: 'employeeIds', scenarios: 'scenarioIds' };
  const key = keys[kind];
  const requests = key ? records.requests.filter(item => Array.isArray(item[key]) ? item[key].includes(id) : item[key] === id).length : 0;
  const scenarios = kind === 'services' ? records.scenarios.filter(item => item.serviceId === id).length : 0;
  return { ...(requests ? { 'заявки': requests } : {}), ...(scenarios ? { 'сценарии': scenarios } : {}) };
}
module.exports = { HttpError, validate, dependentCounts, dateKeys };
