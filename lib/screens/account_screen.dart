import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/api_exceptions.dart';
import '../models/alibi_request.dart';
import '../state/auth_notifier.dart';
import '../widgets/app_shell.dart';
import '../widgets/load_status.dart';

enum AccountSection { client, work, statistics }

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.section});
  final AccountSection section;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Future<dynamic>? _data;
  int _page = 1;
  bool _busy = false;
  String? _message;
  void _load() {
    _data = context.read<AuthNotifier>().api.readAccount(
      widget.section.name,
      _page,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data == null) _load();
  }

  Future<void> _reschedule(Map<String, dynamic> request) async {
    final current = DateTime.parse(request['eventDate'] as String);
    final first = current.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await context.read<AuthNotifier>().api.reschedule(
        (request['id'] as num).toInt(),
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      );
      if (mounted) {
        setState(() {
          _message = 'Дата заявки изменена.';
          _load();
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
    title: switch (widget.section) {
      AccountSection.client => 'Мои заявки',
      AccountSection.work => 'Рабочий кабинет',
      AccountSection.statistics => 'Статистика агентства',
    },
    child: FutureBuilder<dynamic>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return LoadError(
            error: snapshot.error,
            onRetry: () => setState(_load),
          );
        }
        if (widget.section == AccountSection.client) {
          final data = Map<String, dynamic>.from(snapshot.data as Map);
          final items = (data['items'] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          return ListView(
            children: [
              const Text(
                'Здесь доступны только ваши заявки. Для новых заявок и заявок в работе можно перенести дату события.',
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_message!),
                ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('У вас пока нет заявок.'),
                ),
              for (final item in items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['code']} — ${item['title']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Статус: ${requestStatusLabels[RequestStatus.values.byName(item['status'] as String)]}',
                        ),
                        Text(
                          'Дата события: ${(item['eventDate'] as String).split('T').first}',
                        ),
                        Wrap(
                          spacing: 12,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  context.go('/requests/${item['id']}'),
                              child: const Text('Открыть заявку'),
                            ),
                            if (item['deletedAt'] == null &&
                                [
                                  'newRequest',
                                  'inProgress',
                                ].contains(item['status']))
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _reschedule(item),
                                child: const Text('Перенести дату'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Предыдущая',
                    onPressed: _page > 1
                        ? () => setState(() {
                            _page--;
                            _load();
                          })
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Страница ${data['page']} из ${data['totalPages']}'),
                  IconButton(
                    tooltip: 'Следующая',
                    onPressed: _page < (data['totalPages'] as num)
                        ? () => setState(() {
                            _page++;
                            _load();
                          })
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          );
        }
        if (widget.section == AccountSection.work) {
          final rows = (snapshot.data as List).cast<Map<String, dynamic>>();
          return ListView(
            children: [
              Text(
                'Обработка заявок',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text(
                      requestStatusLabels[RequestStatus.values.byName(
                        row['status'] as String,
                      )]!,
                    ),
                    trailing: Text('${row['count']}'),
                    onTap: () =>
                        context.go('/requests?status=${row['status']}'),
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Откройте группу заявок, чтобы назначить исполнителей, изменить статус или завершить работу.',
              ),
            ],
          );
        }
        final data = Map<String, dynamic>.from(snapshot.data as Map);
        const labels = {
          'requests': 'Заявки',
          'clients': 'Клиенты',
          'employees': 'Сотрудники',
          'services': 'Услуги',
          'scenarios': 'Сценарии',
        };
        return ListView(
          children: [
            Text(
              'Пользователей: ${data['users']}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            for (final row
                in (data['catalogs'] as List).cast<Map<String, dynamic>>())
              Card(
                child: ListTile(
                  title: Text(labels[row['kind']]!),
                  subtitle: Text(
                    'Активных: ${row['active']} · В корзине: ${row['deleted']}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/${row['kind']}'),
                ),
              ),
          ],
        );
      },
    ),
  );
}
