import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/seed_data.dart';
import '../models/agency_record.dart';
import '../models/agency_service.dart';
import '../models/alibi_request.dart';
import '../models/client_card.dart';
import '../models/employee.dart';
import '../models/scenario.dart';
import '../models/business_record.dart';
import '../models/pricing_quote.dart';
import 'agency_repository_contract.dart';
import 'repository_exceptions.dart';
export 'repository_exceptions.dart';
import '../models/json_readers.dart';
import '../models/page_result.dart';
import '../models/record_query.dart';
import '../validation/record_fields.dart';

class AgencyRepository extends AgencyRepositoryContract {
  AgencyRepository(this.preferences);
  static const storageKey = 'alibi_agency_v2';
  static const oldStorageKey = 'alibi_agency_v1';
  final SharedPreferences preferences;
  Map<EntityKind, List<AgencyRecord>> _records = {};
  Map<EntityKind, int> _nextIds = {};
  @override
  String? startupNotice;
  bool _writing = false;

  @override
  Map<EntityKind, List<AgencyRecord>> get catalogs => {
    for (final kind in EntityKind.values)
      kind: List.unmodifiable(_records[kind] ?? []),
  };
  @override
  List<AgencyRecord> all(EntityKind kind) => catalogs[kind]!;
  @override
  AgencyRecord? byId(EntityKind kind, int id) =>
      all(kind).where((record) => record.id == id).firstOrNull;
  @override
  String nameOf(EntityKind kind, int id) =>
      byId(kind, id)?.name ?? 'Запись #$id не найдена';

  Map<EntityKind, List<AgencyRecord>> _seed() {
    final date = DateTime(2026, 1, 1);
    final services = [
      AgencyService(
        id: 1,
        name: 'Бытовое объяснение',
        description: 'Подготовка объяснения для повседневной ситуации.',
        category: 'Стандартная',
        price: 500,
        createdAt: date,
      ),
      AgencyService(
        id: 2,
        name: 'Срочная подготовка',
        description: 'Подготовка подходящего объяснения в короткий срок.',
        category: 'Срочная',
        price: 1500,
        createdAt: date,
      ),
      AgencyService(
        id: 3,
        name: 'Подробный сценарий',
        description: 'Подготовка подробного сценария и консультация.',
        category: 'Расширенная',
        price: 2500,
        createdAt: date,
      ),
    ];
    final names = [
      'Алина Орлова',
      'Максим Белов',
      'Ирина Соколова',
      'Антон Лебедев',
    ];
    final employees = [
      for (var index = 0; index < names.length; index++)
        Employee(
          id: index + 1,
          name: names[index],
          email: 'agent${index + 1}@alibi.example',
          phone: '+7 900 100-00-0$index',
          specialty: index.isEven ? 'Бытовые ситуации' : 'Деловые встречи',
          hiredAt: DateTime(2025, index + 1, 10),
          experienceYears: index + 1,
        ),
    ];
    final scenarioNames = [
      'Задержка транспорта',
      'Неотложное домашнее дело',
      'Проблема со связью',
      'Изменение времени встречи',
      'Непредвиденная очередь',
      'Задержка в дороге',
    ];
    final scenarios = [
      for (var index = 0; index < scenarioNames.length; index++)
        Scenario(
          id: index + 1,
          name: scenarioNames[index],
          description:
              'Объяснение ситуации: ${scenarioNames[index].toLowerCase()}.',
          serviceId: index % 3 + 1,
          durationMinutes: 15 + index * 10,
          createdAt: date,
        ),
    ];
    return {
      EntityKind.clients: [
        for (final client in seedClients)
          client.copyWith(
            card: ClientCard(
              number: 'CARD-${client.id.toString().padLeft(4, '0')}',
              issuedAt: client.joinedAt,
              points: client.id * 10,
            ),
          ),
      ],
      EntityKind.requests: [
        for (final request in seedRequests)
          request.copyWith(
            code: 'ALI-${request.id.toString().padLeft(4, '0')}',
            serviceId: (request.id - 1) % 3 + 1,
            employeeIds: [(request.id - 1) % 4 + 1],
            scenarioIds: [(request.id - 1) % 3 + 1],
          ),
      ],
      EntityKind.employees: employees,
      EntityKind.services: services,
      EntityKind.scenarios: scenarios,
      EntityKind.cards: [
        for (final client in seedClients)
          BusinessRecord(EntityKind.cards, {
            'id': client.id,
            'name': 'Карта ${client.name}',
            'clientId': client.id,
            'number': 'CARD-${client.id.toString().padLeft(4, '0')}',
            'points': client.id * 10,
            'issuedAt': client.joinedAt.toIso8601String(),
          }),
      ],
      EntityKind.contracts: [
        BusinessRecord(EntityKind.contracts, {
          'id': 1,
          'name': 'Договор по первой заявке',
          'code': 'CON-0001',
          'requestId': 1,
          'status': 'draft',
          'discountPercent': 0,
          'amount': 650,
          'pricing': PricingQuote.calculate(
            base: 500,
            urgencyLevel: 1,
            preparationMinutes: 15,
          ).toJson(),
          'createdAt': date.toIso8601String(),
        }),
      ],
      EntityKind.payments: [
        BusinessRecord(EntityKind.payments, {
          'id': 1,
          'name': 'Первый платёж',
          'contractId': 1,
          'amount': 100,
          'method': 'card',
          'status': 'paid',
          'paidAt': date.toIso8601String(),
        }),
      ],
    };
  }

  @override
  Future<void> initialize() async {
    _records = _seed();
    final stored =
        preferences.get(storageKey) ?? preferences.get(oldStorageKey);
    final raw = stored == null
        ? null
        : stored is String
        ? stored
        : jsonEncode(stored);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          throw const FormatException('Ожидался объект хранилища');
        }
        final snapshot = readMap(decoded);
        final version = readInt(snapshot['schemaVersion'], 1);
        if (version != 1 && version != 2 && version != 3) {
          throw const FormatException('Неизвестная версия');
        }
        final data = readMap(snapshot['records'] ?? snapshot);
        if (version == 1 &&
            data['requests'] is! List &&
            data['clients'] is! List) {
          throw const FormatException('Не найдены данные предыдущей версии');
        }
        for (final kind in EntityKind.values) {
          final entries = data[kind.name];
          if (entries is! List) {
            if (version < 3 &&
                [
                  EntityKind.cards,
                  EntityKind.contracts,
                  EntityKind.payments,
                ].contains(kind)) {
              _records[kind] = [];
              continue;
            }
            if (version == 1) continue;
            throw const FormatException('Не найден список');
          }
          final records = <AgencyRecord>[];
          for (final entry in entries) {
            if (entry is! Map) {
              throw const FormatException('Некорректная запись');
            }
            final json = readMap(entry);
            if (version == 1) {
              final id = readInt(json['id']);
              if (kind == EntityKind.requests) {
                json.putIfAbsent(
                  'code',
                  () => 'ALI-${id.toString().padLeft(4, '0')}',
                );
                json.putIfAbsent('serviceId', () => 1);
                json.putIfAbsent('employeeIds', () => [1]);
                json.putIfAbsent('scenarioIds', () => [1]);
              } else if (kind == EntityKind.clients) {
                json.putIfAbsent(
                  'card',
                  () => {
                    'number': 'CARD-${id.toString().padLeft(4, '0')}',
                    'issuedAt': json['joinedAt'],
                    'points': 0,
                  },
                );
              }
            }
            records.add(decode(kind, json));
          }
          if (records.any((record) => record.id <= 0) ||
              records.map((record) => record.id).toSet().length !=
                  records.length) {
            throw const FormatException('Некорректные идентификаторы');
          }
          _records[kind] = records;
        }
        if (version < 3) {
          _records[EntityKind.cards] = [
            for (final client in _records[EntityKind.clients]!)
              if (client.toJson()['card'] is Map)
                BusinessRecord(EntityKind.cards, {
                  'id': client.id,
                  'name': 'Карта ${client.name}',
                  'clientId': client.id,
                  ...readMap(client.toJson()['card']),
                  'deletedAt': client.deletedAt?.toIso8601String(),
                }),
          ];
        }
        final storedIds = readMap(snapshot['nextIds']);
        _initializeIds(storedIds);
        if (version < 3 || preferences.get(storageKey) == null) {
          startupNotice =
              'Формат данных обновлён до версии 3. Старые записи сохранены.';
        }
      } catch (_) {
        var backedUp = false;
        try {
          backedUp = await preferences.setString(
            'alibi_backup_${DateTime.now().millisecondsSinceEpoch}',
            raw,
          );
        } catch (_) {}
        _records = _seed();
        startupNotice = backedUp
            ? 'Сохранённые данные имеют неподдерживаемый формат. Их резервная копия сохранена; загружен начальный набор.'
            : 'Сохранённые данные имеют неподдерживаемый формат. Резервную копию сохранить не удалось; загружен начальный набор.';
      }
    }
    _initializeIds();
    try {
      final saved = await preferences.setString(
        storageKey,
        jsonEncode(_snapshot(_records, _nextIds)),
      );
      if (!saved) throw StateError('Хранилище недоступно');
    } catch (_) {
      startupNotice =
          'Браузер не разрешил сохранение данных. Проверьте настройки хранилища.';
    }
  }

  void _initializeIds([Map<String, dynamic>? saved]) {
    for (final kind in EntityKind.values) {
      final maximum = all(
        kind,
      ).fold<int>(0, (max, record) => record.id > max ? record.id : max);
      final candidate = saved == null
          ? _nextIds[kind] ?? 1
          : readInt(saved[kind.name], 1);
      _nextIds[kind] = candidate > maximum ? candidate : maximum + 1;
    }
  }

  Map<String, dynamic> _snapshot(
    Map<EntityKind, List<AgencyRecord>> records,
    Map<EntityKind, int> ids,
  ) => {
    'schemaVersion': 3,
    'records': {
      for (final kind in EntityKind.values)
        kind.name: records[kind]!.map((record) => record.toJson()).toList(),
    },
    'nextIds': {for (final kind in EntityKind.values) kind.name: ids[kind]},
  };

  Future<void> _commit(
    Map<EntityKind, List<AgencyRecord>> next,
    Map<EntityKind, int> ids,
  ) async {
    if (_writing) throw StateError('Дождитесь завершения сохранения');
    _writing = true;
    try {
      final saved = await preferences.setString(
        storageKey,
        jsonEncode(_snapshot(next, ids)),
      );
      if (!saved) throw StateError('Не удалось сохранить данные');
      _records = next;
      _nextIds = ids;
    } finally {
      _writing = false;
    }
  }

  @override
  Future<AgencyRecord> saveForm(
    EntityKind kind,
    Map<String, dynamic> draft,
    int? editingId,
  ) async {
    final values = <String, dynamic>{
      for (final entry in draft.entries)
        entry.key: entry.value is String
            ? (entry.value as String).trim()
            : entry.value,
    };
    final errors = <String, String>{};
    for (final field in recordFields(kind, values, catalogs, editingId)) {
      final error = field.validate(values[field.key]);
      if (error != null) errors[field.key] = error;
    }
    if (errors.isNotEmpty) throw FieldValidationException(errors);
    if (editingId != null && byId(kind, editingId) == null) {
      throw StateError('Запись не найдена');
    }
    values['id'] = editingId ?? _nextIds[kind]!;
    if (kind == EntityKind.clients) {
      values['card'] = {
        'number': values['cardNumber'],
        'issuedAt': values['cardIssuedAt'],
        'points': values['cardPoints'],
      };
    }
    if (kind == EntityKind.requests) {
      values['createdAt'] =
          (byId(kind, editingId ?? -1) as AlibiRequest?)?.createdAt
              .toIso8601String() ??
          DateTime.now().toIso8601String();
    }
    if (kind == EntityKind.contracts) {
      final request =
          byId(EntityKind.requests, readInt(values['requestId']))!
              as AlibiRequest;
      final service =
          byId(EntityKind.services, request.serviceId)! as AgencyService;
      final minutes = request.scenarioIds.fold<int>(
        0,
        (sum, id) =>
            sum + (byId(EntityKind.scenarios, id)! as Scenario).durationMinutes,
      );
      final quote = PricingQuote.calculate(
        base: service.price,
        urgencyLevel: request.urgency,
        preparationMinutes: minutes,
        discountPercent: readInt(values['discountPercent']),
      );
      values['pricing'] = quote.toJson();
      values['amount'] = quote.total;
    }
    final record = decode(kind, values);
    final next = {
      for (final entry in _records.entries) entry.key: [...entry.value],
    };
    next[kind]!.removeWhere((item) => item.id == record.id);
    next[kind]!.add(record);
    final ids = {..._nextIds};
    if (editingId == null) ids[kind] = record.id + 1;
    await _commit(next, ids);
    return record;
  }

  Map<String, int> dependentCounts(EntityKind kind, int id) {
    final requests = all(EntityKind.requests).whereType<AlibiRequest>();
    final requestCount = switch (kind) {
      EntityKind.clients =>
        requests.where((request) => request.clientId == id).length,
      EntityKind.employees =>
        requests.where((request) => request.employeeIds.contains(id)).length,
      EntityKind.services =>
        requests.where((request) => request.serviceId == id).length,
      EntityKind.scenarios =>
        requests.where((request) => request.scenarioIds.contains(id)).length,
      EntityKind.requests ||
      EntityKind.cards ||
      EntityKind.contracts ||
      EntityKind.payments => 0,
    };
    final scenarios = kind == EntityKind.services
        ? all(EntityKind.scenarios)
              .whereType<Scenario>()
              .where((scenario) => scenario.serviceId == id)
              .length
        : 0;
    return {
      if (requestCount > 0) 'заявки': requestCount,
      if (scenarios > 0) 'сценарии': scenarios,
    };
  }

  @override
  Future<void> deleteMany(
    EntityKind kind,
    Iterable<int> ids, {
    bool hard = false,
  }) async {
    final selected = ids.toSet();
    for (final id in selected) {
      final counts = dependentCounts(kind, id);
      if (counts.isNotEmpty) throw RelatedRecordsException(counts);
    }
    final next = {
      for (final entry in _records.entries) entry.key: [...entry.value],
    };
    if (hard) {
      next[kind]!.removeWhere((record) => selected.contains(record.id));
    } else {
      next[kind] = next[kind]!.map((record) {
        if (!selected.contains(record.id) || record.isDeleted) return record;
        return decode(kind, {
          ...record.toJson(),
          'deletedAt': DateTime.now().toIso8601String(),
        });
      }).toList();
    }
    await _commit(next, {..._nextIds});
  }

  @override
  Future<void> restore(EntityKind kind, int id) async {
    final record = byId(kind, id);
    if (record == null) throw StateError('Запись не найдена');
    final next = {
      for (final entry in _records.entries) entry.key: [...entry.value],
    };
    next[kind] = next[kind]!
        .map(
          (record) => record.id == id
              ? decode(kind, {...record.toJson(), 'deletedAt': null})
              : record,
        )
        .toList();
    await _commit(next, {..._nextIds});
  }

  @override
  Future<PageResult<AgencyRecord>> find(
    EntityKind kind,
    RecordQuery query,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (query.demoError) throw StateError('Демонстрационная ошибка загрузки');
    final search = query.search.trim().toLowerCase();
    final start = readOptionalDate(query.dateFrom);
    final end = readOptionalDate(query.dateTo);
    var records = all(kind).where((record) {
      if (!query.includeDeleted && record.isDeleted) return false;
      final json = record.toJson();
      if (search.isNotEmpty &&
          ![
            record.name,
            json['code'],
            json['email'],
            json['description'],
            record.id,
          ].join(' ').toLowerCase().contains(search)) {
        return false;
      }
      final category = switch (kind) {
        EntityKind.requests => json['type'],
        EntityKind.clients => json['city'],
        EntityKind.employees => json['specialty'],
        EntityKind.services => json['category'],
        EntityKind.scenarios => json['serviceId']?.toString(),
        EntityKind.cards => json['clientId']?.toString(),
        EntityKind.contracts => json['status'],
        EntityKind.payments => json['method'],
      };
      if (query.category != null && category != query.category) return false;
      if (query.status != null && json['status'] != query.status) return false;
      if (start != null && record.date.isBefore(start)) return false;
      if (end != null &&
          record.date.isAfter(
            end
                .add(const Duration(days: 1))
                .subtract(const Duration(microseconds: 1)),
          )) {
        return false;
      }
      return true;
    }).toList();
    records.sort((first, second) {
      final compare = switch (query.sortField) {
        'name' || 'title' => first.name.toLowerCase().compareTo(
          second.name.toLowerCase(),
        ),
        'price' || 'urgency' => readInt(
          first.toJson()[query.sortField],
        ).compareTo(readInt(second.toJson()[query.sortField])),
        _ => first.date.compareTo(second.date),
      };
      return query.ascending ? compare : -compare;
    });
    final total = records.length;
    final pages = total == 0 ? 1 : (total / query.size).ceil();
    final page = query.page.clamp(1, pages);
    records = records.skip((page - 1) * query.size).take(query.size).toList();
    return PageResult(
      items: records,
      page: page,
      size: query.size,
      total: total,
    );
  }
}
