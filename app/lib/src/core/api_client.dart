import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exception.dart';
import 'env.dart';
import 'token_store.dart';

/// Thin wrapper over Dio: base URL, bearer auth, JSON headers, and a single
/// place that turns transport errors into [ApiException].
class ApiClient {
  ApiClient(this._tokens) : dio = Dio(_baseOptions) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _tokens.value;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) {
          if (e.response?.statusCode == 401) {
            _onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: false));
    }
  }

  static final _baseOptions = BaseOptions(
    baseUrl: Env.apiV1,
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json'},
    validateStatus: (s) => s != null && s < 400,
  );

  final Dio dio;
  final TokenStore _tokens;
  void Function()? _onUnauthorized;

  set onUnauthorized(void Function() cb) => _onUnauthorized = cb;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _wrap(() => dio.get<T>(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? data}) =>
      _wrap(() => dio.post<T>(path, data: data));

  Future<T> patch<T>(String path, {Object? data}) =>
      _wrap(() => dio.patch<T>(path, data: data));

  Future<T> delete<T>(String path, {Object? data}) =>
      _wrap(() => dio.delete<T>(path, data: data));

  Future<T> _wrap<T>(Future<Response<T>> Function() run) async {
    try {
      final res = await run();
      return res.data as T;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
