import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_practice/core/api_client.dart';

class ResponseAdapter implements HttpClientAdapter {
  ResponseAdapter(this.answer);
  final int Function(RequestOptions) answer;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'message': 'Ответ сервера'}),
      answer(options),
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'expired request is repeated once with new Authorization token',
    () async {
      var token = 'old';
      var refreshes = 0;
      final dio = buildDio(
        tokenProvider: () => token,
        refreshToken: () async {
          refreshes++;
          return token = 'new';
        },
      );
      addTearDown(() => dio.close(force: true));
      final adapter = ResponseAdapter(
        (options) =>
            options.headers['Authorization'] == 'Bearer new' ? 200 : 401,
      );
      dio.httpClientAdapter = adapter;
      expect((await dio.get('/services')).statusCode, 200);
      expect(adapter.requests.length, 2);
      expect(refreshes, 1);
    },
  );
  test(
    '401 from authentication endpoint never triggers token refresh',
    () async {
      var refreshes = 0;
      final dio = buildDio(
        refreshToken: () async {
          refreshes++;
          return 'new';
        },
      );
      addTearDown(() => dio.close(force: true));
      dio.httpClientAdapter = ResponseAdapter((_) => 401);
      await expectLater(dio.post('/auth/login'), throwsA(isA<DioException>()));
      expect(refreshes, 0);
    },
  );
  test(
    'second 401 logs out without another refresh or endless retry',
    () async {
      var refreshes = 0, logouts = 0;
      final dio = buildDio(
        refreshToken: () async {
          refreshes++;
          return 'new';
        },
        onUnauthorized: () async {
          logouts++;
        },
      );
      addTearDown(() => dio.close(force: true));
      final adapter = ResponseAdapter((_) => 401);
      dio.httpClientAdapter = adapter;
      await expectLater(dio.get('/services'), throwsA(isA<DioException>()));
      expect(refreshes, 1);
      expect(logouts, 1);
      expect(adapter.requests.length, 2);
    },
  );
  test('failed refresh ends original request without replay', () async {
    var refreshes = 0;
    final dio = buildDio(
      refreshToken: () async {
        refreshes++;
        return null;
      },
    );
    addTearDown(() => dio.close(force: true));
    final adapter = ResponseAdapter((_) => 401);
    dio.httpClientAdapter = adapter;
    await expectLater(dio.get('/services'), throwsA(isA<DioException>()));
    expect(refreshes, 1);
    expect(adapter.requests.length, 1);
  });
}
