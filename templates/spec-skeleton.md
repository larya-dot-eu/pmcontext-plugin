# [Feature Name] — Design Spec

**Date:** YYYY-MM-DD
**Status:** Spec — ready for plan authoring

---

## Problem

[One paragraph. What breaks or is missing today?]

---

## Goal

[One paragraph. What does done look like? Explicit exclusions go in Out of Scope below.]

---

## Interfaces

### [Interface name — one subsection per changed interface]

**File:** `exact/path/to/file.ext:approximate-line`

**Before:**
```
// paste exact current signature from the file
// write [new file] if this file does not exist yet
```

**After:**
```
// exact new signature — no prose, no placeholders
// if this type originates from a third-party library, record one of:
//   [CONTEXT7] docs fetched for <library>
//   [KNOWN] <library>/<API> — core stable API, no fetch needed
```

---

## Edge Cases & Error States

| Condition | Input / Trigger | Expected Behavior | Error Returned |
|---|---|---|---|
| Empty input | | | |
| Invalid type or format | | | |
| External dependency failure | | | |

*(minimum 3 rows required — add more as needed)*

---

## Access-Control Matrix

| Role | Resource | Can read | Can create / modify / delete | Ownership key | Enforced by |
|---|---|---|---|---|---|
| anon | | | | | |
| user | | | | | |
| admin | | | | | |
| service | | | | | |

**Token revocation:** [If a valid token is stolen right now, how is it revoked before it expires? Name the mechanism — denylist, short-lived + refresh, session table — or state "not revocable" explicitly.]

*(required — never blank.)*

- One row per **role × resource** this feature touches — a resource is a table, endpoint group, or file store (`comments`, `avatars`, `tags`). Add or drop rows as needed; the four roles above are a starting list, not a fixed set.
- `(Role, Resource)` is the identity of a row. Phase 9 merges this table into the project-wide one in `CLAUDE.md` on that pair, so name resources exactly as they are named elsewhere in the project.
- `Ownership key` is the column that scopes a role to its own rows (`comments.author_id`). Write `—` where the role has no ownership scope.
- `Enforced by` names where the check actually runs. Prefer the database (e.g. an RLS policy) over app code — app-code-only enforcement is a finding worth stating.
- No access boundaries at all? Say so in one explicit row rather than leaving blanks: `all | <resource> | all | all | — | nothing — public by design`, plus a sentence on why that is safe here.

---

## Expected Scale

| Dimension | Target | Source |
|---|---|---|
| Peak traffic (req/s, concurrent users) | | measured / assumed |
| Hot-table rows — now → 1 year | | measured / assumed |
| Which data grows unbounded | | |
| Hot queries needing an index | | |
| Big scans or joins | | |
| Where state lives (DB / shared store — never process memory) | | |

*(required — every row needs a named number, even a guessed one. "Unknown" is not an answer; write the assumption and mark it `assumed`.)*

---

## Out of Scope

- [explicit exclusion — what this deliberately does not build]

*(minimum 1 entry required)*

---

## Assumptions

| Assumption | Verified by |
|---|---|
| [state the assumption] | [file:line or "confirmed with user"] |
