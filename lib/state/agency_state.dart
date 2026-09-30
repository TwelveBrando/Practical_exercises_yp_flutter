import 'package:flutter/foundation.dart';
import '../models/agency_record.dart';
import '../repositories/agency_repository.dart';

class AgencyState extends ChangeNotifier {
  AgencyState(this.repository);
  final AgencyRepository repository;
  int revision = 0;

  Future<AgencyRecord> save(
    EntityKind kind,
    Map<String, dynamic> values,
    int? id,
  ) async {
    final record = await repository.saveForm(kind, values, id);
    revision++;
    notifyListeners();
    return record;
  }

  Future<void> delete(
    EntityKind kind,
    Iterable<int> ids, {
    bool hard = false,
  }) async {
    await repository.deleteMany(kind, ids, hard: hard);
    revision++;
    notifyListeners();
  }

  Future<void> restore(EntityKind kind, int id) async {
    await repository.restore(kind, id);
    revision++;
    notifyListeners();
  }
}
