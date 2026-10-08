'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { page } = require('./query');
test('three independent criteria and numeric bounds work in every catalog', () => {
  const configs = {
    requests: ['type', 'lateForWork', 'eventDate', 'urgency'],
    clients: ['city', 'Москва', 'joinedAt', null],
    employees: ['specialty', 'Редактор', 'hiredAt', 'experienceYears'],
    services: ['category', 'Срочная', 'createdAt', 'price'],
    scenarios: ['serviceId', 1, 'createdAt', 'durationMinutes'],
    cards: ['clientId', 1, 'issuedAt', 'points'],
    contracts: ['status', 'signed', 'createdAt', 'amount'],
    payments: ['method', 'card', 'paidAt', 'amount'],
  };
  for (const [kind, [category, value, date, metric]] of Object.entries(configs)) {
    const row = (id, number, when, categoryValue = value) => ({ id, name: `Запись ${id}`, [category]: categoryValue, [date]: when, ...(metric ? { [metric]: number } : { card: { points: number } }) });
    const records = { clients: [{ id: 1, name: 'Клиент' }], services: [{ id: 1, name: 'Услуга' }], [kind]: [row(1, 10, '2026-01-01'), row(2, 20, '2026-01-01'), row(3, 10, '2020-01-01'), row(4, 10, '2026-01-01', 'другая категория')] };
    const result = page(kind, records, new URLSearchParams({ category: String(value), dateFrom: '2026-01-01', dateTo: '2026-12-31', valueFrom: '10', valueTo: '10', size: '1' }));
    assert.equal(result.total, 1, kind);
    assert.deepEqual(result.items.map(item => item.id), [1], kind);
  }
});
test('invalid and reversed numeric filters are rejected before slicing', () => {
  for (const text of ['valueFrom=-1', 'valueTo=Infinity', 'valueFrom=1.5', 'valueTo=10000001', 'valueFrom=10&valueTo=9', 'valueFrom=']) {
    assert.throws(() => page('services', { services: [] }, new URLSearchParams(text)), error => error.status === 400, text);
  }
});
