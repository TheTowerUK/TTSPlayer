import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_failure.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/fake_book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_refresh_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_provider_lifecycle.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_provider_operation_coordinator.dart';
import 'package:ttsplayer/models/application_settings.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';

import 'book_metadata_refresh_service_test.dart' show bookItem;
import 'support/metadata_enrichment_test_support.dart';

class _Outcome {
  const _Outcome.success() : failure = null;
  _Outcome.failure(BookMetadataProviderFailureCategory category,
      {Duration? retryAfter})
      : failure = BookMetadataProviderFailure(
          category: category,
          retryAfter: retryAfter,
        );

  final BookMetadataProviderFailure? failure;
}

class _FakeTime {
  DateTime now = DateTime.utc(2026, 9, 9);
  final List<Duration> delays = [];

  Future<void> delay(Duration duration) async {
    delays.add(duration);
    now = now.add(duration);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsRepository settings;
  late MetadataProviderLifecycle lifecycle;
  late _FakeTime time;
  late MetadataProviderOperationCoordinator coordinator;

  Future<void> enable(Iterable<String> ids) =>
      settings.saveMetadataProviders(MetadataProvidersSettings(
        externalMetadataEnabled: true,
        enabledProviderIds: ids.toSet(),
      ));

  Future<_Outcome> execute(
    String providerId,
    Future<_Outcome> Function() operation,
  ) =>
      coordinator.execute(
        providerId: providerId,
        operation: operation,
        failureOf: (outcome) => outcome.failure,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository();
    await settings.initialize();
    lifecycle = MetadataProviderLifecycle(settingsRepository: settings);
    time = _FakeTime();
    coordinator = MetadataProviderOperationCoordinator(
      lifecycle: lifecycle,
      clock: () => time.now,
      delay: time.delay,
    );
  });

  tearDown(() {
    coordinator.dispose();
    lifecycle.dispose();
  });

  test('enforces one active operation per provider', () async {
    await enable(['open_library']);
    final first = Completer<_Outcome>();
    var starts = 0;
    final a = execute('open_library', () {
      starts++;
      return first.future;
    });
    final b = execute('open_library', () async {
      starts++;
      return const _Outcome.success();
    });
    await Future<void>.delayed(Duration.zero);

    expect(starts, 1);
    expect(coordinator.inFlightOperationCount, 1);
    expect(coordinator.pendingOperationCount, 1);
    first.complete(const _Outcome.success());
    await Future.wait([a, b]);
    expect(starts, 2);
  });

  test('enforces global concurrency of two across providers', () async {
    await enable(['one', 'two', 'three']);
    final gates = List.generate(3, (_) => Completer<_Outcome>());
    var starts = 0;
    final futures = <Future<_Outcome>>[];
    for (var i = 0; i < 3; i++) {
      futures.add(execute(['one', 'two', 'three'][i], () {
        starts++;
        return gates[i].future;
      }));
    }
    await Future<void>.delayed(Duration.zero);
    expect(starts, 2);
    expect(coordinator.inFlightOperationCount, 2);
    expect(coordinator.pendingOperationCount, 1);

    gates[0].complete(const _Outcome.success());
    await Future<void>.delayed(Duration.zero);
    expect(starts, 3);
    gates[1].complete(const _Outcome.success());
    gates[2].complete(const _Outcome.success());
    await Future.wait(futures);
  });

  test('rejects the thirty-third pending operation', () async {
    await enable(['open_library']);
    final gate = Completer<_Outcome>();
    final active = execute('open_library', () => gate.future);
    final pending = List.generate(
      32,
      (_) => execute('open_library', () async => const _Outcome.success()),
    );
    final overflow = execute(
      'open_library',
      () async => const _Outcome.success(),
    );
    await expectLater(
      overflow,
      throwsA(isA<MetadataProviderOperationRejected>()),
    );
    expect(coordinator.pendingOperationCount, 32);
    gate.complete(const _Outcome.success());
    await Future.wait([active, ...pending]);
  });

  test('retries transient failures twice with two and four second delays',
      () async {
    await enable(['open_library']);
    var calls = 0;
    final result = await execute('open_library', () async {
      calls++;
      return calls < 3
          ? _Outcome.failure(BookMetadataProviderFailureCategory.timeout)
          : const _Outcome.success();
    });
    expect(result.failure, isNull);
    expect(calls, 3);
    expect(
        time.delays, [const Duration(seconds: 2), const Duration(seconds: 4)]);
  });

  test('retries network and provider-unavailable failures only twice',
      () async {
    await enable(['network_provider', 'unavailable_provider']);
    for (final entry in {
      'network_provider':
          BookMetadataProviderFailureCategory.networkUnavailable,
      'unavailable_provider':
          BookMetadataProviderFailureCategory.providerUnavailable,
    }.entries) {
      time.delays.clear();
      var calls = 0;
      final result = await execute(entry.key, () async {
        calls++;
        return _Outcome.failure(entry.value);
      });
      expect(result.failure?.category, entry.value);
      expect(calls, 3);
      expect(
        time.delays,
        [const Duration(seconds: 2), const Duration(seconds: 4)],
      );
    }
  });

  test('spaces requests to the same provider by at least one second', () async {
    await enable(['open_library']);
    await execute(
      'open_library',
      () async => const _Outcome.success(),
    );
    await execute(
      'open_library',
      () async => const _Outcome.success(),
    );
    expect(time.delays, [const Duration(seconds: 1)]);
  });

  test('honors bounded Retry-After and rejects values over five minutes',
      () async {
    await enable(['open_library']);
    var calls = 0;
    await execute('open_library', () async {
      calls++;
      return calls == 1
          ? _Outcome.failure(
              BookMetadataProviderFailureCategory.rateLimited,
              retryAfter: const Duration(minutes: 3),
            )
          : const _Outcome.success();
    });
    expect(calls, 2);
    expect(time.delays, [const Duration(minutes: 3)]);

    time.delays.clear();
    calls = 0;
    final result = await execute('open_library', () async {
      calls++;
      return _Outcome.failure(
        BookMetadataProviderFailureCategory.rateLimited,
        retryAfter: const Duration(minutes: 6),
      );
    });
    expect(result.failure?.category,
        BookMetadataProviderFailureCategory.rateLimited);
    expect(calls, 1);
    expect(time.delays, [const Duration(seconds: 1)]);
  });

  test('does not retry permanent or unknown failures', () async {
    await enable(['open_library']);
    for (final category in [
      BookMetadataProviderFailureCategory.authentication,
      BookMetadataProviderFailureCategory.authorization,
      BookMetadataProviderFailureCategory.malformedResponse,
      BookMetadataProviderFailureCategory.cancelled,
      BookMetadataProviderFailureCategory.unknown,
    ]) {
      var calls = 0;
      final result = await execute('open_library', () async {
        calls++;
        return _Outcome.failure(category);
      });
      expect(result.failure?.category, category);
      expect(calls, 1);
    }
  });

  test('provider disable cancels queued work and blocks late completion',
      () async {
    await enable(['open_library']);
    final gate = Completer<_Outcome>();
    final active = execute('open_library', () => gate.future);
    final queued = execute(
      'open_library',
      () async => const _Outcome.success(),
    );
    final queuedExpectation = expectLater(
      queued,
      throwsA(isA<MetadataProviderOperationRejected>()),
    );
    await Future<void>.delayed(Duration.zero);
    await settings.saveMetadataProviders(const MetadataProvidersSettings());
    await queuedExpectation;
    gate.complete(const _Outcome.success());
    await expectLater(
      active,
      throwsA(isA<MetadataProviderOperationRejected>()),
    );
    expect(coordinator.pendingOperationCount, 0);
    expect(coordinator.inFlightOperationCount, 0);
  });

  test('caller cancellation removes queued work before provider request',
      () async {
    await enable(['open_library']);
    final gate = Completer<_Outcome>();
    final active = execute('open_library', () => gate.future);
    var queuedStarts = 0;
    var cancelled = false;
    final signal = Completer<void>();
    final queued = coordinator.execute<_Outcome>(
      providerId: 'open_library',
      operation: () async {
        queuedStarts++;
        return const _Outcome.success();
      },
      failureOf: (outcome) => outcome.failure,
      isCancelled: () => cancelled,
      cancellationSignal: signal.future,
    );
    final expectation = expectLater(
      queued,
      throwsA(isA<MetadataProviderOperationRejected>()),
    );
    cancelled = true;
    signal.complete();
    await expectation;
    expect(queuedStarts, 0);
    gate.complete(const _Outcome.success());
    await active;
  });

  test('caller cancellation interrupts backoff before a retry starts',
      () async {
    await enable(['open_library']);
    final delayStarted = Completer<void>();
    final delayGate = Completer<void>();
    final delayed = MetadataProviderOperationCoordinator(
      lifecycle: lifecycle,
      clock: () => time.now,
      delay: (duration) {
        if (!delayStarted.isCompleted) delayStarted.complete();
        return delayGate.future;
      },
    );
    addTearDown(delayed.dispose);
    var calls = 0;
    var cancelled = false;
    final signal = Completer<void>();
    final operation = delayed.execute<_Outcome>(
      providerId: 'open_library',
      operation: () async {
        calls++;
        return _Outcome.failure(BookMetadataProviderFailureCategory.timeout);
      },
      failureOf: (outcome) => outcome.failure,
      isCancelled: () => cancelled,
      cancellationSignal: signal.future,
    );
    final expectation = expectLater(
      operation,
      throwsA(isA<MetadataProviderOperationRejected>()),
    );
    await delayStarted.future;
    cancelled = true;
    signal.complete();
    await expectation;
    expect(calls, 1);
    expect(delayed.pendingOperationCount, 0);
    expect(delayed.inFlightOperationCount, 0);
  });

  test('operation queue is process-local and is not restored', () async {
    await enable(['open_library']);
    final fresh = MetadataProviderOperationCoordinator(lifecycle: lifecycle);
    addTearDown(fresh.dispose);
    expect(fresh.pendingOperationCount, 0);
    expect(fresh.inFlightOperationCount, 0);
    expect(fresh.lastSuccessfulRefreshAt, isNull);
  });

  test('tracks only bounded telemetry in memory', () async {
    await enable(['open_library']);
    await execute(
      'open_library',
      () async => _Outcome.failure(
        BookMetadataProviderFailureCategory.networkUnavailable,
      ),
    );
    expect(coordinator.lastSafeErrorCategory,
        BookMetadataProviderFailureCategory.networkUnavailable);
    expect(coordinator.lastSuccessfulRefreshAt, isNull);
    coordinator.recordSuccessfulRefresh();
    expect(coordinator.lastSuccessfulRefreshAt, time.now);
  });

  test('records successful refresh only after accepted persistence', () async {
    await enable(['open_library']);
    final repository = await initializedMetadataEnrichmentRepository();
    final provider = FakeBookMetadataProvider(
      providerId: 'open_library',
      lookupResult: BookMetadataLookupSuccess(
        FakeBookMetadataProvider.sampleMetadata(),
      ),
    );
    final service = BookMetadataRefreshService(
      provider: provider,
      repository: repository,
      providerLifecycle: lifecycle,
      operationCoordinator: coordinator,
    );

    expect(coordinator.lastSuccessfulRefreshAt, isNull);
    final result = await service.refreshByIsbn(
      item: bookItem(),
      isbnInput: '9780140449136',
    );
    expect(result, isA<BookMetadataRefreshSuccess>());
    expect(repository.getByItemId('book-1'), isNotNull);
    expect(coordinator.lastSuccessfulRefreshAt, time.now);
  });
}
