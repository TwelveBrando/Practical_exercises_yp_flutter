import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_practice/core/api_client.dart';
import 'package:second_practice/core/api_exceptions.dart';
import 'package:second_practice/models/agency_record.dart';
import 'package:second_practice/models/alibi_request.dart';
import 'package:second_practice/models/record_query.dart';
import 'package:second_practice/repositories/api_agency_repository.dart';

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions, Future<void>?) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return await respond(options, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
Map<String, Object?> result(List<Object> items) => {
  'items': items,
  'page': 1,
  'size': 10,
  'total': items.length,
};
const service = {
  'id': 1,
  'name': 'Тестовая услуга',
  'description': 'Описание услуги',
  'category': 'Стандартная',
  'price': 500,
  'createdAt': '2026-01-01T00:00:00Z',
  'deletedAt': null,
};
const serviceDraft = {
  'name': 'Новая услуга',
  'description': 'Описание услуги',
  'category': 'Стандартная',
  'price': '500',
  'createdAt': '2026-01-01',
};

void main() {
  late Dio dio;
  late StubAdapter adapter;
  late ApiAgencyRepository repository;
  void setup(
    FutureOr<ResponseBody> Function(RequestOptions, Future<void>?) respond,
  ) {
    dio = buildDio();
    adapter = StubAdapter(respond);
    dio.httpClientAdapter = adapter;
    repository = ApiAgencyRepository(dio, retryDelay: Duration.zero);
  }

  tearDown(() => dio.close(force: true));

  test('query parameters and expanded relationships are decoded', () async {
    setup(
      (options, _) => jsonResponse(
        result([
          {
            'id': 4,
            'title': 'Новая заявка',
            'code': 'ALI-0004',
            'client': {'id': 2, 'name': 'Клиент'},
            'service': service,
            'employees': [
              {'id': 3, 'name': 'Сотрудник'},
            ],
            'scenarios': [
              {'id': 5, 'name': 'Сценарий'},
            ],
            'eventDate': '2026-01-01T00:00:00Z',
            'createdAt': '2026-01-01T00:00:00Z',
          },
        ]),
      ),
    );
    final page = await repository.find(
      EntityKind.requests,
      const RecordQuery(
        search: 'тест',
        category: 'lateForWork',
        status: 'ready',
        page: 2,
        size: 25,
        ascending: true,
        includeDeleted: true,
        delayMs: 1500,
      ),
    );
    final record = page.items.single as AlibiRequest;
    expect(record.clientId, 2);
    expect(record.serviceId, 1);
    expect(record.employeeIds, [3]);
    expect(record.scenarioIds, [5]);
    expect(repository.nameOf(EntityKind.clients, 2), 'Клиент');
    expect(adapter.requests.single.queryParameters, containsPair('page', 2));
    expect(
      adapter.requests.single.queryParameters,
      containsPair('sort', 'date,asc'),
    );
    expect(
      adapter.requests.single.queryParameters,
      containsPair('__delay', 1500),
    );
    expect(adapter.requests.single.uri.path, '/api/requests');
  });
  test('422 from a write reaches the form with field names', () async {
    setup(
      (_, _) => jsonResponse({
        'message': 'Ошибка валидации',
        'errors': {'name': 'Уже используется'},
      }, 422),
    );
    await expectLater(
      repository.saveForm(EntityKind.services, serviceDraft, null),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.errors['name'],
          'name',
          'Уже используется',
        ),
      ),
    );
    expect(adapter.requests.length, 1);
  });
  test('network failure is retried at most three times for reads', () async {
    setup(
      (options, _) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    await expectLater(
      repository.find(EntityKind.requests, const RecordQuery()),
      throwsA(isA<NetworkException>()),
    );
    expect(adapter.requests.length, 3);
  });
  test('a transient network failure succeeds on the next attempt', () async {
    var count = 0;
    setup((options, _) {
      if (++count < 3) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return jsonResponse(result([service]));
    });
    expect(
      (await repository.find(
        EntityKind.services,
        const RecordQuery(),
      )).items.length,
      1,
    );
    expect(count, 3);
  });
  test('writes are never retried on a network failure', () async {
    setup(
      (options, _) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    await expectLater(
      repository.saveForm(EntityKind.services, serviceDraft, null),
      throwsA(isA<NetworkException>()),
    );
    expect(adapter.requests.length, 1);
  });
  test('409 preserves the explanation and is not retried', () async {
    setup((_, _) => jsonResponse({'message': 'Связанные заявки: 2'}, 409));
    await expectLater(
      repository.deleteMany(EntityKind.clients, [1]),
      throwsA(
        isA<ConflictException>().having(
          (e) => e.message,
          'message',
          'Связанные заявки: 2',
        ),
      ),
    );
    expect(adapter.requests.length, 1);
  });
  test('500 remains a server error and is not a network retry', () async {
    setup((_, _) => jsonResponse({'message': 'Тестовая ошибка 500'}, 500));
    await expectLater(
      repository.find(EntityKind.requests, const RecordQuery(failStatus: 500)),
      throwsA(
        isA<ServerException>().having(
          (e) => e.message,
          'message',
          'Тестовая ошибка 500',
        ),
      ),
    );
    expect(adapter.requests.length, 1);
  });
  test('reference requests are cached and coalesced across forms', () async {
    setup(
      (options, _) =>
          jsonResponse(options.path == '/services/options' ? [service] : []),
    );
    await Future.wait([
      repository.prepareForm(EntityKind.requests, null),
      repository.prepareForm(EntityKind.requests, null),
    ]);
    await repository.prepareForm(EntityKind.requests, null);
    expect(adapter.requests.length, 4);
    expect(repository.all(EntityKind.services).single.id, 1);
  });
  test('reference cache is invalidated when that entity changes', () async {
    setup(
      (options, _) => jsonResponse(
        options.method == 'POST'
            ? service
            : options.path == '/services/options'
            ? [service]
            : [],
      ),
    );
    await repository.prepareForm(EntityKind.scenarios, null);
    await repository.saveForm(EntityKind.services, serviceDraft, null);
    await repository.prepareForm(EntityKind.scenarios, null);
    expect(
      adapter.requests
          .where((request) => request.path == '/services/options')
          .length,
      2,
    );
  });
  test('the next page replaces the previous page in memory', () async {
    setup(
      (options, _) => jsonResponse(
        result([
          {...service, 'id': options.queryParameters['page']},
        ]),
      ),
    );
    await repository.find(EntityKind.services, const RecordQuery());
    await repository.find(EntityKind.services, const RecordQuery(page: 2));
    expect(repository.all(EntityKind.services).map((record) => record.id), [2]);
    expect(adapter.requests.length, 2);
  });
  test(
    'obsolete list requests are cancelled and do not overwrite data',
    () async {
      final started = Completer<void>();
      setup((options, cancelled) async {
        if (options.queryParameters['search'] == 'старый') {
          started.complete();
          await cancelled;
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
          );
        }
        return jsonResponse(result([service]));
      });
      final old = repository.find(
        EntityKind.services,
        const RecordQuery(search: 'старый'),
      );
      final assertion = expectLater(
        old,
        throwsA(isA<RequestCancelledException>()),
      );
      await started.future;
      await repository.find(
        EntityKind.services,
        const RecordQuery(search: 'новый'),
      );
      await assertion;
      expect(repository.all(EntityKind.services).single.id, 1);
      expect(adapter.requests.length, 2);
    },
  );
  test(
    'duplicate submission is rejected while the first write is pending',
    () async {
      final response = Completer<ResponseBody>();
      setup((_, _) => response.future);
      final first = repository.saveForm(
        EntityKind.services,
        serviceDraft,
        null,
      );
      await expectLater(
        repository.saveForm(EntityKind.services, serviceDraft, null),
        throwsA(isA<ConflictException>()),
      );
      response.complete(jsonResponse(service, 201));
      await first;
      expect(adapter.requests.length, 1);
    },
  );
  test('empty lists and incomplete JSON do not crash decoding', () async {
    setup((_, _) => jsonResponse(result([])));
    expect(
      (await repository.find(EntityKind.requests, const RecordQuery())).items,
      isEmpty,
    );
    expect(
      AlibiRequest.fromJson({
        'id': 1,
        'client': null,
        'employees': null,
      }).employeeIds,
      isEmpty,
    );
  });
  test('invalid response structure becomes a domain error', () async {
    setup((_, _) => jsonResponse({'items': 'incorrect'}));
    await expectLater(
      repository.find(EntityKind.requests, const RecordQuery()),
      throwsA(isA<ServerException>()),
    );
  });
}
