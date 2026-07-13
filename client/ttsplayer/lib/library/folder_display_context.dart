import '../models/catalog.dart';

/// Catalogue-driven folder context for display labels (ADR-009 / Phase 4.3).
///
/// Returns ancestor chain names joined with ` · ` — never raw paths or URLs.
String catalogueFolderContext(Catalog catalog, String itemId) {
  final parent = catalog.parentFolderOfItemId(itemId);
  if (parent == null) return '';

  final chain = catalog.ancestorChainForFolder(parent.id);
  if (chain.isEmpty) return parent.name;

  return chain.map((folder) => folder.name).join(' · ');
}
