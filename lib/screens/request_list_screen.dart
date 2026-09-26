import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/seed_data.dart';
import '../models/alibi_request.dart';
import '../models/request_query.dart';
import '../state/catalog_notifiers.dart';
import '../widgets/app_shell.dart';
import '../widgets/entity_table.dart';
import '../widgets/filter_menu.dart';
import '../widgets/pagination_bar.dart';

class RequestListScreen extends StatefulWidget {
  const RequestListScreen({super.key, required this.query});
  final RequestQuery query;
  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  final _search = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  Timer? _debounce;
  RequestQuery get query => widget.query;
  @override
  void initState() {
    super.initState();
    _sync();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<RequestListNotifier>().applyQuery(query),
    );
  }

  void _sync() {
    _setTextIfChanged(_search, query.search);
    _setTextIfChanged(_from, query.dateFrom ?? '');
    _setTextIfChanged(_to, query.dateTo ?? '');
  }

  void _setTextIfChanged(TextEditingController controller, String value) {
    if (controller.text == value) return;

    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  void didUpdateWidget(covariant RequestListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query.params.toString() != query.params.toString()) {
      _sync();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<RequestListNotifier>().applyQuery(query),
      );
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

  void _navigateWithQuery(RequestQuery updatedQuery) => context.go(
    Uri(path: '/requests', queryParameters: updatedQuery.params).toString(),
  );
  Future<void> _remove(
    RequestListNotifier notifier,
    int id, {
    bool hard = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          hard ? 'Удалить заявку навсегда?' : 'Переместить заявку в корзину?',
        ),
        content: Text(
          hard
              ? 'Восстановить её будет нельзя.'
              : 'Заявку можно будет восстановить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(hard ? 'Удалить' : 'В корзину'),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (hard) {
        await notifier.hardDelete(id);
      } else {
        await notifier.softDelete(id);
      }
    }
  }

  Future<void> _bulk(RequestListNotifier notifier) async {
    final hard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Удалить ${notifier.selected.length} заявок?'),
        content: const Text(
          'Выберите перенос в корзину или окончательное удаление.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
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
    if (hard != null) {
      if (hard) {
        for (final id in notifier.selected.toList()) {
          await notifier.hardDelete(id);
        }
        await notifier.load();
      } else {
        await notifier.deleteSelected();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<RequestListNotifier>();
    final page = notifier.result;
    return AppShell(
      title: 'Заявки агентства',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: MediaQuery.sizeOf(context).width < 400 ? 280 : 320,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Поиск по теме или номеру',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (searchText) {
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 350),
                      () => _navigateWithQuery(
                        query.copyWith(search: searchText),
                      ),
                    );
                  },
                ),
              ),
              const Text(
                'Каталог заявок',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              OutlinedButton.icon(
                onPressed: () => _navigateWithQuery(
                  query.copyWith(demoError: !query.demoError),
                ),
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterMenu<RequestType>(
                value: query.type,
                options: [
                  const FilterMenuOption<RequestType>(
                    value: null,
                    label: 'Все типы',
                  ),
                  ...RequestType.values.map(
                    (requestType) => FilterMenuOption<RequestType>(
                      value: requestType,
                      label: requestTypeLabels[requestType]!,
                    ),
                  ),
                ],
                onSelected: (selectedType) =>
                    _navigateWithQuery(query.copyWith(type: selectedType)),
              ),
              FilterMenu<RequestStatus>(
                value: query.status,
                options: [
                  const FilterMenuOption<RequestStatus>(
                    value: null,
                    label: 'Все статусы',
                  ),
                  ...RequestStatus.values.map(
                    (requestStatus) => FilterMenuOption<RequestStatus>(
                      value: requestStatus,
                      label: requestStatusLabels[requestStatus]!,
                    ),
                  ),
                ],
                onSelected: (selectedStatus) =>
                    _navigateWithQuery(query.copyWith(status: selectedStatus)),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _from,
                  decoration: const InputDecoration(
                    labelText: 'Дата от',
                    hintText: 'ГГГГ-ММ-ДД',
                  ),
                  onSubmitted: (_) => _applyDates(),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _to,
                  decoration: const InputDecoration(
                    labelText: 'Дата до',
                    hintText: 'ГГГГ-ММ-ДД',
                  ),
                  onSubmitted: (_) => _applyDates(),
                ),
              ),
              OutlinedButton(
                onPressed: _applyDates,
                child: const Text('Применить даты'),
              ),
              FilterChip(
                label: const Text('Показывать удалённые'),
                selected: query.includeDeleted,
                onSelected: (showDeleted) => _navigateWithQuery(
                  query.copyWith(includeDeleted: showDeleted),
                ),
              ),
              if (query.search.isNotEmpty ||
                  query.type != null ||
                  query.status != null ||
                  query.dateFrom != null ||
                  query.dateTo != null)
                TextButton(
                  onPressed: () => _navigateWithQuery(const RequestQuery()),
                  child: const Text('Сбросить'),
                ),
            ],
          ),
          _buildSelectionActions(notifier),
          const Divider(),
          Expanded(
            child: switch (notifier.status) {
              LoadStatus.idle || LoadStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              LoadStatus.error => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 44,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Text(notifier.error ?? 'Ошибка загрузки'),
                    FilledButton(
                      onPressed: () =>
                          _navigateWithQuery(query.copyWith(demoError: false)),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
              LoadStatus.success =>
                page.items.isEmpty
                    ? const Center(
                        child: Text(
                          'Заявки не найдены. Измените условия поиска.',
                        ),
                      )
                    : EntityTable<AlibiRequest>(
                        items: page.items,
                        idOf: (request) => request.id,
                        titleOf: (request) => request.title,
                        selected: notifier.selected,
                        onToggleSelect: notifier.toggleSelection,
                        sortField: query.sortField,
                        sortAscending: query.ascending,
                        onSort: (sortField) => _navigateWithQuery(
                          query.copyWith(
                            sortField: sortField,
                            ascending: sortField == query.sortField
                                ? !query.ascending
                                : true,
                          ),
                        ),
                        columns: [
                          TableColumnSpec<AlibiRequest>(
                            label: 'Тема заявки',
                            flex: 2,
                            sortField: 'title',
                            build: (request) => Text(request.title),
                          ),
                          TableColumnSpec<AlibiRequest>(
                            label: 'Тип',
                            flex: 1.6,
                            build: (request) =>
                                Text(requestTypeLabels[request.type]!),
                          ),
                          TableColumnSpec<AlibiRequest>(
                            label: 'Дата события',
                            flex: 1.3,
                            sortField: 'eventDate',
                            build: (request) => Text(_date(request.eventDate)),
                          ),
                          TableColumnSpec<AlibiRequest>(
                            label: 'Статус',
                            sortField: 'status',
                            build: (request) =>
                                Text(requestStatusLabels[request.status]!),
                          ),
                          TableColumnSpec<AlibiRequest>(
                            label: 'Срочность',
                            flex: 1.2,
                            sortField: 'urgency',
                            numeric: true,
                            build: (request) => Text('${request.urgency}/3'),
                          ),
                          TableColumnSpec<AlibiRequest>(
                            label: 'Клиент',
                            flex: 1.5,
                            build: (request) =>
                                Text(_clientName(request.clientId)),
                          ),
                        ],
                        actions: (request) => [
                          if (request.isDeleted)
                            IconButton(
                              tooltip: 'Восстановить',
                              onPressed: () => notifier.restore(request.id),
                              icon: const Icon(
                                Icons.restore,
                                color: Colors.green,
                              ),
                            )
                          else
                            IconButton(
                              tooltip: 'В корзину',
                              onPressed: () => _remove(notifier, request.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          if (request.isDeleted)
                            IconButton(
                              tooltip: 'Удалить навсегда',
                              onPressed: () =>
                                  _remove(notifier, request.id, hard: true),
                              icon: const Icon(Icons.delete_forever),
                            ),
                          IconButton(
                            tooltip: 'Карточка заявки',
                            onPressed: () =>
                                context.go('/requests/${request.id}'),
                            icon: const Icon(Icons.open_in_new),
                          ),
                        ],
                      ),
            },
          ),
          PaginationBar(
            currentPage: page.page,
            totalPages: page.totalPages,
            totalRecords: page.total,
            pageSize: query.size,
            onPageChanged: (pageNumber) =>
                _navigateWithQuery(query.copyWith(page: pageNumber)),
            onPageSizeChanged: (pageSize) =>
                _navigateWithQuery(query.copyWith(size: pageSize)),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionActions(RequestListNotifier notifier) {
    final selectedCount = notifier.selected.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: 48,
        child: Align(
          alignment: Alignment.centerLeft,
          child: selectedCount == 0
              ? Text(
                  'Отметьте заявки, чтобы выполнить массовое действие',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      Expanded(child: Text('Выбрано: $selectedCount')),
                      FilledButton.tonalIcon(
                        onPressed: () => _bulk(notifier),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          constraints.maxWidth < 380
                              ? 'Удалить'
                              : 'Удалить выбранные',
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  void _applyDates() => _navigateWithQuery(
    query.copyWith(
      dateFrom: _from.text.trim().isEmpty ? null : _from.text.trim(),
      dateTo: _to.text.trim().isEmpty ? null : _to.text.trim(),
    ),
  );
  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String _clientName(int id) =>
      seedClients
          .where((client) => client.id == id)
          .map((client) => client.name)
          .firstOrNull ??
      'Клиент #$id';
}
