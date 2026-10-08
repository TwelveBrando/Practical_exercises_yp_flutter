import '../models/alibi_request.dart';
import '../models/agency_service.dart';
import '../models/client.dart';
import '../models/employee.dart';
import '../models/scenario.dart';
import '../models/business_record.dart';
import '../models/json_readers.dart';
import '../models/agency_record.dart';
import '../models/page_result.dart';
import '../models/record_query.dart';
import '../validation/record_fields.dart';

abstract class AgencyRepositoryContract {
  String? get startupNotice;
  bool get validatesOnServer => false;
  Map<EntityKind, List<AgencyRecord>> get catalogs;
  List<AgencyRecord> all(EntityKind kind);
  AgencyRecord? byId(EntityKind kind, int id) =>
      all(kind).where((record) => record.id == id).firstOrNull;
  String nameOf(EntityKind kind, int id) =>
      byId(kind, id)?.name ?? 'Запись #$id не найдена';
  AgencyRecord decode(EntityKind kind, Map<String, dynamic> json) =>
      switch (kind) {
        EntityKind.requests => AlibiRequest.fromJson(json),
        EntityKind.clients => Client.fromJson(json),
        EntityKind.employees => Employee.fromJson(json),
        EntityKind.services => AgencyService.fromJson(json),
        EntityKind.scenarios => Scenario.fromJson(json),
        EntityKind.cards ||
        EntityKind.contracts ||
        EntityKind.payments => BusinessRecord(kind, json),
      };

  Future<void> initialize();
  Map<String, dynamic> formValues(EntityKind kind, int? id) {
    final today = formatDate(DateTime.now());
    final record = id == null ? null : byId(kind, id);
    final values =
        record?.toJson() ??
        <String, dynamic>{
          'type': RequestType.lateForWork.name,
          'status': RequestStatus.newRequest.name,
          'urgency': '1',
          'employeeIds': <int>[],
          'scenarioIds': <int>[],
          'joinedAt': today,
          'hiredAt': today,
          'createdAt': today,
          'cardIssuedAt': today,
          'cardPoints': '0',
          'experienceYears': '0',
          'durationMinutes': '30',
          'issuedAt': today,
          'paidAt': today,
          'points': '0',
          'discountPercent': '0',
          'method': 'card',
        };
    if (record == null && kind == EntityKind.contracts) {
      values['status'] = 'draft';
    }
    if (record == null && kind == EntityKind.payments) {
      values['status'] = 'paid';
    }
    if (record is Client) {
      values['cardNumber'] = record.card?.number ?? '';
      values['cardIssuedAt'] = formatDate(
        record.card?.issuedAt ?? record.joinedAt,
      );
      values['cardPoints'] = '${record.card?.points ?? 0}';
    }
    for (final key in [
      'eventDate',
      'joinedAt',
      'hiredAt',
      'createdAt',
      'issuedAt',
      'paidAt',
    ]) {
      if (values[key] != null) values[key] = formatDate(readDate(values[key]));
    }
    return values;
  }

  Future<void> prepareForm(EntityKind kind, int? id) async {}
  Future<void> prepareDetail(EntityKind kind, int id) async {}
  List<FieldOption> filterOptions(EntityKind kind) =>
      categoryOptions(kind, catalogs);
  void cancelFind() {}
  Future<AgencyRecord> saveForm(
    EntityKind kind,
    Map<String, dynamic> draft,
    int? editingId,
  );
  Future<void> deleteMany(
    EntityKind kind,
    Iterable<int> ids, {
    bool hard = false,
  });
  Future<void> restore(EntityKind kind, int id);
  Future<PageResult<AgencyRecord>> find(EntityKind kind, RecordQuery query);
}
