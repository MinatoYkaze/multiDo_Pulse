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
    connectTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    contentType: Headers.jsonContentType,
    headers: {'Accept': 'application/json'},
  ));

  dio.interceptors.add(AuthInterceptor(
    tokens: ref.read(tokenStorageProvider),
    dio: dio,
    onSessionExpired: () =>
        ref.read(sessionExpiredProvider.notifier).state++,
  ));

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestHeader: false,
      responseHeader: false,
      requestBody: true,
      responseBody: false,
      logPrint: (o) => debugPrint(o.toString()),
    ));
  }
  return dio;
});

/// Thin typed wrapper so repositories never touch `Response` directly and all
/// failures surface as [ApiException].
class ApiClient {
  ApiClient(this._dio);
  final Dio _dio;

  Future<T> get<T>(String path,
          {Map<String, dynamic>? query, required T Function(dynamic) parse}) =>
      _run(() => _dio.get<dynamic>(path, queryParameters: query), parse);

  Future<T> post<T>(String path,
          {Object? body,
          Map<String, dynamic>? query,
          required T Function(dynamic) parse}) =>
      _run(() => _dio.post<dynamic>(path, data: body, queryParameters: query),
          parse);

  Future<T> put<T>(String path,
          {Object? body, required T Function(dynamic) parse}) =>
      _run(() => _dio.put<dynamic>(path, data: body), parse);

  Future<T> patch<T>(String path,
          {Object? body, required T Function(dynamic) parse}) =>
      _run(() => _dio.patch<dynamic>(path, data: body), parse);

  Future<T> delete<T>(String path, {required T Function(dynamic) parse}) =>
      _run(() => _dio.delete<dynamic>(path), parse);

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
