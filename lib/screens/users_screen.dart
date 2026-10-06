import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../state/auth_notifier.dart';
import '../widgets/app_shell.dart';
import '../widgets/load_status.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  Future<List<List<Map<String, dynamic>>>>? _data;
  String? _message;
  bool _busy = false;
  void _load() {
    final api = context.read<AuthNotifier>().api;
    _data = Future.wait([api.users(), api.clients()]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data == null) _load();
  }

  Future<void> _edit(
    Map<String, dynamic> user,
    List<Map<String, dynamic>> clients,
  ) async {
    var role = Role.values.byName(user['role'] as String);
    var active = user['active'] == true;
    int? clientId = (user['clientId'] as num?)?.toInt();
    if (!clients.any(
      (item) => item['id'] == clientId && item['deletedAt'] == null,
    )) {
      clientId = null;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Учётная запись: ${user['username']}'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Role>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Роль'),
                  items: [
                    for (final value in Role.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                  onChanged: (value) => setDialogState(() => role = value!),
                ),
                SwitchListTile(
                  title: const Text('Учётная запись активна'),
                  value: active,
                  onChanged: (value) => setDialogState(() => active = value),
                ),
                if (role == Role.client)
                  DropdownButtonFormField<int>(
                    initialValue: clientId,
                    decoration: const InputDecoration(
                      labelText: 'Запись клиента',
                    ),
                    items: [
                      for (final item in clients)
                        if (item['deletedAt'] == null)
                          DropdownMenuItem(
                            value: (item['id'] as num).toInt(),
                            child: Text(item['name'] as String),
                          ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => clientId = value),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: role != Role.client || clientId != null
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await context.read<AuthNotifier>().api.updateUser(
        (user['id'] as num).toInt(),
        role,
        active,
        clientId,
      );
      if (mounted) {
        setState(() {
          _message = 'Права обновлены. Пользователь должен войти снова.';
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
    title: 'Пользователи и роли',
    child: FutureBuilder<List<List<Map<String, dynamic>>>>(
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
        final users = snapshot.data![0], clients = snapshot.data![1];
        return ListView(
          children: [
            const Text(
              'Управление ролями и доступом. Новые учётные записи создаются через регистрацию и получают роль клиента.',
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_message!),
              ),
            for (final user in users)
              Card(
                child: ListTile(
                  title: Text('${user['name']} (${user['username']})'),
                  subtitle: Text(
                    '${Role.values.byName(user['role'] as String).label} · ${user['active'] == true ? 'Активен' : 'Отключён'}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Изменить права',
                    onPressed: _busy ? null : () => _edit(user, clients),
                    icon: const Icon(Icons.manage_accounts_outlined),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
