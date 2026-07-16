/// Whether a diagnostics section was fully populated, partially read, or unavailable.
enum DiagnosticSectionStatus {
  /// All intended fields were read successfully.
  complete,

  /// Some fields are present; one or more field reads failed or were skipped.
  partial,

  /// The section could not be populated.
  unavailable,
}
