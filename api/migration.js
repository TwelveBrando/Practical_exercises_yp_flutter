'use strict';
function upgrade(source) {
  const data = structuredClone(source);
  if (![2, 3].includes(data.schemaVersion)) throw new Error('Неизвестная версия данных.');
  data.records.cards ??= data.records.clients.filter(item => item.card).map((item, index) => ({ id: index + 1, name: `Карта ${item.name}`, clientId: item.id, number: item.card.number, issuedAt: item.card.issuedAt, points: item.card.points, deletedAt: item.deletedAt ?? null }));
  data.records.contracts ??= [];
  data.records.payments ??= [];
  for (const [kind, items] of Object.entries(data.records)) data.nextIds[kind] = Math.max(data.nextIds[kind] ?? 1, ...items.map(item => item.id + 1));
  data.schemaVersion = 3;
  return data;
}
function synchronizeCards(data) {
  for (const client of data.records.clients) {
    const card = data.records.cards.find(item => item.clientId === client.id && !item.deletedAt);
    client.card = card ? { number: card.number, issuedAt: card.issuedAt, points: card.points } : null;
  }
}
module.exports = { upgrade, synchronizeCards };
