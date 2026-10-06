import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../repositories/auth_api.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier(
    this.prefs,
    this.api, {
    this.idleTimeout = const Duration(
      seconds: int.fromEnvironment('IDLE_SECONDS', defaultValue: 180),
    ),
    this.warningTime = const Duration(seconds: 30),
    this.maxSession = const Duration(
      seconds: int.fromEnvironment('SESSION_SECONDS', defaultValue: 3600),
    ),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  static const accessKey = 'auth_access_token';
  static const refreshKey = 'auth_refresh_token';
  static const userKey = 'auth_user';
  static const activityKey = 'auth_last_activity';
  static const startKey = 'auth_session_started';
  static const endKey = 'auth_session_expires';
  final SharedPreferences prefs;
  final AuthApi api;
  final Duration idleTimeout;
  final Duration warningTime;
  final Duration maxSession;
  final DateTime Function() _now;
  AppUser? _user;
  String? _accessToken;
  String? _refreshToken;
  int _lastActivity = 0;
  int _startedAt = 0;
  int _expiresAt = 0;
  int _generation = 0;
  int _lastStoredActivity = 0;
  Timer? _timer;
  Future<String?>? _refreshing;
  bool _disposed = false;
  int? warningSeconds;
  String? message;
  AppUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _user != null && _accessToken != null;
  bool can(Operation operation) =>
      isAuthenticated && _user!.role.allows(operation);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    _accessToken = prefs.getString(accessKey);
    _refreshToken = prefs.getString(refreshKey);
    if (_accessToken == null || _refreshToken == null) {
      await logout();
      return;
    }
    try {
      _user = AppUser.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(prefs.getString(userKey) ?? '{}') as Map,
        ),
      );
    } catch (_) {
      _user = null;
    }
    _startedAt = prefs.getInt(startKey) ?? 0;
    _expiresAt = prefs.getInt(endKey) ?? 0;
    _lastActivity = prefs.getInt(activityKey) ?? _startedAt;
    if (_expiryReason() case final reason?) {
      await logout(reason: reason);
      return;
    }
    try {
      final verified = await api.me();
      _user = _user?.id == verified.id
          ? verified.withRole(_user!.role)
          : verified;
    } on UnauthorizedException {
      if (await refreshTokens() == null) return;
    } on NetworkException {
      message =
          'Сервер недоступен. Сохранённая сессия будет проверена при следующем запросе.';
    } on ApiException {
      await logout(reason: 'Не удалось восстановить сессию. Войдите снова.');
      return;
    }
    if (!isAuthenticated) {
      await logout();
      return;
    }
    _startTimer();
    _notify();
  }

  Future<void> login(String username, String password) async {
    final generation = ++_generation;
    final result = await api.login(username, password);
    if (_disposed || generation != _generation) return;
    _lastActivity = _now().millisecondsSinceEpoch;
    await _apply(result);
    message = null;
    _startTimer();
    _notify();
  }

  Future<void> _apply(AuthSession result) async {
    _user = result.user;
    _accessToken = result.accessToken;
    _refreshToken = result.refreshToken;
    _startedAt = result.startedAt;
    _expiresAt = result.expiresAt;
    await prefs.setString(accessKey, result.accessToken);
    await prefs.setString(refreshKey, result.refreshToken);
    await prefs.setString(userKey, jsonEncode(result.user.toJson()));
    await prefs.setInt(startKey, _startedAt);
    await prefs.setInt(endKey, _expiresAt);
    await prefs.setInt(activityKey, _lastActivity);
  }

  Future<String?> refreshTokens() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  Future<String?> _refresh() async {
    final token = _refreshToken;
    final generation = _generation;
    if (token == null) {
      await logout(reason: 'Сессия завершена. Войдите снова.');
      return null;
    }
    if (_expiryReason() case final reason?) {
      await logout(reason: reason);
      return null;
    }
    try {
      final result = await api.refresh(token);
      if (_disposed || generation != _generation) return null;
      await _apply(result);
      _notify();
      return _accessToken;
    } catch (_) {
      await logout(
        reason: 'Сессия завершена: обновить токен не удалось. Войдите снова.',
      );
      return null;
    }
  }

  Future<void> logout({String? reason, bool revoke = false}) async {
    final oldRefresh = _refreshToken;
    ++_generation;
    _timer?.cancel();
    _timer = null;
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    warningSeconds = null;
    message = reason;
    for (final key in [
      accessKey,
      refreshKey,
      userKey,
      activityKey,
      startKey,
      endKey,
    ]) {
      await prefs.remove(key);
    }
    _notify();
    if (revoke && oldRefresh != null) {
      try {
        await api.logout(oldRefresh);
      } on ApiException {
        return;
      }
    }
  }

  String? _expiryReason() {
    final current = _now().millisecondsSinceEpoch;
    if (_startedAt == 0 ||
        _expiresAt == 0 ||
        current >= _expiresAt ||
        current - _startedAt >= maxSession.inMilliseconds) {
      return 'Сессия завершена: истекло общее время работы. Войдите снова.';
    }
    if (current - _lastActivity >= idleTimeout.inMilliseconds) {
      return 'Сессия завершена из-за отсутствия активности. Войдите снова.';
    }
    return null;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => checkSession());
  }

  void checkSession() {
    if (!isAuthenticated) return;
    if (_expiryReason() case final reason?) {
      unawaited(logout(reason: reason, revoke: true));
      return;
    }
    final remaining =
        ((idleTimeout.inMilliseconds -
                    (_now().millisecondsSinceEpoch - _lastActivity)) /
                1000)
            .ceil();
    final warning = remaining <= warningTime.inSeconds ? remaining : null;
    if (warningSeconds != warning) {
      warningSeconds = warning;
      _notify();
    }
  }

  void recordActivity() {
    if (!isAuthenticated) return;
    if (_expiryReason() case final reason?) {
      unawaited(logout(reason: reason, revoke: true));
      return;
    }
    _lastActivity = _now().millisecondsSinceEpoch;
    if (_lastActivity - _lastStoredActivity >= 1000) {
      _lastStoredActivity = _lastActivity;
      unawaited(prefs.setInt(activityKey, _lastActivity));
    }
    if (warningSeconds != null) {
      warningSeconds = null;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
