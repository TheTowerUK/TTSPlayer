/// Reference implementation used during Gate 0 against package:unrar 0.1.2.
///
/// Not part of the Flutter package import graph (kept under tool/) because the
/// published package fails to build native assets on Windows MSVC.
///
/// Restore only after a Windows-capable RAR stack passes Gate 0.
library;

// Intentionally not importing package:unrar here while dependency is removed.
// See docs/architecture/cbr-rar-evaluation.md Gate 0 decision.
void main() {
  // ignore: avoid_print
  print(
    'Reference only. package:unrar was evaluated and failed Windows MSVC '
    'native hook compilation. See cbr-rar-evaluation.md.',
  );
}
