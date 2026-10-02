import '../models/agency_record.dart';
import '../models/alibi_request.dart';
import '../models/agency_service.dart';
import '../models/client.dart';
import '../models/scenario.dart';
import 'validators.dart';

enum FieldInput { text, number, date, select, multiple }

class FieldOption {
  const FieldOption(this.value, this.label);
  final Object value;
  final String label;
}

class RecordField {
  const RecordField({
    required this.key,
    required this.label,
    required this.validate,
    this.input = FieldInput.text,
    this.options = const [],
    this.section,
    this.lines = 1,
  });
  final String key;
  final String label;
  final FieldInput input;
  final String? Function(Object?) validate;
  final List<FieldOption> options;
  final String? section;
  final int lines;
}

List<RecordField> recordFields(
  EntityKind kind,
  Map<String, dynamic> values,
  Map<EntityKind, List<AgencyRecord>> catalogs,
  int? editingId, {
  bool checkUnique = true,
}) {
  final current = catalogs[kind]!
      .where((record) => record.id == editingId)
      .firstOrNull;
  final original = current?.toJson() ?? <String, dynamic>{};

  List<FieldOption> references(
    EntityKind target,
    String field, {
    int? serviceId,
  }) {
    final oldValue = original[field];
    return catalogs[target]!
        .where((record) {
          final wasSelected = oldValue is List
              ? oldValue.contains(record.id)
              : oldValue == record.id;
          if (record.isDeleted && !wasSelected) return false;
          if (serviceId != null &&
              record is Scenario &&
              record.serviceId != serviceId) {
            return false;
          }
          return true;
        })
        .map(
          (record) => FieldOption(
            record.id,
            '${record.name}${record.isDeleted ? ' (в корзине)' : ''}',
          ),
        )
        .toList();
  }

  RecordField text(
    String key,
    String label, {
    int min = 2,
    int max = 120,
    String? section,
    int lines = 1,
  }) => RecordField(
    key: key,
    label: label,
    section: section,
    lines: lines,
    validate: (value) => Validators.text(value, min: min, max: max),
  );

  RecordField number(
    String key,
    String label,
    int min,
    int max, {
    String? section,
  }) => RecordField(
    key: key,
    label: label,
    input: FieldInput.number,
    section: section,
    validate: (value) => Validators.integer(value, min: min, max: max),
  );

  RecordField date(String key, String label, {String? section}) => RecordField(
    key: key,
    label: label,
    input: FieldInput.date,
    section: section,
    validate: Validators.date,
  );

  RecordField select(String key, String label, List<FieldOption> options) =>
      RecordField(
        key: key,
        label: label,
        options: options,
        input: FieldInput.select,
        validate: (value) =>
            Validators.selection(value, options.map((option) => option.value)),
      );

  RecordField multiple(String key, String label, List<FieldOption> options) =>
      RecordField(
        key: key,
        label: label,
        options: options,
        input: FieldInput.multiple,
        validate: (value) =>
            Validators.multiple(value, options.map((option) => option.value)),
      );

  String? unique(Object? value, String key) {
    if (!checkUnique) return null;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    final duplicate = catalogs[kind]!.any(
      (record) =>
          record.id != editingId &&
          record.toJson()[key]?.toString().trim().toLowerCase() == normalized,
    );
    return duplicate ? 'Такое значение уже используется' : null;
  }

  RecordField email() => RecordField(
    key: 'email',
    label: 'Электронная почта',
    validate: (value) => Validators.email(value) ?? unique(value, 'email'),
  );

  switch (kind) {
    case EntityKind.requests:
      final scenarios = references(
        EntityKind.scenarios,
        'scenarioIds',
        serviceId: values['serviceId'] is int ? values['serviceId'] as int : -1,
      );
      return [
        RecordField(
          key: 'code',
          label: 'Номер заявки (ALI-0001)',
          validate: (value) =>
              Validators.identifier(value, 'ALI') ?? unique(value, 'code'),
        ),
        text('title', 'Тема заявки', min: 3),
        select('type', 'Тип ситуации', [
          for (final type in RequestType.values)
            FieldOption(type.name, requestTypeLabels[type]!),
        ]),
        select('status', 'Статус', [
          for (final status in RequestStatus.values)
            FieldOption(status.name, requestStatusLabels[status]!),
        ]),
        date('eventDate', 'Дата события'),
        number('urgency', 'Срочность (1–3)', 1, 3),
        select(
          'clientId',
          'Клиент',
          references(EntityKind.clients, 'clientId'),
        ),
        select(
          'serviceId',
          'Услуга',
          references(EntityKind.services, 'serviceId'),
        ),
        multiple(
          'employeeIds',
          'Сотрудники',
          references(EntityKind.employees, 'employeeIds'),
        ),
        multiple('scenarioIds', 'Сценарии для выбранной услуги', scenarios),
      ];
    case EntityKind.clients:
      return [
        text('name', 'Имя клиента'),
        email(),
        text('city', 'Город', max: 80),
        date('joinedAt', 'Дата регистрации'),
        RecordField(
          key: 'cardNumber',
          label: 'Номер карты (CARD-0001)',
          section: 'Карта клиента',
          validate: (value) {
            final error = Validators.identifier(value, 'CARD');
            if (error != null) return error;
            if (!checkUnique) return null;
            return catalogs[kind]!.whereType<Client>().any(
                  (client) =>
                      client.id != editingId &&
                      client.card?.number.toLowerCase() ==
                          value.toString().trim().toLowerCase(),
                )
                ? 'Такой номер карты уже используется'
                : null;
          },
        ),
        date('cardIssuedAt', 'Дата выдачи карты', section: 'Карта клиента'),
        number(
          'cardPoints',
          'Бонусные баллы',
          0,
          100000,
          section: 'Карта клиента',
        ),
      ];
    case EntityKind.employees:
      return [
        text('name', 'Имя сотрудника'),
        email(),
        const RecordField(
          key: 'phone',
          label: 'Телефон',
          validate: Validators.phone,
        ),
        text('specialty', 'Специализация', max: 80),
        date('hiredAt', 'Дата приёма на работу'),
        number('experienceYears', 'Стаж (лет)', 0, 60),
      ];
    case EntityKind.services:
      return [
        text('name', 'Название услуги', min: 3),
        text('description', 'Описание', min: 5, max: 500, lines: 3),
        select('category', 'Категория', const [
          FieldOption('Стандартная', 'Стандартная'),
          FieldOption('Срочная', 'Срочная'),
          FieldOption('Расширенная', 'Расширенная'),
        ]),
        number('price', 'Стоимость (₽)', 1, 1000000),
        date('createdAt', 'Дата добавления'),
      ];
    case EntityKind.scenarios:
      final serviceField = select(
        'serviceId',
        'Услуга',
        references(EntityKind.services, 'serviceId'),
      );
      return [
        text('name', 'Название сценария', min: 3),
        text('description', 'Описание', min: 5, max: 500, lines: 3),
        RecordField(
          key: serviceField.key,
          label: serviceField.label,
          input: serviceField.input,
          options: serviceField.options,
          validate: (value) {
            final error = serviceField.validate(value);
            if (error != null) return error;
            final incompatible = catalogs[EntityKind.requests]!
                .whereType<AlibiRequest>()
                .where(
                  (request) =>
                      request.scenarioIds.contains(editingId) &&
                      request.serviceId != value,
                )
                .length;
            return incompatible > 0
                ? 'Услуга не совпадает с $incompatible связанными заявками'
                : null;
          },
        ),
        number('durationMinutes', 'Подготовка (минут)', 1, 1440),
        date('createdAt', 'Дата добавления'),
      ];
  }
}

List<FieldOption> categoryOptions(
  EntityKind kind,
  Map<EntityKind, List<AgencyRecord>> catalogs,
) {
  switch (kind) {
    case EntityKind.requests:
      return [
        for (final type in RequestType.values)
          FieldOption(type.name, requestTypeLabels[type]!),
      ];
    case EntityKind.clients:
      final cities =
          catalogs[kind]!
              .whereType<Client>()
              .map((client) => client.city)
              .toSet()
              .toList()
            ..sort();
      return [for (final city in cities) FieldOption(city, city)];
    case EntityKind.employees:
      final specialties =
          catalogs[kind]!
              .map((record) => record.toJson()['specialty'].toString())
              .toSet()
              .toList()
            ..sort();
      return [
        for (final specialty in specialties) FieldOption(specialty, specialty),
      ];
    case EntityKind.services:
      final categories =
          catalogs[kind]!
              .whereType<AgencyService>()
              .map((service) => service.category)
              .toSet()
              .toList()
            ..sort();
      return [
        for (final category in categories) FieldOption(category, category),
      ];
    case EntityKind.scenarios:
      return [
        for (final service in catalogs[EntityKind.services]!)
          FieldOption(service.id.toString(), service.name),
      ];
  }
}
