import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/catalog.dart';
import '../models/catalogue_source_kind.dart';
import '../models/catalogue_validation_result.dart';

/// Source from which the catalog is loaded.
enum CatalogSource { bundled, localFile, remoteUrl }

class CatalogService extends ChangeNotifier {
  CatalogService({
    http.Client? httpClient,
    Duration? catalogFetchTimeout,
  })  : _httpClient = httpClient ?? http.Client(),
        _catalogFetchTimeout =
            catalogFetchTimeout ?? catalogFetchTimeoutDefault;

  final http.Client _httpClient;
  final Duration _catalogFetchTimeout;

  /// Default bounded timeout for [loadFromUrl].
  static const catalogFetchTimeoutDefault = Duration(seconds: 15);
  Catalog? _catalog;
  bool _isLoading = false;
  String? _errorMessage;
  String? _catalogPath;
  DateTime? _lastRefreshedAt;

  /// True when the bundled asset is being used because the live NAS catalogue
  /// was unreachable.  Drives the "Demo catalogue in use" banner.
  bool _isUsingFallback = false;

  Catalog? get catalog => _catalog;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get catalogPath => _catalogPath;
  DateTime? get lastRefreshedAt => _lastRefreshedAt;
  bool get isUsingFallback => _isUsingFallback;

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

  /// Catalogue ID for which the user dismissed the scan-warnings banner.
  /// Persisted in shared_preferences — does not modify catalog.json.
  String? _dismissedWarningsCatalogueId;
  bool _dismissedStateLoaded = false;

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
  /// Tries each path in [liveCataloguePaths] in order, silently.
  /// Falls back to the bundled asset if none succeed, with [isUsingFallback]
  /// set to true so the UI can surface a non-blocking "Demo catalogue" banner.
  Future<void> loadOnStartup() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _loadDismissedState();

    final liveLoaded = await _tryLivePaths();

    if (liveLoaded) {
      _isUsingFallback = false;
    } else {
      // NAS not reachable — fall back to bundled without surfacing an error.
      _isUsingFallback = true;
      try {
        final raw = await rootBundle.loadString('assets/catalog.json');
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _catalog = Catalog.fromJson(json);
        _catalogPath = 'bundled';
      } catch (e) {
        _errorMessage = 'Could not load any catalogue: $e';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Rescan
  // ---------------------------------------------------------------------------

  /// Reloads the live NAS catalogue.
  ///
  /// On success: active catalogue is replaced, [isUsingFallback] cleared.
  /// On failure: error banner shown, existing catalogue preserved — the user
  /// can still browse and play whatever was loaded before.
  Future<void> rescan() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _loadDismissedState();

    final success = await _tryLivePaths();

    if (success) {
      _isUsingFallback = false;
    } else {
      _errorMessage =
          'Could not reach live NAS catalogue '
          '(${liveCataloguePaths.join(' or ')}). '
          'Check that the NAS drive is mounted.';
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

  Future<String> _fetchCatalogBody(String url) async {
    try {
      final response = await _httpClient
          .get(Uri.parse(url))
          .timeout(_catalogFetchTimeout);
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
        _catalogFetchTimeout,
      );
    }
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

  /// Tries catalogue paths in priority order:
  ///   1. [cataloguePath] from [scannerConfigPath]
  ///   2. Last successfully loaded path (shared_preferences)
  ///   3. [liveCataloguePaths] fallbacks
  Future<bool> _tryLivePaths() async {
    final candidates = <String>[];

    final fromConfig = await _cataloguePathFromConfig();
    if (fromConfig != null) candidates.add(fromConfig);

    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(_prefKeyPath);
    if (savedPath != null &&
        savedPath != 'bundled' &&
        !_isBlockedCataloguePath(savedPath)) {
      candidates.add(savedPath);
    }

    candidates.addAll(liveCataloguePaths);

    final seen = <String>{};
    for (final path in candidates) {
      final key = path.toLowerCase();
      if (seen.contains(key) || _isBlockedCataloguePath(path)) continue;
      seen.add(key);

      final file = File(path);
      if (await file.exists()) {
        debugPrint('[CatalogService] loading catalogue from ${file.path}');
        return _tryLoadLiveFile(file);
      }
    }
    return false;
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeySource, source.name);
      await prefs.setString(_prefKeyPath, identifier);
    } on TimeoutException {
      _errorMessage = 'Timed out loading catalogue. Check the URL and network.';
    } on SocketException catch (e) {
      _errorMessage = 'Network error loading catalogue: ${e.message}';
    } on HttpException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Could not load catalogue: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
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
