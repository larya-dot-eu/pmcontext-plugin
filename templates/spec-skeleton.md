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

## Out of Scope

- [explicit exclusion — what this deliberately does not build]

*(minimum 1 entry required)*

---

## Assumptions

| Assumption | Verified by |
|---|---|
| [state the assumption] | [file:line or "confirmed with user"] |
