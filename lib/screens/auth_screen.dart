import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/api_exceptions.dart';
import '../repositories/auth_api.dart';
import '../state/auth_notifier.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.register = false,
    this.from,
    this.registered = false,
  });
  final bool register;
  final String? from;
  final bool registered;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  Map<String, String> _errors = {};

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _errors = {};
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final auth = context.read<AuthNotifier>();
      if (widget.register) {
        await auth.api.register(
          _name.text.trim(),
          _username.text.trim(),
          _email.text.trim(),
          _password.text,
        );
        if (!mounted) return;
        context.go(
          Uri(
            path: '/login',
            queryParameters: {
              'registered': '1',
              if (widget.from != null) 'from': widget.from!,
            },
          ).toString(),
        );
      } else {
        await auth.login(_username.text.trim(), _password.text);
      }
    } on ValidationException catch (error) {
      if (mounted) {
        setState(() {
          _errors = error.errors;
          _error = error.message;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String key,
    String label,
    TextEditingController controller, {
    bool password = false,
    String? Function(String)? check,
  }) => TextFormField(
    key: ValueKey(key),
    controller: controller,
    enabled: !_busy,
    obscureText: password && _obscure,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(
      labelText: label,
      errorMaxLines: 3,
      suffixIcon: password
          ? IconButton(
              tooltip: _obscure ? 'Показать пароль' : 'Скрыть пароль',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            )
          : null,
    ),
    validator: (value) =>
        _errors[key] ??
        ((value ?? '').trim().isEmpty
            ? 'Обязательное поле'
            : check?.call(value!)),
    onChanged: (_) => setState(() {
      _errors.remove(key);
      _error = null;
    }),
    onFieldSubmitted: (_) => _submit(),
  );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final password = _password.text;
    return Scaffold(
      appBar: AppBar(title: const Text('Агентство Alibi')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.register ? 'Регистрация' : 'Вход в систему',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      if (widget.register) ...[
                        _field(
                          'name',
                          'Имя',
                          _name,
                          check: (value) => value.trim().length < 2
                              ? 'Не менее 2 символов'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          'email',
                          'Электронная почта',
                          _email,
                          check: (value) =>
                              RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(value.trim())
                              ? null
                              : 'Введите корректную почту',
                        ),
                        const SizedBox(height: 16),
                      ],
                      _field(
                        'username',
                        'Логин',
                        _username,
                        check: widget.register
                            ? (value) =>
                                  RegExp(
                                    r'^[a-zA-Z0-9_.-]{3,40}$',
                                  ).hasMatch(value.trim())
                                  ? null
                                  : '3–40 латинских букв, цифр, точек, дефисов или подчёркиваний'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _field(
                        'password',
                        'Пароль',
                        _password,
                        password: true,
                        check: widget.register
                            ? (value) => passwordProblems(value).isEmpty
                                  ? null
                                  : passwordProblems(value).join('. ')
                            : null,
                      ),
                      if (widget.register) ...[
                        const SizedBox(height: 12),
                        for (final rule in [
                          ('Не менее 8 символов', password.length >= 8),
                          (
                            'Хотя бы одна цифра',
                            RegExp(r'\d').hasMatch(password),
                          ),
                          (
                            'Хотя бы один специальный символ',
                            RegExp(
                              r'[^\p{L}\p{N}\s]',
                              unicode: true,
                            ).hasMatch(password),
                          ),
                        ])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(
                                  rule.$2
                                      ? Icons.check_circle_outline
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: rule.$2
                                      ? Colors.green.shade700
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(rule.$1)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        _field(
                          'confirmation',
                          'Повторите пароль',
                          _confirmation,
                          password: true,
                          check: (value) => value == _password.text
                              ? null
                              : 'Пароли не совпадают',
                        ),
                      ],
                      if (_error != null ||
                          (!widget.register && auth.message != null))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            _error ?? auth.message!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (widget.registered)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Регистрация завершена. Войдите с указанным логином и паролем.',
                          ),
                        ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(
                          _busy
                              ? 'Подождите…'
                              : widget.register
                              ? 'Зарегистрироваться'
                              : 'Войти',
                        ),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => context.go(
                                Uri(
                                  path: widget.register
                                      ? '/login'
                                      : '/register',
                                  queryParameters: {
                                    if (widget.from != null)
                                      'from': widget.from!,
                                  },
                                ).toString(),
                              ),
                        child: Text(
                          widget.register
                              ? 'Уже есть учётная запись? Войти'
                              : 'Создать учётную запись',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _username,
      _email,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}
