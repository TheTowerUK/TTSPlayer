/// Active catalogue source — drives Storage Status and Library Manager.
enum CatalogueSourceKind {
  liveNas,
  fallbackNas,
  demo,
}

extension CatalogueSourceKindLabels on CatalogueSourceKind {
  String get label => switch (this) {
        CatalogueSourceKind.liveNas => 'Live NAS',
        CatalogueSourceKind.fallbackNas => 'Fallback NAS',
        CatalogueSourceKind.demo => 'Demo Catalogue',
      };

  bool get isNas => this != CatalogueSourceKind.demo;
}
