import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'epub_book_document.dart';

/// Renders EPUB chapter HTML with blocked external navigation and local images.
class EpubChapterView extends StatelessWidget {
  const EpubChapterView({
    super.key,
    required this.chapter,
    required this.document,
    required this.textScale,
    this.onInternalLink,
  });

  final EpubSpineChapter chapter;
  final EpubBookDocument document;
  final double textScale;
  final void Function(String href)? onInternalLink;

  @override
  Widget build(BuildContext context) {
    final chapterDir = chapter.href.contains('/')
        ? chapter.href.substring(0, chapter.href.lastIndexOf('/') + 1)
        : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Html(
        data: chapter.html,
        onLinkTap: (url, attributes, element) {
          if (url == null) return;
          final lower = url.toLowerCase();
          if (lower.startsWith('http://') ||
              lower.startsWith('https://') ||
              lower.startsWith('mailto:')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('External links are not opened from books.'),
              ),
            );
            return;
          }
          onInternalLink?.call(url);
        },
        extensions: [
          TagExtension(
            tagsToExtend: {'img'},
            builder: (ctx) {
              final src = ctx.attributes['src'];
              if (src == null || src.isEmpty) {
                return const SizedBox.shrink();
              }
              if (src.toLowerCase().startsWith('http')) {
                return const Text('[External image blocked]');
              }
              final resolved = _resolveRelative(chapterDir, src);
              final bytes = document.resources[resolved];
              if (bytes == null) {
                return const Text('[Missing image]');
              }
              return Image.memory(
                Uint8List.fromList(bytes),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Text('[Image could not be displayed]'),
              );
            },
          ),
        ],
        style: {
          'body': Style(
            fontSize: FontSize(16 * textScale),
            lineHeight: const LineHeight(1.5),
            color: Colors.white,
          ),
          'p': Style(margin: Margins.only(bottom: 12)),
        },
      ),
    );
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
        if (parts.isNotEmpty) parts.removeLast();
      } else {
        parts.add(part);
      }
    }
    return parts.join('/');
  }
}
