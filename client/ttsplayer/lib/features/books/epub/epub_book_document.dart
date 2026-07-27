import 'epub_resource_loader.dart';

class EpubTocEntry {
  const EpubTocEntry({
    required this.title,
    required this.spineIndex,
    required this.href,
  });

  final String title;
  final int spineIndex;
  final String href;
}

class EpubSpineChapter {
  const EpubSpineChapter({
    required this.id,
    required this.href,
    this.html,
    this.title,
  });

  final String id;
  final String href;

  /// Populated eagerly for in-memory test fixtures; null when lazy-loaded.
  final String? html;
  final String? title;
}

/// Parsed EPUB package for an open session.
class EpubBookDocument {
  const EpubBookDocument({
    required this.title,
    required this.spine,
    required this.toc,
    required this.resourceLoader,
    required this.opfDirectory,
  });

  final String title;
  final List<EpubSpineChapter> spine;
  final List<EpubTocEntry> toc;
  final EpubResourceLoader resourceLoader;
  final String opfDirectory;

  Future<String> loadChapterHtml(int index) async {
    final chapter = spine[index];
    if (chapter.html != null) return chapter.html!;
    final text = await resourceLoader.loadText(chapter.href);
    if (text == null) {
      throw StateError('Missing spine chapter: ${chapter.href}');
    }
    final lower = text.toLowerCase();
    if (lower.contains('<script') || lower.contains('javascript:')) {
      throw StateError('Unsupported active content in ${chapter.href}');
    }
    return text;
  }

  void dispose() {
    resourceLoader.dispose();
  }
}
