import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/agency_record.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: compact
            ? [
                PopupMenuButton<EntityKind>(
                  tooltip: 'Разделы',
                  icon: const Icon(Icons.menu),
                  onSelected: (kind) => context.go(kind.path),
                  itemBuilder: (context) => [
                    for (final kind in EntityKind.values)
                      PopupMenuItem(value: kind, child: Text(kind.label)),
                  ],
                ),
              ]
            : [
                for (final kind in EntityKind.values)
                  TextButton(
                    onPressed: () => context.go(kind.path),
                    child: Text(kind.label),
                  ),
              ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );
  }
}
