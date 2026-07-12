import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ttsplayer/features/dashboard/widgets/provider_status_section.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/catalogue_provider_snapshot.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_catalogue_provider.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';
import 'package:ttsplayer/theme/app_theme.dart';

class _StubCatalogService extends CatalogService {
  _StubCatalogService({
    required this.stubCatalog,
    required this.stubSnapshot,
    this.loading = false,
    this.error,
    this.demo = false,
    this.degraded = false,
    this.activeProvider,
    this.lastLoad,
  });

  final Catalog stubCatalog;
  final CatalogueProviderSnapshot stubSnapshot;
  final bool loading;
  final String? error;
  final bool demo;
  final bool degraded;
  final MediaCatalogueProviderDefinition? activeProvider;
  final DateTime? lastLoad;

  @override
  Catalog? get catalog => stubCatalog;

  @override
  bool get isLoading => loading;

  @override
  String? get errorMessage => error;

  @override
  bool get isUsingFallback => demo;

  @override
  bool get isDemoCatalogue => demo;

  @override
  bool get isDegradedLoad => degraded;

  @override
  CatalogueProviderSnapshot get providerSnapshot => stubSnapshot;

  @override
  MediaCatalogueProviderDefinition? get activeCatalogueProvider =>
      activeProvider;

  @override
  DateTime? get lastCatalogueLoadAt => lastLoad;

  @override
  String? get catalogPath => stubSnapshot.catalogPath;

  @override
  Future<void> refreshCatalogue() async {}
}

CatalogueProviderSnapshot _snapshot({
  required List<CatalogueProviderAttemptRecord> providers,
  bool degraded = false,
  String? catalogPath,
}) {
  return CatalogueProviderSnapshot(
    providers: providers,
    activeProvider: providers.where((r) => r.isActive).firstOrNull?.definition,
    catalogPath: catalogPath,
    accessMode: MediaAccessMode.localPreferred,
    lastCatalogueLoadAt: DateTime.utc(2026, 7, 12, 9, 30),
    isDegradedLoad: degraded,
  );
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

Widget _panelHarness(CatalogService service) {
  return ChangeNotifierProvider<CatalogService>.value(
    value: service,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const Scaffold(
        body: SingleChildScrollView(child: ProviderStatusSection()),
      ),
    ),
  );
}

Catalog _minimalCatalog() {
  return Catalog.fromJson({
    'generated_at': '2026-07-12T09:00:00+00:00',
    'total_items': 2,
    'folders': [],
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const local = MediaCatalogueProviderDefinition.localFile(
    r'Y:\Media\catalog.json',
  );

  testWidgets('shows active provider and refresh action', (tester) async {
    final service = _StubCatalogService(
      stubCatalog: _minimalCatalog(),
      activeProvider: local,
      lastLoad: DateTime.utc(2026, 7, 12, 9, 30),
      stubSnapshot: _snapshot(
        catalogPath: local.location,
        providers: const [
          CatalogueProviderAttemptRecord(
            definition: local,
            health: CatalogueProviderHealth.success,
            lastSuccessAt: null,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_panelHarness(service));
    await tester.pumpAndSettle();

    expect(find.text('PROVIDER STATUS'), findsOneWidget);
    expect(find.text('Active provider'), findsOneWidget);
    expect(find.text(local.location), findsWidgets);
    expect(find.text('Refresh catalogue'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(
      find.textContaining('Refresh catalogue reloads catalog.json'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Full Scan'),
      findsOneWidget,
    );
  });

  testWidgets('shows retry when error present and disables refresh while loading',
      (tester) async {
    final service = _StubCatalogService(
      stubCatalog: _minimalCatalog(),
      error: 'Could not load catalogue.',
      loading: true,
      stubSnapshot: _snapshot(
        providers: const [
          CatalogueProviderAttemptRecord(
            definition: local,
            health: CatalogueProviderHealth.failed,
            lastError: 'Could not load catalogue.',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_panelHarness(service));
    await tester.pump();

    expect(find.text('Retry'), findsOneWidget);
    final refreshButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Refresh catalogue'),
    );
    expect(refreshButton.onPressed, isNull);
  });

  testWidgets('shows degraded hint when snapshot reports degraded load',
      (tester) async {
    const http = MediaCatalogueProviderDefinition.http(
      'https://192.168.0.10:8443/catalog.json',
    );
    final service = _StubCatalogService(
      stubCatalog: _minimalCatalog(),
      degraded: true,
      activeProvider: http,
      stubSnapshot: _snapshot(
        degraded: true,
        catalogPath: http.location,
        providers: const [
          CatalogueProviderAttemptRecord(
            definition: local,
            health: CatalogueProviderHealth.failed,
          ),
          CatalogueProviderAttemptRecord(
            definition: http,
            health: CatalogueProviderHealth.degraded,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_panelHarness(service));
    await tester.pump();

    expect(find.text('Degraded'), findsWidgets);
    expect(
      find.textContaining('Loaded from fallback'),
      findsOneWidget,
    );
  });
}
