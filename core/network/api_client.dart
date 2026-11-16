
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_endpoints.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>(
  (_) => TokenStorage(),
);

/// Emits whenever the session can no longer be refreshed.
/// The router listens to this and redirects the user to login.
final sessionExpiredProvider = StateProvider<int>((_) => 0);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Api.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      headers: {'Accept': 'application/json'},
      extra: {'withCredentials': true},
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      tokens: ref.read(tokenStorageProvider),
      dio: dio,
      onSessionExpired: () {
        ref.read(sessionExpiredProvider.notifier).state++;
      },
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        responseHeader: false,
        requestBody: true,
        responseBody: false,
        logPrint: (o) => debugPrint(o.toString()),
      ),
    );
  }

  return dio;
});

/// Centralized API client.
/// Repositories use this class instead of accessing Dio directly.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  // GET request
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Duration? receiveTimeout,
    required T Function(dynamic) parse,
  }) {
    return _run(
      () => _dio.get<dynamic>(
        path,
        queryParameters: query,
        options: Options(
          receiveTimeout: receiveTimeout,
        ),
      ),
      parse,
    );
  }

 
Future<T> post<T>(
  String path, {
  Object? body,
  Map<String, dynamic>? query,
  Duration? connectTimeout,
  Duration? receiveTimeout,
  required T Function(dynamic) parse,
}) {
  return _run(
    () => _dio.post<dynamic>(
      path,
      data: body,
      queryParameters: query,
      options: Options(
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
      ),
    ),
    parse,
  );
}

  // PUT request
  Future<T> put<T>(
    String path, {
    Object? body,
    Duration? receiveTimeout,
    required T Function(dynamic) parse,
  }) {
    return _run(
      () => _dio.put<dynamic>(
        path,
        data: body,
        options: Options(
          receiveTimeout: receiveTimeout,
        ),
      ),
      parse,
    );
  }

  // PATCH request
  Future<T> patch<T>(
    String path, {
    Object? body,
    Duration? receiveTimeout,
    required T Function(dynamic) parse,
  }) {
    return _run(
      () => _dio.patch<dynamic>(
        path,
        data: body,
        options: Options(
          receiveTimeout: receiveTimeout,
        ),
      ),
      parse,
    );
  }

  // DELETE request
  Future<T> delete<T>(
    String path, {
    Duration? receiveTimeout,
    required T Function(dynamic) parse,
  }) {
    return _run(
      () => _dio.delete<dynamic>(
        path,
        options: Options(
          receiveTimeout: receiveTimeout,
        ),
      ),
      parse,
    );
  }

  /// Executes request and converts errors into ApiException.
  Future<T> _run<T>(
    Future<Response<dynamic>> Function() call,
    T Function(dynamic) parse,
  ) async {
    try {
      final response = await call();
      return parse(response.data);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  // Parsing helpers

  static List<T> list<T>(
    dynamic data,
    T Function(Map<String, dynamic>) parser,
  ) {
    return (data as List)
        .map(
          (e) => parser(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  static T obj<T>(
    dynamic data,
    T Function(Map<String, dynamic>) parser,
  ) {
    return parser(
      Map<String, dynamic>.from(data as Map),
    );
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider)),
);
