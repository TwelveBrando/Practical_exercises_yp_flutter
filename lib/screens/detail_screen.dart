import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/alibi_request.dart';
import '../models/client.dart';
import '../state/catalog_notifiers.dart';
import '../widgets/app_shell.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen.client({super.key, required this.id}) : isClient = true;
  const DetailScreen.request({super.key, required this.id}) : isClient = false;
  final int id;
  final bool isClient;
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<Object?> _future;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = widget.isClient
        ? context.read<ClientListNotifier>().findById(widget.id)
        : context.read<RequestListNotifier>().findById(widget.id);
  }

  @override
  Widget build(BuildContext context) => AppShell(
    title: widget.isClient ? 'Карточка клиента' : 'Карточка заявки',
    child: FutureBuilder<Object?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final item = snapshot.data;
        if (item == null) return const Center(child: Text('Запись не найдена'));
        late final Map<String, String> rows;
        if (item is Client) {
          rows = {
            'Имя': item.name,
            'Электронная почта': item.email,
            'Город': item.city,
            'Дата регистрации': _date(item.joinedAt),
            'Статус': item.isDeleted ? 'Удалён' : 'Активен',
          };
        } else if (item is AlibiRequest) {
          rows = {
            'Номер': '#${item.id}',
            'Заявка': item.title,
            'Тип': requestTypeLabels[item.type]!,
            'Дата события': _date(item.eventDate),
            'Статус': requestStatusLabels[item.status]!,
            'Срочность': '${item.urgency} из 3',
            'Клиент': 'Клиент #${item.clientId}',
          };
        } else {
          return const Center(child: Text('Неизвестная запись'));
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...rows.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 175,
                              child: Text(
                                entry.key,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            Expanded(child: Text(entry.value)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => context.go(
                        widget.isClient ? '/clients' : '/requests',
                      ),
                      child: const Text('Назад к списку'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
