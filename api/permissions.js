'use strict';

const roles = ['client', 'employee', 'admin'];
function permits(role, operation) {
  if (!roles.includes(role)) return false;
  switch (operation) {
    case 'catalog': return true;
    case 'records': case 'write': case 'softDelete': return role !== 'client';
    case 'ownRequests': case 'reschedule': return role === 'client';
    case 'work': return role === 'employee';
    case 'users': case 'statistics': case 'hardDelete': case 'restore': return role === 'admin';
    default: return false;
  }
}
module.exports = { roles, permits };
