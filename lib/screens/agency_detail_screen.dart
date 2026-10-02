import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/agency_record.dart';
import '../models/alibi_request.dart';
import 'record_details.dart';
import '../state/agency_state.dart';
import '../widgets/app_shell.dart';
import '../widgets/load_status.dart';

class AgencyDetailScreen extends StatefulWidget {
  const AgencyDetailScreen({super.key, required this.kind, required this.id});
  final EntityKind kind;
  final int id;

  @override
  State<AgencyDetailScreen> createState() => _AgencyDetailScreenState();
}

class _AgencyDetailScreenState extends State<AgencyDetailScreen> {
  Future<void>? _loading;
  EntityKind get kind => widget.kind;
  int get id => widget.id;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loading ??= context.read<AgencyState>().repository.prepareDetail(kind, id);
  }

  @override
  void didUpdateWidget(covariant AgencyDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != kind || oldWidget.id != id) {
      _loading = context.read<AgencyState>().repository.prepareDetail(kind, id);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _loading,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return AppShell(
          title: 'Загрузка карточки',
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return AppShell(
          title: 'Загрузка карточки',
          child: LoadError(
            error: snapshot.error,
            onRetry: () => setState(
              () => _loading = context
                  .read<AgencyState>()
                  .repository
                  .prepareDetail(kind, id),
            ),
          ),
        );
      }
      return _buildDetail(context);
    },
  );

  Widget _buildDetail(BuildContext context) {
    final repository = context.watch<AgencyState>().repository;
    final record = repository.byId(kind, id);
    if (record == null) {
      return AppShell(
        title: 'Запись не найдена',
        child: Center(
          child: OutlinedButton(
            onPressed: () => context.go(kind.path),
            child: const Text('К списку'),
          ),
        ),
      );
    }
    final rows = recordDetails(kind, record, repository);
    final linked = <EntityKind, List<AgencyRecord>>{};
    if (record is AlibiRequest) {
      linked[EntityKind.clients] = repository
          .all(EntityKind.clients)
          .where((item) => item.id == record.clientId)
          .toList();
      linked[EntityKind.services] = repository
          .all(EntityKind.services)
          .where((item) => item.id == record.serviceId)
          .toList();
      linked[EntityKind.employees] = repository
          .all(EntityKind.employees)
          .where((item) => record.employeeIds.contains(item.id))
          .toList();
      linked[EntityKind.scenarios] = repository
          .all(EntityKind.scenarios)
          .where((item) => record.scenarioIds.contains(item.id))
          .toList();
    } else {
      linked[EntityKind.requests] = repository
          .all(EntityKind.requests)
          .whereType<AlibiRequest>()
          .where(
            (request) => switch (kind) {
              EntityKind.clients => request.clientId == id,
              EntityKind.employees => request.employeeIds.contains(id),
              EntityKind.services => request.serviceId == id,
              EntityKind.scenarios => request.scenarioIds.contains(id),
              EntityKind.requests => false,
            },
          )
          .toList();
      if (kind == EntityKind.services) {
        linked[EntityKind.scenarios] = repository
            .all(EntityKind.scenarios)
            .where((scenario) => scenario.toJson()['serviceId'] == id)
            .toList();
      }
      if (kind == EntityKind.scenarios) {
        linked[EntityKind.services] = repository
            .all(EntityKind.services)
            .where((service) => service.id == record.toJson()['serviceId'])
            .toList();
      }
    }
    return AppShell(
      title: 'Карточка: ${kind.singular}',
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      record.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    for (final row in rows.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: MediaQuery.sizeOf(context).width < 500
                                  ? 120
                                  : 180,
                              child: Text(
                                row.key,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            Expanded(
                              child: Text(row.value.isEmpty ? '—' : row.value),
                            ),
                          ],
                        ),
                      ),
                    for (final entry in linked.entries) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Связанные ${entry.key.label.toLowerCase()}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (entry.value.isEmpty)
                        const Text('Нет связанных записей'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in entry.value)
                            ActionChip(
                              label: Text(
                                '${item.name}${item.isDeleted ? ' (в корзине)' : ''}',
                              ),
                              onPressed: () =>
                                  context.go('${entry.key.path}/${item.id}'),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (!record.isDeleted)
                          FilledButton.icon(
                            onPressed: () =>
                                context.go('${kind.path}/$id/edit'),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Редактировать'),
                          ),
                        OutlinedButton(
                          onPressed: () => context.go(kind.path),
                          child: const Text('К списку'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
