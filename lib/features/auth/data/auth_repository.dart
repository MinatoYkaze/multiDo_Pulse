import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/token_storage.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokens, this._dio);
  final ApiClient _api;
  final TokenStorage _tokens;
  final Dio _dio;

  /// GET /auth/me
  Future<UserPost> fetchMe() =>
      _api.get(Api.me, parse: (d) => ApiClient.obj(d, UserPost.fromJson));

  /// Default mock profile returned when accessing via developer secret key.
  static const devUser = UserPost(
    id: 'dev_user_001',
    email: 'developer@multido.local',
    name: 'Developer Mode',
    picture: null,
  );

  /// Called on cold start. Returns null when there is no valid session.
  Future<UserPost?> restore() async {
    if (await _tokens.isDevSession) {
      return devUser;
    }
    if (!await _tokens.hasSession) return null;
    try {
      return await fetchMe();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _tokens.clear();
        return null;
      }
      rethrow; // offline etc. → keep tokens, surface error
    }
  }

  /// Authenticate instantly using the developer secret key.
  Future<UserPost> signInWithSecretKey(String key) async {
    if (key.trim() != Api.devSecretKey) {
      throw const ApiException('Invalid developer secret key.');
    }
    await _tokens.saveDevSession();
    return devUser;
  }

  /// GET /auth/google/login can answer with a 302 or with JSON {"url": ...}.
  /// We support both and fall back to the endpoint itself.
  Future<Uri> _resolveLoginUrl() async {
    final fallback = Uri.parse('${Api.baseUrl}${Api.googleLogin}');
    try {
      final res = await _dio.get<dynamic>(
        Api.googleLogin,
        options: Options(
          followRedirects: false,
          validateStatus: (s) => s != null && s < 400,
        ),
      );
      final loc = res.headers.value('location');
      if (loc != null) return Uri.parse(loc);
      final data = res.data;
      if (data is Map) {
        final u = data['url'] ?? data['auth_url'] ?? data['authorization_url'];
        if (u is String) return Uri.parse(u);
      }
    } catch (_) {}
    return fallback;
  }

  /// Full Google OAuth round-trip through the system browser.
  /// The backend must finish by redirecting to
  /// `obsidiantodo://auth?access_token=…&refresh_token=…`
  /// (or `?code=…&state=…`, which we exchange via GET /auth/google/callback).
  Future<UserPost> signInWithGoogle() async {
    final url = await _resolveLoginUrl();
    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: Api.callbackScheme,
      );
    } catch (_) {
      throw const ApiException('Sign-in was cancelled.');
    }

    final uri = Uri.parse(result);
    final params = <String, String>{...uri.queryParameters};
    if (uri.fragment.isNotEmpty) {
      try {
        params.addAll(Uri.splitQueryString(uri.fragment));
      } catch (_) {}
    }

    var access = params['access_token'] ?? params['token'];
    var refresh = params['refresh_token'];

    if (access == null && params['code'] != null) {
      final data = await _api.get<Map<String, dynamic>>(
        Api.googleCallback,
        query: {'code': params['code'], 'state': params['state']}
          ..removeWhere((_, v) => v == null),
        parse: (d) => Map<String, dynamic>.from(d as Map),
      );
      access = (data['access_token'] ?? data['token']) as String?;
      refresh = data['refresh_token'] as String?;
    }

    if (access == null) {
      throw ApiException(
          params['error'] ?? 'Sign-in failed: no token returned by server.');
    }
    return signInWithTokens(access: access, refresh: refresh);
  }

  /// Persist tokens, then load the profile (also used by the debug sheet).
  Future<UserPost> signInWithTokens(
      {required String access, String? refresh}) async {
    await _tokens.save(access: access, refresh: refresh);
    try {
      return await fetchMe();
    } catch (e) {
      await _tokens.clear();
      rethrow;
    }
  }

  /// POST /auth/Logout (capital L). Local tokens are always cleared, even if
  /// the server call fails, so the user can never get stuck signed-in.
  Future<void> logout() async {
    try {
      if (!await _tokens.isDevSession) {
        await _api.post<void>(Api.logout, parse: (_) {});
      }
    } catch (_) {
      // ignore: session is being discarded locally regardless
    } finally {
      await _tokens.clear();
    }
  }
}
