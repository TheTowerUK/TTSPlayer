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
    required this.html,
    this.title,
  });

  final String id;
  final String href;
  final String html;
  final String? title;
}

/// Parsed EPUB package kept in memory for the open session.
class EpubBookDocument {
  const EpubBookDocument({
    required this.title,
    required this.spine,
    required this.toc,
    required this.resources,
    required this.opfDirectory,
  });

  final String title;
  final List<EpubSpineChapter> spine;
  final List<EpubTocEntry> toc;
  final Map<String, List<int>> resources;
  final String opfDirectory;
}
