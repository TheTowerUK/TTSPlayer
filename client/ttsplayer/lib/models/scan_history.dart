// ---------------------------------------------------------------------------
// ScanHistoryEntry — one record per completed scan run
// ---------------------------------------------------------------------------

class ScanHistoryEntry {
  /// Links this entry to the specific catalog.json that was produced.
  final String catalogueId;

  /// UTC timestamp when the scan completed.
  final DateTime completed;

  /// True if the scan finished without a fatal error.
  /// False entries may be added in future (e.g. aborted runs).
  final bool success;

  final int sources;
  final int folders;
  final int items;
  final int warnings;
  final int durationSeconds;

  const ScanHistoryEntry({
    required this.catalogueId,
    required this.completed,
    required this.success,
    required this.sources,
    required this.folders,
    required this.items,
    required this.warnings,
    required this.durationSeconds,
  });

  factory ScanHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ScanHistoryEntry(
      catalogueId: json['catalogue_id'] as String? ?? 'unknown',
      completed: DateTime.tryParse(json['completed'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      success: json['success'] as bool? ?? true,
      sources: json['sources'] as int? ?? 0,
      folders: json['folders'] as int? ?? 0,
      items: json['items'] as int? ?? 0,
      warnings: json['warnings'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
    );
  }

  /// Formatted completion date and time, e.g. "2026-07-01  20:14".
  String get formattedDate {
    final d = completed.toLocal();
    final date =
        '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
    final time = '${_pad(d.hour)}:${_pad(d.minute)}';
    return '$date  $time';
  }

  /// Formatted item count with thousands separator, e.g. "42,891".
  String get formattedItems => _formatCount(items);

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _formatCount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ---------------------------------------------------------------------------
// ScanHistory — top-level object decoded from scan.history.json
// ---------------------------------------------------------------------------

class ScanHistory {
  final int maxEntries;

  /// Entries in newest-first order.
  final List<ScanHistoryEntry> entries;

  const ScanHistory({required this.maxEntries, required this.entries});

  factory ScanHistory.fromJson(Map<String, dynamic> json) {
    return ScanHistory(
      maxEntries: json['max_entries'] as int? ?? 50,
      entries: ((json['entries'] as List<dynamic>?) ?? [])
          .map((e) => ScanHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isEmpty => entries.isEmpty;
}
