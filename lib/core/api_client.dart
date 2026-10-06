import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_exceptions.dart';
import 'config.dart';

Dio buildDio({
  String? baseUrl,
  String? Function()? tokenProvider,
  Future<String?> Function()? refreshToken,
  Future<void> Function()? onUnauthorized,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: (baseUrl ?? apiBaseUrl).replaceFirst(RegExp(r'/+$'), ''),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider?.call();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (kDebugMode) debugPrint('[API] ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        final status = response.statusCode ?? 0;
        if (kDebugMode) {
          debugPrint(
            '[API] ${response.requestOptions.method} ${response.requestOptions.uri} → $status',
          );
        }
        if (status >= 400) {
          handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        } else {
          handler.next(response);
        }
      },
      onError: (error, handler) async {
        final options = error.requestOptions;
        if (error.response?.statusCode == 401 &&
            !options.path.startsWith('/auth/') &&
            refreshToken != null) {
          if (options.extra['authRetried'] == true) {
            await onUnauthorized?.call();
          } else {
            try {
              final oldToken = options.headers['Authorization'];
              final current = tokenProvider?.call();
              final token = current != null && oldToken != 'Bearer $current'
                  ? current
                  : await refreshToken();
              if (token != null) {
                options.extra['authRetried'] = true;
                options.headers['Authorization'] = 'Bearer $token';
                final response = await dio.fetch<dynamic>(options);
                handler.resolve(response);
                return;
              }
            } on DioException catch (replayError) {
              handler.next(replayError);
              return;
            } on NetworkException {
              handler.next(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
              return;
            }
          }
        }
        if (kDebugMode) {
          debugPrint(
            '[API] ${error.requestOptions.method} ${error.requestOptions.uri} → ${error.response?.statusCode ?? error.type.name}',
          );
        }
        handler.next(error);
      },
    ),
  );
  return dio;
}
