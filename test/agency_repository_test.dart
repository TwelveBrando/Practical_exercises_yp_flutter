import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_practice/models/agency_record.dart';
import 'package:second_practice/models/alibi_request.dart';
import 'package:second_practice/models/client.dart';
import 'package:second_practice/models/record_query.dart';
import 'package:second_practice/repositories/agency_repository.dart';
import 'package:second_practice/validation/validators.dart';

void main() {
  late SharedPreferences preferences;
  late AgencyRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = AgencyRepository(preferences);
    await repository.initialize();
  });

  Map<String, dynamic> draft(EntityKind kind) => {
    ...repository.formValues(kind, null),
    ...switch (kind) {
      EntityKind.requests => {
        'title': 'Новая заявка',
        'code': 'ALI-0900',
        'eventDate': '2026-09-30',
        'clientId': 1,
        'serviceId': 1,
        'employeeIds': [1],
        'scenarioIds': [1],
      },
      EntityKind.clients => {
        'name': 'Новый клиент',
        'email': 'new@example.com',
        'city': 'Москва',
        'cardNumber': 'CARD-0900',
      },
      EntityKind.employees => {
        'name': 'Новый сотрудник',
        'email': 'new@alibi.example',
        'phone': '+7 900 123-45-67',
        'specialty': 'Бытовые ситуации',
      },
      EntityKind.services => {
        'name': 'Новая услуга',
        'description': 'Описание новой услуги',
        'category': 'Стандартная',
        'price': '800',
      },
      EntityKind.scenarios => {
        'name': 'Новый сценарий',
        'description': 'Описание нового сценария',
        'serviceId': 1,
      },
    },
  };

  test('all five models safely parse absent and null fields', () {
    for (final kind in EntityKind.values) {
      expect(() => repository.decode(kind, {}), returnsNormally);
      expect(
        () => repository.decode(kind, {
          'id': null,
          'name': null,
          'deletedAt': null,
          'employeeIds': null,
          'urgency': '2',
          'createdAt': false,
        }),
        returnsNormally,
      );
    }
  });

  test('all models and embedded client card round-trip JSON', () {
    for (final kind in EntityKind.values) {
      for (final record in repository.all(kind)) {
        final json = record.toJson();
        expect(repository.decode(kind, json).toJson(), equals(json));
      }
    }
  });

  for (final kind in EntityKind.values) {
    test('${kind.name}: create edit delete restore and persistence', () async {
      final record = await repository.saveForm(kind, draft(kind), null);
      final values = repository.formValues(kind, record.id);
      values[kind == EntityKind.requests ? 'title' : 'name'] =
          'Изменённая запись';
      await repository.saveForm(kind, values, record.id);
      await repository.deleteMany(kind, [record.id]);
      final restoredRepository = AgencyRepository(preferences);
      await restoredRepository.initialize();
      expect(
        restoredRepository.byId(kind, record.id)!.name,
        'Изменённая запись',
      );
      expect(restoredRepository.byId(kind, record.id)!.isDeleted, isTrue);
      await restoredRepository.restore(kind, record.id);
      expect(restoredRepository.byId(kind, record.id)!.isDeleted, isFalse);
      await restoredRepository.deleteMany(kind, [record.id], hard: true);
      expect(restoredRepository.byId(kind, record.id), isNull);
    });
  }

  test(
    'client email and request code are unique, current record is excluded',
    () async {
      final client = draft(EntityKind.clients)
        ..['email'] = ' I.PETROV@example.com ';
      await expectLater(
        repository.saveForm(EntityKind.clients, client, null),
        throwsA(
          isA<FieldValidationException>().having(
            (error) => error.errors.keys,
            'field',
            contains('email'),
          ),
        ),
      );
      final request = draft(EntityKind.requests)..['code'] = 'ALI-0001';
      await expectLater(
        repository.saveForm(EntityKind.requests, request, null),
        throwsA(
          isA<FieldValidationException>().having(
            (error) => error.errors.keys,
            'field',
            contains('code'),
          ),
        ),
      );
      await repository.saveForm(
        EntityKind.clients,
        repository.formValues(EntityKind.clients, 1),
        1,
      );
    },
  );

  test(
    'deleting a related service is refused and storage does not change',
    () async {
      final before = preferences.getString(AgencyRepository.storageKey);
      await expectLater(
        repository.deleteMany(EntityKind.services, [1], hard: true),
        throwsA(
          isA<RelatedRecordsException>().having(
            (error) => error.counts['заявки'],
            'requests',
            greaterThan(0),
          ),
        ),
      );
      expect(preferences.getString(AgencyRepository.storageKey), before);
    },
  );

  test('scenarios must belong to the selected service', () async {
    final values = draft(EntityKind.requests)..['scenarioIds'] = [2];
    await expectLater(
      repository.saveForm(EntityKind.requests, values, null),
      throwsA(
        isA<FieldValidationException>().having(
          (error) => error.errors.keys,
          'field',
          contains('scenarioIds'),
        ),
      ),
    );
  });

  test('invalid fields are rejected together, not only the first', () async {
    final values = draft(EntityKind.clients)
      ..['name'] = ''
      ..['email'] = 'broken'
      ..['cardPoints'] = '-1';
    await expectLater(
      repository.saveForm(EntityKind.clients, values, null),
      throwsA(
        isA<FieldValidationException>().having(
          (error) => error.errors.keys,
          'fields',
          containsAll(['name', 'email', 'cardPoints']),
        ),
      ),
    );
  });

  test(
    'old schema migrates and damaged data is backed up without crashing',
    () async {
      final old = {
        'schemaVersion': 1,
        'records': {
          'clients': [
            {
              'id': 1,
              'name': 'Старый клиент',
              'email': 'old@example.com',
              'city': 'Москва',
              'joinedAt': '2025-01-01',
            },
          ],
          'requests': [
            {
              'id': 1,
              'clientId': 1,
              'title': 'Старая заявка',
              'eventDate': '2026-01-01',
            },
          ],
        },
      };
      await preferences.remove(AgencyRepository.storageKey);
      await preferences.setString(
        AgencyRepository.oldStorageKey,
        jsonEncode(old),
      );
      final migrated = AgencyRepository(preferences);
      await migrated.initialize();
      expect((migrated.byId(EntityKind.clients, 1) as Client).card, isNotNull);
      expect(
        (migrated.byId(EntityKind.requests, 1) as AlibiRequest).code,
        'ALI-0001',
      );
      expect(migrated.startupNotice, contains('обновлён'));
      await preferences.setString(AgencyRepository.storageKey, 'not-json');
      final recovered = AgencyRepository(preferences);
      await recovered.initialize();
      expect(recovered.all(EntityKind.requests), hasLength(24));
      expect(recovered.startupNotice, contains('резервная копия'));
      expect(
        preferences.getKeys().any((key) => key.startsWith('alibi_backup_')),
        isTrue,
      );
    },
  );

  test('calendar dates, number ranges and identifier format are validated', () {
    expect(Validators.date('2026-02-31'), isNotNull);
    expect(Validators.date('2024-02-29'), isNull);
    expect(Validators.integer('1.5', min: 1), isNotNull);
    expect(Validators.integer('-1', min: 0), isNotNull);
    expect(Validators.identifier('ALI-0001', 'ALI'), isNull);
    expect(Validators.identifier('wrong', 'ALI'), isNotNull);
  });

  test(
    'all catalogs support search, category, dates, sorting and pages',
    () async {
      final categories = <EntityKind, String>{
        EntityKind.requests: 'lateForWork',
        EntityKind.clients: 'Москва',
        EntityKind.employees: 'Бытовые ситуации',
        EntityKind.services: 'Стандартная',
        EntityKind.scenarios: '1',
      };
      for (final kind in EntityKind.values) {
        final record = repository.all(kind).first;
        final searched = await repository.find(
          kind,
          RecordQuery(search: record.name),
        );
        expect(searched.items.map((item) => item.id), contains(record.id));
        final filtered = await repository.find(
          kind,
          RecordQuery(category: categories[kind]),
        );
        expect(filtered.items, isNotEmpty);
        final dated = await repository.find(
          kind,
          RecordQuery(
            dateFrom: record.date.toIso8601String().substring(0, 10),
            dateTo: record.date.toIso8601String().substring(0, 10),
          ),
        );
        expect(dated.items.map((item) => item.id), contains(record.id));
        final sorted = await repository.find(
          kind,
          const RecordQuery(sortField: 'name', ascending: true, size: 50),
        );
        final names = sorted.items
            .map((item) => item.name.toLowerCase())
            .toList();
        expect(names, equals([...names]..sort()));
        final empty = await repository.find(
          kind,
          const RecordQuery(search: 'несуществующаязаписьxyz'),
        );
        expect(empty.items, isEmpty);
      }
      final secondPage = await repository.find(
        EntityKind.requests,
        const RecordQuery(page: 2, size: 10),
      );
      expect(secondPage.page, 2);
      expect(secondPage.items, hasLength(10));
      await expectLater(
        repository.find(
          EntityKind.requests,
          const RecordQuery(demoError: true),
        ),
        throwsStateError,
      );
    },
  );

  test('batch deletion is atomic and next IDs are not reused', () async {
    final service = await repository.saveForm(
      EntityKind.services,
      draft(EntityKind.services),
      null,
    );
    await expectLater(
      repository.deleteMany(EntityKind.services, [service.id, 1], hard: true),
      throwsA(isA<RelatedRecordsException>()),
    );
    expect(repository.byId(EntityKind.services, service.id), isNotNull);
    await repository.deleteMany(EntityKind.services, [service.id], hard: true);
    final reloaded = AgencyRepository(preferences);
    await reloaded.initialize();
    final next = await reloaded.saveForm(
      EntityKind.services,
      draft(EntityKind.services),
      null,
    );
    expect(next.id, greaterThan(service.id));
  });

  test(
    'changing a linked scenario service is rejected at service field',
    () async {
      final values = repository.formValues(EntityKind.scenarios, 1)
        ..['serviceId'] = 2;
      await expectLater(
        repository.saveForm(EntityKind.scenarios, values, 1),
        throwsA(
          isA<FieldValidationException>().having(
            (error) => error.errors.keys,
            'fields',
            contains('serviceId'),
          ),
        ),
      );
    },
  );

  test('unsupported storage types recover without a cast failure', () async {
    await preferences.setInt(AgencyRepository.storageKey, 42);
    final recovered = AgencyRepository(preferences);
    await recovered.initialize();
    expect(recovered.all(EntityKind.requests), hasLength(24));
    expect(recovered.startupNotice, contains('неподдерживаемый'));
  });
}
