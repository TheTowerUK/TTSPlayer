import 'package:flutter/foundation.dart';

import '../../../models/application_settings.dart';
import '../../../services/settings/settings_repository.dart';

class MetadataProviderOperationToken {
  const MetadataProviderOperationToken({
    required this.providerId,
    required this.generation,
  });

  final String providerId;
  final int generation;
}

/// Production opt-in boundary for all external metadata operations (M7.7.2).
class MetadataProviderLifecycle extends ChangeNotifier {
  static const openLibraryProviderId = 'open_library';

  MetadataProviderLifecycle({required SettingsRepository settingsRepository})
      : _settingsRepository = settingsRepository,
        _lastSettings = settingsRepository.metadataProviders {
    _settingsRepository.addListener(_onSettingsChanged);
  }

  final SettingsRepository _settingsRepository;
  var _generation = 0;
  MetadataProvidersSettings _lastSettings;

  bool isProviderOperational(String providerId) =>
      _settingsRepository.metadataProviders.isProviderOperational(providerId);

  MetadataProviderOperationToken? beginOperation(String providerId) {
    if (!isProviderOperational(providerId)) return null;
    return MetadataProviderOperationToken(
      providerId: providerId,
      generation: _generation,
    );
  }

  bool isCurrent(MetadataProviderOperationToken token) =>
      token.generation == _generation &&
      isProviderOperational(token.providerId);

  void _onSettingsChanged() {
    final next = _settingsRepository.metadataProviders;
    if (_sameSettings(_lastSettings, next)) return;
    _lastSettings = next;
    _generation++;
    notifyListeners();
  }

  static bool _sameSettings(
    MetadataProvidersSettings a,
    MetadataProvidersSettings b,
  ) =>
      a.externalMetadataEnabled == b.externalMetadataEnabled &&
      setEquals(a.enabledProviderIds, b.enabledProviderIds) &&
      a.metadataRetentionOnDisable == b.metadataRetentionOnDisable &&
      a.artworkRetentionOnDisable == b.artworkRetentionOnDisable;

  @override
  void dispose() {
    _settingsRepository.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
