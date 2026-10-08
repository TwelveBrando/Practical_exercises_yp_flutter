'use strict';
const fs = require('node:fs');
const path = require('node:path');

const { upgrade, synchronizeCards } = require('./migration');
const kinds = ['requests', 'clients', 'employees', 'services', 'scenarios', 'cards', 'contracts', 'payments'];
function openStore(file, persistence = null) {
  const seed = JSON.parse(fs.readFileSync(path.join(__dirname, 'seed.json'), 'utf8'));
  const raw = persistence ? persistence.read('records') : fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : null;
  let data = upgrade(raw ?? seed);
  synchronizeCards(data);
  if (data.schemaVersion !== 3 || kinds.some(kind => !Array.isArray(data.records?.[kind]))) {
    throw new Error('Неверный формат базы сервера. Сохраните копию файла и проверьте schemaVersion и records.');
  }
  function persist(next) {
    synchronizeCards(next);
    if (persistence) { persistence.write('records', next); data = next; return; }
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file + '.tmp', JSON.stringify(next, null, 2), 'utf8');
    fs.renameSync(file + '.tmp', file);
    data = next;
  }
  if (raw && raw.schemaVersion !== 3 && !persistence && !fs.existsSync(file + '.v2.bak')) fs.copyFileSync(file, file + '.v2.bak');
  if (!raw || raw.schemaVersion !== 3) persist(data);
  return {
    get data() { return data; },
    reload() { data = upgrade(persistence.read('records')); },
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
