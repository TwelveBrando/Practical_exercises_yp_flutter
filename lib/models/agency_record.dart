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
