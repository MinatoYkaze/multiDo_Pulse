import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/token_storage.dart';
import '../../../core/storage/offline_cache.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokens, this._cache);
  final ApiClient _api;
  final TokenStorage _tokens;
  final OfflineCache _cache;

  /// GET /auth/me
  Future<UserPost> fetchMe() async {
    final user = await _api.get(Api.me, parse: (d) => ApiClient.obj(d, UserPost.fromJson));
    await _cache.saveUser(user);
    return user;
  }

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
    // On web, cookies are stored in the browser directly; on mobile, tokens are in secure storage.
    if (!kIsWeb && !await _tokens.hasSession) return null;

    // Check offline cache first: return immediately so app opens with ZERO spinner!
    final cachedUser = _cache.getUser();
    if (cachedUser != null) {
      // In the background, refresh profile if online without blocking app launch
      fetchMe().then((fresh) => _cache.saveUser(fresh)).catchError((_) {});
      return cachedUser;
    }

    try {
      final user = await fetchMe();
      await _cache.saveUser(user);
      return user;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _tokens.clear();
        await _cache.clearUser();
        return null;
      }
      final token = await _tokens.accessToken;
      if (token != null) {
        // We have a stored session token but were offline during initial launch
        const fallback = UserPost(id: 'offline_user', email: 'offline@multido.local', name: 'Offline User');
        await _cache.saveUser(fallback);
        return fallback;
      }
      return null;
    }
  }

  /// Authenticate instantly using the developer secret key.
  Future<UserPost> signInWithSecretKey(String key) async {
    if (key.trim() != Api.devSecretKey) {
      throw const ApiException('Invalid developer secret key.');
    }
    await _tokens.saveDevSession();
    await _cache.saveUser(devUser);
    return devUser;
  }

  /// Full Google OAuth sign-in.
  /// On web: redirects current window to Google OAuth endpoint.
  /// On mobile: opens the Render backend /auth/google/login in a Custom Tab,
  /// waits for the obsidiantodo:// callback, then extracts tokens.
  Future<UserPost?> signInWithGoogle() async {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      final uri = Uri.parse('${Api.baseUrl}${Api.googleLogin}').replace(queryParameters: {
        'redirect_url': origin,
      });
      await launchUrl(uri, mode: LaunchMode.platformDefault, webOnlyWindowName: '_self');
      return null;
    }

    return _signInWithGoogleBrowser();
  }

  /// Browser-based OAuth via Render backend using Custom Tabs / FlutterWebAuth2.
  Future<UserPost?> _signInWithGoogleBrowser() async {
    final url = Uri.parse('${Api.baseUrl}${Api.googleLogin}').replace(queryParameters: {
      'redirect_url': '${Api.callbackScheme}://auth',
    });

    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: Api.callbackScheme,
      );
    } catch (e) {
      if (e.toString().toLowerCase().contains('cancel')) {
        throw const ApiException('Sign-in was cancelled.');
      }
      throw ApiException('Authentication error: $e');
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
      final user = await fetchMe();
      await _cache.saveUser(user);
      return user;
    } catch (e) {
      await _tokens.clear();
      await _cache.clearUser();
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
      await _cache.clearUser();
    }
  }
}
