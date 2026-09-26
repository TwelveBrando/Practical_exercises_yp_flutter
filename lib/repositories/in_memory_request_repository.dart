import '../data/seed_data.dart';
import '../models/alibi_request.dart';
import '../models/page_result.dart';
import '../models/request_query.dart';
import 'request_repository.dart';

class InMemoryRequestRepository implements RequestRepository {
  final List<AlibiRequest> _requests = [...seedRequests];

  @override
  Future<PageResult<AlibiRequest>> find(RequestQuery query) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (query.demoError) {
      throw StateError('Демонстрационная ошибка загрузки');
    }
    var filteredRequests = _requests
        .where((request) => query.includeDeleted || !request.isDeleted)
        .toList();
    final searchText = query.search.trim().toLowerCase();

    if (searchText.isNotEmpty) {
      filteredRequests = filteredRequests
          .where(
            (request) =>
                request.title.toLowerCase().contains(searchText) ||
                request.id.toString() == searchText,
          )
          .toList();
    }
    if (query.type != null) {
      filteredRequests = filteredRequests
          .where((request) => request.type == query.type)
          .toList();
    }
    if (query.status != null) {
      filteredRequests = filteredRequests
          .where((request) => request.status == query.status)
          .toList();
    }
    final startDate = DateTime.tryParse(query.dateFrom ?? '');
    final endDate = DateTime.tryParse(query.dateTo ?? '');

    if (startDate != null) {
      filteredRequests = filteredRequests
          .where((request) => !request.eventDate.isBefore(startDate))
          .toList();
    }
    if (endDate != null) {
      filteredRequests = filteredRequests
          .where(
            (request) => !request.eventDate.isAfter(
              endDate.add(const Duration(days: 1)),
            ),
          )
          .toList();
    }

    filteredRequests.sort((firstRequest, secondRequest) {
      final comparison = switch (query.sortField) {
        'title' => firstRequest.title.toLowerCase().compareTo(
          secondRequest.title.toLowerCase(),
        ),
        'status' => firstRequest.status.index.compareTo(
          secondRequest.status.index,
        ),
        'urgency' => firstRequest.urgency.compareTo(secondRequest.urgency),
        _ => firstRequest.eventDate.compareTo(secondRequest.eventDate),
      };
      return query.ascending ? comparison : -comparison;
    });

    final totalPages = filteredRequests.isEmpty
        ? 1
        : (filteredRequests.length / query.size).ceil();
    final currentPage = query.page.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * query.size;
    final endIndex = (startIndex + query.size).clamp(
      0,
      filteredRequests.length,
    );

    return PageResult(
      items: filteredRequests.isEmpty
          ? <AlibiRequest>[]
          : filteredRequests.sublist(startIndex, endIndex),
      page: currentPage,
      size: query.size,
      total: filteredRequests.length,
    );
  }

  @override
  Future<AlibiRequest?> findById(int id) async {
    for (final request in _requests) {
      if (request.id == id) return request;
    }
    return null;
  }

  int _indexOfRequest(int id) =>
      _requests.indexWhere((request) => request.id == id);

  @override
  Future<void> softDelete(int id) async {
    final requestIndex = _indexOfRequest(id);
    if (requestIndex < 0) throw StateError('Заявка не найдена');
    _requests[requestIndex] = _requests[requestIndex].copyWith(
      deletedAt: DateTime.now(),
    );
  }

  @override
  Future<void> hardDelete(int id) async {
    _requests.removeWhere((request) => request.id == id);
  }

  @override
  Future<void> restore(int id) async {
    final requestIndex = _indexOfRequest(id);
    if (requestIndex < 0) throw StateError('Заявка не найдена');
    _requests[requestIndex] = _requests[requestIndex].copyWith(
      clearDeletedAt: true,
    );
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    var count = 0;
    for (final id in ids) {
      final requestIndex = _requests.indexWhere(
        (request) => request.id == id && !request.isDeleted,
      );
      if (requestIndex != -1) {
        _requests[requestIndex] = _requests[requestIndex].copyWith(
          deletedAt: DateTime.now(),
        );
        count++;
      }
    }
    return count;
  }
}
