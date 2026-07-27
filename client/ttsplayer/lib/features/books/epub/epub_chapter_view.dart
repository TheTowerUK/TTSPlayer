import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'epub_book_document.dart';

/// Renders EPUB chapter HTML with blocked external navigation and local images.
class EpubChapterView extends StatefulWidget {
  const EpubChapterView({
    super.key,
    required this.chapter,
    required this.document,
    required this.textScale,
    this.onInternalLink,
    this.initialScrollOffset = 0,
    this.onScrollOffsetChanged,
  });

  final EpubSpineChapter chapter;
  final EpubBookDocument document;
  final double textScale;
  final void Function(String href)? onInternalLink;
  final double initialScrollOffset;
  final ValueChanged<double>? onScrollOffsetChanged;

  @override
  State<EpubChapterView> createState() => _EpubChapterViewState();
}

class _EpubChapterViewState extends State<EpubChapterView> {
  late final ScrollController _scrollController;
  bool _layoutReady = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant EpubChapterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter.href != widget.chapter.href &&
        widget.initialScrollOffset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(
          widget.initialScrollOffset.clamp(
            0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    widget.onScrollOffsetChanged?.call(_scrollController.offset);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapterDir = widget.chapter.href.contains('/')
        ? widget.chapter.href.substring(0, widget.chapter.href.lastIndexOf('/') + 1)
        : '';

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification && !_layoutReady) {
          _layoutReady = true;
          widget.onScrollOffsetChanged?.call(_scrollController.offset);
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Html(
          data: widget.chapter.html,
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
            widget.onInternalLink?.call(url);
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
                final bytes = widget.document.resources[resolved];
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
              fontSize: FontSize(16 * widget.textScale),
              lineHeight: const LineHeight(1.5),
              color: Colors.white,
            ),
            'p': Style(margin: Margins.only(bottom: 12)),
          },
        ),
      ),
    );
  }

  static String _resolveRelative(String baseDir, String src) {
    if (src.startsWith('/')) return src.substring(1);
    if (!baseDir.endsWith('/')) {
      return '$baseDir$src';
    }
    return '$baseDir$src';
  }
}
