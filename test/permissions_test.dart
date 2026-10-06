import 'package:flutter_test/flutter_test.dart';
import 'package:second_practice/models/app_user.dart';
import 'package:second_practice/router.dart';
import 'package:second_practice/repositories/auth_api.dart';

void main() {
  final expected = <Operation, List<bool>>{
    Operation.catalog: [true, true, true],
    Operation.records: [false, true, true],
    Operation.write: [false, true, true],
    Operation.softDelete: [false, true, true],
    Operation.ownRequests: [true, false, false],
    Operation.reschedule: [true, false, false],
    Operation.work: [false, true, false],
    Operation.users: [false, false, true],
    Operation.statistics: [false, false, true],
    Operation.hardDelete: [false, false, true],
    Operation.restore: [false, false, true],
  };
  for (final entry in expected.entries) {
    test('permissions for ${entry.key.name}', () {
      for (var index = 0; index < Role.values.length; index++) {
        expect(Role.values[index].allows(entry.key), entry.value[index]);
      }
    });
  }
  test('exclusive routes are denied to other roles', () {
    expect(allowedPath(Role.client, '/my-requests'), true);
    expect(allowedPath(Role.admin, '/my-requests'), false);
    expect(allowedPath(Role.employee, '/work'), true);
    expect(allowedPath(Role.admin, '/work'), false);
    expect(allowedPath(Role.client, '/admin/users'), false);
    expect(allowedPath(Role.admin, '/admin/users'), true);
  });
  test('client cannot open management form through direct URL', () {
    expect(allowedPath(Role.client, '/services/new'), false);
    expect(allowedPath(Role.client, '/requests/1/edit'), false);
    expect(allowedPath(Role.client, '/services'), true);
  });
  test(
    'return destination accepts internal URL and rejects external redirects',
    () {
      expect(safeDestination('/services/1?from=demo'), '/services/1?from=demo');
      for (final value in [
        'https://evil.example',
        '//evil.example',
        '/\\evil.example',
        '/login',
        '/register',
        '/forbidden',
      ]) {
        expect(safeDestination(value), null);
      }
    },
  );
  test('password must meet all three rules including unicode text', () {
    expect(passwordProblems('short'), hasLength(3));
    expect(passwordProblems('password1'), hasLength(1));
    expect(passwordProblems('Пароль12!'), isEmpty);
  });
}
