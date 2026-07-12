# Architecture Decision Records (ADRs)

TTSPlayer uses **Architecture Decision Records** to capture significant technical decisions in a durable, reviewable form. ADRs complement roadmap and architecture planning documents — they record **what was decided and why**, not implementation task lists.

---

## What is an ADR?

An ADR is a short markdown document describing a single architectural decision: the context, the choice made, alternatives considered, and consequences. ADRs are immutable once accepted — if a decision changes, add a new ADR that supersedes the old one.

---

## When an ADR is required

Create an ADR when a decision:

- Affects more than one layer (UI, service, persistence, deployment)
- Is hard to reverse without migration cost
- Introduces a new persistence format, cache contract, or provider contract
- Changes M3/M3.5 behaviour that users rely on (fallback, resume, catalogue loading)
- Has multiple reasonable alternatives worth documenting

**Not required** for: routine UI polish, single-widget refactors, bug fixes that restore documented behaviour, or choices already fully specified in an accepted architecture doc.

---

## ADR numbering format

| Element | Convention |
|---|---|
| Filename | `ADR-NNN-short-decision-title.md` (three-digit zero-padded number) |
| Location | `docs/architecture/decisions/` |
| Sequence | Increment `NNN` monotonically; never reuse numbers |
| Status values | `Proposed` · `Accepted` · `Deprecated` · `Superseded by ADR-XXX` |

Example: `ADR-001-settings-schema-versioning.md`

---

## Required sections

Every ADR must include these headings (use [ADR-template.md](./ADR-template.md)):

| Section | Content |
|---|---|
| **Status** | Proposed, Accepted, Deprecated, or Superseded |
| **Context** | Problem and forces — what motivates a decision |
| **Decision** | What we will do |
| **Rationale** | Why this option over others |
| **Consequences** | Positive, negative, and neutral outcomes |
| **Alternatives considered** | Options rejected and brief why |
| **Related documents** | Roadmap phase, architecture docs, PRs |

---

## Workflow

1. Copy [ADR-template.md](./ADR-template.md) to a new numbered file during the **Plan** or **Document architecture** step of a sub-phase.
2. Set status to **Proposed**; link from the relevant architecture planning doc.
3. Review alongside implementation PR.
4. Set status to **Accepted** when the sub-phase closes.
5. If superseded, update old ADR status and link forward — do not delete historical ADRs.

---

## Index

| ADR | Title | Status |
|---|---|---|
| [ADR-001](./ADR-001-provider-health-model.md) | Provider Health Model | Accepted |
| [ADR-002](./ADR-002-provider-refresh-lifecycle.md) | Provider Refresh Lifecycle | Accepted |
| [ADR-003](./ADR-003-provider-status-presentation.md) | Provider Status Presentation | Accepted |
| [ADR-004](./ADR-004-settings-storage-and-versioning.md) | Settings Storage and Versioning | Proposed |
| [ADR-005](./ADR-005-settings-information-architecture.md) | Settings Information Architecture | Proposed |
| [ADR-006](./ADR-006-settings-validation-and-apply-behaviour.md) | Settings Validation and Apply Behaviour | Proposed |

---

## Related documents

- [M4 plan](../roadmap/m4-plan.md) — engineering principle #10
- [Architecture index](../README.md)
