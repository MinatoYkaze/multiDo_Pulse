import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/storage/offline_cache.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));

  await Hive.initFlutter();
  final box = await Hive.openBox(OfflineCache.boxName);
  final offlineCache = OfflineCache(box);

  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      offlineCacheProvider.overrideWithValue(offlineCache),
    ],
    child: const ObsidianApp(),
  ));
}

class ObsidianApp extends ConsumerWidget {
  const ObsidianApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant = ref.watch(prefsProvider.select((s) => s.variant));
    final isDark = ref.watch(prefsProvider.select((s) => s.isDarkMode));
    return MaterialApp.router(
      title: 'Pulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(variant, isDark: isDark),
      themeAnimationDuration: const Duration(milliseconds: 300),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
