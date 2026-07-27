import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../comics/archive/cbz_zip_lazy_reader.dart';
import '../archive/book_path_safety.dart';
import '../archive/book_reader_errors.dart';
import 'epub_book_document.dart';
import 'epub_resource_loader.dart';

/// EPUB parser using lazy ZIP reads where possible (M6.6).
///
/// [parseFile] lists the ZIP central directory and loads chapters/resources on
/// demand via [EpubLazyResourceLoader]. [parseBytes] retains the in-memory test
/// path for small fixtures.
class EpubParser {
  static const maxResourceBytes = 16 * 1024 * 1024;

  Future<EpubBookDocument> parseFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw BookReaderException(
        kind: BookReaderErrorKind.fileMissing,
        userMessage: 'This book file could not be found.',
        diagnosticDetail: 'missing:${bookBasename(path)}',
      );
    }
    if (file.lengthSync() == 0) {
      throw BookReaderException(
        kind: BookReaderErrorKind.epubInvalidZip,
        userMessage: 'This book file appears to be empty.',
        diagnosticDetail: 'zero_byte:${bookBasename(path)}',
      );
    }

    final loader = EpubLazyResourceLoader(archivePath: path);
    try {
      return await _parseWithLoader(
        loader: loader,
        sourceLabel: bookBasename(path),
        entryNames: (await CbzZipLazyReader(path).centralEntries())
            .map((e) => e.name)
            .toSet(),
      );
    } on FormatException {
      throw BookReaderException(
        kind: BookReaderErrorKind.epubInvalidZip,
        userMessage: 'This book archive appears to be damaged.',
        diagnosticDetail: 'zip_open:${bookBasename(path)}',
      );
    }
  }

  Future<EpubBookDocument> parseBytes(
    List<int> bytes, {
    required String sourceLabel,
  }) async {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (_) {
      throw BookReaderException(
        kind: BookReaderErrorKind.epubInvalidZip,
        userMessage: 'This book archive appears to be damaged.',
        diagnosticDetail: 'zip_open:$sourceLabel',
      );
    }

    final resources = <String, List<int>>{};
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name.replaceAll('\\', '/');
      if (bookIsUnsafeArchiveEntry(name)) {
        throw BookReaderException(
          kind: BookReaderErrorKind.epubUnsafePath,
          userMessage: 'This book contains an unsafe file path.',
          diagnosticDetail: 'unsafe:$sourceLabel',
        );
      }
      if (entry.size > maxResourceBytes) {
        throw BookReaderException(
          kind: BookReaderErrorKind.epubResourceTooLarge,
          userMessage: 'This book contains a file that is too large to open.',
          diagnosticDetail: 'large_entry:$sourceLabel',
        );
      }
      resources[name] = entry.content;
    }

    return _parseWithLoader(
      loader: EpubMemoryResourceLoader(resources),
      sourceLabel: sourceLabel,
      entryNames: resources.keys.toSet(),
      eagerSpineHtml: true,
    );
  }

  Future<EpubBookDocument> _parseWithLoader({
    required EpubResourceLoader loader,
    required String sourceLabel,
    required Set<String> entryNames,
    bool eagerSpineHtml = false,
  }) async {
    for (final name in entryNames) {
      if (bookIsUnsafeArchiveEntry(name)) {
        throw BookReaderException(
          kind: BookReaderErrorKind.epubUnsafePath,
          userMessage: 'This book contains an unsafe file path.',
          diagnosticDetail: 'unsafe:$sourceLabel',
        );
      }
    }

    if (!entryNames.contains('META-INF/container.xml')) {
      throw BookReaderException(
        kind: BookReaderErrorKind.epubMissingContainer,
        userMessage: 'This book is missing required EPUB metadata.',
        diagnosticDetail: 'no_container:$sourceLabel',
      );
    }

    final containerText = await loader.loadText('META-INF/container.xml');
    if (containerText == null) {
      throw BookReaderException(
        kind: BookReaderErrorKind.epubMissingContainer,
        userMessage: 'This book is missing required EPUB metadata.',
        diagnosticDetail: 'no_container:$sourceLabel',
      );
    }

    final opfPath = _readContainerOpfPath(containerText);
    if (!entryNames.contains(opfPath)) {
      throw BookReaderException(
        kind: BookReaderErrorKind.epubMalformedManifest,
        userMessage: 'This book package document could not be found.',
        diagnosticDetail: 'missing_opf:$sourceLabel',
      );
    }

    final opfText = await loader.loadText(opfPath);
    if (opfText == null) {
      throw BookReaderException(
        kind: BookReaderErrorKind.epubMalformedManifest,
        userMessage: 'This book package document could not be found.',
        diagnosticDetail: 'missing_opf:$sourceLabel',
      );
    }

    final opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
        : '';

    final parsed = _parseOpf(opfText, sourceLabel);
    final spine = <EpubSpineChapter>[];

    for (final idref in parsed.spineIdRefs) {
      final href = parsed.manifest[idref];
      if (href == null) {
        throw BookReaderException(
          kind: BookReaderErrorKind.epubInvalidSpine,
          userMessage: 'This book has an invalid reading order.',
          diagnosticDetail: 'bad_spine:$sourceLabel',
        );
      }
      final fullHref = _resolveRelative(opfDir, href);
      if (!entryNames.contains(fullHref)) {
        throw BookReaderException(
          kind: BookReaderErrorKind.epubMissingResource,
          userMessage: 'Part of this book could not be found inside the file.',
          diagnosticDetail: 'missing_spine:$sourceLabel',
        );
      }

      String? html;
      if (eagerSpineHtml) {
        html = await loader.loadText(fullHref);
        if (html == null) {
          throw BookReaderException(
            kind: BookReaderErrorKind.epubMissingResource,
            userMessage: 'Part of this book could not be found inside the file.',
            diagnosticDetail: 'missing_spine:$sourceLabel',
          );
        }
        if (_containsBlockedActiveContent(html)) {
          throw BookReaderException(
            kind: BookReaderErrorKind.epubUnsupportedActiveContent,
            userMessage: 'This book uses active content that is not supported.',
            diagnosticDetail: 'active_content:$sourceLabel',
          );
        }
      } else {
        final probe = await loader.loadText(fullHref);
        if (probe != null && _containsBlockedActiveContent(probe)) {
          throw BookReaderException(
            kind: BookReaderErrorKind.epubUnsupportedActiveContent,
            userMessage: 'This book uses active content that is not supported.',
            diagnosticDetail: 'active_content:$sourceLabel',
          );
        }
      }

      spine.add(
        EpubSpineChapter(
          id: idref,
          href: fullHref,
          html: html,
          title: parsed.itemTitles[idref],
        ),
      );
    }

    if (spine.isEmpty) {
      throw BookReaderException(
        kind: BookReaderErrorKind.epubInvalidSpine,
        userMessage: 'This book has no readable chapters.',
        diagnosticDetail: 'empty_spine:$sourceLabel',
      );
    }

    final toc = <EpubTocEntry>[];
    for (var i = 0; i < spine.length; i++) {
      final chapter = spine[i];
      toc.add(
        EpubTocEntry(
          title: chapter.title ?? 'Chapter ${i + 1}',
          spineIndex: i,
          href: chapter.href,
        ),
      );
    }

    return EpubBookDocument(
      title: parsed.title ?? bookBasename(sourceLabel),
      spine: spine,
      toc: toc,
      resourceLoader: loader,
      opfDirectory: opfDir,
    );
  }

  String _readContainerOpfPath(String xmlText) {
    try {
      final doc = XmlDocument.parse(xmlText);
      final rootfiles = doc.findAllElements('rootfile');
      for (final rf in rootfiles) {
        final path = rf.getAttribute('full-path');
        final mediaType = rf.getAttribute('media-type') ?? '';
        if (path != null &&
            path.isNotEmpty &&
            (mediaType.contains('oebps-package') ||
                path.toLowerCase().endsWith('.opf'))) {
          return path.replaceAll('\\', '/');
        }
      }
    } catch (_) {
      throw BookReaderException(
        kind: BookReaderErrorKind.epubMissingContainer,
        userMessage: 'This book container metadata is invalid.',
      );
    }
    throw BookReaderException(
      kind: BookReaderErrorKind.epubMissingContainer,
      userMessage: 'This book container metadata is invalid.',
    );
  }

  _ParsedOpf _parseOpf(String xmlText, String sourceLabel) {
    try {
      final doc = XmlDocument.parse(xmlText);
      final manifest = <String, String>{};
      final itemTitles = <String, String>{};
      for (final item in doc.findAllElements('item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        if (id == null || href == null) continue;
        manifest[id] = href.replaceAll('\\', '/');
      }

      final spineIdRefs = <String>[];
      for (final itemref in doc.findAllElements('itemref')) {
        final idref = itemref.getAttribute('idref');
        if (idref != null && idref.isNotEmpty) {
          spineIdRefs.add(idref);
        }
      }

      String? title;
      for (final t in doc.findAllElements('dc:title')) {
        final text = t.innerText.trim();
        if (text.isNotEmpty) {
          title = text;
          break;
        }
      }
      for (final t in doc.findAllElements('title')) {
        final text = t.innerText.trim();
        if (text.isNotEmpty) {
          title ??= text;
          break;
        }
      }

      return _ParsedOpf(
        title: title,
        manifest: manifest,
        spineIdRefs: spineIdRefs,
        itemTitles: itemTitles,
      );
    } catch (_) {
      throw BookReaderException(
        kind: BookReaderErrorKind.epubMalformedManifest,
        userMessage: 'This book package document appears to be invalid.',
        diagnosticDetail: 'bad_opf:$sourceLabel',
      );
    }
  }

  bool _containsBlockedActiveContent(String html) {
    final lower = html.toLowerCase();
    return lower.contains('<script') || lower.contains('javascript:');
  }

  String _resolveRelative(String baseDir, String href) {
    if (href.startsWith('/')) {
      return href.substring(1).replaceAll('\\', '/');
    }
    final combined = '$baseDir$href'.replaceAll('\\', '/');
    final parts = <String>[];
    for (final part in combined.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isEmpty) {
          throw BookReaderException(
            kind: BookReaderErrorKind.epubUnsafePath,
            userMessage: 'This book contains an unsafe file path.',
          );
        }
        parts.removeLast();
      } else {
        parts.add(part);
      }
    }
    return parts.join('/');
  }
}

class _ParsedOpf {
  const _ParsedOpf({
    required this.title,
    required this.manifest,
    required this.spineIdRefs,
    required this.itemTitles,
  });

  final String? title;
  final Map<String, String> manifest;
  final List<String> spineIdRefs;
  final Map<String, String> itemTitles;
}
