import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/diagnostics/runtime_diagnostics_models.dart';

import 'support/diagnostics_test_harness.dart';

void main() {
  test('RuntimeDiagnosticsSnapshot stores one capture time', () {
    final capturedAt = DateTime.utc(2026, 7, 16, 12, 30);
    final snapshot = minimalSnapshot(capturedAt: capturedAt);

    expect(snapshot.capturedAt, capturedAt);
    expect(snapshot.application.appVersion, '0.5.0-dev');
    expect(snapshot.catalogue?.itemCount, 2);
  });

  test('section models use final typed fields', () {
    const cache = CacheDiagnostics(
      status: DiagnosticSectionStatus.complete,
      artworkCandidateCount: 0,
      artworkCandidateCapacity: 500,
      artworkEvictionCount: 0,
    );

    expect(cache.artworkCandidateCount, 0);
    expect(cache.artworkEvictionCount, 0);
    expect(cache.status, DiagnosticSectionStatus.complete);
  });

  test('nullable fields distinguish unavailable from zero and false', () {
    const search = SearchDiagnostics(
      status: DiagnosticSectionStatus.complete,
      hasIndex: false,
      indexBuildCount: 0,
      isBuildInFlight: false,
    );
    const playback = PlaybackDiagnostics(
      status: DiagnosticSectionStatus.complete,
      hasActiveSession: false,
      isPlaying: null,
      audioTrackCount: null,
    );

    expect(search.hasIndex, isFalse);
    expect(search.indexBuildCount, 0);
    expect(playback.hasActiveSession, isFalse);
    expect(playback.isPlaying, isNull);
    expect(playback.audioTrackCount, isNull);
  });

  test('provider rows are fixed-length lists', () {
    const provider = ProviderDiagnostics(
      status: DiagnosticSectionStatus.complete,
      providers: [
        ProviderAttemptDiagnostics(
          providerKindLabel: 'Local file',
          healthLabel: 'success',
          isActive: true,
        ),
      ],
    );

    expect(provider.providers, hasLength(1));
    expect(() => provider.providers.add(
          const ProviderAttemptDiagnostics(
            providerKindLabel: 'HTTPS',
            healthLabel: 'failed',
            isActive: false,
          ),
        ), throwsUnsupportedError);
  });
}
