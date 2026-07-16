# ADR-017: Diagnostics Architecture

**Status:** Accepted — implemented (M4 Phase 4.6 Step 2, 2026-07-16)  
**Milestone:** M4 Phase 4.6  
**Authors:** M4 documentation pass

---

## Context

TTSPlayer already exposes substantial runtime state across production services:

- `CatalogService` — provider snapshot, catalogue identity, load timestamps, error messages (ADR-001, ADR-002)
- `ArtworkService` — bounded candidate cache counters (ADR-015)
- `SearchService` — index lifecycle counters (ADR-016)
- `PlaybackService` — session state and error taxonomy (ADR-013)
- Dashboard **Provider Status** panel — operational summary (ADR-003)
- Settings **Diagnostics & Advanced** section — version display only (ADR-005)

Phase 4.5 deferred cache health UI to Phase 4.6. Test harnesses (`Phase45RuntimeBaseline`, `PHASE_45_RUNTIME`) prove instrumentation exists but are not user-facing.

Users and maintainers need in-app introspection without reading logs or source. The design must **consume existing state** rather than introduce parallel monitoring systems.

Constraints:

- Local-first; no remote telemetry
- No personal filesystem paths or secrets in UI or export
- Settings remains configuration; diagnostics remain read-only observation
- Production services must not depend on diagnostics types (no circular imports)

---

## Decision

### 1. Introduce `DiagnosticsService` as the sole aggregation owner

`DiagnosticsService` lives at the composition root (`main.dart` Provider tree). It:

- Receives references to existing services via constructor injection
- Builds an immutable `RuntimeDiagnosticsSnapshot` on demand
- Formats plain-text export via `formatExport()` (ADR-019)
- Does **not** mutate catalogue, cache, search, playback, or settings

Production services **never** import diagnostics types.

### 2. Sub-model DTOs map to existing owners

| DTO | Primary source | New measurement logic |
|---|---|---|
| `ApplicationDiagnostics` | `package_info`, app bootstrap timestamp | Startup elapsed only |
| `ProviderDiagnostics` | `CatalogService`, `MediaProviderConfigService` | None |
| `CatalogueDiagnostics` | `CatalogService`, `Catalog` | None |
| `CacheDiagnostics` | `ArtworkService`, Flutter `ImageCache` | None |
| `SearchDiagnostics` | `SearchService` | None |
| `PlaybackDiagnostics` | `PlaybackService`, `playback_platform.dart` | None |
| `LibraryDiagnostics` | `LibraryMetadataRepository` | None |

### 3. Promote diagnostics-facing getters; do not duplicate counters

Selected `@visibleForTesting` getters on `ArtworkService` and `SearchService` become **production diagnostics getters** (same backing fields). Test-only presentation metrics (`FolderPresentationMetrics`, `SearchPresentationMetrics`) remain excluded from production diagnostics.

### 4. Surface boundaries (ADR-003 preserved)

| Surface | Role |
|---|---|
| Dashboard Provider Status | Operational summary + refresh/retry |
| Settings sections | Editable configuration |
| Diagnostics screen | Deep read-only detail + copy/export |

Operational actions (refresh catalogue, open provider settings) stay on the dashboard and settings — not on the diagnostics screen.

### 5. Failure behaviour

`DiagnosticsService.buildSnapshot()` must complete even when individual sources are null or unavailable. Per-field fallbacks (`"Unavailable"`) — the screen must never throw.

**Implementation (Step 2):** Public API is `captureSnapshot()` (async for cached `package_info`). Plain-text formatting lives in `diagnostics_export_formatter.dart`; `DiagnosticsService.formatExport()` delegates without I/O.

---

## Rationale

- A single aggregator avoids scattering diagnostic reads across widgets and keeps redaction logic centralized.
- Consuming existing instrumentation honours Phase 4.5 investment and prevents drift between test counters and UI counters.
- Unidirectional dependency (diagnostics → services) preserves service layer purity and testability.
- Separating dashboard summary from diagnostics detail matches ADR-003 intent.

---

## Consequences

### Positive

- Support workflows gain structured in-app context without new background daemons.
- Export and tests can target one stable snapshot type.
- Phase 4.5 cache/search lifecycle evidence maps directly to user-visible health.

### Negative

- `DiagnosticsService` becomes a composition-root dependency with a wide constructor surface.
- Snapshot build must stay cheap (synchronous reads; no network on open).

### Neutral

- `DiagnosticsSettings` placeholder in `application_settings.dart` remains unused in 4.6 v1.
- Log ring buffer deferred — would require new collection infrastructure.

---

## Alternatives considered

| Alternative | Rejected because |
|---|---|
| Widgets read services directly | Duplicated redaction; harder to test export format |
| Extend Provider Status panel with cache/search detail | Violates ADR-003 dashboard conciseness |
| New `MonitoringService` with parallel counters | Duplicates Phase 4.5 instrumentation |
| JSON-only export | Plain text is more paste-friendly for support tickets (ADR-019) |
| Hidden developer section with test metrics | Test hooks are not session truth; adds IA complexity |

---

## Related documents

- [M4 Phase 4.6 specification](../../roadmap/m4-phase-4.6-diagnostics-supportability.md)
- [diagnostics.md](../diagnostics.md)
- [ADR-003](./ADR-003-provider-status-presentation.md) — dashboard vs diagnostics boundary
- [ADR-005](./ADR-005-settings-information-architecture.md) — Settings entry point
- [ADR-015](./ADR-015-artwork-and-image-decode-caching.md) — cache counters
- [ADR-016](./ADR-016-search-index-and-large-library-browsing.md) — search lifecycle
