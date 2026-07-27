import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'epub_book_document.dart';
import 'epub_resource_loader.dart';

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
  late Future<String> _htmlFuture;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
    );
    _scrollController.addListener(_onScroll);
    _htmlFuture = _loadHtml();
  }

  @override
  void didUpdateWidget(covariant EpubChapterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter.href != widget.chapter.href) {
      _htmlFuture = _loadHtml();
      if (widget.initialScrollOffset > 0) {
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
  }

  Future<String> _loadHtml() async {
    if (widget.chapter.html != null) return widget.chapter.html!;
    return widget.document.loadChapterHtml(
      widget.document.spine.indexWhere((c) => c.href == widget.chapter.href),
    );
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
        ? widget.chapter.href
            .substring(0, widget.chapter.href.lastIndexOf('/') + 1)
        : '';

    return FutureBuilder<String>(
      future: _htmlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(
            child: Text('This chapter could not be loaded.'),
          );
        }
        final html = snapshot.data!;
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
              data: html,
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
                    return _EpubEmbeddedImage(
                      loader: widget.document.resourceLoader,
                      path: resolved,
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
      },
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

class _EpubEmbeddedImage extends StatelessWidget {
  const _EpubEmbeddedImage({
    required this.loader,
    required this.path,
  });

  final EpubResourceLoader loader;
  final String path;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>?>(
      future: loader.loadBytes(path),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final bytes = snapshot.data;
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
    );
  }
}
