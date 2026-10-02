'use strict';
const { dateKeys, HttpError } = require('./validation');
const categoryKeys = { requests: 'type', clients: 'city', employees: 'specialty', services: 'category', scenarios: 'serviceId' };
const requestTypeLabels = { lateForWork: 'Опоздание', missedMeeting: 'Пропущенная встреча', missedDeadline: 'Сорванный срок', awkwardEvent: 'Неловкое событие' };
function filters(kind, records) {
  if (kind === 'scenarios') return records.services.map(item => ({ value: String(item.id), label: item.name }));
  return [...new Set(records[kind].map(item => String(item[categoryKeys[kind]])))].sort().map(value => ({ value, label: kind === 'requests' ? requestTypeLabels[value] ?? value : value }));
}
function page(kind, records, params) {
  const search = (params.get('search') ?? '').trim().toLowerCase();
  const from = params.get('dateFrom');
  const to = params.get('dateTo');
  for (const value of [from, to]) {
    if (value != null && (!/^\d{4}-\d{2}-\d{2}$/.test(value) || !Number.isFinite(Date.parse(value)))) throw new HttpError(400, 'Неверный диапазон дат');
  }
  const size = Math.min(100, Math.max(1, Number.parseInt(params.get('size'), 10) || 10));
  let result = records[kind].filter(item => {
    if (item.deletedAt && params.get('includeDeleted') !== 'true') return false;
    if (search && ![item.name, item.title, item.code, item.email, item.description, item.id].join(' ').toLowerCase().includes(search)) return false;
    if (params.has('category') && String(item[categoryKeys[kind]]) !== params.get('category')) return false;
    if (params.has('status') && item.status !== params.get('status')) return false;
    const date = item[dateKeys[kind]].slice(0, 10);
    return (!from || date >= from) && (!to || date <= to);
  });
  const [field = 'date', direction = 'desc'] = (params.get('sort') ?? 'date,desc').split(',');
  if (!['date', 'name', 'title', 'price', 'urgency', 'durationMinutes'].includes(field) || !['asc', 'desc'].includes(direction)) throw new HttpError(400, 'Неверная сортировка');
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
  }
  return result;
}
function relations(kind, item, records) {
  if (kind === 'requests') return {
    clients: records.clients.filter(record => record.id === item.clientId),
    services: records.services.filter(record => record.id === item.serviceId),
    employees: records.employees.filter(record => item.employeeIds.includes(record.id)),
    scenarios: records.scenarios.filter(record => item.scenarioIds.includes(record.id)),
  };
  const key = { clients: 'clientId', employees: 'employeeIds', services: 'serviceId', scenarios: 'scenarioIds' }[kind];
  return {
    requests: records.requests.filter(record => Array.isArray(record[key]) ? record[key].includes(item.id) : record[key] === item.id),
    ...(kind === 'services' ? { scenarios: records.scenarios.filter(record => record.serviceId === item.id) } : {}),
    ...(kind === 'scenarios' ? { services: records.services.filter(record => record.id === item.serviceId) } : {}),
  };
}
module.exports = { page, expand, relations };
