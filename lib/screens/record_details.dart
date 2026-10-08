import '../models/agency_record.dart';
import '../models/alibi_request.dart';
import '../models/business_record.dart';
import '../models/json_readers.dart';
import '../repositories/agency_repository_contract.dart';

Map<String, String> recordDetails(
  EntityKind kind,
  AgencyRecord record,
  AgencyRepositoryContract repository,
) {
  final json = record.toJson();
  String linked(EntityKind target, Object? ids) =>
      readIds(ids).map((id) => repository.nameOf(target, id)).join(', ');
  final fields = <String, String>{};
  switch (kind) {
    case EntityKind.cards:
      fields.addAll({
        'Название': record.name,
        'Клиент': repository.nameOf(
          EntityKind.clients,
          readInt(json['clientId']),
        ),
        'Номер карты': readString(json['number']),
        'Бонусные баллы': '${json['points']}',
        'Дата выдачи': formatDate(record.date),
      });
    case EntityKind.contracts:
      final pricing = readMap(json['pricing']);
      fields.addAll({
        'Название': record.name,
        'Номер договора': readString(json['code']),
        'Заявка': repository.nameOf(
          EntityKind.requests,
          readInt(json['requestId']),
        ),
        'Состояние': contractStatuses[json['status']] ?? '—',
        'Базовая цена': '${pricing['base'] ?? 0} ₽',
        'Срочность': '${pricing['urgency'] ?? 0} ₽',
        'Подготовка сценариев': '${pricing['preparation'] ?? 0} ₽',
        'Скидка': '${json['discountPercent']}%',
        'Итоговая стоимость': '${json['amount']} ₽',
        'Дата договора': formatDate(record.date),
      });
    case EntityKind.payments:
      fields.addAll({
        'Назначение': record.name,
        'Договор': repository.nameOf(
          EntityKind.contracts,
          readInt(json['contractId']),
        ),
        'Сумма': '${json['amount']} ₽',
        'Способ оплаты': paymentMethods[json['method']] ?? '—',
        'Состояние': paymentStatuses[json['status']] ?? '—',
        'Дата платежа': formatDate(record.date),
      });
    case EntityKind.requests:
      final request = record as AlibiRequest;
      fields.addAll({
        'Номер заявки': request.code,
        'Тема': request.title,
        'Тип ситуации': requestTypeLabels[request.type]!,
        'Статус': requestStatusLabels[request.status]!,
        'Дата события': formatDate(request.eventDate),
        'Срочность': '${request.urgency}/3',
        'Клиент': repository.nameOf(EntityKind.clients, request.clientId),
        'Услуга': repository.nameOf(EntityKind.services, request.serviceId),
        'Сотрудники': linked(EntityKind.employees, request.employeeIds),
        'Сценарии': linked(EntityKind.scenarios, request.scenarioIds),
      });
    case EntityKind.clients:
      final card = readMap(json['card']);
      fields.addAll({
        'Имя': record.name,
        'Электронная почта': json['email'].toString(),
        'Город': json['city'].toString(),
        'Дата регистрации': formatDate(record.date),
        'Номер карты': readString(card['number'], 'Не оформлена'),
        'Дата выдачи карты': card.isEmpty
            ? '—'
            : formatDate(readDate(card['issuedAt'])),
        'Бонусные баллы': '${readInt(card['points'])}',
      });
    case EntityKind.employees:
      fields.addAll({
        'Имя': record.name,
        'Электронная почта': json['email'].toString(),
        'Телефон': json['phone'].toString(),
        'Специализация': json['specialty'].toString(),
        'Дата приёма': formatDate(record.date),
        'Стаж': '${json['experienceYears']} лет',
      });
    case EntityKind.services:
      fields.addAll({
        'Название': record.name,
        'Описание': json['description'].toString(),
        'Категория': json['category'].toString(),
        'Стоимость': '${json['price']} ₽',
        'Дата добавления': formatDate(record.date),
      });
    case EntityKind.scenarios:
      fields.addAll({
        'Название': record.name,
        'Описание': json['description'].toString(),
        'Услуга': repository.nameOf(
          EntityKind.services,
          readInt(json['serviceId']),
        ),
        'Подготовка': '${json['durationMinutes']} мин.',
        'Дата добавления': formatDate(record.date),
      });
  }
  fields['Запись'] = record.isDeleted ? 'В корзине' : 'Активна';
  return fields;
}
