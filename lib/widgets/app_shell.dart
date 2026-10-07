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

  IconData _icon(String path) => switch (path) {
    '/my-requests' || '/work' => Icons.dashboard_outlined,
    '/admin/statistics' => Icons.bar_chart,
    '/requests' => Icons.assignment_outlined,
    '/clients' => Icons.people_outline,
    '/employees' => Icons.badge_outlined,
    '/services' => Icons.work_outline,
    '/scenarios' => Icons.description_outlined,
    _ => Icons.manage_accounts_outlined,
  };

  Future<void> _more(BuildContext context, List<(String, String)> items) async {
    final destination = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items)
                ListTile(
                  leading: Icon(_icon(item.$1)),
                  title: Text(item.$2),
                  onTap: () => Navigator.pop(context, item.$1),
                ),
            ],
          ),
        ),
      ),
    );
    if (destination != null && context.mounted) context.go(destination);
  }

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
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 600;
    final expanded = width >= 1100;
    final path = GoRouterState.of(context).uri.path;
    final found = destinations.indexWhere(
      (item) => path == item.$1 || path.startsWith('${item.$1}/'),
    );
    final selected = found < 0 ? 0 : found;
    final visible = destinations.length > 4
        ? destinations.take(3).toList()
        : destinations;
    final account = PopupMenuButton<String>(
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
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 8 : 16,
          vertical: 12,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_outlined),
            ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: mobile ? 80 : 180),
                child: Text(
                  auth.user!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [account],
      ),
      bottomNavigationBar: !mobile
          ? null
          : NavigationBar(
              selectedIndex: selected < visible.length
                  ? selected
                  : visible.length,
              onDestinationSelected: (index) => index < visible.length
                  ? context.go(visible[index].$1)
                  : _more(context, destinations.skip(3).toList()),
              destinations: [
                for (final item in visible)
                  NavigationDestination(
                    icon: Icon(_icon(item.$1)),
                    label: item.$2,
                  ),
                if (destinations.length > 4)
                  const NavigationDestination(
                    icon: Icon(Icons.more_horiz),
                    label: 'Ещё',
                  ),
              ],
            ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!mobile) ...[
              SingleChildScrollView(
                child: IntrinsicHeight(
                  child: NavigationRail(
                    extended: expanded,
                    minExtendedWidth: 216,
                    selectedIndex: selected,
                    labelType: expanded
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.selected,
                    onDestinationSelected: (index) =>
                        context.go(destinations[index].$1),
                    destinations: [
                      for (final item in destinations)
                        NavigationRailDestination(
                          icon: Tooltip(
                            message: item.$2,
                            child: Icon(_icon(item.$1)),
                          ),
                          label: Text(item.$2),
                        ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
            ],
            Expanded(
              child: Column(
                children: [
                  if (auth.warningSeconds != null)
                    Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Выход из-за неактивности через ${auth.warningSeconds} сек.',
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
                    child: Align(
                      alignment: Alignment.topCenter,
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
          ],
        ),
      ),
    );
  }
}
