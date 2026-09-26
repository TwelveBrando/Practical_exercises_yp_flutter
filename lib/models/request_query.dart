import 'alibi_request.dart';

class RequestQuery {
  const RequestQuery({
    this.search = '',
    this.type,
    this.status,
    this.dateFrom,
    this.dateTo,
    this.sortField = 'eventDate',
    this.ascending = false,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
    this.demoError = false,
  });
  final String search;
  final RequestType? type;
  final RequestStatus? status;
  final String? dateFrom;
  final String? dateTo;
  final String sortField;
  final bool ascending;
  final int page;
  final int size;
  final bool includeDeleted;
  final bool demoError;

  static const _unchanged = Object();

  RequestQuery copyWith({
    String? search,
    Object? type = _unchanged,
    Object? status = _unchanged,
    Object? dateFrom = _unchanged,
    Object? dateTo = _unchanged,
    String? sortField,
    bool? ascending,
    int? page,
    int? size,
    bool? includeDeleted,
    bool? demoError,
  }) {
    return RequestQuery(
      search: search ?? this.search,
      type: identical(type, _unchanged) ? this.type : type as RequestType?,
      status: identical(status, _unchanged)
          ? this.status
          : status as RequestStatus?,
      dateFrom: identical(dateFrom, _unchanged)
          ? this.dateFrom
          : dateFrom as String?,
      dateTo: identical(dateTo, _unchanged) ? this.dateTo : dateTo as String?,
      sortField: sortField ?? this.sortField,
      ascending: ascending ?? this.ascending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      demoError: demoError ?? this.demoError,
    );
  }

  factory RequestQuery.fromUri(Uri uri) {
    final parameters = uri.queryParameters;
    final sortParts = (parameters['sort'] ?? 'eventDate,desc').split(',');
    final requestedPageSize = int.tryParse(parameters['size'] ?? '') ?? 10;

    RequestType? type;
    RequestStatus? status;
    for (final requestType in RequestType.values) {
      if (requestType.name == parameters['type']) type = requestType;
    }
    for (final requestStatus in RequestStatus.values) {
      if (requestStatus.name == parameters['status']) {
        status = requestStatus;
      }
    }

    return RequestQuery(
      search: parameters['search'] ?? '',
      type: type,
      status: status,
      dateFrom: parameters['dateFrom'],
      dateTo: parameters['dateTo'],
      sortField: sortParts.first,
      ascending: sortParts.length < 2 || sortParts[1] != 'desc',
      page: (int.tryParse(parameters['page'] ?? '') ?? 1).clamp(1, 9999),
      size: [10, 25, 50].contains(requestedPageSize) ? requestedPageSize : 10,
      includeDeleted: parameters['deleted'] == '1',
      demoError: parameters['demoError'] == '1',
    );
  }

  Map<String, String> get params {
    final queryParameters = <String, String>{};
    if (search.isNotEmpty) queryParameters['search'] = search;
    if (type != null) queryParameters['type'] = type!.name;
    if (status != null) queryParameters['status'] = status!.name;
    if (dateFrom != null) queryParameters['dateFrom'] = dateFrom!;
    if (dateTo != null) queryParameters['dateTo'] = dateTo!;
    queryParameters['sort'] = '$sortField,${ascending ? 'asc' : 'desc'}';
    queryParameters['page'] = '$page';
    queryParameters['size'] = '$size';
    if (includeDeleted) queryParameters['deleted'] = '1';
    if (demoError) queryParameters['demoError'] = '1';
    return queryParameters;
  }
}
