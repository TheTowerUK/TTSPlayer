import '../../artwork/metadata_artwork_download_url_resolver.dart';
import '../../artwork/metadata_artwork_reference.dart';

/// Open Library Covers API URL resolver (M7.4.3).
class OpenLibraryArtworkDownloadUrlResolver
    extends MetadataArtworkDownloadUrlResolver {
  const OpenLibraryArtworkDownloadUrlResolver({
    this.size = 'L',
    this.baseUrl = 'https://covers.openlibrary.org',
  });

  final String size;
  final String baseUrl;

  @override
  Uri? resolveDownloadUrl(MetadataArtworkReference reference) {
    if (reference.providerId != 'open_library') {
      return null;
    }
    final artworkId = reference.artworkId.trim();
    if (artworkId.isEmpty) {
      return null;
    }
    return Uri.parse('$baseUrl/b/id/$artworkId-$size.jpg');
  }
}
