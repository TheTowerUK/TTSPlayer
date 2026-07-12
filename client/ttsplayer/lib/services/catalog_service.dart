import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/application_settings.dart';
import '../models/catalog.dart';
import '../models/catalogue_provider_snapshot.dart';
import '../models/catalogue_source_kind.dart';
import '../models/catalogue_validation_result.dart';
import 'media_access/catalogue_provider_selector.dart';
import 'media_access/media_catalogue_provider.dart';
import 'media_access/media_provider_config.dart';
import 'media_access/remote_fetch_errors.dart';
import 'settings/settings_repository.dart';

/// Source from which the catalog is loaded.
enum CatalogSource { bundled, localFile, remoteUrl }

class CatalogService extends ChangeNotifier {
  CatalogService({
    http.Client? httpClient,
    SettingsRepository? settingsRepository,
    Duration? catalogFetchTimeout,
    VoidCallback? onCatalogReplaced,
  })  : _httpClient = httpClient ?? http.Client(),
        _settingsRepository = settingsRepository,
        _catalogFetchTimeoutOverride = catalogFetchTimeout,
        _onCatalogReplaced = onCatalogReplaced;

  final http.Client _httpClient;
  final SettingsRepository? _settingsRepository;

  /// Test-only override; production uses [SettingsRepository.networkSettings].
  final Duration? _catalogFetchTimeoutOverride;
  final VoidCallback? _onCatalogReplaced;

  /// Default bounded timeout when no [SettingsRepository] is attached.
  static Duration get catalogFetchTimeoutDefault => const Duration(
        seconds: NetworkSettings.defaultCatalogueFetchTimeoutSeconds,
      );

  /// Resolved timeout for HTTP catalogue fetches (reads repository each call).
  @visibleForTesting
  Duration get catalogFetchTimeout => _resolveCatalogFetchTimeout();

  Duration _resolveCatalogFetchTimeout() {
    final override = _catalogFetchTimeoutOverride;
    if (override != null) {
      return override;
    }
    final seconds =
        _settingsRepository?.networkSettings.catalogueFetchTimeoutSeconds ??
            NetworkSettings.defaultCatalogueFetchTimeoutSeconds;
    return Duration(seconds: seconds);
  }

  Catalog? _catalog;
  bool _isLoading = false;
  String? _errorMessage;
  String? _catalogPath;
  DateTime? _lastRefreshedAt;

  /// True when the bundled demo asset is active because **all** configured
  /// providers failed on startup (not when a later provider succeeds after an
  /// earlier failure — that is [isDegradedLoad]). Drives the demo fallback banner.
  bool _isUsingFallback = false;

  /// User-facing message when [isUsingFallback] is true.
  String get fallbackBannerMessage {
    if (activeProviderConfig.httpCatalogueUrl != null) {
      return 'Demo catalogue in use — configured remote catalogue could not be loaded.';
    }
    return 'Demo catalogue in use — live NAS catalogue not reachable '
        '(${liveCataloguePaths.join(' or ')}).';
  }

  Catalog? get catalog => _catalog;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get catalogPath => _catalogPath;
  DateTime? get lastRefreshedAt => _lastRefreshedAt;
  bool get isUsingFallback => _isUsingFallback;

  /// Session-scoped provider load snapshot (ADR-001). Not persisted.
  CatalogueProviderSnapshot get providerSnapshot =>
      _providerSnapshot ??
      CatalogueProviderSnapshot.initial(config: activeProviderConfig);

  /// Provider that supplied the current catalogue, if known.
  MediaCatalogueProviderDefinition? get activeCatalogueProvider =>
      _activeCatalogueProvider ?? providerSnapshot.activeProvider;

  /// When the active catalogue was last successfully replaced.
  DateTime? get lastCatalogueLoadAt => _lastCatalogueLoadAt;

  /// When the most recent provider-chain load cycle started.
  DateTime? get lastLoadStartedAt => _lastLoadStartedAt;

  /// True when the active provider loaded after earlier failures (localPreferred).
  bool get isDegradedLoad => providerSnapshot.isDegradedLoad;

  /// True when the bundled demo asset is active (auto-fallback or user-selected).
  bool get isDemoCatalogue =>
      _isUsingFallback || _catalogPath == 'bundled';

  /// True when a live NAS catalogue file is loaded (drive letter or UNC).
  bool get isLiveNasCatalogue =>
      _catalog != null && !isDemoCatalogue;

  /// Short label for dashboard/debug UI.
  String get catalogueSourceLabel => catalogueSourceKind.label;

  /// Three-way source classification for Storage Status and Library Manager.
  CatalogueSourceKind get catalogueSourceKind =>
      classifyCataloguePath(
        catalogPath: _catalogPath,
        isDemoFallback: isDemoCatalogue,
      );

  /// Classifies a loaded catalogue path for UI labelling.
  static CatalogueSourceKind classifyCataloguePath({
    required String? catalogPath,
    required bool isDemoFallback,
  }) {
    if (isDemoFallback ||
        catalogPath == null ||
        catalogPath == 'bundled') {
      return CatalogueSourceKind.demo;
    }
    final path = _normalizeCataloguePath(catalogPath);
    if (path == _normalizeCataloguePath(liveCataloguePaths[1])) {
      return CatalogueSourceKind.fallbackNas;
    }
    return CatalogueSourceKind.liveNas;
  }

  static String _normalizeCataloguePath(String? path) =>
      (path ?? '').replaceAll('/', '\\').toLowerCase();

  static const _prefKeyPath = 'catalog_path';
  static const _prefKeySource = 'catalog_source';
  static const _prefKeyDismissedWarningsCatalogueId =
      'scan_warnings_dismissed_catalogue_id';

  /// Same config file the Python indexer reads for [cataloguePath].
  static const scannerConfigPath = r'D:\AppDev\TTSPlayer\ttsplayer.config.json';

  /// Default live catalogue paths when config is missing or the configured
  /// file is absent. Primary: mapped drive; secondary: UNC fallback.
  static const liveCataloguePaths = [
    r'Y:\Media\catalog.json',
    r'\\MEDIATNAS-B725\Media\catalog.json',
  ];

  /// Paths that must never be used — e.g. retired dev/test locations.
  static const _blockedCataloguePaths = {
    r'd:\temp\catalog.json',
  };

  /// Persisted provider config used for [loadOnStartup] and [rescan].
  MediaProviderConfig? _activeProviderConfig;

  /// When false, skips scanner-config and last-good pref paths (tests only).
  @visibleForTesting
  bool includeLegacyCataloguePaths = true;

  /// When false, skips [scannerConfigPath] catalogue path during startup
  /// (tests only). [includeLegacyCataloguePaths] must still be true.
  @visibleForTesting
  bool includeScannerConfigCataloguePath = true;

  /// Active provider config, or [MediaProviderConfig.defaults] when unset.
  MediaProviderConfig get activeProviderConfig =>
      _activeProviderConfig ?? MediaProviderConfig.defaults();

  /// Updates provider config for subsequent [rescan] calls without reloading.
  void setProviderConfig(MediaProviderConfig config) {
    _activeProviderConfig = config;
  }
  /// Persisted in shared_preferences — does not modify catalog.json.
  String? _dismissedWarningsCatalogueId;
  bool _dismissedStateLoaded = false;

  CatalogueProviderSnapshot? _providerSnapshot;
  CatalogueProviderLoadTracker? _loadTracker;
  MediaCatalogueProviderDefinition? _activeCatalogueProvider;
  DateTime? _sessionStartedAt;
  DateTime? _lastLoadStartedAt;
  DateTime? _lastCatalogueLoadAt;

  /// True when the loaded catalogue has scan warnings the user has not
  /// dismissed for this catalogue revision.
  bool get shouldShowScanWarnings {
    final catalog = _catalog;
    if (catalog == null || !catalog.hasScanWarnings) return false;
    return _dismissedWarningsCatalogueId != catalog.catalogueIdentity;
  }

  // ---------------------------------------------------------------------------
  // Startup
  // ---------------------------------------------------------------------------

  /// Called once on app launch.
  ///
  /// Tries configured catalogue providers in priority order ([providerConfig]
  /// or [MediaProviderConfig.defaults]). Falls back to the bundled asset when
  /// none succeed, with [isUsingFallback] set so the UI can show a demo banner.
  Future<void> loadOnStartup({MediaProviderConfig? providerConfig}) async {
    if (providerConfig != null) {
      _activeProviderConfig = providerConfig;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _loadDismissedState();

    final attempt =
        await _tryProviderCatalogue(activeProviderConfig);

    if (attempt.didSucceed) {
      _isUsingFallback = false;
      _errorMessage = null;
    } else {
      // All configured providers failed — fall back to bundled and surface why.
      _isUsingFallback = true;
      if (attempt.lastError != null) {
        _errorMessage = attempt.lastError;
      }
      try {
        final raw = await rootBundle.loadString('assets/catalog.json');
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _catalog = Catalog.fromJson(json);
        _catalogPath = 'bundled';
        _notifyCatalogReplaced();
        _activeCatalogueProvider = null;
        _finalizeProviderSnapshot(
          chainSucceeded: false,
          demoFallback: true,
          demoWithoutProvider: true,
        );
      } catch (e) {
        _errorMessage = 'Could not load any catalogue: $e';
        _finalizeProviderSnapshot(
          chainSucceeded: false,
          demoFallback: false,
          demoWithoutProvider: false,
        );
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Rescan / refresh
  // ---------------------------------------------------------------------------

  /// Reloads [catalog.json] from the full eligible provider chain (ADR-002).
  ///
  /// Alias for [rescan]. This is **catalogue refresh** — it re-attempts configured
  /// local/HTTP catalogue sources in priority order. It does **not** run the
  /// filesystem indexer or [ScannerService] scan.
  Future<void> refreshCatalogue() => rescan();

  /// Re-attempts the full eligible provider chain and replaces the catalogue on
  /// success.
  ///
  /// Same behaviour as [refreshCatalogue]. Not a filesystem/indexer scan — use
  /// [ScannerService] for that.
  ///
  /// On success: active catalogue is replaced, [isUsingFallback] cleared.
  /// On failure: error banner shown, existing catalogue preserved — the user
  /// can still browse and play whatever was loaded before.
  Future<void> rescan() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _loadDismissedState();

    final attempt = await _tryProviderCatalogue(activeProviderConfig);

    if (attempt.didSucceed) {
      _isUsingFallback = false;
      _errorMessage = null;
    } else {
      _errorMessage = attempt.lastError ??
          'Could not load catalogue from configured providers. '
          'Check network, drive mounts, and Settings.';
      _finalizeProviderSnapshot(
        chainSucceeded: false,
        demoFallback: isUsingFallback,
        demoWithoutProvider: false,
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Manual source selection (from the source dialog)
  // ---------------------------------------------------------------------------

  /// Load from an absolute local file path.
  Future<void> loadFromFile(String filePath) async {
    await _load(
      source: CatalogSource.localFile,
      loader: () async {
        final file = File(filePath);
        if (!await file.exists()) throw Exception('File not found: $filePath');
        return file.readAsString();
      },
      identifier: filePath,
    );
    if (_errorMessage == null) _isUsingFallback = false;
  }

  /// Load from a remote URL.
  ///
  /// Explicit capability only — not used by [loadOnStartup]. On failure the
  /// previously loaded catalogue is preserved and [errorMessage] is set.
  Future<void> loadFromUrl(String url) async {
    await _load(
      source: CatalogSource.remoteUrl,
      loader: () => _fetchCatalogBody(url),
      identifier: url,
    );
    if (_errorMessage == null) _isUsingFallback = false;
  }

  /// Load the bundled mock catalogue (always available offline).
  Future<void> loadBundled() async {
    await _load(
      source: CatalogSource.bundled,
      loader: () => rootBundle.loadString('assets/catalog.json'),
      identifier: 'bundled',
    );
    _isUsingFallback = false; // user explicitly chose bundled — not a fallback
    notifyListeners();
  }

  /// Dismiss the current error banner without reloading.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Hide scan-warning banner for the current catalogue revision only.
  /// Stored locally — catalog.json is never modified.
  Future<void> dismissScanWarnings() async {
    final catalog = _catalog;
    if (catalog == null || !catalog.hasScanWarnings) return;

    final id = catalog.catalogueIdentity;
    _dismissedWarningsCatalogueId = id;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyDismissedWarningsCatalogueId, id);
    notifyListeners();
  }

  /// Re-reads and re-parses the active catalogue file without replacing state
  /// on failure.
  Future<CatalogueValidationResult> validateCatalogue() async {
    final path = _catalogPath;
    if (path == null) {
      return CatalogueValidationResult.unavailable(
        'No catalogue is loaded.',
      );
    }
    if (path == 'bundled') {
      final catalog = _catalog;
      if (catalog == null) {
        return CatalogueValidationResult.unavailable(
          'Bundled demo catalogue could not be validated.',
        );
      }
      return CatalogueValidationResult(
        success: true,
        message: 'Bundled demo catalogue is valid.',
        itemCount: catalog.allItems.length,
        libraryCount: catalog.libraryFolders.length,
        catalogueIdentity: catalog.catalogueIdentity,
      );
    }

    final file = File(path);
    if (!await file.exists()) {
      return CatalogueValidationResult.unavailable(
        'Catalogue file not found at $path',
      );
    }

    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final parsed = Catalog.fromJson(json);
      return CatalogueValidationResult(
        success: true,
        message: 'Catalogue file is readable and valid.',
        itemCount: parsed.allItems.length,
        libraryCount: parsed.libraryFolders.length,
        catalogueIdentity: parsed.catalogueIdentity,
      );
    } on FormatException {
      return CatalogueValidationResult.unavailable(
        'Catalogue file contains invalid JSON.',
      );
    } catch (e) {
      return CatalogueValidationResult.unavailable(
        'Catalogue validation failed: $e',
      );
    }
  }

  /// Read-only summary from [scannerConfigPath] for Library Manager.
  Future<ScannerConfigSummary?> readScannerConfig() async {
    try {
      final configFile = File(scannerConfigPath);
      if (!await configFile.exists()) return null;

      final json =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final cataloguePath = json['cataloguePath'] as String? ?? '';
      final historyPath = json['historyPath'] as String? ?? '';

      String mediaRoot = '';
      String uncPath = '';
      final roots = json['mediaRoots'] as List<dynamic>?;
      if (roots != null && roots.isNotEmpty) {
        final first = roots.first as Map<String, dynamic>;
        mediaRoot = first['path'] as String? ?? '';
        uncPath = first['uncPath'] as String? ?? '';
      }

      return ScannerConfigSummary(
        cataloguePath: cataloguePath,
        historyPath: historyPath,
        mediaRoot: mediaRoot,
        uncPath: uncPath,
      );
    } catch (e) {
      debugPrint('[CatalogService] could not read scanner config: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _loadDismissedState() async {
    if (_dismissedStateLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _dismissedWarningsCatalogueId =
        prefs.getString(_prefKeyDismissedWarningsCatalogueId);
    _dismissedStateLoaded = true;
  }

  /// Sidecar artwork is resolved at runtime and cached in [ArtworkService].
  /// Clear that cache whenever a new catalogue revision is loaded so rescans
  /// and reloads can pick up new poster files beside existing items.
  void _notifyCatalogReplaced() => _onCatalogReplaced?.call();

  /// Tries configured catalogue providers in priority order.
  Future<_ProviderCatalogueAttempt> _tryProviderCatalogue(
    MediaProviderConfig config,
  ) async {
    final legacyLocal = <MediaCatalogueProviderDefinition>[];

    if (includeLegacyCataloguePaths) {
      if (includeScannerConfigCataloguePath) {
        final fromConfig = await _cataloguePathFromConfig();
        if (fromConfig != null) {
          legacyLocal.add(_legacyProviderForPath(fromConfig));
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString(_prefKeyPath);
      if (savedPath != null &&
          savedPath != 'bundled' &&
          !_isBlockedCataloguePath(savedPath)) {
        legacyLocal.add(_legacyProviderForPath(savedPath));
      }
    }

    final attemptChain = CatalogueProviderSelector.orderedProviders(
      config: config,
      legacyLocalProviders: legacyLocal,
    );
    final skipped =
        CatalogueProviderSelector.configurationExcludedProviders(
      config: config,
      attemptChain: attemptChain,
    );

    _loadTracker = CatalogueProviderLoadTracker(
      config: config,
      attemptChain: attemptChain,
      skippedProviders: skipped,
    );

    final cycleStart = DateTime.now().toUtc();
    _sessionStartedAt ??= cycleStart;
    _lastLoadStartedAt = cycleStart;
    _loadTracker!.beginCycle(cycleStart);

    String? lastError;
    for (var i = 0; i < attemptChain.length; i++) {
      final provider = attemptChain[i];
      _loadTracker!.markLoading(i, DateTime.now().toUtc());

      final errorBefore = _errorMessage;
      _errorMessage = null;
      final loaded = await _tryCatalogueProvider(provider);
      if (loaded) {
        final hadEarlierFailure = _loadTracker!.records
            .take(i)
            .any((r) => r.health == CatalogueProviderHealth.failed);
        _loadTracker!.markSuccess(
          i,
          DateTime.now().toUtc(),
          hadEarlierFailure: hadEarlierFailure,
        );
        _activeCatalogueProvider = provider;
        _lastCatalogueLoadAt = _lastRefreshedAt;
        _finalizeProviderSnapshot(
          chainSucceeded: true,
          demoFallback: false,
          demoWithoutProvider: false,
        );
        return _ProviderCatalogueAttempt.success;
      }

      final attemptError = _errorMessage;
      _errorMessage = errorBefore;
      lastError = attemptError ?? lastError;
      _loadTracker!.markFailed(
        i,
        attemptError ?? _loadFailureMessage(provider),
        DateTime.now().toUtc(),
      );
    }

    _loadTracker!.markAllAttemptedFailed(lastError);
    _finalizeProviderSnapshot(
      chainSucceeded: false,
      demoFallback: false,
      demoWithoutProvider: false,
    );
    return _ProviderCatalogueAttempt.failed(lastError);
  }

  void _finalizeProviderSnapshot({
    required bool chainSucceeded,
    required bool demoFallback,
    required bool demoWithoutProvider,
  }) {
    final tracker = _loadTracker;
    if (tracker == null) return;

    _providerSnapshot = tracker.build(
      loadedCatalogueIdentity: _catalog?.catalogueIdentity,
      catalogPath: _catalogPath,
      lastCatalogueLoadAt: _lastCatalogueLoadAt,
      sessionStartedAt: _sessionStartedAt,
      isDemoFallback: demoFallback || isUsingFallback,
      demoActiveWithoutProvider: demoWithoutProvider,
    );
  }

  static String _loadFailureMessage(MediaCatalogueProviderDefinition provider) {
    switch (provider.kind) {
      case MediaCatalogueProviderKind.localFile:
        return 'Could not load catalogue from ${provider.location}.';
      case MediaCatalogueProviderKind.http:
        return 'Could not load catalogue from ${provider.location}.';
    }
  }

  static MediaCatalogueProviderDefinition _legacyProviderForPath(String path) {
    if (_isRemoteCatalogueUrl(path)) {
      return MediaCatalogueProviderDefinition.http(path);
    }
    return MediaCatalogueProviderDefinition.localFile(path);
  }

  static bool _isRemoteCatalogueUrl(String path) {
    final uri = Uri.tryParse(path.trim());
    if (uri == null || !uri.hasScheme) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  Future<bool> _tryCatalogueProvider(
    MediaCatalogueProviderDefinition provider,
  ) async {
    try {
      switch (provider.kind) {
        case MediaCatalogueProviderKind.localFile:
          return _tryLoadLocalCataloguePath(provider.location);
        case MediaCatalogueProviderKind.http:
          return _tryLoadHttpCatalogue(provider.location);
      }
    } catch (e) {
      debugPrint(
        '[CatalogService] catalogue provider failed (${provider.location}): $e',
      );
      return false;
    }
  }

  Future<bool> _tryLoadLocalCataloguePath(String path) async {
    if (_isBlockedCataloguePath(path)) return false;
    final file = File(path);
    if (!await file.exists()) return false;
    debugPrint('[CatalogService] loading catalogue from ${file.path}');
    return _tryLoadLiveFile(file);
  }

  Future<bool> _tryLoadHttpCatalogue(String url) async {
    try {
      final raw = await _fetchCatalogBody(url);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _catalog = Catalog.fromJson(json);
      _catalogPath = url;
      _lastRefreshedAt = DateTime.now();
      _notifyCatalogReplaced();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeySource, CatalogSource.remoteUrl.name);
      await prefs.setString(_prefKeyPath, url);
      return true;
    } on TimeoutException catch (e) {
      _errorMessage = RemoteFetchErrors.catalogueLoadMessage(e, url);
      debugPrint('[CatalogService] HTTP catalogue load failed for $url: $e');
      return false;
    } on SocketException catch (e) {
      _errorMessage = RemoteFetchErrors.catalogueLoadMessage(e, url);
      debugPrint('[CatalogService] HTTP catalogue load failed for $url: $e');
      return false;
    } on HandshakeException catch (e) {
      _errorMessage = RemoteFetchErrors.catalogueLoadMessage(e, url);
      debugPrint('[CatalogService] HTTP catalogue load failed for $url: $e');
      return false;
    } on CertificateException catch (e) {
      _errorMessage = RemoteFetchErrors.catalogueLoadMessage(e, url);
      debugPrint('[CatalogService] HTTP catalogue load failed for $url: $e');
      return false;
    } on TlsException catch (e) {
      _errorMessage = RemoteFetchErrors.catalogueLoadMessage(e, url);
      debugPrint('[CatalogService] HTTP catalogue load failed for $url: $e');
      return false;
    } on HttpException catch (e) {
      _errorMessage = RemoteFetchErrors.catalogueLoadMessage(e, url);
      debugPrint('[CatalogService] HTTP catalogue load failed for $url: $e');
      return false;
    } on FormatException catch (e) {
      _errorMessage = 'Catalogue response could not be parsed as JSON.';
      debugPrint('[CatalogService] HTTP catalogue load failed for $url: $e');
      return false;
    } catch (e) {
      _errorMessage = RemoteFetchErrors.catalogueLoadMessage(e, url);
      debugPrint('[CatalogService] HTTP catalogue load failed for $url: $e');
      return false;
    }
  }

  Future<String> _fetchCatalogBody(String url) async {
    final timeout = _resolveCatalogFetchTimeout();
    try {
      final response = await _httpClient.get(Uri.parse(url)).timeout(timeout);
      if (response.statusCode != 200) {
        throw HttpException(
          'HTTP ${response.statusCode} loading catalogue from $url',
          uri: Uri.parse(url),
        );
      }
      return response.body;
    } on TimeoutException {
      throw TimeoutException(
        'Timed out loading catalogue from $url',
        timeout,
      );
    }
  }

  static bool _isBlockedCataloguePath(String path) =>
      _blockedCataloguePaths.contains(path.toLowerCase());

  Future<String?> _cataloguePathFromConfig() async {
    try {
      final configFile = File(scannerConfigPath);
      if (!await configFile.exists()) return null;

      final json =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final path = json['cataloguePath'] as String?;
      if (path == null || path.isEmpty) return null;
      return path;
    } catch (e) {
      debugPrint('[CatalogService] could not read scanner config: $e');
      return null;
    }
  }

  /// Loads a live catalogue file whose existence has already been confirmed.
  ///
  /// Stages are kept separate so failures are attributed correctly:
  ///   1. File.readAsString()  — I/O error
  ///   2. jsonDecode()         — malformed JSON
  ///   3. Catalog.fromJson()   — schema mismatch
  ///
  /// Sets [_errorMessage] if the file exists but cannot be parsed.
  /// Never uses rootBundle, Uri.parse, or any asset bundle.
  Future<bool> _tryLoadLiveFile(File file) async {
    // Stage 1 — read
    final String raw;
    try {
      raw = await file.readAsString();
    } catch (e) {
      _errorMessage = 'Could not read catalogue: $e';
      return false;
    }

    // Stage 2 — decode JSON
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      _errorMessage = 'Catalogue found but could not be parsed.';
      debugPrint('jsonDecode failed for ${file.path}: $e');
      return false;
    }

    // Stage 3 — build model
    try {
      _catalog = Catalog.fromJson(json);
    } catch (e) {
      _errorMessage = 'Catalogue found but could not be parsed.';
      debugPrint('Catalog.fromJson failed for ${file.path}: $e');
      return false;
    }

    _catalogPath = file.path;
    _lastRefreshedAt = DateTime.now();
    _notifyCatalogReplaced();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeySource, CatalogSource.localFile.name);
    await prefs.setString(_prefKeyPath, file.path);
    return true;
  }

  Future<void> _load({
    required CatalogSource source,
    required Future<String> Function() loader,
    required String identifier,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _loadDismissedState();

    try {
      final raw = await loader();

      final Map<String, dynamic> json;
      try {
        json = jsonDecode(raw) as Map<String, dynamic>;
      } on FormatException {
        _errorMessage = 'Catalogue response could not be parsed as JSON.';
        return;
      }

      final Catalog parsed;
      try {
        parsed = Catalog.fromJson(json);
      } catch (e) {
        _errorMessage = 'Catalogue response was not a valid catalogue.';
        debugPrint('[CatalogService] Catalog.fromJson failed: $e');
        return;
      }

      // Only replace on success — a failed load preserves the current catalogue.
      _catalog = parsed;
      _catalogPath = identifier;
      if (identifier != 'bundled') {
        _lastRefreshedAt = DateTime.now();
      }
      _notifyCatalogReplaced();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeySource, source.name);
      await prefs.setString(_prefKeyPath, identifier);
    } on TimeoutException {
      _errorMessage = RemoteFetchErrors.catalogueLoadMessage(
        TimeoutException('timed out', _resolveCatalogFetchTimeout()),
        identifier,
      );
    } on SocketException catch (e) {
      _errorMessage = RemoteFetchErrors.catalogueLoadMessage(e, identifier);
    } on HandshakeException catch (e) {
      _errorMessage = RemoteFetchErrors.catalogueLoadMessage(e, identifier);
    } on CertificateException catch (e) {
      _errorMessage = RemoteFetchErrors.catalogueLoadMessage(e, identifier);
    } on TlsException catch (e) {
      _errorMessage = RemoteFetchErrors.catalogueLoadMessage(e, identifier);
    } on HttpException catch (e) {
      _errorMessage = RemoteFetchErrors.catalogueLoadMessage(e, identifier);
    } catch (e) {
      _errorMessage = RemoteFetchErrors.catalogueLoadMessage(e, identifier);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

/// Result of trying all configured catalogue providers during startup/rescan.
class _ProviderCatalogueAttempt {
  final bool didSucceed;
  final String? lastError;

  const _ProviderCatalogueAttempt._({
    required this.didSucceed,
    this.lastError,
  });

  static const success = _ProviderCatalogueAttempt._(didSucceed: true);

  factory _ProviderCatalogueAttempt.failed(String? lastError) =>
      _ProviderCatalogueAttempt._(didSucceed: false, lastError: lastError);
}

/// Read-only paths from [CatalogService.scannerConfigPath].
class ScannerConfigSummary {
  final String cataloguePath;
  final String historyPath;
  final String mediaRoot;
  final String uncPath;

  const ScannerConfigSummary({
    required this.cataloguePath,
    required this.historyPath,
    required this.mediaRoot,
    required this.uncPath,
  });
}
