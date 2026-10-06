import 'package:flutter/foundation.dart';
import '../models/agency_record.dart';
import '../repositories/agency_repository_contract.dart';

class AgencyState extends ChangeNotifier {
  AgencyState(this.repository);
  final AgencyRepositoryContract repository;
  int revision = 0;
  bool _disposed = false;

  Future<AgencyRecord> save(
    EntityKind kind,
    Map<String, dynamic> values,
    int? id,
  ) async {
    final record = await repository.saveForm(kind, values, id);
    revision++;
    if (!_disposed) notifyListeners();
    return record;
  }

  Future<void> delete(
    EntityKind kind,
    Iterable<int> ids, {
    bool hard = false,
  }) async {
    await repository.deleteMany(kind, ids, hard: hard);
    revision++;
    if (!_disposed) notifyListeners();
  }

  Future<void> restore(EntityKind kind, int id) async {
    await repository.restore(kind, id);
    revision++;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
