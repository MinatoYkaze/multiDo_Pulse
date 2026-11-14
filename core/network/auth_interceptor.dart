import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_endpoints.dart';
import 'token_storage.dart';

/// Injects `Authorization: Bearer <jwt>` and transparently refreshes on 401.
///
/// Extends [QueuedInterceptor] so requests/errors are processed strictly one at
/// a time: while one 401 triggers a refresh, every other failing request waits,
/// then retries with the new token — no refresh stampede.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.tokens,
    required this.dio,
    required this.onSessionExpired,
  }) : _refreshDio = Dio(BaseOptions(
          baseUrl: Api.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Accept': 'application/json'},
          extra: {'withCredentials': true},
        ));

  final TokenStorage tokens;
  final Dio dio; // main client, used to replay the failed request
  final void Function() onSessionExpired;
  final Dio _refreshDio; // bare client: no interceptors → no recursion

  static const _retriedKey = '__retried';
  static const _publicPaths = <String>[
    Api.googleLogin,
    Api.googleCallback,
    Api.refresh,
  ];

  bool _isPublic(RequestOptions o) =>
      _publicPaths.any((p) => o.path.startsWith(p));

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isPublic(options)) {
      final t = await tokens.accessToken;
      if (t != null) options.headers['Authorization'] = 'Bearer $t';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final is401 = err.response?.statusCode == 401;

    if (!is401 || _isPublic(req) || req.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    if (await tokens.isDevSession) {
      // In dev bypass mode, 401 errors from backend should not invalidate the dev session
      return handler.next(err);
    }

    // Another queued request may already have refreshed while we waited.
    final current = await tokens.accessToken;
    final sentWith = (req.headers['Authorization'] as String?)
        ?.replaceFirst('Bearer ', '');
    if (current != null && sentWith != null && current != sentWith) {
      return _retry(req, handler, err);
    }

    final refreshed = await _refresh();
    if (!refreshed) {
      await tokens.clear();
      onSessionExpired();
      return handler.next(err);
    }
    return _retry(req, handler, err);
  }

  Future<void> _retry(RequestOptions req, ErrorInterceptorHandler handler,
      DioException original) async {
    try {
      final t = await tokens.accessToken;
      req.headers['Authorization'] = 'Bearer $t';
      req.extra[_retriedKey] = true;
      final res = await dio.fetch<dynamic>(req);
      handler.resolve(res);
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.next(original);
    }
  }

  Future<bool> _refresh() async {
    final rt = await tokens.refreshToken;
    if (!kIsWeb && rt == null) return false;
    try {
      final res = await _refreshDio.post<dynamic>(
        Api.refresh,
        data: rt != null ? {'refresh_token': rt} : null,
        options: Options(
          headers: rt != null ? {'Authorization': 'Bearer $rt'} : null,
          extra: {'withCredentials': true},
        ),
      );
      if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
        final data = res.data;
        if (data is Map) {
          final access = (data['access_token'] ?? data['token']) as String?;
          if (access != null) {
            await tokens.save(
                access: access, refresh: data['refresh_token'] as String?);
          }
        }
        return true;
      }
      return false;
    } on DioException {
      return false;
    }
  }
}
