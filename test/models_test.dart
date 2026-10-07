import 'package:flutter_test/flutter_test.dart';
import 'package:second_practice/models/agency_service.dart';
import 'package:second_practice/models/client.dart';
import 'package:second_practice/models/alibi_request.dart';
import 'package:second_practice/models/json_readers.dart';
import 'package:second_practice/models/page_result.dart';

void main() {
  test('client tolerates absent fields and malformed card', () {
    final client = Client.fromJson({'id': '7', 'card': 'invalid'});
    expect(client.id, 7);
    expect(client.name, '');
    expect(client.card, isNull);
    expect(client.isDeleted, false);
  });
  test('service round trip preserves price and deletion state', () {
    final service = AgencyService.fromJson({
      'id': 5,
      'name': 'Услуга',
      'price': '500',
      'createdAt': '2026-01-01',
      'deletedAt': '2026-02-01',
    });
    final restored = AgencyService.fromJson(service.toJson());
    expect(restored.price, 500);
    expect(restored.name, 'Услуга');
    expect(restored.isDeleted, true);
  });
  test('request defaults unknown enums and removes duplicate relations', () {
    final request = AlibiRequest.fromJson({
      'id': 1,
      'type': 'unknown',
      'status': 'unknown',
      'employeeIds': [1, '2', 1, -1],
    });
    expect(request.type, RequestType.lateForWork);
    expect(request.status, RequestStatus.newRequest);
    expect(request.employeeIds, [1, 2]);
  });
  test('JSON readers reject nonfinite numbers and malformed structures', () {
    expect(readInt(double.infinity, 7), 7);
    expect(readIds('1,2'), isEmpty);
    expect(readOptionalDate('bad'), isNull);
    expect(readMap(null), isEmpty);
  });
  test('pagination rounds up and retains one page for an empty result', () {
    expect(
      const PageResult<int>(
        items: [1],
        page: 1,
        size: 10,
        total: 21,
      ).totalPages,
      3,
    );
    expect(PageResult<int>.empty().totalPages, 1);
  });
}
