import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/matching/isbn_equivalence.dart';

void main() {
  group('IsbnEquivalence', () {
    test('normalizes valid ISBN-13 and ISBN-10', () {
      expect(
        IsbnEquivalence.normalizeValid('978-0-14-044913-6'),
        '9780140449136',
      );
      expect(
        IsbnEquivalence.normalizeValid('0-14-044913-2'),
        '0140449132',
      );
    });

    test('rejects invalid checksum', () {
      expect(IsbnEquivalence.normalizeValid('9780140449137'), isNull);
    });

    test('rejects invalid length and characters', () {
      expect(IsbnEquivalence.normalizeValid('123'), isNull);
      expect(IsbnEquivalence.normalizeValid('978014044913A'), isNull);
    });

    test('converts ISBN-10 to 978 ISBN-13', () {
      expect(
        IsbnEquivalence.isbn10ToIsbn13('0140449132'),
        '9780140449136',
      );
    });

    test('converts 978 ISBN-13 to ISBN-10', () {
      expect(
        IsbnEquivalence.isbn13ToIsbn10('9780140449136'),
        '0140449132',
      );
    });

    test('does not convert 979 ISBN-13 to ISBN-10', () {
      expect(
        IsbnEquivalence.isbn13ToIsbn10('9791234567890'),
        isNull,
      );
    });

    test('detects equivalent collections', () {
      final result = IsbnEquivalence.compareCollections(
        localIsbn10: const ['0140449132'],
        localIsbn13: const [],
        candidateIsbn10: const [],
        candidateIsbn13: const ['9780140449136'],
      );
      expect(result, IsbnComparisonResult.match);
    });

    test('detects conflicts when both sides have valid unlike identifiers', () {
      final result = IsbnEquivalence.compareCollections(
        localIsbn10: const [],
        localIsbn13: const ['9780140449136'],
        candidateIsbn10: const ['0061120081'],
        candidateIsbn13: const [],
      );
      expect(result, IsbnComparisonResult.conflict);
    });

    test('returns insufficient when one side lacks valid identifiers', () {
      final result = IsbnEquivalence.compareCollections(
        localIsbn10: const [],
        localIsbn13: const [],
        candidateIsbn10: const [],
        candidateIsbn13: const ['9780140449136'],
      );
      expect(result, IsbnComparisonResult.insufficient);
    });

    test('ignores invalid identifiers deterministically', () {
      final normalized = IsbnEquivalence.normalizeCollection([
        '9780140449136',
        'invalid',
        '9780140449136',
      ]);
      expect(normalized, ['9780140449136']);
    });

    test('matches when multiple identifiers include one equivalent pair', () {
      final result = IsbnEquivalence.compareCollections(
        localIsbn10: const ['0140449132', '0451524934'],
        localIsbn13: const [],
        candidateIsbn10: const [],
        candidateIsbn13: const ['9780140449136', '9780000000001'],
      );
      expect(result, IsbnComparisonResult.match);
    });
    test('invalid local identifiers do not produce conflict', () {
      final result = IsbnEquivalence.compareCollections(
        localIsbn10: const ['invalid'],
        localIsbn13: const [],
        candidateIsbn10: const [],
        candidateIsbn13: const ['9780140449136'],
      );
      expect(result, IsbnComparisonResult.insufficient);
    });
  });
}
