import 'package:dio/dio.dart';

sealed class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException([
    super.message = 'Сервер недоступен. Проверьте соединение.',
  ]);
}

class RequestCancelledException extends ApiException {
  const RequestCancelledException() : super('Запрос отменён.');
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'Недостаточно прав для этого действия.',
  ]);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

class ConflictException extends ApiException {
  const ConflictException(super.message);
}

class ValidationException extends ApiException {
  const ValidationException(super.message, this.errors);
  final Map<String, String> errors;
}

class ServerException extends ApiException {
  const ServerException([
    super.message = 'Ошибка на сервере. Попробуйте позже.',
  ]);
}

class BadRequestException extends ApiException {
  const BadRequestException(super.message);
}

ApiException mapHttpError(int status, dynamic body) {
  final message = body is Map && body['message'] is String
      ? body['message'] as String
      : null;
  return switch (status) {
    400 => BadRequestException(message ?? 'Некорректный запрос.'),
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException(
      message ?? 'Недостаточно прав для этого действия.',
    ),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(
      message ?? 'Операция невозможна: конфликт данных.',
    ),
    422 => ValidationException(
      message ?? 'Ошибка валидации.',
      body is Map && body['errors'] is Map
          ? (body['errors'] as Map).map(
              (key, value) => MapEntry('$key', '$value'),
            )
          : const {},
    ),
    _ => ServerException(message ?? 'Ошибка на сервере (код $status).'),
  };
}

ApiException mapDioError(DioException error) {
  if (error.error is ApiException) return error.error as ApiException;
  if (error.response != null) {
    return mapHttpError(
      error.response!.statusCode ?? 500,
      error.response!.data,
    );
  }
  return switch (error.type) {
    DioExceptionType.cancel => const RequestCancelledException(),
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkException(
      'Сервер не ответил вовремя.',
    ),
    DioExceptionType.connectionError ||
    DioExceptionType.unknown => const NetworkException(
      'Не удалось соединиться с сервером. Если сервер запущен, откройте консоль браузера и проверьте ошибку CORS.',
    ),
    _ => const ServerException(),
  };
}

Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (error) {
    throw mapDioError(error);
  } on FormatException {
    throw const ServerException('Сервер вернул данные в неверном формате.');
  }
}
