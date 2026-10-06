import 'agency_record.dart';

enum Role { client, employee, admin }

enum Operation {
  catalog,
  records,
  write,
  softDelete,
  ownRequests,
  reschedule,
  work,
  users,
  statistics,
  hardDelete,
  restore,
}

extension RolePermissions on Role {
  String get label => switch (this) {
    Role.client => 'Клиент',
    Role.employee => 'Сотрудник',
    Role.admin => 'Администратор',
  };

  bool allows(Operation operation) => switch (operation) {
    Operation.catalog => true,
    Operation.records ||
    Operation.write ||
    Operation.softDelete => this != Role.client,
    Operation.ownRequests || Operation.reschedule => this == Role.client,
    Operation.work => this == Role.employee,
    Operation.users ||
    Operation.statistics ||
    Operation.hardDelete ||
    Operation.restore => this == Role.admin,
  };

  bool canView(EntityKind kind) =>
      allows(Operation.records) ||
      kind == EntityKind.services ||
      kind == EntityKind.scenarios;

  String get home => switch (this) {
    Role.client => '/my-requests',
    Role.employee => '/work',
    Role.admin => '/admin/statistics',
  };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    this.clientId,
    this.active = true,
  });
  final int id;
  final String username;
  final String name;
  final Role role;
  final int? clientId;
  final bool active;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: (json['id'] as num).toInt(),
    username: json['username'] as String,
    name: json['name'] as String,
    role: Role.values.byName(json['role'] as String),
    clientId: (json['clientId'] as num?)?.toInt(),
    active: json['active'] != false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'name': name,
    'role': role.name,
    'clientId': clientId,
    'active': active,
  };
  AppUser withRole(Role value) => AppUser(
    id: id,
    username: username,
    name: name,
    role: value,
    clientId: clientId,
    active: active,
  );
}
