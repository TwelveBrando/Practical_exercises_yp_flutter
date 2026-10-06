import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/auth_notifier.dart';

class InactivityWatcher extends StatefulWidget {
  const InactivityWatcher({super.key, required this.auth, required this.child});
  final AuthNotifier auth;
  final Widget child;
  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  bool _onKey(KeyEvent event) {
    widget.auth.recordActivity();
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => widget.auth.recordActivity(),
    onPointerMove: (_) => widget.auth.recordActivity(),
    onPointerSignal: (_) => widget.auth.recordActivity(),
    child: widget.child,
  );
}
