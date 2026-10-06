import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/agency_record.dart';
import '../models/app_user.dart';
import '../state/auth_notifier.dart';
import '../state/form_navigation_guard.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final role = auth.user?.role;
    if (role == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final destinations = <(String, String)>[
      (role.home, 'Мой кабинет'),
      for (final kind in EntityKind.values)
        if (role.canView(kind)) (kind.path, kind.label),
      if (auth.can(Operation.users)) ('/admin/users', 'Пользователи'),
    ];
    final compact = MediaQuery.sizeOf(context).width < 1200;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (compact)
            PopupMenuButton<String>(
              tooltip: 'Разделы',
              icon: const Icon(Icons.menu),
              onSelected: context.go,
              itemBuilder: (_) => [
                for (final item in destinations)
                  PopupMenuItem(value: item.$1, child: Text(item.$2)),
              ],
            )
          else
            for (final item in destinations)
              TextButton(
                onPressed: () => context.go(item.$1),
                child: Text(item.$2),
              ),
          PopupMenuButton<String>(
            tooltip: '${auth.user!.name} — ${role.label}',
            onSelected: (_) async {
              final canLeave = await context
                  .read<FormNavigationGuard>()
                  .confirmExit();
              if (canLeave) await auth.logout(revoke: true);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text('${auth.user!.name}\n${role.label}'),
              ),
              const PopupMenuItem(value: 'logout', child: Text('Выйти')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle_outlined),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: compact ? 130 : 180),
                    child: Text(
                      auth.user!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (auth.warningSeconds != null)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Выход из-за неактивности через ${auth.warningSeconds} сек.',
                        ),
                      ),
                      TextButton(
                        onPressed: auth.recordActivity,
                        child: const Text('Продолжить работу'),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
