enum EntityKind {
  requests,
  clients,
  employees,
  services,
  scenarios,
  cards,
  contracts,
  payments,
}

extension EntityKindLabels on EntityKind {
  String get label => switch (this) {
    EntityKind.requests => 'Заявки',
    EntityKind.clients => 'Клиенты',
    EntityKind.employees => 'Сотрудники',
    EntityKind.services => 'Услуги',
    EntityKind.scenarios => 'Сценарии',
    EntityKind.cards => 'Карты клиентов',
    EntityKind.contracts => 'Договоры',
    EntityKind.payments => 'Платежи',
  };
  String get singular => switch (this) {
    EntityKind.requests => 'заявка',
    EntityKind.clients => 'клиент',
    EntityKind.employees => 'сотрудник',
    EntityKind.services => 'услуга',
    EntityKind.scenarios => 'сценарий',
    EntityKind.cards => 'карта клиента',
    EntityKind.contracts => 'договор',
    EntityKind.payments => 'платёж',
  };
  String get metricLabel => switch (this) {
    EntityKind.requests => 'Срочность',
    EntityKind.clients || EntityKind.cards => 'Баллы',
    EntityKind.employees => 'Стаж (лет)',
    EntityKind.services => 'Цена (₽)',
    EntityKind.scenarios => 'Длительность (мин.)',
    EntityKind.contracts || EntityKind.payments => 'Сумма (₽)',
  };
  int metricValue(Map<String, dynamic> json) => switch (this) {
    EntityKind.requests => (json['urgency'] as num).toInt(),
    EntityKind.clients =>
      ((json['card'] as Map?)?['points'] as num?)?.toInt() ?? 0,
    EntityKind.cards => (json['points'] as num).toInt(),
    EntityKind.employees => (json['experienceYears'] as num).toInt(),
    EntityKind.services => (json['price'] as num).toInt(),
    EntityKind.scenarios => (json['durationMinutes'] as num).toInt(),
    EntityKind.contracts ||
    EntityKind.payments => (json['amount'] as num).toInt(),
  };
  String get path => '/$name';
}

abstract interface class AgencyRecord {
  int get id;
  String get name;
  DateTime get date;
  DateTime? get deletedAt;
  bool get isDeleted;
  Map<String, dynamic> toJson();
}
