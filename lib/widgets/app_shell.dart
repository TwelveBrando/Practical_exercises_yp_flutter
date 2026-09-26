import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(title),
        actions: compact
            ? [
                IconButton(
                  tooltip: 'Заявки',
                  onPressed: () => context.go('/requests'),
                  icon: const Icon(Icons.assignment_outlined),
                ),
                IconButton(
                  tooltip: 'Клиенты',
                  onPressed: () => context.go('/clients'),
                  icon: const Icon(Icons.people_outline),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => context.go('/requests'),
                  child: const Text('Заявки'),
                ),
                TextButton(
                  onPressed: () => context.go('/clients'),
                  child: const Text('Клиенты'),
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
