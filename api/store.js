'use strict';
const fs = require('node:fs');
const path = require('node:path');

const kinds = ['requests', 'clients', 'employees', 'services', 'scenarios'];
function openStore(file) {
  const seed = JSON.parse(fs.readFileSync(path.join(__dirname, 'seed.json'), 'utf8'));
  let data = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : seed;
  if (data.schemaVersion !== 2 || kinds.some(kind => !Array.isArray(data.records?.[kind]))) {
    throw new Error('Неверный формат базы сервера. Сохраните копию файла и проверьте schemaVersion и records.');
  }
  function persist(next) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file + '.tmp', JSON.stringify(next, null, 2), 'utf8');
    fs.renameSync(file + '.tmp', file);
    data = next;
  }
  if (!fs.existsSync(file)) persist(data);
  return {
    get data() { return data; },
    records: kind => data.records[kind],
    change(action) {
      const next = structuredClone(data);
      const result = action(next);
      persist(next);
      return result;
    },
  };
}
module.exports = { kinds, openStore };
