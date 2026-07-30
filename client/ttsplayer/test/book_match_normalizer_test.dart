import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/matching/book_match_normalizer.dart';

void main() {
  group('BookMatchNormalizer', () {
    test('normalizes case and whitespace', () {
      expect(
        BookMatchNormalizer.normalizeText('  The   Sample  '),
        'the sample',
      );
    });

    test('normalizes punctuation and ampersand', () {
      expect(
        BookMatchNormalizer.normalizeText('War & Peace: Part One'),
        'war and peace part one',
      );
    });

    test('treats straight and typographic apostrophes consistently', () {
      final straight = BookMatchNormalizer.normalizeComparableTokens(
        "Author's Guide",
      );
      final curly = BookMatchNormalizer.normalizeComparableTokens(
        'Author’s Guide',
      );
      expect(straight, curly);
      expect(straight, 'authors guide');
    });

    test('strips leading articles into alternate forms only', () {
      final forms = BookMatchNormalizer.normalizeTitle(
        title: 'The Republic',
      );
      expect(forms.full, 'the republic');
      expect(forms.articleStrippedFull, 'republic');
      expect(forms.main, 'the republic');
    });

    test('splits subtitles on colon and spaced dash', () {
      final colon = BookMatchNormalizer.normalizeTitle(
        title: 'Dune: Messiah',
      );
      expect(colon.main, 'dune');
      expect(colon.subtitle, 'messiah');

      final dash = BookMatchNormalizer.normalizeTitle(
        title: 'Dune — Messiah',
      );
      expect(dash.main, 'dune');
      expect(dash.subtitle, 'messiah');
    });

    test('strips bounded format markers from comparison title', () {
      final forms = BookMatchNormalizer.normalizeTitle(
        title: 'Sample Book (Paperback)',
      );
      expect(forms.full, 'sample book');
      expect(forms.formatMarkers, contains('paperback'));
    });

    test('detects edition and volume markers', () {
      final forms = BookMatchNormalizer.normalizeTitle(
        title: 'Sample Book Vol. 2 (2nd Edition)',
      );
      expect(forms.volumeNumber, 2);
      expect(forms.editionMarkers, isNotEmpty);
    });

    test('normalizes contextual roman numerals for volume', () {
      final forms = BookMatchNormalizer.normalizeTitle(
        title: 'Sample Series Volume IV',
      );
      expect(forms.volumeNumber, 4);
    });

    test('folds common diacritics deterministically', () {
      expect(
        BookMatchNormalizer.normalizeComparableTokens('García Márquez'),
        BookMatchNormalizer.normalizeComparableTokens('Garcia Marquez'),
      );
    });

    test('normalizes author initials and surname-first order', () {
      final authors = BookMatchNormalizer.normalizeAuthors([
        'Tolkien, J. R. R.',
      ]);
      expect(authors.primary, 'j r r tolkien');
      expect(authors.allExactKeys, contains('j r r tolkien'));
    });

    test('deduplicates multiple authors deterministically', () {
      final authors = BookMatchNormalizer.normalizeAuthors([
        'Plato',
        'plato',
      ]);
      expect(authors.displayOrder.length, 2);
      expect(authors.allExactKeys, ['plato']);
    });

    test('token-set jaccard is deterministic', () {
      final first = BookMatchNormalizer.tokenSetJaccard(
        'the republic plato',
        'republic by plato',
      );
      final second = BookMatchNormalizer.tokenSetJaccard(
        'the republic plato',
        'republic by plato',
      );
      expect(first, second);
      expect(first, closeTo(0.5, 1e-9));
    });

    test('handles empty and null values', () {
      expect(BookMatchNormalizer.normalizeText(null), '');
      expect(BookMatchNormalizer.normalizeAuthors([]).primary, '');
    });

    test('repeated execution is stable', () {
      for (var i = 0; i < 5; i++) {
        expect(
          BookMatchNormalizer.normalizeTitle(title: 'The Hobbit').full,
          'the hobbit',
        );
      }
    });

    test('article stripping does not replace full title comparison form', () {
      final theA = BookMatchNormalizer.normalizeTitle(title: 'The A');
      final a = BookMatchNormalizer.normalizeTitle(title: 'A');
      expect(theA.full, 'the a');
      expect(a.full, 'a');
      expect(theA.articleStrippedFull, 'a');
      expect(theA.full == a.full, isFalse);
    });

    test('short titles remain distinct after normalization', () {
      final it = BookMatchNormalizer.normalizeComparableTokens('It');
      final information = BookMatchNormalizer.normalizeComparableTokens(
        'Information Technology',
      );
      expect(it, 'it');
      expect(it == information, isFalse);
    });

    test('roman numerals require volume context', () {
      final standalone = BookMatchNormalizer.normalizeTitle(title: 'I');
      final contextual = BookMatchNormalizer.normalizeTitle(title: 'Volume I');
      expect(standalone.volumeNumber, isNull);
      expect(contextual.volumeNumber, 1);
    });

    test('weak surnames are excluded from surname matching keys', () {
      final authors = BookMatchNormalizer.normalizeAuthors(['Lee']);
      expect(authors.allSurnameKeys, isEmpty);
    });
  });

  group('author compatibility helpers', () {
    test('initial-compatible author keys match strongly', () {
      expect(
        authorExactKeysCompatible('j r r tolkien', 'j r r tolkien'),
        isTrue,
      );
      expect(
        authorExactKeysCompatible('j r tolkien', 'j r r tolkien'),
        isTrue,
      );
    });
  });
}
