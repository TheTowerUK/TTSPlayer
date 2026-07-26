import 'comic_page_ref.dart';

/// Implementation-neutral comic archive contract (CBZ and CBR backends).
abstract class ComicArchiveSource {
  /// Lists image pages in natural order (directories / non-images omitted).
  Future<List<ComicPageRef>> listPages();

  /// Loads raw image bytes for [entryName] (must already be a listed page).
  Future<List<int>> loadPageBytes(String entryName);

  Future<void> dispose();
}
