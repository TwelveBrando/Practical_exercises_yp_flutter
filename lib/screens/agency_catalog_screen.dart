import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/agency_record.dart';
import '../models/alibi_request.dart';
import '../models/json_readers.dart';
import '../models/page_result.dart';
import '../models/record_query.dart';
import '../repositories/agency_repository.dart';
import '../state/agency_state.dart';
import '../validation/record_fields.dart';
import '../validation/validators.dart';
import '../widgets/app_shell.dart';
import '../widgets/entity_table.dart';
import '../widgets/filter_menu.dart';
import '../widgets/pagination_bar.dart';

class AgencyCatalogScreen extends StatefulWidget {
  const AgencyCatalogScreen({
    super.key,
    required this.kind,
    required this.query,
  });
  final EntityKind kind;
  final RecordQuery query;
  @override
  State<AgencyCatalogScreen> createState() => _AgencyCatalogScreenState();
}

class _AgencyCatalogScreenState extends State<AgencyCatalogScreen> {
  final _search = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _selected = <int>{};
  Timer? _debounce;
  Future<PageResult<AgencyRecord>>? _future;
  int _revision = -1;
  String? _fromError;
  String? _toError;
  bool _noticeHidden = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    void update(TextEditingController controller, String value) {
      if (controller.text == value) return;
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }

    update(_search, widget.query.search);
    update(_from, widget.query.dateFrom ?? '');
    update(_to, widget.query.dateTo ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<AgencyState>();
    if (_revision != state.revision || _future == null) {
      _revision = state.revision;
      _future = state.repository.find(widget.kind, widget.query);
      _selected.removeWhere(
        (id) => state.repository.byId(widget.kind, id) == null,
      );
    }
  }

  @override
  void didUpdateWidget(covariant AgencyCatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.query.params.toString() != widget.query.params.toString()) {
      _debounce?.cancel();
      _selected.clear();
      _sync();
      _fromError = null;
      _toError = null;
      _future = context.read<AgencyState>().repository.find(
        widget.kind,
        widget.query,
      );
    }
  }

  void _navigate(Map<String, String?> changes, {bool resetPage = true}) {
    final params = {...widget.query.params};
    if (resetPage) params['page'] = '1';
    for (final entry in changes.entries) {
      if (entry.value == null || entry.value!.isEmpty) {
        params.remove(entry.key);
      } else {
        params[entry.key] = entry.value!;
      }
    }
    context.go(Uri(path: widget.kind.path, queryParameters: params).toString());
  }

  void _applyDates() {
    setState(() {
      _fromError = _from.text.isEmpty ? null : Validators.date(_from.text);
      _toError = _to.text.isEmpty ? null : Validators.date(_to.text);
      if (_fromError == null &&
          _toError == null &&
          _from.text.isNotEmpty &&
          _to.text.isNotEmpty &&
          _from.text.compareTo(_to.text) > 0) {
        _toError = 'Дата должна быть не раньше начальной';
      }
    });
    if (_fromError == null && _toError == null) {
      _navigate({'dateFrom': _from.text, 'dateTo': _to.text});
    }
  }

  Future<void> _message(String message) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Действие не выполнено'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Понятно'),
        ),
      ],
    ),
  );

  Future<void> _delete(Iterable<int> ids) async {
    if (_busy) return;
    final selected = ids.toList();
    final hard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Удалить записи: ${selected.length}?'),
        content: const Text(
          'Записи из корзины можно восстановить. Окончательное удаление необратимо.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('В корзину'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить навсегда'),
          ),
        ],
      ),
    );
    if (hard == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<AgencyState>().delete(
        widget.kind,
        selected,
        hard: hard,
      );
      if (mounted) setState(() => _selected.removeAll(selected));
    } on RelatedRecordsException catch (error) {
      if (mounted) await _message(error.toString());
    } catch (_) {
      if (mounted) {
        await _message('Не удалось сохранить изменение. Попробуйте ещё раз.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(int id) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<AgencyState>().restore(widget.kind, id);
    } catch (_) {
      if (mounted) await _message('Не удалось восстановить запись.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<TableColumnSpec<AgencyRecord>> _columns(AgencyRepository repository) {
    TableColumnSpec<AgencyRecord> text(
      String key,
      String label, {
      double flex = 1.3,
      bool sortable = false,
    }) => TableColumnSpec(
      label: label,
      flex: flex,
      sortField: sortable ? key : null,
      build: (record) => Text(record.toJson()[key]?.toString() ?? '—'),
    );
    final title = TableColumnSpec<AgencyRecord>(
      label: widget.kind == EntityKind.requests ? 'Тема заявки' : 'Название',
      flex: 2,
      sortField: 'name',
      build: (record) => Text(record.name),
    );
    final date = TableColumnSpec<AgencyRecord>(
      label: widget.kind == EntityKind.requests ? 'Дата события' : 'Дата',
      flex: 1.4,
      sortField: 'date',
      build: (record) => Text(formatDate(record.date)),
    );
    switch (widget.kind) {
      case EntityKind.requests:
        return [
          title,
          TableColumnSpec(
            label: 'Тип',
            flex: 1.6,
            build: (record) =>
                Text(requestTypeLabels[(record as AlibiRequest).type]!),
          ),
          date,
          TableColumnSpec(
            label: 'Статус',
            build: (record) =>
                Text(requestStatusLabels[(record as AlibiRequest).status]!),
          ),
          TableColumnSpec(
            label: 'Срочность',
            flex: 1.2,
            sortField: 'urgency',
            numeric: true,
            build: (record) => Text('${(record as AlibiRequest).urgency}/3'),
          ),
          TableColumnSpec(
            label: 'Клиент',
            flex: 1.5,
            build: (record) => Text(
              repository.nameOf(
                EntityKind.clients,
                (record as AlibiRequest).clientId,
              ),
            ),
          ),
        ];
      case EntityKind.clients:
        return [
          title,
          text('email', 'Электронная почта', flex: 2),
          text('city', 'Город'),
          date,
        ];
      case EntityKind.employees:
        return [
          title,
          text('email', 'Электронная почта', flex: 2),
          text('specialty', 'Специализация', flex: 1.6),
          date,
        ];
      case EntityKind.services:
        return [
          title,
          text('category', 'Категория'),
          text('price', 'Цена, ₽', sortable: true),
          date,
        ];
      case EntityKind.scenarios:
        return [
          title,
          TableColumnSpec(
            label: 'Услуга',
            flex: 2,
            build: (record) => Text(
              repository.nameOf(
                EntityKind.services,
                readInt(record.toJson()['serviceId']),
              ),
            ),
          ),
          text('durationMinutes', 'Подготовка, мин.'),
          date,
        ];
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AgencyState>().repository;
    final query = widget.query;
    final options = categoryOptions(widget.kind, repository.catalogs);
    return AppShell(
      title: '${widget.kind.label} агентства',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (repository.startupNotice != null && !_noticeHidden)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(repository.startupNotice!, maxLines: 4),
                      ),
                      IconButton(
                        tooltip: 'Закрыть сообщение',
                        onPressed: () => setState(() => _noticeHidden = true),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: MediaQuery.sizeOf(context).width < 400 ? 280 : 320,
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      labelText: switch (widget.kind) {
                        EntityKind.requests => 'Поиск по теме или номеру',
                        EntityKind.clients ||
                        EntityKind.employees => 'Поиск по имени или почте',
                        _ => 'Поиск по названию',
                      },
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(
                        const Duration(milliseconds: 350),
                        () => _navigate({'search': value}),
                      );
                    },
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.go('${widget.kind.path}/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Создать'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _navigate({'demoError': query.demoError ? null : '1'}),
                  icon: Icon(
                    query.demoError
                        ? Icons.refresh
                        : Icons.warning_amber_outlined,
                  ),
                  label: Text(
                    query.demoError ? 'Сбросить ошибку' : 'Демо ошибки',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterMenu<String>(
                  value: query.category,
                  options: [
                    const FilterMenuOption(value: null, label: 'Все категории'),
                    for (final option in options)
                      FilterMenuOption(
                        value: option.value.toString(),
                        label: option.label,
                      ),
                  ],
                  onSelected: (value) => _navigate({'category': value}),
                ),
                if (widget.kind == EntityKind.requests)
                  FilterMenu<String>(
                    value: query.status,
                    options: [
                      const FilterMenuOption(value: null, label: 'Все статусы'),
                      for (final status in RequestStatus.values)
                        FilterMenuOption(
                          value: status.name,
                          label: requestStatusLabels[status]!,
                        ),
                    ],
                    onSelected: (value) => _navigate({'status': value}),
                  ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _from,
                    decoration: InputDecoration(
                      labelText: 'Дата от',
                      hintText: 'ГГГГ-ММ-ДД',
                      errorText: _fromError,
                    ),
                    onSubmitted: (_) => _applyDates(),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _to,
                    decoration: InputDecoration(
                      labelText: 'Дата до',
                      hintText: 'ГГГГ-ММ-ДД',
                      errorText: _toError,
                    ),
                    onSubmitted: (_) => _applyDates(),
                  ),
                ),
                OutlinedButton(
                  onPressed: _applyDates,
                  child: const Text('Применить даты'),
                ),
                FilterMenu<String>(
                  value: query.sortField,
                  options: [
                    const FilterMenuOption(value: 'date', label: 'По дате'),
                    const FilterMenuOption(value: 'name', label: 'По названию'),
                    if (widget.kind == EntityKind.services)
                      const FilterMenuOption(value: 'price', label: 'По цене'),
                    if (widget.kind == EntityKind.requests)
                      const FilterMenuOption(
                        value: 'urgency',
                        label: 'По срочности',
                      ),
                  ],
                  onSelected: (value) => _navigate({
                    'sort': '$value,${query.ascending ? 'asc' : 'desc'}',
                  }),
                ),
                IconButton(
                  tooltip: 'Изменить порядок сортировки',
                  icon: Icon(
                    query.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  ),
                  onPressed: () => _navigate({
                    'sort':
                        '${query.sortField},${query.ascending ? 'desc' : 'asc'}',
                  }),
                ),
                FilterChip(
                  label: const Text('Показывать удалённые'),
                  selected: query.includeDeleted,
                  onSelected: (value) =>
                      _navigate({'deleted': value ? '1' : null}),
                ),
                TextButton(
                  onPressed: () => context.go(widget.kind.path),
                  child: const Text('Сбросить'),
                ),
              ],
            ),
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selected.isEmpty
                          ? 'Отметьте записи для массового действия'
                          : 'Выбрано: ${_selected.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : () => _delete(_selected),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Удалить'),
                    ),
                ],
              ),
            ),
            const Divider(),
            FutureBuilder<PageResult<AgencyRecord>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40),
                        const Text('Не удалось загрузить записи'),
                        FilledButton(
                          onPressed: () => _navigate({'demoError': null}),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  );
                }
                final page = snapshot.data!;
                if (page.items.isEmpty) {
                  return const Center(
                    child: Text('Записи не найдены. Измените условия поиска.'),
                  );
                }
                return EntityTable<AgencyRecord>(
                  scrollable: false,
                  items: page.items,
                  columns: _columns(repository),
                  idOf: (record) => record.id,
                  titleOf: (record) => record.name,
                  selected: _selected,
                  onToggleSelect: (id) => setState(() {
                    _selected.contains(id)
                        ? _selected.remove(id)
                        : _selected.add(id);
                  }),
                  sortField: query.sortField,
                  sortAscending: query.ascending,
                  onSort: (field) => _navigate({
                    'sort':
                        '$field,${field == query.sortField && query.ascending ? 'desc' : 'asc'}',
                  }),
                  actions: (record) => [
                    if (record.isDeleted)
                      IconButton(
                        tooltip: 'Восстановить',
                        onPressed: _busy ? null : () => _restore(record.id),
                        icon: const Icon(Icons.restore),
                      )
                    else
                      IconButton(
                        tooltip: 'В корзину',
                        onPressed: _busy ? null : () => _delete([record.id]),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    if (record.isDeleted)
                      IconButton(
                        tooltip: 'Удалить навсегда',
                        onPressed: _busy ? null : () => _delete([record.id]),
                        icon: const Icon(Icons.delete_forever),
                      )
                    else
                      IconButton(
                        tooltip: 'Редактировать',
                        onPressed: () =>
                            context.go('${widget.kind.path}/${record.id}/edit'),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    IconButton(
                      tooltip: 'Карточка записи',
                      onPressed: () =>
                          context.go('${widget.kind.path}/${record.id}'),
                      icon: const Icon(Icons.open_in_new),
                    ),
                  ],
                );
              },
            ),
            FutureBuilder<PageResult<AgencyRecord>>(
              future: _future,
              builder: (context, snapshot) {
                final page = snapshot.data ?? PageResult<AgencyRecord>.empty();
                return PaginationBar(
                  currentPage: page.page,
                  totalPages: page.totalPages,
                  totalRecords: page.total,
                  pageSize: query.size,
                  onPageChanged: (page) =>
                      _navigate({'page': '$page'}, resetPage: false),
                  onPageSizeChanged: (size) => _navigate({'size': '$size'}),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
