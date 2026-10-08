'use strict';
const { dateKeys, HttpError } = require('./validation');
const categoryKeys = { requests: 'type', clients: 'city', employees: 'specialty', services: 'category', scenarios: 'serviceId', cards: 'clientId', contracts: 'status', payments: 'method' };
const metricKeys = { requests: 'urgency', clients: null, employees: 'experienceYears', services: 'price', scenarios: 'durationMinutes', cards: 'points', contracts: 'amount', payments: 'amount' };
const requestTypeLabels = { lateForWork: 'Опоздание', missedMeeting: 'Пропущенная встреча', missedDeadline: 'Сорванный срок', awkwardEvent: 'Неловкое событие' };
const labels = { contracts: { draft: 'Черновик', signed: 'Подписан', completed: 'Исполнен', cancelled: 'Отменён' }, payments: { cash: 'Наличные', card: 'Банковская карта', transfer: 'Перевод' } };
function filters(kind, records) {
  if (kind === 'cards') return records.clients.map(item => ({ value: String(item.id), label: item.name }));
  if (kind === 'scenarios') return records.services.map(item => ({ value: String(item.id), label: item.name }));
  return [...new Set(records[kind].map(item => String(item[categoryKeys[kind]])))].sort().map(value => ({ value, label: kind === 'requests' ? requestTypeLabels[value] ?? value : labels[kind]?.[value] ?? value }));
}
function page(kind, records, params) {
  const search = (params.get('search') ?? '').trim().toLowerCase();
  const from = params.get('dateFrom');
  const to = params.get('dateTo');
  for (const value of [from, to]) {
    if (value != null && (!/^\d{4}-\d{2}-\d{2}$/.test(value) || !Number.isFinite(Date.parse(value)))) throw new HttpError(400, 'Неверный диапазон дат');
  }
  const bounds = ['valueFrom', 'valueTo'].map(key => {
    if (!params.has(key)) return null;
    const text = params.get(key);
    const value = Number(text);
    if (!/^\d+$/.test(text) || !Number.isSafeInteger(value) || value > 10000000) throw new HttpError(400, 'Числовой фильтр: целое число от 0 до 10000000');
    return value;
  });
  if (bounds[0] != null && bounds[1] != null && bounds[0] > bounds[1]) throw new HttpError(400, 'Конец числового диапазона меньше начала');
  const size = Math.min(100, Math.max(1, Number.parseInt(params.get('size'), 10) || 10));
  let result = records[kind].filter(item => {
    if (item.deletedAt && params.get('includeDeleted') !== 'true') return false;
    if (search && ![item.name, item.title, item.code, item.email, item.description, item.id].join(' ').toLowerCase().includes(search)) return false;
    if (params.has('category') && String(item[categoryKeys[kind]]) !== params.get('category')) return false;
    if (params.has('status') && item.status !== params.get('status')) return false;
    const metric = kind === 'clients' ? item.card?.points ?? 0 : item[metricKeys[kind]];
    if (bounds[0] != null && metric < bounds[0]) return false;
    if (bounds[1] != null && metric > bounds[1]) return false;
    const date = item[dateKeys[kind]].slice(0, 10);
    return (!from || date >= from) && (!to || date <= to);
  });
  const [field = 'date', direction = 'desc'] = (params.get('sort') ?? 'date,desc').split(',');
  if (!['date', 'name', 'title', 'price', 'urgency', 'durationMinutes', 'amount', 'points'].includes(field) || !['asc', 'desc'].includes(direction)) throw new HttpError(400, 'Неверная сортировка');
  const get = item => field === 'date' ? item[dateKeys[kind]] : field === 'name' || field === 'title' ? item.name ?? item.title : item[field];
  result.sort((a, b) => {
    const first = get(a), second = get(b);
    const comparison = typeof first === 'number' ? first - second : String(first).toLowerCase().localeCompare(String(second).toLowerCase(), 'ru');
    return (direction === 'asc' ? comparison : -comparison) || a.id - b.id;
  });
  const total = result.length;
  const totalPages = Math.max(1, Math.ceil(total / size));
  const number = Math.min(totalPages, Math.max(1, Number.parseInt(params.get('page'), 10) || 1));
  return { items: result.slice((number - 1) * size, number * size), page: number, size, total, totalPages, filters: filters(kind, records) };
}
function expand(kind, item, records) {
  const result = { ...item };
  if (kind === 'requests') {
    result.client = records.clients.find(record => record.id === item.clientId) ?? null;
    result.service = records.services.find(record => record.id === item.serviceId) ?? null;
    result.employees = records.employees.filter(record => item.employeeIds.includes(record.id));
    result.scenarios = records.scenarios.filter(record => item.scenarioIds.includes(record.id));
    delete result.clientId; delete result.serviceId; delete result.employeeIds; delete result.scenarioIds;
  } else if (kind === 'scenarios') {
    result.service = records.services.find(record => record.id === item.serviceId) ?? null;
    delete result.serviceId;
  } else if (kind === 'cards') {
    result.client = records.clients.find(record => record.id === item.clientId) ?? null;
  } else if (kind === 'contracts') {
    result.request = records.requests.find(record => record.id === item.requestId) ?? null;
  } else if (kind === 'payments') {
    result.contract = records.contracts.find(record => record.id === item.contractId) ?? null;
  }
  return result;
}
function relations(kind, item, records) {
  if (kind === 'requests') return {
    contracts: records.contracts.filter(record => record.requestId === item.id),
    clients: records.clients.filter(record => record.id === item.clientId),
    services: records.services.filter(record => record.id === item.serviceId),
    employees: records.employees.filter(record => item.employeeIds.includes(record.id)),
    scenarios: records.scenarios.filter(record => item.scenarioIds.includes(record.id)),
  };
  if (kind === 'cards') return { clients: records.clients.filter(record => record.id === item.clientId) };
  if (kind === 'contracts') return { requests: records.requests.filter(record => record.id === item.requestId), payments: records.payments.filter(record => record.contractId === item.id) };
  if (kind === 'payments') return { contracts: records.contracts.filter(record => record.id === item.contractId) };
  const key = { clients: 'clientId', employees: 'employeeIds', services: 'serviceId', scenarios: 'scenarioIds' }[kind];
  return {
    ...(kind === 'clients' ? { cards: records.cards.filter(record => record.clientId === item.id) } : {}),
    requests: records.requests.filter(record => Array.isArray(record[key]) ? record[key].includes(item.id) : record[key] === item.id),
    ...(kind === 'services' ? { scenarios: records.scenarios.filter(record => record.serviceId === item.id) } : {}),
    ...(kind === 'scenarios' ? { services: records.services.filter(record => record.id === item.serviceId) } : {}),
  };
}
module.exports = { page, expand, relations };
