import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/pricing_quote.dart';
import '../state/auth_notifier.dart';
import '../validation/validators.dart';
import '../widgets/app_shell.dart';
import '../widgets/load_status.dart';

class EstimateScreen extends StatefulWidget {
  const EstimateScreen({super.key, required this.requestId});
  final int requestId;
  @override
  State<EstimateScreen> createState() => _EstimateScreenState();
}

class _EstimateScreenState extends State<EstimateScreen> {
  final _form = GlobalKey<FormState>();
  final _discount = TextEditingController(text: '0');
  Future<PricingQuote>? _quote;
  int _applied = 0;
  void _load() {
    _quote = context.read<AuthNotifier>().api.estimate(
      widget.requestId,
      _applied,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_quote == null) _load();
  }

  @override
  void didUpdateWidget(covariant EstimateScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestId != widget.requestId) _load();
  }

  @override
  void dispose() {
    _discount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Расчёт стоимости заявки',
    child: SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Стоимость зависит от услуги, срочности и времени подготовки выбранных сценариев. Срочность 2 добавляет 20%, срочность 3 — 50% к цене услуги. Подготовка стоит 10 ₽ за минуту. Скидка применяется ко всей сумме.',
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _form,
                    child: TextFormField(
                      controller: _discount,
                      decoration: const InputDecoration(
                        labelText: 'Скидка (% от 0 до 30)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          Validators.integer(value, min: 0, max: 30),
                      onFieldSubmitted: (_) => _calculate(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _calculate,
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Пересчитать'),
                  ),
                  const SizedBox(height: 20),
                  FutureBuilder<PricingQuote>(
                    future: _quote,
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
                      final q = snapshot.data!;
                      final rows = {
                        'Услуга': '${q.base} ₽',
                        'Надбавка за срочность (${q.urgencyPercent}%)':
                            '${q.urgency} ₽',
                        'Подготовка (${q.preparationMinutes} мин.)':
                            '${q.preparation} ₽',
                        'Скидка (${q.discountPercent}%)': '−${q.discount} ₽',
                        'Итоговая стоимость': '${q.total} ₽',
                      };
                      return Column(
                        children: [
                          for (final row in rows.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(child: Text(row.key)),
                                  const SizedBox(width: 12),
                                  Text(
                                    row.value,
                                    style: row.key == 'Итоговая стоимость'
                                        ? Theme.of(context).textTheme.titleLarge
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        context.go('/requests/${widget.requestId}'),
                    child: const Text('К заявке'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  void _calculate() {
    if (_form.currentState!.validate()) {
      setState(() {
        _applied = int.parse(_discount.text.trim());
        _load();
      });
    }
  }
}
