import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsidian_todo/core/audio/audio_controller.dart';
import 'package:obsidian_todo/core/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'audio_fx': true});
  });

  test('AudioFxService initializes safely and does not throw', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
      ],
    );
    addTearDown(container.dispose);

    final service = container.read(audioFxProvider);
    expect(service, isNotNull);

    // Calling playChime and playPop must never throw or unhandled rethrow
    await expectLater(service.playChime(), completes);
    await expectLater(service.playPop(), completes);
  });
}
