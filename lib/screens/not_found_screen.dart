import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.location});
  final String location;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Страница не найдена')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Ошибка 404', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Адрес $location не найден.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/requests'),
            child: const Text('К заявкам'),
          ),
        ],
      ),
    ),
  );
}
