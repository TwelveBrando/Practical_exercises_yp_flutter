import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/agency_record.dart';
import '../repositories/repository_exceptions.dart';
import '../state/agency_state.dart';
import '../state/form_navigation_guard.dart';
import '../validation/record_fields.dart';
import '../widgets/app_shell.dart';
import '../widgets/record_form.dart';
import '../widgets/load_status.dart';
import '../core/api_exceptions.dart';

class AgencyFormScreen extends StatefulWidget {
  const AgencyFormScreen({super.key, required this.kind, this.id});
  final EntityKind kind;
  final int? id;
  @override
  State<AgencyFormScreen> createState() => _AgencyFormScreenState();
}

class _AgencyFormScreenState extends State<AgencyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  late Map<String, dynamic> _values;
  late String _initial;
  late FormNavigationGuard _guard;
  bool _initialized = false;
  Future<void>? _loading;
  bool _started = false;
  bool _dirty = false;
  bool _saving = false;
  bool _allowLeave = false;
  Future<bool>? _leaveDialog;
  Map<String, String> _errors = {};
  String? _saveError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _guard = context.read<FormNavigationGuard>();
    _guard.attach(this, _confirmLeave);
    _loading = _load();
  }

  Future<void> _load() async {
    final repository = context.read<AgencyState>().repository;
    await repository.prepareForm(widget.kind, widget.id);
    if (!mounted) return;
    _initializeForm();
  }

  void _initializeForm() {
    if (_initialized) return;
    _initialized = true;
    final repository = context.read<AgencyState>().repository;
    _values = repository.formValues(widget.kind, widget.id);
    final fields = recordFields(
      widget.kind,
      _values,
      repository.catalogs,
      widget.id,
      checkUnique: !repository.validatesOnServer,
    );
    for (final field in fields) {
      if (field.input == FieldInput.select) {
        _values.putIfAbsent(field.key, () => null);
      } else if (field.input == FieldInput.multiple) {
        _values.putIfAbsent(field.key, () => <int>[]);
      } else {
        _values[field.key] = _values[field.key]?.toString() ?? '';
        _controllers[field.key] = TextEditingController(
          text: _values[field.key] as String,
        );
      }
    }
    _initial = jsonEncode(_values);
  }

  void _changed(String key, Object? value) {
    setState(() {
      _values[key] = value;
      _errors.remove(key);
      _saveError = null;
      if (widget.kind == EntityKind.requests && key == 'serviceId') {
        _values['scenarioIds'] = <int>[];
        _errors.remove('scenarioIds');
      }
      _dirty = jsonEncode(_values) != _initial;
    });
  }

  Future<bool> _confirmLeave() async {
    if (_saving) return false;
    if (!_dirty || _allowLeave) return true;
    if (_leaveDialog != null) return _leaveDialog!;
    _leaveDialog = showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: const Text('Изменения будут потеряны. Выйти из формы?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    ).then((result) => result ?? false);
    final result = await _leaveDialog!;
    _leaveDialog = null;
    if (result && mounted) setState(() => _allowLeave = true);
    return result;
  }

  Future<void> _cancel() async {
    final canLeave = await _confirmLeave();
    if (canLeave && mounted) context.go(widget.kind.path);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _errors = {});
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final record = await context.read<AgencyState>().save(
        widget.kind,
        _values,
        widget.id,
      );
      if (!mounted) return;
      setState(() {
        _allowLeave = true;
        _dirty = false;
        _saving = false;
      });
      context.go('${widget.kind.path}/${record.id}');
    } on ValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _errors = error.errors;
        _saving = false;
      });
      _formKey.currentState!.validate();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saveError = error.message;
        _saving = false;
      });
    } on FieldValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _errors = error.errors;
        _saving = false;
      });
      _formKey.currentState!.validate();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saveError = 'Не удалось сохранить запись. Повторите попытку.';
        _saving = false;
      });
    }
  }

  @override
  void dispose() {
    _guard.detach(this);
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _loading,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return AppShell(
          title: 'Загрузка формы',
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return AppShell(
          title: 'Загрузка формы',
          child: LoadError(
            error: snapshot.error,
            onRetry: () => setState(() => _loading = _load()),
          ),
        );
      }
      return _buildForm(context);
    },
  );

  Widget _buildForm(BuildContext context) {
    final repository = context.watch<AgencyState>().repository;
    if (widget.id != null && repository.byId(widget.kind, widget.id!) == null) {
      return AppShell(
        title: 'Запись не найдена',
        child: Center(
          child: OutlinedButton(
            onPressed: () => context.go(widget.kind.path),
            child: const Text('К списку'),
          ),
        ),
      );
    }
    final fields = recordFields(
      widget.kind,
      _values,
      repository.catalogs,
      widget.id,
    );
    return PopScope(
      canPop: !_dirty || _allowLeave,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cancel();
      },
      child: AppShell(
        title: widget.id == null
            ? 'Создание: ${widget.kind.singular}'
            : 'Редактирование: ${widget.kind.singular}',
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
                      if (_saveError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _saveError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      RecordForm(
                        formKey: _formKey,
                        fields: fields,
                        values: _values,
                        controllers: _controllers,
                        onChanged: _changed,
                        onSubmit: _save,
                        onCancel: _cancel,
                        saving: _saving,
                        editing: widget.id != null,
                        errors: _errors,
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
}
