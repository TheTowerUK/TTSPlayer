/// Synthetic Open Library fixtures for deterministic tests (M7.2).
abstract final class OpenLibraryTestFixtures {
  static const validIsbn13 = '9780140449136';
  static const validIsbn10 = '0140449132';

  static String get booksApiSuccess => '''
{
  "ISBN:$validIsbn13": {
    "url": "https://openlibrary.org/books/OL45804M",
    "key": "/books/OL45804M",
    "title": "The Republic",
    "subtitle": "A Dialogue",
    "authors": [
      {"url": "https://openlibrary.org/authors/OL123A", "name": "Plato"}
    ],
    "publishers": ["Penguin Classics"],
    "publish_date": "2007",
    "languages": [{"key": "/languages/eng"}],
    "subjects": ["Political science", "Philosophy"],
    "description": "A classic work.",
    "identifiers": {
      "isbn_10": ["0140449132"],
      "isbn_13": ["9780140449136"]
    },
    "works": [{"key": "/works/OL45804W"}]
  }
}
''';

  static const booksApiMissing = '{}';

  static const searchMultiple = '''
{
  "numFound": 2,
  "docs": [
    {
      "key": "/works/OL100W",
      "title": "Alpha Book",
      "author_name": ["Author One"],
      "first_publish_year": 2001,
      "edition_key": ["OL100M"],
      "isbn": ["9780000000001"],
      "score": 12.5
    },
    {
      "key": "/works/OL200W",
      "title": "Beta Book",
      "author_name": ["Author Two"],
      "first_publish_year": 2002,
      "edition_key": ["OL200M"],
      "isbn": ["9780000000002"],
      "score": 8.0
    }
  ]
}
''';

  static const searchSparse = '''
{
  "numFound": 1,
  "docs": [
    {
      "title": "Sparse Title"
    }
  ]
}
''';

  static String get descriptionObject => '''
{
  "ISBN:$validIsbn13": {
    "title": "Object Description",
    "key": "/books/OL999M",
    "description": {"type": "/type/text", "value": "Nested description."}
  }
}
''';

  static const duplicateCandidates = '''
{
  "numFound": 2,
  "docs": [
    {
      "title": "Duplicate Book",
      "edition_key": ["OL555M"],
      "author_name": ["Same Author"],
      "first_publish_year": 1999,
      "score": 5.0
    },
    {
      "title": "Duplicate Book",
      "edition_key": ["OL555M"],
      "author_name": ["Same Author"],
      "first_publish_year": 1999,
      "score": 3.0
    }
  ]
}
''';

  static const malformedJson = '{not-json';

  static const wrongRootType = '[]';
}
