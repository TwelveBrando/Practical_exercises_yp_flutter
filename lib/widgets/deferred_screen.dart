import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'load_status.dart';

class DeferredScreen extends StatefulWidget {
  const DeferredScreen({super.key, required this.load, required this.builder});
  final Future<void> Function() load;
  final Widget Function() builder;
  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<void> _loading = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _loading,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return AppShell(
          title: 'Загрузка раздела',
          child: LoadError(
            error: snapshot.error,
            onRetry: () => setState(() => _loading = widget.load()),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const AppShell(
          title: 'Загрузка раздела',
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return widget.builder();
    },
  );
}
