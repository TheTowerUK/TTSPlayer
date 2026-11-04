import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_repository.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/book_search_request.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_failure.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/coordinated_book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/open_library/open_library_book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/open_library/open_library_config.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_refresh_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_provider_lifecycle.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_provider_operation_coordinator.dart';
import 'package:ttsplayer/features/metadata_enrichment/transport/http_metadata_http_transport.dart';
import 'package:ttsplayer/features/metadata_enrichment/transport/metadata_http_transport.dart';
import 'package:ttsplayer/models/application_settings.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';

import 'book_metadata_refresh_service_test.dart' show bookItem;
import 'support/diagnostics_test_harness.dart';

// A real HTTP transport is required; ordinary widget tests override HttpClient.
class _Phase78Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _Phase78Binding();
  if (Platform.environment['PHASE_78_RUNTIME'] != '1' || !Platform.isWindows) {
    test('Phase 7.8 requires Windows and PHASE_78_RUNTIME=1', () {},
        skip: true);
    return;
  }

  late HttpServer server;
  late IOClient client;
  late SettingsRepository settings;
  late MetadataEnrichmentRepository records;
  late MetadataProviderLifecycle lifecycle;
  late MetadataProviderOperationCoordinator operations;
  late CoordinatedBookMetadataProvider provider;
  late Future<void> Function(HttpRequest, int) respond;
  late List<Uri> requests;
  late List<Duration> delays;
  late Future<void> Function(Duration) delay;
  late DateTime now;

  Future<void> enable(bool value) => settings.saveMetadataProviders(
        MetadataProvidersSettings(
          externalMetadataEnabled: value,
          enabledProviderIds: const {'open_library'},
        ),
      );

  Future<BookMetadataSearchResult> search({MetadataCancellationToken? token}) =>
      provider.search(
        BookSearchRequest.create(
            title: 'P78_PRIVATE_TITLE', author: 'P78_AUTHOR'),
        options: BookMetadataRequestOptions(cancellationToken: token),
      );

  Future<void> success(HttpRequest request, int count) async {
    request.response.headers.contentType = ContentType.json;
    if (request.uri.path == '/api/books') {
      request.response.write(jsonEncode({
        'ISBN:9780140449136': {
          'key': '/books/OL78M',
          'title': 'P78_PRIVATE_TITLE',
          'authors': [
            {'name': 'P78_AUTHOR'}
          ],
          'identifiers': {
            'isbn_13': ['9780140449136']
          },
        },
      }));
    } else {
      request.response.write('{"numFound":0,"docs":[]}');
    }
    await request.response.close();
  }

  Future<void> settleUntil(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('Runtime condition timed out');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  void expectFailure(BookMetadataSearchResult result,
      BookMetadataProviderFailureCategory category) {
    expect(result, isA<BookMetadataSearchFailure>());
    expect((result as BookMetadataSearchFailure).failure.category, category);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository();
    await settings.initialize();
    records = MetadataEnrichmentRepository();
    await records.initialize();
    lifecycle = MetadataProviderLifecycle(settingsRepository: settings);
    now = DateTime.utc(2026, 11, 3);
    requests = [];
    delays = [];
    delay = (duration) async {
      now = now.add(duration);
    };
    operations = MetadataProviderOperationCoordinator(
      lifecycle: lifecycle,
      clock: () => now,
      minimumProviderSpacing: Duration.zero,
      delay: (duration) {
        delays.add(duration);
        return delay(duration);
      },
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    respond = success;
    server.listen((request) async {
      requests.add(request.uri);
      try {
        await respond(request, requests.length);
      } catch (_) {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      }
    });
    client = IOClient(HttpClient());
    provider = CoordinatedBookMetadataProvider(
      delegate: OpenLibraryBookMetadataProvider(
        transport: HttpMetadataHttpTransport(client: client),
        config: OpenLibraryConfig(
          userAgent: 'TTSPlayer-Phase78-Local-Test',
          baseUrl: 'http://127.0.0.1:${server.port}',
          defaultTimeout: const Duration(seconds: 3),
        ),
      ),
      coordinator: operations,
    );
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
    operations.dispose();
    lifecycle.dispose();
  });

  test('P78-01 disabled and enable-only paths send no HTTP', () async {
    expectFailure(
        await search(), BookMetadataProviderFailureCategory.cancelled);
    expect(requests, isEmpty);
    await enable(true);
    expect(requests, isEmpty);
    expect(await search(), isA<BookMetadataSearchSuccess>());
    expect(requests, hasLength(1));
    expect(requests.single.path, '/search.json');
    expect(requests.single.queryParameters['title'], 'P78_PRIVATE_TITLE');
  });

  test('P78-02 HTTP 500 retries through production transport with 2s/4s policy',
      () async {
    await enable(true);
    respond = (request, count) async {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    };
    expectFailure(await search(),
        BookMetadataProviderFailureCategory.providerUnavailable);
    expect(requests, hasLength(3));
    expect(delays, [const Duration(seconds: 2), const Duration(seconds: 4)]);
  });

  test('P78-03 HTTP 429 honors Retry-After before successful retry', () async {
    await enable(true);
    respond = (request, count) async {
      if (count == 1) {
        request.response.statusCode = HttpStatus.tooManyRequests;
        request.response.headers.set('retry-after', '3');
        await request.response.close();
      } else {
        await success(request, count);
      }
    };
    expect(await search(), isA<BookMetadataSearchSuccess>());
    expect(requests, hasLength(2));
    expect(delays, [const Duration(seconds: 3)]);
  });

  test('P78-04 malformed JSON and HTTP 403 do not retry', () async {
    await enable(true);
    respond = (request, count) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write('{broken');
      await request.response.close();
    };
    expectFailure(
        await search(), BookMetadataProviderFailureCategory.malformedResponse);
    expect(requests, hasLength(1));
    respond = (request, count) async {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
    };
    expectFailure(
        await search(), BookMetadataProviderFailureCategory.authorization);
    expect(requests, hasLength(2));
    expect(delays, isEmpty);
  });

  test('P78-05 queued cancellation sends no second HTTP request', () async {
    await enable(true);
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    respond = (request, count) async {
      await release.future;
      await success(request, count);
    };
    final active = search();
    await settleUntil(() => requests.length == 1);
    final token = MetadataCancellationToken();
    final queued = search(token: token);
    expect(operations.pendingOperationCount, 1);
    token.cancel();
    expectFailure(await queued, BookMetadataProviderFailureCategory.cancelled);
    release.complete();
    expect(await active, isA<BookMetadataSearchSuccess>());
    expect(requests, hasLength(1));
  });

  test('P78-06 disable rejects queued and delayed in-flight results', () async {
    await enable(true);
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    respond = (request, count) async {
      await release.future;
      await success(request, count);
    };
    final service = BookMetadataRefreshService(
      provider: provider,
      repository: records,
      providerLifecycle: lifecycle,
      operationCoordinator: operations,
    );
    final active =
        service.refreshByIsbn(item: bookItem(), isbnInput: '9780140449136');
    await settleUntil(() => requests.length == 1);
    final queued = search();
    await enable(false);
    expectFailure(await queued, BookMetadataProviderFailureCategory.cancelled);
    release.complete();
    expect(await active, isNot(isA<BookMetadataRefreshSuccess>()));
    expect(records.storedRecordCount, 0);
    expect(operations.lastSuccessfulRefreshAt, isNull);
    expect(requests, hasLength(1));
  });

  test('P78-07 cancellation interrupts retry backoff', () async {
    await enable(true);
    final entered = Completer<void>();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    delay = (duration) {
      if (!entered.isCompleted) entered.complete();
      return release.future;
    };
    respond = (request, count) async {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    };
    final token = MetadataCancellationToken();
    final result = search(token: token);
    await entered.future.timeout(const Duration(seconds: 5));
    token.cancel();
    expectFailure(await result, BookMetadataProviderFailureCategory.cancelled);
    expect(requests, hasLength(1));
  });

  test('P78-08 persisted ISBN record survives disable and repository reload',
      () async {
    await enable(true);
    final service = BookMetadataRefreshService(
      provider: provider,
      repository: records,
      providerLifecycle: lifecycle,
      operationCoordinator: operations,
    );
    expect(
        await service.refreshByIsbn(
            item: bookItem(), isbnInput: '9780140449136'),
        isA<BookMetadataRefreshSuccess>());
    expect(operations.lastSuccessfulRefreshAt, isNotNull);
    await enable(false);
    final reloaded = MetadataEnrichmentRepository();
    await reloaded.initialize();
    expect(reloaded.getByItemId('book-1'), isNotNull);
    final fresh = MetadataProviderOperationCoordinator(lifecycle: lifecycle);
    addTearDown(fresh.dispose);
    expect(fresh.pendingOperationCount, 0);
    expect(fresh.inFlightOperationCount, 0);
    expect(fresh.lastSuccessfulRefreshAt, isNull);
    expect(requests, hasLength(1));
  });

  test('P78-09 live HTTP operation counters and diagnostic export redaction',
      () async {
    await enable(true);
    final cacheRoot =
        await Directory.systemTemp.createTemp('ttsplayer_phase78_cache_');
    addTearDown(() async {
      if (await cacheRoot.exists()) await cacheRoot.delete(recursive: true);
    });
    final artwork =
        MetadataArtworkCacheRepository(cacheRootOverride: cacheRoot);
    await artwork.initialize();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    respond = (request, count) async {
      await release.future;
      await success(request, count);
    };
    final active = search();
    await settleUntil(() => requests.length == 1);
    final token = MetadataCancellationToken();
    final queued = search(token: token);
    final diagnostics = await buildDiagnosticsHarness(
      settingsRepository: settings,
      metadataEnrichmentRepository: records,
      metadataArtworkCacheRepository: artwork,
      metadataProviderOperationCoordinator: operations,
    );
    final snapshot = await diagnostics.captureSnapshot();
    expect(snapshot.metadataEnrichment, isNotNull,
        reason:
            'Metadata diagnostics require settings, enrichment and artwork repositories.');
    expect(snapshot.metadataEnrichment!.pendingOperationCount, 1);
    expect(snapshot.metadataEnrichment!.inFlightOperationCount, 1);
    final export = diagnostics.formatExport(snapshot);
    expect(export, contains('=== Metadata Enrichment ==='));
    for (final secret in [
      'P78_PRIVATE_TITLE',
      'P78_AUTHOR',
      '9780140449136',
      '127.0.0.1:${server.port}',
      '/search.json'
    ]) {
      expect(export, isNot(contains(secret)));
    }
    expect(requests, hasLength(1)); // capture/export initiates no HTTP
    token.cancel();
    expectFailure(await queued, BookMetadataProviderFailureCategory.cancelled);
    release.complete();
    expect(await active, isA<BookMetadataSearchSuccess>());
  });
}
