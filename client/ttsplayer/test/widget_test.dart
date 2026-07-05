// Smoke test — verifies the app starts without throwing.
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ttsplayer/main.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/scan_history_service.dart';
import 'package:ttsplayer/services/scanner_service.dart';

void main() {
  testWidgets('App renders without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
          Provider(
            create: (context) => MediaLocationResolver(
              config: context.read<MediaProviderConfigService>().mediaAccess,
              isWindowsDesktop: false,
            ),
          ),
          Provider(create: (_) => ArtworkService()),
          ChangeNotifierProvider(create: (_) => CatalogService()),
          ChangeNotifierProvider(
            create: (context) => PlaybackService(
              mediaLocationResolver: context.read<MediaLocationResolver>(),
            ),
          ),
          ChangeNotifierProvider(create: (_) => ScannerService()),
          ChangeNotifierProvider(create: (_) => ScanHistoryService()),
        ],
        child: const TTSPlayerApp(),
      ),
    );
    await tester.pump();
  });
}
