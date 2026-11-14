import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenPair {
  final String accessToken;
  final String? refreshToken;
  const TokenPair(this.accessToken, this.refreshToken);
}

class TokenStorage {
  TokenStorage([FlutterSecureStorage? s])
      : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kDevSession = 'is_dev_session';

  // In-memory cache avoids an async hop on every request.
  String? _access;
  String? _refresh;
  bool? _isDev;
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _access = await _s.read(key: _kAccess);
    _refresh = await _s.read(key: _kRefresh);
    _isDev = (await _s.read(key: _kDevSession)) == 'true';
    _loaded = true;
  }

  Future<String?> get accessToken async {
    await _ensureLoaded();
    return _access;
  }

  Future<String?> get refreshToken async {
    await _ensureLoaded();
    return _refresh;
  }

  Future<bool> get isDevSession async {
    await _ensureLoaded();
    return _isDev == true;
  }

  Future<bool> get hasSession async => (await accessToken) != null;

  Future<void> save({required String access, String? refresh}) async {
    _access = access;
    if (refresh != null) _refresh = refresh;
    _isDev = false;
    _loaded = true;
    await _s.write(key: _kAccess, value: access);
    if (refresh != null) await _s.write(key: _kRefresh, value: refresh);
    await _s.delete(key: _kDevSession);
  }

  Future<void> saveDevSession() async {
    _access = 'dev_secret_bypass_token';
    _refresh = null;
    _isDev = true;
    _loaded = true;
    await _s.write(key: _kAccess, value: 'dev_secret_bypass_token');
    await _s.delete(key: _kRefresh);
    await _s.write(key: _kDevSession, value: 'true');
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _isDev = false;
    _loaded = true;
    await _s.delete(key: _kAccess);
    await _s.delete(key: _kRefresh);
    await _s.delete(key: _kDevSession);
  }
}
