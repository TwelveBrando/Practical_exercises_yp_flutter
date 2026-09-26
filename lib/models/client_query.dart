class ClientQuery {
  const ClientQuery({
    this.search = '',
    this.city,
    this.joinedFrom,
    this.joinedTo,
    this.sortField = 'name',
    this.ascending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
    this.demoError = false,
  });
  final String search;
  final String? city;
  final int? joinedFrom;
  final int? joinedTo;
  final String sortField;
  final bool ascending;
  final int page;
  final int size;
  final bool includeDeleted;
  final bool demoError;

  static const _unchanged = Object();

  ClientQuery copyWith({
    String? search,
    Object? city = _unchanged,
    Object? joinedFrom = _unchanged,
    Object? joinedTo = _unchanged,
    String? sortField,
    bool? ascending,
    int? page,
    int? size,
    bool? includeDeleted,
    bool? demoError,
  }) {
    return ClientQuery(
      search: search ?? this.search,
      city: identical(city, _unchanged) ? this.city : city as String?,
      joinedFrom: identical(joinedFrom, _unchanged)
          ? this.joinedFrom
          : joinedFrom as int?,
      joinedTo: identical(joinedTo, _unchanged)
          ? this.joinedTo
          : joinedTo as int?,
      sortField: sortField ?? this.sortField,
      ascending: ascending ?? this.ascending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      demoError: demoError ?? this.demoError,
    );
  }

  factory ClientQuery.fromUri(Uri uri) {
    final parameters = uri.queryParameters;
    final sortParts = (parameters['sort'] ?? 'name,asc').split(',');

    int? readIntParameter(String name) => int.tryParse(parameters[name] ?? '');

    final requestedPageSize = readIntParameter('size') ?? 10;

    return ClientQuery(
      search: parameters['search'] ?? '',
      city: parameters['city'],
      joinedFrom: readIntParameter('joinedFrom'),
      joinedTo: readIntParameter('joinedTo'),
      sortField: sortParts.first,
      ascending: sortParts.length < 2 || sortParts[1] != 'desc',
      page: (readIntParameter('page') ?? 1).clamp(1, 9999),
      size: [10, 25, 50].contains(requestedPageSize) ? requestedPageSize : 10,
      includeDeleted: parameters['deleted'] == '1',
      demoError: parameters['demoError'] == '1',
    );
  }

  Map<String, String> get params {
    final queryParameters = <String, String>{};
    if (search.isNotEmpty) queryParameters['search'] = search;
    if (city != null) queryParameters['city'] = city!;
    if (joinedFrom != null) queryParameters['joinedFrom'] = '$joinedFrom';
    if (joinedTo != null) queryParameters['joinedTo'] = '$joinedTo';
    queryParameters['sort'] = '$sortField,${ascending ? 'asc' : 'desc'}';
    queryParameters['page'] = '$page';
    queryParameters['size'] = '$size';
    if (includeDeleted) queryParameters['deleted'] = '1';
    if (demoError) queryParameters['demoError'] = '1';
    return queryParameters;
  }
}
