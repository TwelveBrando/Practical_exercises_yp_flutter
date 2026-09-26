class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });
  PageResult.empty() : items = <T>[], page = 1, size = 10, total = 0;
  final List<T> items;
  final int page;
  final int size;
  final int total;
  int get totalPages => total == 0 ? 1 : (total / size).ceil();
}
