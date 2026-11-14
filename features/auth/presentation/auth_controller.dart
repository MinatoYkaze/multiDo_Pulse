import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      ref.watch(apiClientProvider),
      ref.watch(tokenStorageProvider),
      ref.watch(dioProvider),
    ));

/// `AsyncData(null)` = signed out, `AsyncData(user)` = signed in,
/// `AsyncLoading` = restoring session on cold start (router shows splash).
class AuthController extends AsyncNotifier<UserPost?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<UserPost?> build() async {
    // The Dio interceptor bumps this when a refresh fails → force sign-out.
    ref.listen<int>(sessionExpiredProvider, (_, __) {
      state = const AsyncData(null);
    });
    if (Api.devBypass) {
      return _repo.signInWithSecretKey(Api.devSecretKey);
    }
    return _repo.restore();
  }

  Future<void> signInWithGoogle() async {
    final user = await _repo.signInWithGoogle();
    state = AsyncData(user);
  }

  Future<void> signInWithSecretKey(String key) async {
    final user = await _repo.signInWithSecretKey(key);
    state = AsyncData(user);
  }

  Future<void> signInWithTokens(String access, String? refresh) async {
    final user = await _repo.signInWithTokens(access: access, refresh: refresh);
    state = AsyncData(user);
  }

  /// Re-fetches GET /auth/me without flashing a loading state.
  Future<void> refreshProfile() async {
    try {
      state = AsyncData(await _repo.fetchMe());
    } catch (_) {/* keep the cached profile */}
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, UserPost?>(AuthController.new);

final currentUserProvider =
    Provider<UserPost?>((ref) => ref.watch(authControllerProvider).valueOrNull);
