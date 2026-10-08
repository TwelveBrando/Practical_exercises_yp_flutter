'use strict';
const { HttpError } = require('./validation');
function quote(request, records, discountPercent = 0) {
  if (!Number.isInteger(discountPercent) || discountPercent < 0 || discountPercent > 30) throw new HttpError(422, 'Скидка должна быть от 0 до 30%.', { discountPercent: 'Введите целое число от 0 до 30' });
  const service = records.services.find(item => item.id === request.serviceId);
  if (!service) throw new HttpError(409, 'Услуга заявки не найдена.');
  const preparationMinutes = records.scenarios.filter(item => request.scenarioIds.includes(item.id)).reduce((sum, item) => sum + item.durationMinutes, 0);
  const base = service.price;
  const urgencyPercent = [0, 0, 20, 50][request.urgency];
  const urgency = Math.round(base * urgencyPercent / 100);
  const preparation = preparationMinutes * 10;
  const subtotal = base + urgency + preparation;
  const discount = Math.round(subtotal * discountPercent / 100);
  return { base, urgencyPercent, urgency, preparationMinutes, preparation, discountPercent, discount, total: subtotal - discount };
}
function paidFor(contractId, records, exceptId = null) {
  return records.payments.filter(item => item.contractId === contractId && item.id !== exceptId && !item.deletedAt && item.status === 'paid').reduce((sum, item) => sum + item.amount, 0);
}
module.exports = { quote, paidFor };
