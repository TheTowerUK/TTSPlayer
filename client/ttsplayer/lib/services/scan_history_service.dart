import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/scan_history.dart';

class ScanHistoryService extends ChangeNotifier {
  ScanHistory? _history;
  bool _isLoading = false;
  String? _errorMessage;

  ScanHistory? get history => _history;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Load the bundled mock history (always available offline).
  Future<void> loadBundled() async {
    await _load(() async => rootBundle.loadString('assets/scan.history.json'));
  }

  /// Load from a local file path — e.g. Y:\Media\scan.history.json.
  Future<void> loadFromFile(String filePath) async {
    await _load(() async {
      final file = File(filePath);
      if (!await file.exists()) throw Exception('History file not found: $filePath');
      return file.readAsString();
    });
  }

  /// Load from a remote URL alongside the catalogue endpoint.
  Future<void> loadFromUrl(String url) async {
    await _load(() async {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} from $url');
      }
      return response.body;
    });
  }

  /// Derive the history URL/path from a known catalogue URL/path and reload.
  /// Replaces "catalog.json" with "scan.history.json" in the identifier.
  Future<void> loadAdjacentTo(String catalogueIdentifier) async {
    final historyIdentifier = catalogueIdentifier
        .replaceAll('catalog.json', 'scan.history.json')
        .replaceAll('catalogue.json', 'scan.history.json');

    if (historyIdentifier == catalogueIdentifier) {
      // Path didn't contain a recognisable catalogue filename — fall back.
      await loadBundled();
      return;
    }

    if (historyIdentifier.startsWith('http')) {
      await loadFromUrl(historyIdentifier);
    } else if (historyIdentifier == 'bundled') {
      await loadBundled();
    } else {
      await loadFromFile(historyIdentifier);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _load(Future<String> Function() loader) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final raw = await loader();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _history = ScanHistory.fromJson(json);
    } catch (e) {
      // A missing or corrupt history file is non-fatal — show empty history.
      _errorMessage = e.toString();
      _history = const ScanHistory(maxEntries: 50, entries: []);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
