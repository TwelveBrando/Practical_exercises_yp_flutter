import '../models/alibi_request.dart';
import '../models/page_result.dart';
import '../models/request_query.dart';

abstract interface class RequestRepository {
  Future<PageResult<AlibiRequest>> find(RequestQuery query);
  Future<AlibiRequest?> findById(int id);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}
