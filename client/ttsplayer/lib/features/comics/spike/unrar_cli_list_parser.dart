/// Parses `UnRAR lt` technical listing output into entry rows.
class UnrarCliListRow {
  const UnrarCliListRow({
    required this.name,
    required this.sizeBytes,
    required this.packedSizeBytes,
    required this.isDirectory,
  });

  final String name;
  final int sizeBytes;
  final int packedSizeBytes;
  final bool isDirectory;
}

List<UnrarCliListRow> parseUnrarTechnicalList(String stdout) {
  final rows = <UnrarCliListRow>[];
  String? name;
  int? size;
  int? packed;

  void flush() {
    if (name == null) return;
    final n = name!.replaceAll('\\', '/');
    final isDir = n.endsWith('/');
    rows.add(
      UnrarCliListRow(
        name: isDir ? n.substring(0, n.length - 1) : n,
        sizeBytes: size ?? 0,
        packedSizeBytes: packed ?? 0,
        isDirectory: isDir,
      ),
    );
    name = null;
    size = null;
    packed = null;
  }

  for (final rawLine in stdout.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    final nameMatch = RegExp(r'^Name:\s*(.+)$').firstMatch(line);
    if (nameMatch != null) {
      flush();
      name = nameMatch.group(1)!.trim();
      continue;
    }
    final sizeMatch = RegExp(r'^Size:\s*(\d+)$').firstMatch(line);
    if (sizeMatch != null) {
      size = int.tryParse(sizeMatch.group(1)!);
      continue;
    }
    final packedMatch = RegExp(r'^Packed size:\s*(\d+)$').firstMatch(line);
    if (packedMatch != null) {
      packed = int.tryParse(packedMatch.group(1)!);
      continue;
    }
  }
  flush();

  if (rows.isNotEmpty) return rows;

  for (final rawLine in stdout.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (line.toUpperCase().startsWith('UNRAR ')) continue;
    if (line.startsWith('Archive:')) continue;
    rows.add(
      UnrarCliListRow(
        name: line.replaceAll('\\', '/'),
        sizeBytes: 0,
        packedSizeBytes: 0,
        isDirectory: line.endsWith('/') || line.endsWith('\\'),
      ),
    );
  }
  return rows;
}
