import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_practice/core/api_exceptions.dart';
import 'package:second_practice/models/app_user.dart';
import 'package:second_practice/repositories/auth_api.dart';
import 'package:second_practice/state/auth_notifier.dart';

class SessionApi extends AuthApi {
  SessionApi(this.clock) : super(Dio());
  final DateTime Function() clock;
  late final int startedAt = clock().millisecondsSinceEpoch;
  int refreshCount = 0;
  int meCount = 0;
  bool rejectRefresh = false;
  Completer<AuthSession>? gate;
  final profile = const AppUser(
    id: 1,
    username: 'client',
    name: 'Клиент',
    role: Role.client,
    clientId: 1,
  );
  AuthSession session() => AuthSession.fromJson({
    'user': profile.toJson(),
    'accessToken': 'access-$refreshCount',
    'refreshToken': 'refresh-$refreshCount',
    'sessionStartedAt': startedAt,
    'sessionExpiresAt': startedAt + 3600000,
  });
  @override
  Future<AuthSession> login(String username, String password) async =>
      session();
  @override
  Future<AppUser> me() async {
    meCount++;
    return profile;
  }

  @override
  Future<AuthSession> refresh(String token) async {
    refreshCount++;
    if (rejectRefresh) throw const UnauthorizedException();
    return gate == null ? session() : gate!.future;
  }

  @override
  Future<void> logout(String token) async {}
}

void main() {
  late SharedPreferences prefs;
  late SessionApi api;
  late AuthNotifier auth;
  late DateTime current;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    current = DateTime(2026, 10, 6, 12);
    api = SessionApi(() => current);
    auth = AuthNotifier(prefs, api, now: () => current);
  });
  tearDown(() => auth.dispose());

  test('login stores tokens and identity but never stores password', () async {
    await auth.login('client', 'Alibi123!');
    expect(auth.isAuthenticated, true);
    expect(prefs.getString(AuthNotifier.accessKey), 'access-0');
    expect(prefs.getString(AuthNotifier.refreshKey), 'refresh-0');
    expect(
      prefs.getKeys().any((key) => '${prefs.get(key)}'.contains('Alibi123!')),
      false,
    );
  });
  test('reload validates saved access and preserves the session', () async {
    await auth.login('client', 'password');
    auth.dispose();
    auth = AuthNotifier(prefs, api, now: () => current);
    await auth.restore();
    expect(auth.isAuthenticated, true);
    expect(api.meCount, 1);
  });
  test('parallel token refreshes share one request', () async {
    await auth.login('client', 'password');
    api.gate = Completer<AuthSession>();
    final first = auth.refreshTokens(),
        second = auth.refreshTokens(),
        third = auth.refreshTokens();
    expect(api.refreshCount, 1);
    api.gate!.complete(api.session());
    expect(await Future.wait([first, second, third]), [
      'access-1',
      'access-1',
      'access-1',
    ]);
  });
  test('failed refresh clears session and cannot loop', () async {
    await auth.login('client', 'password');
    api.rejectRefresh = true;
    expect(await auth.refreshTokens(), null);
    expect(auth.isAuthenticated, false);
    expect(prefs.getString(AuthNotifier.refreshKey), null);
    expect(await auth.refreshTokens(), null);
    expect(api.refreshCount, 1);
  });
  test(
    'inactivity warns after 150 seconds, activity resets it and timeout logs out',
    () async {
      await auth.login('client', 'password');
      current = current.add(const Duration(seconds: 150));
      auth.checkSession();
      expect(auth.warningSeconds, 30);
      auth.recordActivity();
      expect(auth.warningSeconds, null);
      current = current.add(const Duration(seconds: 181));
      auth.checkSession();
      await Future<void>.delayed(Duration.zero);
      expect(auth.isAuthenticated, false);
      expect(auth.message, contains('отсутствия активности'));
    },
  );
  test('absolute duration ends session despite recent activity', () async {
    auth.dispose();
    auth = AuthNotifier(
      prefs,
      api,
      now: () => current,
      maxSession: const Duration(seconds: 120),
    );
    await auth.login('client', 'password');
    current = current.add(const Duration(seconds: 119));
    auth.recordActivity();
    current = current.add(const Duration(seconds: 2));
    auth.checkSession();
    await Future<void>.delayed(Duration.zero);
    expect(auth.isAuthenticated, false);
    expect(auth.message, contains('общее время'));
  });
  test('reload does not reset persisted inactivity deadline', () async {
    await auth.login('client', 'password');
    auth.dispose();
    current = current.add(const Duration(seconds: 181));
    auth = AuthNotifier(prefs, api, now: () => current);
    await auth.restore();
    expect(auth.isAuthenticated, false);
    expect(api.meCount, 0);
  });
  test('UI snapshot can be changed but access token stays unchanged', () async {
    await auth.login('client', 'password');
    final snapshot =
        jsonDecode(prefs.getString(AuthNotifier.userKey)!)
            as Map<String, dynamic>;
    snapshot['role'] = 'admin';
    await prefs.setString(AuthNotifier.userKey, jsonEncode(snapshot));
    auth.dispose();
    auth = AuthNotifier(prefs, api, now: () => current);
    await auth.restore();
    expect(auth.can(Operation.users), true);
    expect(auth.accessToken, 'access-0');
  });
}
