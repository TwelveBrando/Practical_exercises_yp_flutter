import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/seed_data.dart';
import '../models/client.dart';
import '../models/client_query.dart';
import '../state/catalog_notifiers.dart';
import '../widgets/app_shell.dart';
import '../widgets/entity_table.dart';
import '../widgets/filter_menu.dart';
import '../widgets/pagination_bar.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key, required this.query});
  final ClientQuery query;
  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final _search = TextEditingController();
  final _yearFrom = TextEditingController();
  final _yearTo = TextEditingController();
  Timer? _debounce;
  ClientQuery get query => widget.query;
  @override
  void initState() {
    super.initState();
    _sync();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ClientListNotifier>().applyQuery(query),
    );
  }

  void _sync() {
    _setTextIfChanged(_search, query.search);
    _setTextIfChanged(_yearFrom, query.joinedFrom?.toString() ?? '');
    _setTextIfChanged(_yearTo, query.joinedTo?.toString() ?? '');
  }

  void _setTextIfChanged(TextEditingController controller, String value) {
    if (controller.text == value) return;

    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  void didUpdateWidget(covariant ClientListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query.params.toString() != query.params.toString()) {
      _sync();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<ClientListNotifier>().applyQuery(query),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _yearFrom.dispose();
    _yearTo.dispose();
    super.dispose();
  }

  void _navigateWithQuery(ClientQuery updatedQuery) => context.go(
    Uri(path: '/clients', queryParameters: updatedQuery.params).toString(),
  );
  Future<void> _remove(
    ClientListNotifier notifier,
    int id, {
    bool hard = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          hard ? 'Удалить клиента навсегда?' : 'Переместить клиента в корзину?',
        ),
        content: Text(
          hard
              ? 'Восстановить запись не получится.'
              : 'Запись можно будет восстановить.',
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

  Future<void> _bulk(ClientListNotifier notifier) async {
    final hard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Удалить ${notifier.selected.length} клиентов?'),
        content: const Text(
          'Можно перенести выбранные записи в корзину или удалить окончательно.',
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
    final notifier = context.watch<ClientListNotifier>();
    final page = notifier.result;
    final cities = seedClients.map((client) => client.city).toSet().toList()
      ..sort();
    return AppShell(
      title: 'Клиенты агентства',
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
                    labelText: 'Поиск по имени или электронной почте',
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
                'Каталог клиентов',
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
              FilterMenu<String>(
                value: query.city,
                options: [
                  const FilterMenuOption<String>(
                    value: null,
                    label: 'Все города',
                  ),
                  ...cities.map<FilterMenuOption<String>>(
                    (city) =>
                        FilterMenuOption<String>(value: city, label: city),
                  ),
                ],
                onSelected: (selectedCity) =>
                    _navigateWithQuery(query.copyWith(city: selectedCity)),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _yearFrom,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Год регистрации от',
                  ),
                  onSubmitted: (_) => _applyYears(),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _yearTo,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Год до'),
                  onSubmitted: (_) => _applyYears(),
                ),
              ),
              OutlinedButton(
                onPressed: _applyYears,
                child: const Text('Применить'),
              ),
              FilterChip(
                label: const Text('Показывать удалённых'),
                selected: query.includeDeleted,
                onSelected: (showDeleted) => _navigateWithQuery(
                  query.copyWith(includeDeleted: showDeleted),
                ),
              ),
              if (query.search.isNotEmpty ||
                  query.city != null ||
                  query.joinedFrom != null ||
                  query.joinedTo != null)
                TextButton(
                  onPressed: () => _navigateWithQuery(const ClientQuery()),
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
                          'Клиенты не найдены. Измените условия поиска.',
                        ),
                      )
                    : EntityTable<Client>(
                        items: page.items,
                        idOf: (client) => client.id,
                        titleOf: (client) => client.name,
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
                          TableColumnSpec<Client>(
                            label: 'Имя',
                            sortField: 'name',
                            build: (client) => Text(client.name),
                          ),
                          TableColumnSpec<Client>(
                            label: 'Электронная почта',
                            flex: 1.5,
                            sortField: 'email',
                            build: (client) => Text(client.email),
                          ),
                          TableColumnSpec<Client>(
                            label: 'Город',
                            sortField: 'city',
                            build: (client) => Text(client.city),
                          ),
                          TableColumnSpec<Client>(
                            label: 'Дата регистрации',
                            sortField: 'joinedAt',
                            build: (client) => Text(_date(client.joinedAt)),
                          ),
                        ],
                        actions: (client) => [
                          if (client.isDeleted)
                            IconButton(
                              tooltip: 'Восстановить',
                              onPressed: () => notifier.restore(client.id),
                              icon: const Icon(
                                Icons.restore,
                                color: Colors.green,
                              ),
                            )
                          else
                            IconButton(
                              tooltip: 'В корзину',
                              onPressed: () => _remove(notifier, client.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          if (client.isDeleted)
                            IconButton(
                              tooltip: 'Удалить навсегда',
                              onPressed: () =>
                                  _remove(notifier, client.id, hard: true),
                              icon: const Icon(Icons.delete_forever),
                            ),
                          IconButton(
                            tooltip: 'Карточка клиента',
                            onPressed: () =>
                                context.go('/clients/${client.id}'),
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

  Widget _buildSelectionActions(ClientListNotifier notifier) {
    final selectedCount = notifier.selected.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: 48,
        child: Align(
          alignment: Alignment.centerLeft,
          child: selectedCount == 0
              ? Text(
                  'Отметьте клиентов, чтобы выполнить массовое действие',
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
                              : 'Удалить выбранных',
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  void _applyYears() => _navigateWithQuery(
    query.copyWith(
      joinedFrom: int.tryParse(_yearFrom.text),
      joinedTo: int.tryParse(_yearTo.text),
    ),
  );
  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
