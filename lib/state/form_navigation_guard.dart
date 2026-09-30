class FormNavigationGuard {
  Object? _owner;
  Future<bool> Function()? _confirm;
  void attach(Object owner, Future<bool> Function() confirm) {
    _owner = owner;
    _confirm = confirm;
  }

  void detach(Object owner) {
    if (identical(owner, _owner)) {
      _owner = null;
      _confirm = null;
    }
  }

  Future<bool> confirmExit() async => await _confirm?.call() ?? true;
}
