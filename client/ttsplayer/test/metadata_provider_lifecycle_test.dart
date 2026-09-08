import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/isbn_lookup_request.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/fake_book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_refresh_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_provider_lifecycle.dart';
import 'package:ttsplayer/models/application_settings.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';

import 'book_metadata_refresh_service_test.dart' show bookItem;
import 'support/metadata_enrichment_test_support.dart';

class _DelayedProvider extends FakeBookMetadataProvider {
  _DelayedProvider() : super(providerId: 'open_library');

  final lookupCompleter = Completer<BookMetadataLookupResult>();

  @override
  Future<BookMetadataLookupResult> lookupByIsbn(
    IsbnLookupRequest request, {
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  }) {
    lookupInvocationCount++;
    lastLookupRequest = request;
    return lookupCompleter.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsRepository settingsRepository;
  late MetadataProviderLifecycle lifecycle;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settingsRepository = SettingsRepository();
    await settingsRepository.initialize();
    lifecycle = MetadataProviderLifecycle(
      settingsRepository: settingsRepository,
    );
  });

  tearDown(() => lifecycle.dispose());

  test('external providers are disabled by default', () {
    expect(settingsRepository.metadataProviders.externalMetadataEnabled, false);
    expect(settingsRepository.metadataProviders.enabledProviderIds, isEmpty);
    expect(lifecycle.isProviderOperational('open_library'), false);
  });

  test('provider requires both master opt-in and provider enablement',
      () async {
    await settingsRepository.saveMetadataProviders(
      const MetadataProvidersSettings(
        enabledProviderIds: {'open_library'},
      ),
    );
    expect(lifecycle.isProviderOperational('open_library'), false);

    await settingsRepository.saveMetadataProviders(
      const MetadataProvidersSettings(externalMetadataEnabled: true),
    );
    expect(lifecycle.isProviderOperational('open_library'), false);

    await settingsRepository.saveMetadataProviders(
      const MetadataProvidersSettings(
        externalMetadataEnabled: true,
        enabledProviderIds: {'open_library'},
      ),
    );
    expect(lifecycle.isProviderOperational('open_library'), true);
  });

  test('settings changes cause no provider request or deletion', () async {
    final provider = FakeBookMetadataProvider(providerId: 'open_library');
    final repository = await initializedMetadataEnrichmentRepository();
    await repository.upsert(
      const MetadataEnrichmentRecord(
        itemId: 'retained-book',
        matchState: EnrichmentMatchState.unmatched,
      ),
    );

    await settingsRepository.saveMetadataProviders(
      const MetadataProvidersSettings(
        externalMetadataEnabled: true,
        enabledProviderIds: {'open_library'},
      ),
    );
    await settingsRepository.saveMetadataProviders(
      const MetadataProvidersSettings(
        enabledProviderIds: {'open_library'},
      ),
    );

    expect(provider.lookupInvocationCount, 0);
    expect(provider.searchInvocationCount, 0);
    expect(repository.getByItemId('retained-book'), isNotNull);
  });

  test('disabled provider blocks explicit refresh before request', () async {
    final provider = FakeBookMetadataProvider(providerId: 'open_library');
    final repository = await initializedMetadataEnrichmentRepository();
    final service = BookMetadataRefreshService(
      provider: provider,
      repository: repository,
      providerLifecycle: lifecycle,
    );

    await service.refreshByIsbn(
      item: bookItem(),
      isbnInput: '9780140449136',
    );

    expect(provider.lookupInvocationCount, 0);
    expect(repository.storedRecordCount, 0);
  });

  test('in-flight completion after disable cannot persist', () async {
    await settingsRepository.saveMetadataProviders(
      const MetadataProvidersSettings(
        externalMetadataEnabled: true,
        enabledProviderIds: {'open_library'},
      ),
    );
    final provider = _DelayedProvider();
    final repository = await initializedMetadataEnrichmentRepository();
    final service = BookMetadataRefreshService(
      provider: provider,
      repository: repository,
      providerLifecycle: lifecycle,
    );

    final operation = service.refreshByIsbn(
      item: bookItem(),
      isbnInput: '9780140449136',
    );
    await Future<void>.delayed(Duration.zero);
    expect(provider.lookupInvocationCount, 1);

    await settingsRepository.saveMetadataProviders(
      const MetadataProvidersSettings(
        enabledProviderIds: {'open_library'},
      ),
    );
    provider.lookupCompleter.complete(
      BookMetadataLookupSuccess(FakeBookMetadataProvider.sampleMetadata()),
    );
    await operation;

    expect(repository.storedRecordCount, 0);
  });
}
