import '../models/client.dart';
import '../models/client_query.dart';
import '../models/page_result.dart';

abstract interface class ClientRepository {
  Future<PageResult<Client>> find(ClientQuery query);
  Future<Client?> findById(int id);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}
