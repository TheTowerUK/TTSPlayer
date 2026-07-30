import 'dart:convert';

import '../../../../models/media_kind.dart';
import '../../models/book_search_request.dart';
import '../../models/isbn_lookup_request.dart';
import '../../models/provider_attribution.dart';
import '../../transport/http_metadata_http_transport.dart';
import '../../transport/metadata_http_transport.dart';
import '../book_metadata_provider.dart';
import '../book_metadata_provider_failure.dart';
import '../book_metadata_provider_result.dart';
import 'open_library_config.dart';
import 'open_library_response_parser.dart';

/// Open Library book metadata adapter (M7.2).
class OpenLibraryBookMetadataProvider implements BookMetadataProvider {
  OpenLibraryBookMetadataProvider({
    required MetadataHttpTransport transport,
    OpenLibraryConfig config = const OpenLibraryConfig(
      userAgent: OpenLibraryConfig.defaultUserAgent,
    ),
    OpenLibraryResponseParser? parser,
  })  : _transport = transport,
        _config = config,
        _parser = parser ?? const OpenLibraryResponseParser();

  static const providerIdValue = 'open_library';

  final MetadataHttpTransport _transport;
  final OpenLibraryConfig _config;
  final OpenLibraryResponseParser _parser;

  @override
  String get providerId => providerIdValue;

  @override
  Set<MediaKind> get supportedKinds => const {MediaKind.book};

  @override
  ProviderAttribution get attribution => _parser.attribution;

  @override
  Future<BookMetadataLookupResult> lookupByIsbn(
    IsbnLookupRequest request, {
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  }) async {
    if (!request.isValid) {
      return BookMetadataLookupFailure(
        BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.invalidRequest,
        ),
      );
    }

    final cancel = options.cancellationToken;
    if (cancel?.isCancelled ?? false) {
      return const BookMetadataLookupFailure(
        BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.cancelled,
        ),
      );
    }

    final uri = Uri.parse('${_config.baseUrl}/api/books').replace(
      queryParameters: {
        'bibkeys': 'ISBN:${request.normalizedIsbn}',
        'format': 'json',
        'jscmd': 'data',
      },
    );

    try {
      final response = await _transport.get(
        uri,
        headers: _requestHeaders(),
        timeout: options.timeout ?? _config.defaultTimeout,
        cancellationToken: cancel,
      );

      final failure = _mapHttpFailure(response);
      if (failure != null) {
        return BookMetadataLookupFailure(failure);
      }

      if (!_isJsonResponse(response)) {
        return const BookMetadataLookupFailure(
          BookMetadataProviderFailure(
            category: BookMetadataProviderFailureCategory.unsupportedResponse,
          ),
        );
      }

      final decoded = _decodeJson(response.body);
      if (decoded == null) {
        return const BookMetadataLookupFailure(
          BookMetadataProviderFailure(
            category: BookMetadataProviderFailureCategory.malformedResponse,
          ),
        );
      }

      final fetchedAt = DateTime.now().toUtc();
      final metadata = _parser.parseBooksApiResponse(
        decoded,
        request.normalizedIsbn,
        fetchedAt: fetchedAt,
      );
      return BookMetadataLookupSuccess(metadata);
    } on MetadataTransportCancelledException {
      return const BookMetadataLookupFailure(
        BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.cancelled,
        ),
      );
    } on MetadataTransportTimeoutException {
      return const BookMetadataLookupFailure(
        BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.timeout,
        ),
      );
    } on MetadataTransportNetworkException {
      return const BookMetadataLookupFailure(
        BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.networkUnavailable,
        ),
      );
    } catch (_) {
      return const BookMetadataLookupFailure(
        BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.unknown,
        ),
      );
    }
  }

  @override
  Future<BookMetadataSearchResult> search(
    BookSearchRequest request, {
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  }) async {
    if (!request.isValid) {
      return BookMetadataSearchFailure(
        BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.invalidRequest,
        ),
      );
    }

    final cancel = options.cancellationToken;
    if (cancel?.isCancelled ?? false) {
      return const BookMetadataSearchFailure(
        BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.cancelled,
        ),
      );
    }

    final params = <String, String>{
      'limit': request.limit.toString(),
      'fields':
          'key,title,subtitle,author_name,first_publish_year,publish_year,'
          'publisher,language,subject,isbn,edition_key',
    };
    final title = request.normalizedTitle;
    final author = request.normalizedAuthor;
    if (title != null) params['title'] = title;
    if (author != null) params['author'] = author;
    if (request.publicationYear != null) {
      params['first_publish_year'] = request.publicationYear.toString();
    }

    final uri = Uri.parse('${_config.baseUrl}/search.json').replace(
      queryParameters: params,
    );

    try {
      final response = await _transport.get(
        uri,
        headers: _requestHeaders(),
        timeout: options.timeout ?? _config.defaultTimeout,
        cancellationToken: cancel,
      );

      final failure = _mapHttpFailure(response);
      if (failure != null) {
        return BookMetadataSearchFailure(failure);
      }

      if (!_isJsonResponse(response)) {
        return const BookMetadataSearchFailure(
          BookMetadataProviderFailure(
            category: BookMetadataProviderFailureCategory.unsupportedResponse,
          ),
        );
      }

      final decoded = _decodeJson(response.body);
      if (decoded == null) {
        return const BookMetadataSearchFailure(
          BookMetadataProviderFailure(
            category: BookMetadataProviderFailureCategory.malformedResponse,
          ),
        );
      }

      final fetchedAt = DateTime.now().toUtc();
      final candidates = _parser.parseSearchResponse(
        decoded,
        fetchedAt: fetchedAt,
        requestedLimit: request.limit,
      );
      return BookMetadataSearchSuccess(candidates);
    } on MetadataTransportCancelledException {
      return const BookMetadataSearchFailure(
        BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.cancelled,
        ),
      );
    } on MetadataTransportTimeoutException {
      return const BookMetadataSearchFailure(
        BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.timeout,
        ),
      );
    } on MetadataTransportNetworkException {
      return const BookMetadataSearchFailure(
        BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.networkUnavailable,
        ),
      );
    } catch (_) {
      return const BookMetadataSearchFailure(
        BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.unknown,
        ),
      );
    }
  }

  Map<String, String> _requestHeaders() => {
        'User-Agent': _config.userAgent,
        'Accept': 'application/json',
      };

  BookMetadataProviderFailure? _mapHttpFailure(MetadataHttpResponse response) {
    switch (response.statusCode) {
      case >= 200 && < 300:
        return null;
      case 400:
        return const BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.malformedResponse,
        );
      case 401:
        return const BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.authentication,
        );
      case 403:
        return const BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.authorization,
        );
      case 404:
        return null;
      case 429:
        return BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.rateLimited,
          retryAfter: _parseRetryAfter(response.headers),
        );
      case >= 500:
        return const BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.providerUnavailable,
        );
      default:
        return const BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.unknown,
        );
    }
  }

  Duration? _parseRetryAfter(Map<String, String> headers) {
    final raw = headers['retry-after'];
    if (raw == null) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds != null) return Duration(seconds: seconds);
    return null;
  }

  bool _isJsonResponse(MetadataHttpResponse response) {
    final mediaType = _normalizedMediaType(response.contentType);
    if (mediaType == 'application/json' ||
        (mediaType?.endsWith('+json') ?? false)) {
      return true;
    }
    final trimmed = response.body.trimLeft();
    return trimmed.startsWith('{') || trimmed.startsWith('[');
  }

  String? _normalizedMediaType(String? contentType) {
    if (contentType == null) return null;
    final trimmed = contentType.trim().toLowerCase();
    final semicolon = trimmed.indexOf(';');
    return semicolon == -1 ? trimmed : trimmed.substring(0, semicolon).trim();
  }

  Map<String, dynamic>? _decodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }
}
