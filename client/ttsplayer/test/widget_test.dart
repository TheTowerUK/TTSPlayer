// Smoke test — verifies the app starts without throwing.
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ttsplayer/main.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/scan_history_service.dart';
import 'package:ttsplayer/services/scanner_service.dart';

void main() {
  testWidgets('App renders without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CatalogService()),
          ChangeNotifierProvider(create: (_) => PlaybackService()),
          ChangeNotifierProvider(create: (_) => ScannerService()),
          ChangeNotifierProvider(create: (_) => ScanHistoryService()),
        ],
        child: const TTSPlayerApp(),
      ),
    );
    await tester.pump();
  });
}
