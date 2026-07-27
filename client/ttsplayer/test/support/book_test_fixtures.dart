import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

/// Minimal valid PDF bytes (TTSPlayer-owned structure, no copyrighted content).
List<int> minimalPdf({int pages = 1, double width = 200, double height = 200}) {
  final objects = <String>[
    '1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj',
    '2 0 obj<< /Type /Pages /Kids [${List.generate(pages, (i) => '${3 + i} 0 R').join(' ')}] /Count $pages >>endobj',
  ];
  for (var i = 0; i < pages; i++) {
    final pageNum = 3 + i;
    objects.add(
      '$pageNum 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $width $height] >>endobj',
    );
  }

  return _encodePdfObjects(objects);
}

/// PDF with per-page [MediaBox] dimensions (mixed layout stress).
List<int> minimalPdfMixedDimensions(List<(double width, double height)> sizes) {
  final pages = sizes.length;
  final objects = <String>[
    '1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj',
    '2 0 obj<< /Type /Pages /Kids [${List.generate(pages, (i) => '${3 + i} 0 R').join(' ')}] /Count $pages >>endobj',
  ];
  for (var i = 0; i < pages; i++) {
    final pageNum = 3 + i;
    final (width, height) = sizes[i];
    objects.add(
      '$pageNum 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $width $height] >>endobj',
    );
  }
  return _encodePdfObjects(objects);
}

/// PDF with one image-heavy page (large content stream, not full-document decode).
List<int> minimalPdfImageHeavyPage({int streamBytes = 65536}) {
  final streamData = List.filled(streamBytes, 0x41);
  final streamObjNum = 4;
  final objects = <String>[
    '1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj',
    '2 0 obj<< /Type /Pages /Kids [3 0 R] /Count 1 >>endobj',
    '3 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 800 600] /Contents $streamObjNum 0 R >>endobj',
    '$streamObjNum 0 obj<< /Length $streamBytes >>stream\n${String.fromCharCodes(streamData)}\nendstream\nendobj',
  ];
  return _encodePdfObjects(objects);
}

List<int> _encodePdfObjects(List<String> objects) {
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (final obj in objects) {
    offsets.add(buffer.length);
    buffer.writeln(obj);
  }
  final xrefOffset = buffer.length;
  buffer.writeln('xref');
  buffer.writeln('0 ${objects.length + 1}');
  buffer.writeln('0000000000 65535 f ');
  for (var i = 1; i < offsets.length; i++) {
    buffer.writeln('${offsets[i].toString().padLeft(10, '0')} 00000 n ');
  }
  buffer.writeln('trailer<< /Root 1 0 R /Size ${objects.length + 1} >>');
  buffer.writeln('startxref');
  buffer.writeln('$xrefOffset');
  buffer.writeln('%%EOF');
  return utf8.encode(buffer.toString());
}

File writePdf(
  Directory dir,
  String name, {
  int pages = 1,
  double width = 200,
  double height = 200,
}) {
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  file.writeAsBytesSync(minimalPdf(pages: pages, width: width, height: height));
  return file;
}

/// Phase 6.6 PDF profiles (generated locally — not committed).
File writePhase66Pdf(
  Directory dir,
  String name, {
  int pages = 120,
  double width = 200,
  double height = 200,
  List<(double, double)>? mixedSizes,
  bool imageHeavyFirstPage = false,
}) {
  final bytes = mixedSizes != null
      ? minimalPdfMixedDimensions(mixedSizes)
      : imageHeavyFirstPage
          ? minimalPdfImageHeavyPage()
          : minimalPdf(pages: pages, width: width, height: height);
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  file.writeAsBytesSync(bytes);
  return file;
}

/// Writes a synthetic EPUB ZIP for parser/reader tests.
File writeEpub(
  Directory dir,
  String name, {
  required List<MapEntry<String, String>> chapters,
  String version = '3.0',
  String title = 'Fixture Book',
  bool includeScript = false,
  bool includeExternalLink = false,
  bool unsafeEntry = false,
  bool missingSpineResource = false,
}) {
  final archive = Archive();
  archive.addFile(ArchiveFile.string('mimetype', 'application/epub+zip'));
  archive.addFile(
    ArchiveFile.string(
      'META-INF/container.xml',
      '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''',
    ),
  );

  final manifestItems = <String>[];
  final spineItems = <String>[];
  for (var i = 0; i < chapters.length; i++) {
    final id = 'ch$i';
    final href = chapters[i].key;
    manifestItems.add(
      '<item id="$id" href="$href" media-type="application/xhtml+xml"/>',
    );
    spineItems.add('<itemref idref="$id"/>');
    if (!missingSpineResource || i > 0) {
      var html = chapters[i].value;
      if (includeScript && i == 0) {
        html = '$html<script>alert(1)</script>';
      }
      if (includeExternalLink && i == 0) {
        html = '$html<p><a href="https://example.com">External</a></p>';
      }
      archive.addFile(ArchiveFile.string('OEBPS/$href', html));
    }
  }

  final opf = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="$version">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>$title</dc:title>
  </metadata>
  <manifest>
    ${manifestItems.join('\n    ')}
  </manifest>
  <spine toc="ncx">
    ${spineItems.join('\n    ')}
  </spine>
</package>''';
  archive.addFile(ArchiveFile.string('OEBPS/content.opf', opf));

  if (unsafeEntry) {
    archive.addFile(ArchiveFile.string('../escape.txt', 'bad'));
  }

  final encoded = ZipEncoder().encode(archive)!;
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  file.writeAsBytesSync(encoded);
  return file;
}

/// Unicode chapter HTML for fixture-set validation.
String unicodeChapterHtml() => '''
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Unicode — 日本語</title></head>
<body><p>Hello 世界 — café naïve</p></body>
</html>''';

/// Internal link chapter pair for navigation tests.
List<MapEntry<String, String>> linkedChapters() => [
      MapEntry(
        'chapter1.xhtml',
        '''<!DOCTYPE html><html><body>
<p><a href="chapter2.xhtml">Next</a></p>
</body></html>''',
      ),
      MapEntry(
        'chapter2.xhtml',
        '<!DOCTYPE html><html><body><p>Chapter two</p></body></html>',
      ),
    ];
