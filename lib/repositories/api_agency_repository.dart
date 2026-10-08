import 'package:dio/dio.dart';
import '../core/api_exceptions.dart';
import '../models/agency_record.dart';
import '../models/alibi_request.dart';
import '../models/json_readers.dart';
import '../models/page_result.dart';
import '../models/record_query.dart';
import '../validation/record_fields.dart';
import 'agency_repository_contract.dart';
import 'repository_exceptions.dart';

class ApiAgencyRepository extends AgencyRepositoryContract {
  ApiAgencyRepository(
    this._dio, {
    this.retryDelay = const Duration(milliseconds: 350),
    this.sessionOwner,
  });
  final Dio _dio;
  final Duration retryDelay;
  final String? sessionOwner;
  final _references = <EntityKind, List<AgencyRecord>>{};
  final _referenceLoads = <EntityKind, Future<void>>{};
  final _filters = <EntityKind, List<FieldOption>>{};
  final _names = <EntityKind, Map<int, String>>{};
  Map<EntityKind, List<AgencyRecord>> _relations = {};
  AgencyRecord? _detail;
  EntityKind? _detailKind;
  EntityKind? _pageKind;
  List<AgencyRecord> _pageRecords = [];
  CancelToken? _findToken;
  bool _writing = false;

  @override
  String? get startupNotice => null;
  @override
  bool get validatesOnServer => true;
  @override
  Map<EntityKind, List<AgencyRecord>> get catalogs => {
    for (final kind in EntityKind.values) kind: all(kind),
  };
  @override
  List<AgencyRecord> all(EntityKind kind) {
    final records = <int, AgencyRecord>{
      for (final record in _references[kind] ?? <AgencyRecord>[])
        record.id: record,
      for (final record in _relations[kind] ?? <AgencyRecord>[])
        record.id: record,
      if (kind == _pageKind)
        for (final record in _pageRecords) record.id: record,
      if (kind == _detailKind && _detail != null) _detail!.id: _detail!,
    };
    return List.unmodifiable(records.values);
  }

  @override
  String nameOf(EntityKind kind, int id) =>
      byId(kind, id)?.name ?? _names[kind]?[id] ?? 'Запись #$id не найдена';
  @override
  Future<void> initialize() async {}
  @override
  List<FieldOption> filterOptions(EntityKind kind) =>
      _filters[kind] ?? const [];
  @override
  void cancelFind() {
    _findToken?.cancel('Параметры поиска изменились');
    _findToken = null;
  }

  Future<T> _read<T>(Future<T> Function() action, {CancelToken? token}) async {
    for (var attempt = 0; ; attempt++) {
      if (token?.isCancelled ?? false) throw const RequestCancelledException();
      try {
        final result = await guard(action);
        if (token?.isCancelled ?? false) {
          throw const RequestCancelledException();
        }
        return result;
      } on NetworkException {
        if (attempt >= 2) rethrow;
        final delay = Future<void>.delayed(retryDelay * (attempt + 1));
        if (token == null) {
          await delay;
        } else {
          await Future.any([delay, token.whenCancel.then<void>((_) {})]);
        }
      }
    }
  }

  Map<String, dynamic> _object(dynamic value) {
    if (value is! Map) {
      throw const ServerException('Сервер вернул данные в неверном формате.');
    }
    return readMap(value);
  }

  List<AgencyRecord> _items(EntityKind kind, dynamic value) {
    if (value is! List) {
      throw const ServerException('Сервер вернул данные в неверном формате.');
    }
    return value.map((item) => decode(kind, _object(item))).toList();
  }

  void _rememberNames(Map<String, dynamic> json) {
    void remember(EntityKind kind, dynamic value) {
      if (value is Map) {
        final id = readInt(value['id']);
        if (id > 0) {
          (_names[kind] ??= {})[id] = readString(
            value['name'] ?? value['title'],
          );
        }
      }
    }

    remember(EntityKind.clients, json['client']);
    remember(EntityKind.services, json['service']);
    remember(EntityKind.requests, json['request']);
    remember(EntityKind.contracts, json['contract']);
    for (final pair in [
      (EntityKind.employees, 'employees'),
      (EntityKind.scenarios, 'scenarios'),
    ]) {
      final values = json[pair.$2];
      if (values is List) {
        for (final value in values) {
          remember(pair.$1, value);
        }
      }
    }
  }

  @override
  Future<PageResult<AgencyRecord>> find(
    EntityKind kind,
    RecordQuery query,
  ) async {
    cancelFind();
    final token = CancelToken();
    _findToken = token;
    final data = await _read(() async {
      final response = await _dio.get(
        '/${kind.name}',
        queryParameters: {
          if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
          if (query.category != null) 'category': query.category,
          if (query.status != null) 'status': query.status,
          if (query.dateFrom != null) 'dateFrom': query.dateFrom,
          if (query.dateTo != null) 'dateTo': query.dateTo,
          'sort': '${query.sortField},${query.ascending ? 'asc' : 'desc'}',
          'page': query.page,
          'size': query.size,
          if (query.includeDeleted) 'includeDeleted': true,
          if (query.demoError || query.failStatus != null)
            '__fail': query.failStatus ?? 500,
          if (query.delayMs > 0) '__delay': query.delayMs,
        },
        cancelToken: token,
      );
      return _object(response.data);
    }, token: token);
    if (token.isCancelled) throw const RequestCancelledException();
    final records = _items(kind, data['items']);
    _names.clear();
    for (final item in data['items'] as List) {
      _rememberNames(_object(item));
    }
    _pageKind = kind;
    _pageRecords = records;
    _detail = null;
    _detailKind = null;
    _relations = {};
    if (data['filters'] is List) {
      _filters[kind] = (data['filters'] as List).map((value) {
        final option = _object(value);
        return FieldOption('${option['value']}', '${option['label']}');
      }).toList();
    }
    return PageResult(
      items: records,
      page: readInt(data['page'], 1),
      size: readInt(data['size'], query.size),
      total: readInt(data['total']),
    );
  }

  Future<void> _loadReference(EntityKind kind) {
    if (_references.containsKey(kind)) return Future.value();
    return _referenceLoads.putIfAbsent(kind, () async {
      try {
        final response = await _read(() => _dio.get('/${kind.name}/options'));
        _references[kind] = _items(kind, response.data);
      } finally {
        _referenceLoads.remove(kind);
      }
    });
  }

  @override
  Future<void> prepareForm(EntityKind kind, int? id) async {
    if (id != null) await prepareDetail(kind, id);
    final required = switch (kind) {
      EntityKind.requests => [
        EntityKind.clients,
        EntityKind.employees,
        EntityKind.services,
        EntityKind.scenarios,
      ],
      EntityKind.scenarios => [EntityKind.services],
      EntityKind.cards => [EntityKind.clients],
      EntityKind.contracts => [EntityKind.requests],
      EntityKind.payments => [EntityKind.contracts],
      _ => <EntityKind>[],
    };
    await Future.wait(required.map(_loadReference));
  }

  @override
  Future<void> prepareDetail(EntityKind kind, int id) async {
    final response = await _read(() => _dio.get('/${kind.name}/$id'));
    final data = _object(response.data);
    final relations = readMap(data['relations']);
    _relations = {
      for (final target in EntityKind.values)
        if (relations[target.name] is List)
          target: _items(target, relations[target.name]),
    };
    _detailKind = kind;
    _detail = decode(kind, data);
    _rememberNames(data);
  }

  Future<T> _write<T>(Future<T> Function() action) async {
    if (_writing) {
      throw const ConflictException('Дождитесь завершения сохранения.');
    }
    _writing = true;
    try {
      return await guard(action);
    } finally {
      _writing = false;
    }
  }

  void _invalidate(EntityKind kind) {
    _references.clear();
    _filters.clear();
    _relations = {};
    _names.clear();
    if (_pageKind == kind) _pageRecords = [];
    if (_detailKind == kind) {
      _detail = null;
      _detailKind = null;
    }
  }

  @override
  Future<AgencyRecord> saveForm(
    EntityKind kind,
    Map<String, dynamic> draft,
    int? editingId,
  ) => _write(() async {
    final values = {
      for (final entry in draft.entries)
        entry.key: entry.value is String
            ? (entry.value as String).trim()
            : entry.value,
    };
    final errors = <String, String>{};
    for (final field in recordFields(
      kind,
      values,
      catalogs,
      editingId,
      checkUnique: false,
    )) {
      final error = field.validate(values[field.key]);
      if (error != null) errors[field.key] = error;
    }
    if (errors.isNotEmpty) throw FieldValidationException(errors);
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
    final input = decode(kind, {...values, 'id': editingId ?? 0}).toJson()
      ..remove('id')
      ..remove('deletedAt');
    final response = editingId == null
        ? await _dio.post('/${kind.name}', data: input)
        : await _dio.put('/${kind.name}/$editingId', data: input);
    final record = decode(kind, _object(response.data));
    _invalidate(kind);
    _detail = record;
    _detailKind = kind;
    return record;
  });
  @override
  Future<void> deleteMany(
    EntityKind kind,
    Iterable<int> ids, {
    bool hard = false,
  }) => _write(() async {
    final selected = ids.toSet().toList();
    if (selected.isEmpty) return;
    if (selected.length == 1) {
      await _dio.delete(
        '/${kind.name}/${selected.single}',
        queryParameters: {if (hard) 'hard': true},
      );
    } else {
      await _dio.post(
        '/${kind.name}/bulk-delete',
        data: {'ids': selected, 'hard': hard},
      );
    }
    _invalidate(kind);
  });
  @override
  Future<void> restore(EntityKind kind, int id) => _write(() async {
    await _dio.post('/${kind.name}/$id/restore');
    _invalidate(kind);
  });
}
