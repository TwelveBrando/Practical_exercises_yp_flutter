import 'package:dio/dio.dart';
import '../core/api_exceptions.dart';
import '../models/app_user.dart';

class AuthSession {
  AuthSession.fromJson(Map<String, dynamic> json)
    : user = AppUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
      accessToken = json['accessToken'] as String,
      refreshToken = json['refreshToken'] as String,
      startedAt = (json['sessionStartedAt'] as num).toInt(),
      expiresAt = (json['sessionExpiresAt'] as num).toInt();
  final AppUser user;
  final String accessToken;
  final String refreshToken;
  final int startedAt;
  final int expiresAt;
}

class AuthApi {
  AuthApi(this.dio);
  final Dio dio;
  Future<AuthSession> login(String username, String password) =>
      guard(() async {
        final response = await dio.post(
          '/auth/login',
          data: {'username': username, 'password': password},
        );
        return AuthSession.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      });
  Future<void> register(
    String name,
    String username,
    String email,
    String password,
  ) => guard(() async {
    await dio.post(
      '/auth/register',
      data: {
        'name': name,
        'username': username,
        'email': email,
        'password': password,
      },
    );
  });
  Future<AppUser> me() => guard(() async {
    final response = await dio.get('/auth/me');
    return AppUser.fromJson(Map<String, dynamic>.from(response.data as Map));
  });
  Future<AuthSession> refresh(String token) => guard(() async {
    final response = await dio.post(
      '/auth/refresh',
      data: {'refreshToken': token},
    );
    return AuthSession.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  });
  Future<void> logout(String token) => guard(() async {
    await dio.post('/auth/logout', data: {'refreshToken': token});
  });
  Future<dynamic> readAccount(String section, int page) => guard(() async {
    final path = switch (section) {
      'client' => '/my/requests',
      'work' => '/work',
      _ => '/admin/statistics',
    };
    return (await dio.get(
      path,
      queryParameters: section == 'client' ? {'page': page, 'size': 10} : null,
    )).data;
  });
  Future<void> reschedule(int id, String eventDate) => guard(() async {
    await dio.post(
      '/my/requests/$id/reschedule',
      data: {'eventDate': eventDate},
    );
  });
  Future<List<Map<String, dynamic>>> users() => _list('/admin/users');
  Future<List<Map<String, dynamic>>> clients() => _list('/clients/options');
  Future<List<Map<String, dynamic>>> _list(String path) => guard(() async {
    final response = await dio.get(path);
    return (response.data as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  });
  Future<void> updateUser(int id, Role role, bool active, int? clientId) =>
      guard(() async {
        await dio.put(
          '/admin/users/$id',
          data: {'role': role.name, 'active': active, 'clientId': clientId},
        );
      });
}

List<String> passwordProblems(String value) => [
  if (value.length < 8) 'Не менее 8 символов',
  if (!RegExp(r'\d').hasMatch(value)) 'Хотя бы одна цифра',
  if (!RegExp(r'[^\p{L}\p{N}\s]', unicode: true).hasMatch(value))
    'Хотя бы один специальный символ',
];
