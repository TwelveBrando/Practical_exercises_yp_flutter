import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_practice/models/app_user.dart';
import 'package:second_practice/repositories/auth_api.dart';
import 'package:second_practice/state/auth_notifier.dart';

class FakeAuthApi extends AuthApi {
  FakeAuthApi({this.role = Role.admin}) : super(Dio());
  final Role role;
  @override
  Future<AuthSession> login(String username, String password) async =>
      AuthSession.fromJson({
        'user': {
          'id': 3,
          'username': 'test',
          'name': 'Тестовый пользователь',
          'role': role.name,
          'clientId': role == Role.client ? 1 : null,
        },
        'accessToken': 'test-access',
        'refreshToken': 'test-refresh',
        'sessionStartedAt': DateTime.now().millisecondsSinceEpoch,
        'sessionExpiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      });
}

Future<AuthNotifier> testAuth({Role role = Role.admin}) async {
  final auth = AuthNotifier(
    await SharedPreferences.getInstance(),
    FakeAuthApi(role: role),
  );
  await auth.login('test', 'password');
  return auth;
}
