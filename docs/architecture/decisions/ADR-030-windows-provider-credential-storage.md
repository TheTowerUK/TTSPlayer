# ADR-030: Windows Provider Credential Storage

**Status:** Proposed
**Date:** 2026-09-09
**Milestone:** M7 Phase 7.7.5
**Authors:** M7 production-hardening review

---

## Context

TTSPlayer currently ships one production metadata provider, Open Library, which requires no credential. Future providers may require API keys or tokens. Those secrets must be protected from casual filesystem inspection, copied settings/catalogues, diagnostics exports, and other Windows accounts. Protection from malware running as the same user, a compromised application process, administrator access, or transient process-memory exposure is outside this boundary.

Credentials must never be written to SharedPreferences, settings JSON, `catalog.json`, enrichment or artwork records, logs, diagnostics, surfaced exception text, or provider query strings where an authorization header is available. Plaintext persistence, hardcoded secrets, environment-file persistence, and reversible application encryption without separately protected key material are prohibited.

The two Windows candidates are Windows Credential Manager and an application-managed, user-scoped DPAPI-protected blob store.

## Decision

**Windows Credential Manager is the preferred future target behind a provider-credential-store abstraction.** Credentialed providers remain unsupported for persistent configuration until that abstraction and its Windows implementation pass the acceptance gates below. A session-only credential that must be re-entered may be considered separately, but no credential field may be added to current settings or enrichment persistence.

This ADR remains **Proposed**. Acceptance requires implementation/package selection, a Windows release-build exercise, deletion and rotation semantics, integration tests, and a diagnostics/logging leakage audit. Raw DPAPI-backed application storage is not the fallback without a separate design review.

Open Library does not use, require, initialize, or depend on this future credential storage.

## Rationale

| Concern | Windows Credential Manager | Application-managed DPAPI blob |
|---|---|---|
| Security boundary | OS credential vault scoped to the signed-in Windows user | DPAPI protects bytes for a user/machine context, but the application owns the surrounding file/index boundary |
| Persistence ownership | Windows owns vault persistence and access control | TTSPlayer owns file location, permissions, atomic writes, corruption recovery, and indexing |
| Delete/rotation | Stable target names support replace/delete semantics; implementation must verify overwrite and not-found behavior | Application must design atomic replacement, orphan cleanup, and partial-failure recovery |
| Flutter integration | Native API through a reviewed plugin/FFI adapter behind an injectable interface | Custom plugin/FFI plus a separate blob repository and lifecycle |
| Packaging | Requires validation of the selected plugin's Windows native/build requirements | Requires shipping and maintaining custom native code and storage conventions |
| Testability | In-memory contract fake plus Windows vault integration tests | Contract fake, crypto adapter tests, filesystem/corruption tests, and Windows integration tests |
| Migration | Provider-scoped target naming can support explicit versioned migration | Ciphertext format, index version, file migration, and cleanup all become application contracts |
| Backup/restore | Governed by Windows/account vault behavior; never treated as portable app data | Protected blobs generally fail after user/machine loss and can be copied without being recoverable |
| Portability | A cross-platform abstraction can select each OS vault | Windows-specific persistence format creates a migration burden |
| Supportability | Familiar OS-level inspection/removal and lower application data-recovery responsibility | More application-owned failure modes and support tooling |
| Leakage risk | Secret remains outside ordinary app persistence; names and boolean state still require redaction | Extra paths, filenames, blob metadata, and error surfaces increase leakage opportunities |

Credential Manager therefore provides the narrower application responsibility and the clearest operational boundary. The preference does not assert that any particular Flutter package is approved.

## Alternatives considered

### User-scoped DPAPI-backed application storage

Encrypt a credential with DPAPI and persist the protected blob in application support storage.

**Not selected as the leading target because:** TTSPlayer would own the blob schema, file/index permissions, atomicity, corruption recovery, deletion, migration, and backup failure modes. It remains a possible separately reviewed fallback if no acceptable Credential Manager integration is available.

### Plain settings or environment-file persistence

**Rejected because:** Secrets would be exposed through ordinary application files, backup/copy workflows, diagnostics, or support collection.

### Application-managed reversible encryption

**Rejected because:** Encryption without separately protected key material merely relocates the secret and does not establish a meaningful at-rest boundary.

### Implement secure storage during M7

**Rejected because:** Open Library requires no credential, no credentialed provider is approved, and unused security-sensitive code would add packaging and maintenance risk without enabling an M7 requirement.

## Security constraints

- Use opaque, stable provider/account target identifiers; never include the secret in a target name.
- Prefer authorization headers over query-string credentials where the future provider supports them.
- Return only configured/not-configured state to settings and diagnostics.
- Map native and provider failures to bounded categories without raw secret, header, URL, native exception, or stack-trace content.
- Explicit deletion must remove the vault entry; provider disablement alone must not imply deletion unless a future approved contract says so.
- Rotation must replace atomically from the application's perspective and must not retain superseded values.
- Never copy desktop credentials to NAS, catalogue, enrichment sidecars, or another platform automatically.

## Consequences

### Positive

- Secrets remain outside TTSPlayer's ordinary JSON and media metadata stores.
- Windows account scoping and vault lifecycle are delegated to the operating system.
- A provider-neutral interface leaves non-Windows platforms free to use their native vaults.

### Negative

- A native integration/package dependency and Windows packaging validation are required before a credentialed provider can ship.
- Vault contents are not portable TTSPlayer backup data and may not survive account or machine migration.
- Same-user process compromise remains outside the protection boundary.

### Neutral

- Credentialed providers remain unavailable for persistent configuration until this ADR's implementation gate passes.
- Open Library remains fully operational under its existing explicit opt-in lifecycle.

## Implementation boundary

Future implementation requires a minimal asynchronous store interface for read, write/replace, delete, and configured-state checks. Provider adapters receive credentials at request execution time without copying them into settings models, provider URLs, diagnostics DTOs, or persistence records. No implementation or dependency is added in Phase 7.7.5.

## Testing requirements

- Contract tests with an in-memory fake: absent, write/read, replace, delete, idempotent delete, and bounded failures.
- Windows integration tests for user scoping, persistence across app restart, rotation, deletion, denied access, and corrupt/unavailable vault state.
- Release-build and installer/package validation on supported Windows configurations.
- Redaction canaries across diagnostics screen/export, logs, provider errors, URLs, settings, enrichment, and artwork stores.
- Tests proving provider disablement and credential deletion remain separate explicit operations.

## Migration considerations

There is no existing persisted credential to migrate. A future target-name/version scheme must be documented before first use. Cross-machine restore must treat a missing vault entry as unconfigured and must never fall back to plaintext. Migration from Credential Manager to another store requires explicit read-write-verify-delete sequencing and rollback handling.

## Future provider implications

A credentialed provider must remain unavailable until secure storage is accepted and integrated. Provider-specific authentication, rotation, and revocation semantics require their own review. Future non-Windows clients use platform-native secure storage behind the same conceptual interface. NAS execution requires a separate server threat model and secret store; desktop credentials are never reused automatically.

## Related documents

- [ADR-028](./ADR-028-external-metadata-enrichment-boundary.md)
- [Phase 7.7 production-hardening plan](../../roadmap/m7-phase-7.7-production-hardening-plan.md)
- [Phase 7.7 closure report](../../roadmap/m7-phase-7.7-closure-report.md)
- [Metadata enrichment architecture](../metadata-enrichment.md)
