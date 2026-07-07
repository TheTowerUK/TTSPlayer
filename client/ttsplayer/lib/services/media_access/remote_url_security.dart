import 'media_access_config.dart';

/// Production rules for remote catalogue and media base URLs (Phase 4.5).
///
/// - **HTTPS** remote URLs are preferred and always accepted when syntactically valid.
/// - **Plain HTTP** is allowed only in [MediaAccessMode.localPreferred] (LAN /
///   development) and surfaces a non-blocking warning on save.
/// - **Plain HTTP** is **rejected** when [MediaAccessMode.httpRequired] is selected
///   because the app is configured for remote-only access.
/// - Local file paths and default behaviour are unchanged.
class RemoteUrlSecurity {
  RemoteUrlSecurity._();

  static const insecureHttpWarning =
      'Plain http:// is not recommended for production. Prefer https:// for remote URLs.';

  static const httpRequiredRejection =
      'Use https:// for remote URLs when HTTP required mode is selected.';

  /// Validation errors (blocking) and warnings (non-blocking) for a remote URL.
  static RemoteUrlValidationResult validateRemoteUrl(
    String url, {
    required String fieldPrefix,
    required MediaAccessMode mode,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return RemoteUrlValidationResult(errors: errors, warnings: warnings);
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      errors.add('$fieldPrefix: URL must use http or https.');
      return RemoteUrlValidationResult(errors: errors, warnings: warnings);
    }

    switch (uri.scheme) {
      case 'https':
        break;
      case 'http':
        if (mode == MediaAccessMode.httpRequired) {
          errors.add('$fieldPrefix: $httpRequiredRejection');
        } else {
          warnings.add('$fieldPrefix: $insecureHttpWarning');
        }
      default:
        errors.add('$fieldPrefix: URL must use http or https.');
    }

    return RemoteUrlValidationResult(errors: errors, warnings: warnings);
  }

  static bool isHttpsUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null && uri.scheme == 'https';
  }

  static bool isPlainHttpUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null && uri.scheme == 'http';
  }
}

class RemoteUrlValidationResult {
  final List<String> errors;
  final List<String> warnings;

  const RemoteUrlValidationResult({
    required this.errors,
    required this.warnings,
  });

  bool get isValid => errors.isEmpty;
}
