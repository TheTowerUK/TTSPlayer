import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/models/catalogue_provider_snapshot.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_catalogue_provider.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';

void main() {
  const localA = MediaCatalogueProviderDefinition.localFile(
    r'Y:\Media\catalog.json',
  );
  const httpProvider = MediaCatalogueProviderDefinition.http(
    'https://192.168.0.10:8443/catalog.json',
  );

  MediaProviderConfig localPreferredConfig() => MediaProviderConfig(
        catalogueProviders: const [localA, httpProvider],
        mediaAccess: MediaAccessConfig.defaults(),
      );

  group('CatalogueProviderLoadTracker', () {
    test('first provider success marks success and leaves rest idle', () {
      final tracker = CatalogueProviderLoadTracker(
        config: localPreferredConfig(),
        attemptChain: const [localA, httpProvider],
        skippedProviders: const [],
      );
      final started = DateTime.utc(2026, 7, 12, 10);

      tracker.beginCycle(started);
      tracker.markLoading(0, started);
      tracker.markSuccess(0, started.add(const Duration(seconds: 1)),
          hadEarlierFailure: false);

      final snapshot = tracker.build(
        loadedCatalogueIdentity: 'CAT-1',
        catalogPath: localA.location,
        lastCatalogueLoadAt: started,
        sessionStartedAt: started,
        isDemoFallback: false,
        demoActiveWithoutProvider: false,
      );

      expect(snapshot.providers[0].health, CatalogueProviderHealth.success);
      expect(snapshot.providers[1].health, CatalogueProviderHealth.idle);
      expect(snapshot.isDegradedLoad, isFalse);
      expect(snapshot.activeProvider, localA);
    });

    test('later success after failure marks degraded', () {
      final tracker = CatalogueProviderLoadTracker(
        config: localPreferredConfig(),
        attemptChain: const [localA, httpProvider],
        skippedProviders: const [],
      );
      final started = DateTime.utc(2026, 7, 12, 10);

      tracker.beginCycle(started);
      tracker.markLoading(0, started);
      tracker.markFailed(0, 'File not found', started);
      tracker.markLoading(1, started);
      tracker.markSuccess(1, started, hadEarlierFailure: true);

      final snapshot = tracker.build(
        loadedCatalogueIdentity: 'CAT-2',
        catalogPath: httpProvider.location,
        lastCatalogueLoadAt: started,
        sessionStartedAt: started,
        isDemoFallback: false,
        demoActiveWithoutProvider: false,
      );

      expect(snapshot.providers[0].health, CatalogueProviderHealth.failed);
      expect(snapshot.providers[1].health, CatalogueProviderHealth.degraded);
      expect(snapshot.isDegradedLoad, isTrue);
    });

    test('httpRequired does not mark degraded on success after failure', () {
      final config = MediaProviderConfig(
        catalogueProviders: const [httpProvider],
        mediaAccess: MediaAccessConfig.defaults(
          mode: MediaAccessMode.httpRequired,
        ),
      );
      final tracker = CatalogueProviderLoadTracker(
        config: config,
        attemptChain: const [httpProvider],
        skippedProviders: const [localA],
      );
      final started = DateTime.utc(2026, 7, 12, 10);

      tracker.beginCycle(started);
      tracker.markLoading(0, started);
      tracker.markSuccess(0, started, hadEarlierFailure: false);

      final snapshot = tracker.build(
        loadedCatalogueIdentity: 'CAT-3',
        catalogPath: httpProvider.location,
        lastCatalogueLoadAt: started,
        sessionStartedAt: started,
        isDemoFallback: false,
        demoActiveWithoutProvider: false,
      );

      expect(snapshot.providers[0].health, CatalogueProviderHealth.success);
      expect(snapshot.providers[1].health, CatalogueProviderHealth.skipped);
      expect(snapshot.isDegradedLoad, isFalse);
    });

    test('all attempted providers failed leaves no active record', () {
      final tracker = CatalogueProviderLoadTracker(
        config: localPreferredConfig(),
        attemptChain: const [localA, httpProvider],
        skippedProviders: const [],
      );
      final started = DateTime.utc(2026, 7, 12, 10);

      tracker.beginCycle(started);
      tracker.markLoading(0, started);
      tracker.markFailed(0, 'missing', started);
      tracker.markLoading(1, started);
      tracker.markFailed(1, 'TLS error', started);
      tracker.markAllAttemptedFailed('TLS error');

      final snapshot = tracker.build(
        loadedCatalogueIdentity: null,
        catalogPath: null,
        lastCatalogueLoadAt: null,
        sessionStartedAt: started,
        isDemoFallback: true,
        demoActiveWithoutProvider: true,
      );

      expect(
        snapshot.providers.every((r) => r.health == CatalogueProviderHealth.failed),
        isTrue,
      );
      expect(snapshot.activeRecord, isNull);
      expect(snapshot.lastCycleError, 'TLS error');
    });

    test('beginCycle resets attempt chain to idle', () {
      final tracker = CatalogueProviderLoadTracker(
        config: localPreferredConfig(),
        attemptChain: const [localA],
        skippedProviders: const [],
      );
      final t0 = DateTime.utc(2026, 7, 12, 10);
      final t1 = DateTime.utc(2026, 7, 12, 11);

      tracker.beginCycle(t0);
      tracker.markLoading(0, t0);
      tracker.markFailed(0, 'err', t0);

      tracker.beginCycle(t1);
      expect(tracker.records.single.health, CatalogueProviderHealth.idle);
      expect(tracker.records.single.lastError, isNull);
    });
  });
}
