import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());

/// Emits whenever the session can no longer be refreshed. The router (Phase 2)
/// listens to this to bounce the user to the login screen.
final sessionExpiredProvider =
    StateProvider<int>((_) => 0); // counter → every bump is an event

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: Api.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    contentType: Headers.jsonContentType,
    headers: {'Accept': 'application/json'},
    extra: {'withCredentials': true},
  ));

  dio.interceptors.add(AuthInterceptor(
    tokens: ref.read(tokenStorageProvider),
    dio: dio,
    onSessionExpired: () =>
        ref.read(sessionExpiredProvider.notifier).state++,
  ));

  dio.interceptors.add(const _NetworkTimingInterceptor());

  return dio;
});

/// Interceptor that safely logs HTTP method, endpoint, status code, start time,
/// elapsed duration, and DioExceptionType without logging sensitive tokens,
/// passwords, or request bodies.
class _NetworkTimingInterceptor extends Interceptor {
  const _NetworkTimingInterceptor();

  static const _kStartTimeKey = '__req_start_time';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_kStartTimeKey] = DateTime.now().millisecondsSinceEpoch;
    final nowIso = DateTime.now().toIso8601String();
    debugPrint('[HTTP ->] ${options.method} ${options.path} started at $nowIso');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final start = response.requestOptions.extra[_kStartTimeKey] as int?;
    final elapsed = start != null
        ? DateTime.now().millisecondsSinceEpoch - start
        : -1;
    debugPrint(
        '[HTTP <-] ${response.requestOptions.method} ${response.requestOptions.path} completed with ${response.statusCode} in ${elapsed}ms');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final start = err.requestOptions.extra[_kStartTimeKey] as int?;
    final elapsed = start != null
        ? DateTime.now().millisecondsSinceEpoch - start
        : -1;
    debugPrint(
        '[HTTP !!] ${err.requestOptions.method} ${err.requestOptions.path} failed with ${err.type} (status: ${err.response?.statusCode}) after ${elapsed}ms: ${err.message}');
    handler.next(err);
  }
}

/// Thin typed wrapper so repositories never touch `Response` directly and all
/// failures surface as [ApiException]. Supports per-request custom timeouts.
class ApiClient {
  ApiClient(this._dio);
  final Dio _dio;

  Options _buildOptions({
    Duration? timeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Options? options,
  }) {
    final base = options ?? Options();
    final effectiveReceive = receiveTimeout ?? timeout ?? base.receiveTimeout;
    return base.copyWith(
      sendTimeout: sendTimeout ?? base.sendTimeout,
      receiveTimeout: effectiveReceive,
    );
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Duration? timeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Options? options,
    required T Function(dynamic) parse,
  }) =>
      _run(
        () => _dio.get<dynamic>(
          path,
          queryParameters: query,
          options: _buildOptions(
            timeout: timeout,
            receiveTimeout: receiveTimeout,
            sendTimeout: sendTimeout,
            options: options,
          ),
        ),
        parse,
      );

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Duration? timeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Options? options,
    required T Function(dynamic) parse,
  }) =>
      _run(
        () => _dio.post<dynamic>(
          path,
          data: body,
          queryParameters: query,
          options: _buildOptions(
            timeout: timeout,
            receiveTimeout: receiveTimeout,
            sendTimeout: sendTimeout,
            options: options,
          ),
        ),
        parse,
      );

  Future<T> put<T>(
    String path, {
    Object? body,
    Duration? timeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Options? options,
    required T Function(dynamic) parse,
  }) =>
      _run(
        () => _dio.put<dynamic>(
          path,
          data: body,
          options: _buildOptions(
            timeout: timeout,
            receiveTimeout: receiveTimeout,
            sendTimeout: sendTimeout,
            options: options,
          ),
        ),
        parse,
      );

  Future<T> patch<T>(
    String path, {
    Object? body,
    Duration? timeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Options? options,
    required T Function(dynamic) parse,
  }) =>
      _run(
        () => _dio.patch<dynamic>(
          path,
          data: body,
          options: _buildOptions(
            timeout: timeout,
            receiveTimeout: receiveTimeout,
            sendTimeout: sendTimeout,
            options: options,
          ),
        ),
        parse,
      );

  Future<T> delete<T>(
    String path, {
    Duration? timeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Options? options,
    required T Function(dynamic) parse,
  }) =>
      _run(
        () => _dio.delete<dynamic>(
          path,
          options: _buildOptions(
            timeout: timeout,
            receiveTimeout: receiveTimeout,
            sendTimeout: sendTimeout,
            options: options,
          ),
        ),
        parse,
      );

  Future<T> _run<T>(
      Future<Response<dynamic>> Function() call, T Function(dynamic) parse) async {
    try {
      final res = await call();
      return parse(res.data);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  // Parsing helpers
  static List<T> list<T>(dynamic data, T Function(Map<String, dynamic>) f) =>
      (data as List)
          .map((e) => f(Map<String, dynamic>.from(e as Map)))
          .toList();

  static T obj<T>(dynamic data, T Function(Map<String, dynamic>) f) =>
      f(Map<String, dynamic>.from(data as Map));
}

final apiClientProvider =
    Provider<ApiClient>((ref) => ApiClient(ref.watch(dioProvider)));
