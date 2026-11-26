import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/token_storage.dart';
import '../../../core/storage/offline_cache.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokens, this._dio, this._cache);
  final ApiClient _api;
  final TokenStorage _tokens;
  final Dio _dio;
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

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId:
        Api.googleServerClientId.isNotEmpty ? Api.googleServerClientId : null,
  );

  /// Opens the backend Google OAuth endpoint directly with mobile callback scheme.
  Future<Uri> _resolveLoginUrl() async {
    return Uri.parse('${Api.baseUrl}${Api.googleLogin}').replace(queryParameters: {
      'redirect_url': '${Api.callbackScheme}://auth',
    });
  }

  /// Full Google OAuth sign-in.
  /// On web: redirects current window to Google OAuth endpoint with current web origin.
  /// On mobile: uses native Google Sign-In SDK (Google Play Services) to obtain
  /// tokens directly without browser redirect issues, then verifies via /auth/google/verify.
  /// Seamlessly falls back to browser OAuth if native services are unavailable.
  Future<UserPost?> signInWithGoogle() async {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      final uri = Uri.parse('${Api.baseUrl}${Api.googleLogin}').replace(queryParameters: {
        'redirect_url': origin,
      });
      await launchUrl(uri, mode: LaunchMode.platformDefault, webOnlyWindowName: '_self');
      return null;
    }

    // Native Mobile Google Sign-In
    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const ApiException(
            'Sign-in was cancelled. (Tip: Tap the Pulse logo 5 times for Developer Access).');
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      final serverAuthCode = account.serverAuthCode;

      if (idToken != null || accessToken != null) {
        try {
          final res = await _dio.post<dynamic>(
            '${Api.baseUrl}${Api.googleVerify}',
            data: {
              if (idToken != null) 'id_token': idToken,
              if (accessToken != null) 'access_token': accessToken,
              if (serverAuthCode != null) 'server_auth_code': serverAuthCode,
            },
            options: Options(
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 15),
            ),
          );
          final data =
              res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null;
          final access = data?['access_token'] as String?;
          final refresh = data?['refresh_token'] as String?;
          if (access != null) {
            return await signInWithTokens(access: access, refresh: refresh);
          }
        } on DioException catch (dioErr) {
          // If backend hasn't deployed /auth/google/verify yet, notify clearly
          if (dioErr.response?.statusCode == 404) {
            throw const ApiException(
              'Backend is still deploying on Render (/auth/google/verify not active yet).\n'
              'Please check Render dashboard or use Developer Access (tap logo 5 times).',
            );
          }
          throw ApiException.from(dioErr);
        }
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      final s = e.toString().toLowerCase();

      debugPrint('[AuthRepository] Native Google Sign-In notice: $e');

      // ApiException 12501: Google Play Services cancelled/rejected the sign-in
      if (s.contains('12501') || s.contains('sign_in_canceled')) {
        throw const ApiException(
          'Google Sign-In rejected by Google Play Services (code 12501).\n'
          'Common causes:\n'
          '1. In Google Cloud Console, add your email under "OAuth consent screen" -> "Test users".\n'
          '2. Google Cloud credentials take ~5-15 min to propagate.\n'
          '(Tip: Tap the Pulse logo 5 times to bypass sign-in instantly).',
        );
      }

      // ApiException 10: Missing SHA-1 in Google Cloud Console
      if (s.contains('10') || s.contains('developer_error')) {
        throw const ApiException(
          'Google Sign-In setup error (code 10: DEVELOPER_ERROR).\n'
          'Ensure Android SHA-1 (7C:A9:22:83...) is registered in Google Cloud Console for com.example.multido.\n'
          '(Tip: Tap the Pulse logo 5 times to bypass sign-in instantly).',
        );
      }

      if (s.contains('cancel') || s.contains('canceled')) {
        throw const ApiException(
          'Sign-in was cancelled. (Tip: Tap the Pulse logo 5 times for Developer Access).',
        );
      }

      // Fallback to browser OAuth for platform limitations
      return await _signInWithGoogleBrowser();
    }

    return await _signInWithGoogleBrowser();
  }

  /// Browser-based OAuth fallback using Custom Tabs / FlutterWebAuth2.
  Future<UserPost?> _signInWithGoogleBrowser() async {
    final url = await _resolveLoginUrl();
    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: Api.callbackScheme,
      );
    } catch (e) {
      if (e.toString().toLowerCase().contains('cancel')) {
        throw const ApiException(
          'Sign-in was cancelled. (Tip: You can also bypass sign-in instantly by tapping the Pulse logo 5 times).',
        );
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
