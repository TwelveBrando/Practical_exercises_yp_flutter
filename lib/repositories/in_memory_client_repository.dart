import '../data/seed_data.dart';
import '../models/client.dart';
import '../models/client_query.dart';
import '../models/page_result.dart';
import 'client_repository.dart';

class InMemoryClientRepository implements ClientRepository {
  final List<Client> _clients = [...seedClients];

  @override
  Future<PageResult<Client>> find(ClientQuery query) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (query.demoError) {
      throw StateError('Демонстрационная ошибка загрузки');
    }
    var filteredClients = _clients
        .where((client) => query.includeDeleted || !client.isDeleted)
        .toList();
    final searchText = query.search.trim().toLowerCase();

    if (searchText.isNotEmpty) {
      filteredClients = filteredClients
          .where(
            (client) =>
                client.name.toLowerCase().contains(searchText) ||
                client.email.toLowerCase().contains(searchText),
          )
          .toList();
    }
    if (query.city != null) {
      filteredClients = filteredClients
          .where((client) => client.city == query.city)
          .toList();
    }
    if (query.joinedFrom != null) {
      filteredClients = filteredClients
          .where((client) => client.joinedAt.year >= query.joinedFrom!)
          .toList();
    }
    if (query.joinedTo != null) {
      filteredClients = filteredClients
          .where((client) => client.joinedAt.year <= query.joinedTo!)
          .toList();
    }

    filteredClients.sort((firstClient, secondClient) {
      final comparison = switch (query.sortField) {
        'email' => firstClient.email.compareTo(secondClient.email),
        'city' => firstClient.city.compareTo(secondClient.city),
        'joinedAt' => firstClient.joinedAt.compareTo(secondClient.joinedAt),
        _ => firstClient.name.toLowerCase().compareTo(
          secondClient.name.toLowerCase(),
        ),
      };
      return query.ascending ? comparison : -comparison;
    });

    final totalPages = filteredClients.isEmpty
        ? 1
        : (filteredClients.length / query.size).ceil();
    final currentPage = query.page.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * query.size;
    final endIndex = (startIndex + query.size).clamp(0, filteredClients.length);

    return PageResult(
      items: filteredClients.isEmpty
          ? <Client>[]
          : filteredClients.sublist(startIndex, endIndex),
      page: currentPage,
      size: query.size,
      total: filteredClients.length,
    );
  }

  @override
  Future<Client?> findById(int id) async {
    for (final client in _clients) {
      if (client.id == id) return client;
    }
    return null;
  }

  int _indexOfClient(int id) =>
      _clients.indexWhere((client) => client.id == id);

  @override
  Future<void> softDelete(int id) async {
    final clientIndex = _indexOfClient(id);
    if (clientIndex < 0) throw StateError('Клиент не найден');
    _clients[clientIndex] = _clients[clientIndex].copyWith(
      deletedAt: DateTime.now(),
    );
  }

  @override
  Future<void> hardDelete(int id) async {
    _clients.removeWhere((client) => client.id == id);
  }

  @override
  Future<void> restore(int id) async {
    final clientIndex = _indexOfClient(id);
    if (clientIndex < 0) throw StateError('Клиент не найден');
    _clients[clientIndex] = _clients[clientIndex].copyWith(
      clearDeletedAt: true,
    );
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    var count = 0;
    for (final id in ids) {
      final clientIndex = _clients.indexWhere(
        (client) => client.id == id && !client.isDeleted,
      );
      if (clientIndex != -1) {
        _clients[clientIndex] = _clients[clientIndex].copyWith(
          deletedAt: DateTime.now(),
        );
        count++;
      }
    }
    return count;
  }
}
