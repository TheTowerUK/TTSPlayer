/// Pure Dart helpers for CBR Gate 0 — safe to unit-test without loading unrar.dll.
library;

const kCbrSupportedImageExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'bmp',
};

bool cbrIsImageEntryName(String name) {
  final base = name.replaceAll('\\', '/').split('/').last;
  final dot = base.lastIndexOf('.');
  if (dot < 0 || dot == base.length - 1) return false;
  final ext = base.substring(dot + 1).toLowerCase();
  return kCbrSupportedImageExtensions.contains(ext);
}

/// Reject absolute paths and `..` segments (path-traversal hardening).
bool cbrIsUnsafeEntryName(String name) {
  if (name.isEmpty) return true;
  if (name.startsWith('/') || name.startsWith('\\')) return true;
  if (RegExp(r'^[a-zA-Z]:').hasMatch(name)) return true;
  final parts = name.split(RegExp(r'[/\\]'));
  for (final part in parts) {
    if (part == '..') return true;
  }
  return false;
}

int cbrNaturalCompare(String a, String b) {
  final ra = RegExp(r'(\d+)|(\D+)').allMatches(a.toLowerCase()).toList();
  final rb = RegExp(r'(\d+)|(\D+)').allMatches(b.toLowerCase()).toList();
  final n = ra.length < rb.length ? ra.length : rb.length;
  for (var i = 0; i < n; i++) {
    final ma = ra[i].group(0)!;
    final mb = rb[i].group(0)!;
    final da = int.tryParse(ma);
    final db = int.tryParse(mb);
    if (da != null && db != null) {
      final c = da.compareTo(db);
      if (c != 0) return c;
    } else {
      final c = ma.compareTo(mb);
      if (c != 0) return c;
    }
  }
  return a.toLowerCase().compareTo(b.toLowerCase());
}

String cbrBasename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final i = normalized.lastIndexOf('/');
  return i < 0 ? normalized : normalized.substring(i + 1);
}
