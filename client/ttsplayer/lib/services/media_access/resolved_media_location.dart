import 'media_access_provider.dart';

/// Result of resolving a catalogue filesystem path to a playable URI.
class ResolvedMediaLocation {
  final String? uri;
  final MediaAccessProviderType providerType;
  final MediaLocationResolveStatus status;
  final String? errorReason;

  const ResolvedMediaLocation({
    this.uri,
    required this.providerType,
    required this.status,
    this.errorReason,
  });

  const ResolvedMediaLocation.resolved({
    required String uri,
    required MediaAccessProviderType providerType,
  }) : this(
          uri: uri,
          providerType: providerType,
          status: MediaLocationResolveStatus.resolved,
        );

  const ResolvedMediaLocation.unresolved({
    required MediaAccessProviderType providerType,
    required String errorReason,
  }) : this(
          providerType: providerType,
          status: MediaLocationResolveStatus.unresolved,
          errorReason: errorReason,
        );

  bool get isPlayable => status.isPlayable && uri != null && uri!.isNotEmpty;
}
