class RecordQuery {
  const RecordQuery({
    this.search = '',
    this.category,
    this.status,
    this.dateFrom,
    this.dateTo,
    this.sortField = 'date',
    this.ascending = false,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
    this.demoError = false,
    this.failStatus,
    this.delayMs = 0,
  });
  final String search;
  final String? category;
  final String? status;
  final String? dateFrom;
  final String? dateTo;
  final String sortField;
  final bool ascending;
  final int page;
  final int size;
  final bool includeDeleted;
  final bool demoError;
  final int? failStatus;
  final int delayMs;

  factory RecordQuery.fromUri(Uri uri) {
    final params = uri.queryParameters;
    final sort = (params['sort'] ?? 'date,desc').split(',');
    final size = int.tryParse(params['size'] ?? '') ?? 10;
    return RecordQuery(
      search: params['search'] ?? '',
      category: params['category'] ?? params['type'] ?? params['city'],
      status: params['status'],
      dateFrom: params['dateFrom'],
      dateTo: params['dateTo'],
      sortField: sort.first,
      ascending: sort.length < 2 || sort[1] != 'desc',
      page: (int.tryParse(params['page'] ?? '') ?? 1).clamp(1, 9999),
      size: [10, 25, 50].contains(size) ? size : 10,
      includeDeleted: params['deleted'] == '1',
      demoError: params['demoError'] == '1',
      failStatus: int.tryParse(params['__fail'] ?? ''),
      delayMs: (int.tryParse(params['__delay'] ?? '') ?? 0).clamp(0, 10000),
    );
  }

  Map<String, String> get params => {
    if (search.isNotEmpty) 'search': search,
    'category': ?category,
    'status': ?status,
    'dateFrom': ?dateFrom,
    'dateTo': ?dateTo,
    'sort': '$sortField,${ascending ? 'asc' : 'desc'}',
    'page': '$page',
    'size': '$size',
    if (includeDeleted) 'deleted': '1',
    if (demoError) 'demoError': '1',
    if (failStatus != null) '__fail': '$failStatus',
    if (delayMs > 0) '__delay': '$delayMs',
  };
}
