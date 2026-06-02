# Planning & Implementation Workflow

> **Invoke this skill at the start of any new feature, integration, or implementation session.**
> Work through every phase in order. Do not skip phases. Do not proceed past an exit gate until it is explicitly cleared.

---

## Prerequisites — Load Before Starting

Before Phase 1, load the following into context. If any are missing, stop and ask the user to provide them before continuing.

- **`CLAUDE.md`** — architecture rules, stack conventions, coding patterns, explicit constraints, what NOT to do
- **`ROADMAP.md`** — current project state, priorities, already-decided directions
- **Relevant existing code** — any files, modules, or APIs the planned work touches or must follow

After loading, summarize to the user:
- What you understand about the current project state
- Which architectural patterns and conventions apply to this session
- Any prior decisions that are relevant

Do not proceed to Phase 1 until the user confirms your summary is correct or provides corrections.

---

## Phase 1 — Context Priming

Confirm your working model of the project before any exploration begins.

State explicitly:
- The current relevant architecture and patterns
- Known constraints from `CLAUDE.md` and `ROADMAP.md`
- Stack conventions (integration patterns, external services, APIs, databases)
- Any prior decisions relevant to this session

**Exit gate:** Ask the user: *"Is this an accurate picture of the project context? Anything to correct or add before we explore the problem?"*
Do not proceed to Phase 2 until the user confirms.

---

## Phase 2 — Exploration (PM Mode)

Your role in this phase is to ask clarifying questions only. Do not propose solutions. Do not write specs. Do not suggest implementations.

Ask the user to define:
- **The why:** What problem does this solve? Why now?
- **The constraints:** Technical, time-based, dependency-based
- **What makes this case different:** How does this deviate from existing patterns in the codebase?

While exploring, surface:
- Ambiguities and unstated assumptions
- Which parts of the existing codebase are affected
- Anything in the existing code that complicates the request

**Exit gate (hard stop):** Before proceeding to Phase 3, you must be able to answer all three:
1. What is the exact problem being solved?
2. What are the constraints?
3. What makes this case different from existing patterns?

If you cannot answer all three clearly — stay in Phase 2 and ask the user for the missing clarity.

---

## Phase 3 — Spec Writing

Write a spec that covers:
- Behavior and expected outcomes
- Interfaces: inputs, outputs, APIs, data shapes
- Edge cases and error states
- Assumptions you are making — state them explicitly

### Transition Checkpoint Before Phase 4

Before writing any plan, run this check against the codebase:

> - Do any proposed APIs or types conflict with existing code?
> - Is anything in the spec assumed without being verified against the actual codebase?

Report your findings explicitly to the user. Do not summarize as "looks good." If conflicts or unverified assumptions exist, fix the spec before proceeding.

**Exit gate:** The spec is verified against the codebase. No unresolved conflicts. No unverified assumptions. User has approved the spec.

### Output Format

Two outputs, both saved to `docs/superpowers/specs/` (gitignored — local only, never committed):

**1. Markdown spec (primary — for Claude):**
`YYYY-MM-DD-[feature-name]-design.md` — structured prose with headers covering behavior, interfaces, edge cases, and assumptions. This is what future sessions read.

**2. HTML visual companion (for human review):**
`spec-[feature-name].html` — self-contained styled file generated from the same content. Must include:
- Sticky sidebar navigation linking to each section
- Color-coded sections: behavior (blue), interfaces (green), edge cases (amber), assumptions (red)
- All assumptions highlighted with a visible warning style
- A checklist of exit gate items the user can tick off while reviewing

---

## Phase 4 — Plan Writing

Break the verified spec into ordered, executable steps.

Each step must include:
- What code changes or actions are required
- The exit state after this step — is the codebase in a consistent or broken state between steps?
- How this step will be verified

### Transition Checkpoint Before Phase 5

After writing the plan, run these four questions against it. Answer each one with specific findings — not "yes":

> 1. Is verification built in at each step, not just at the end?
> 2. Are tasks and steps grouped by what is independently vs. dependently testable?
> 3. Did you extract everything relevant from the codebase and the conversation — constraints, limitations, non-obvious edge cases?
> 4. Are there external dependencies — APIs, file paths, database states, service availability — that the plan assumes exist but does not verify first?

Fix any issues found before proceeding.

**Exit gate:** All four questions answered with concrete findings. All issues resolved. User has approved the plan.

### Output Format

Two outputs, both saved to `docs/superpowers/plans/` (gitignored — local only, never committed):

**1. Markdown plan (primary — for Claude):**
`YYYY-MM-DD-[feature-name]-plan.md` — ordered steps with exit states and verification methods. This is what future sessions execute from.

**2. HTML visual companion (for human review):**
`plan-[feature-name].html` — self-contained styled file generated from the same content. Must include:
- Sticky sidebar navigation with phase links
- Color-coded phases: exploration (purple), spec (blue), plan (green), review (red), TDD (orange), implementation (teal)
- Each plan step as a card with: step number, action, exit state, verification method
- The dependency graph rendered as an inline SVG diagram
- Checkpoint questions rendered as a visible checklist the user ticks off before approving
- External dependencies called out in a highlighted warning box

**3. Session Launch section (required — in the plan file itself):**
Append a `## Session Launch` section at the bottom of the Markdown plan file:

```markdown
## Session Launch

What this builds:
Codebase state going in:
Files the plan touches:
Libraries touched:
Key design decisions:
Gotchas:
Start here:
End here:
```

Fill every field before the plan is marked approved. `Libraries touched:` should list any external libraries or APIs the plan interacts with — leave blank or write `—` if none. This section is what `/pmcontext:execute` reads at the start of each execution session.

---

## Phase 5 — Adversarial Review

Switch from generation mode to review mode. Your goal is to break the plan, not defend it.

Check:
- Trace each step's intermediate state: after this step, is the codebase consistent or is it broken between steps?
- Draw the actual dependency graph: what must already exist before each step can run?
- What did you observe in the codebase that is not yet documented in the plan?

### Loop-Back Decision

| Finding | Action |
|---|---|
| Surface fix — wrong step order, missing verification point | Return to Phase 4 and fix the plan |
| Architectural issue — wrong interface, broken dependency, broken intermediate state | Return to Phase 3 and fix the spec |
| Fundamental problem — wrong approach or wrong problem being solved | Return to Phase 2 and re-explore |

**Rollback rule:** If more than one-third of plan steps need reworking, do not patch. Restart from Phase 3.

**Exit gate:** The plan is structurally sound. No broken intermediate states. Dependency order is correct. All assumptions are surfaced and verified. User has approved.

---

## Phase 6 — TDD Planning

Do not start this phase until Phase 5 is complete and the plan is structurally sound. Designing tests against a broken plan wastes the work.

Define before writing any implementation code:
- What interface changes are needed? (functions, methods, APIs, data shapes)
- Which behaviors must be tested first? (critical paths, complex logic, integration points)
- Can each component have a deep module design? (small interface, complex logic inside)
- Can each component be designed for testability? (inject dependencies, return results instead of side effects, no hidden state)

Output a prioritized list of behaviors to test with interface definitions agreed.

**Exit gate:** Interface design agreed with the user. Test priority order defined. No implementation code written yet.

---

## Phase 7 — Implementation

Work in vertical slices. Complete one slice fully before starting the next.

For each slice:
1. Write one failing test — RED. The test defines the expected behavior.
2. Write the minimal code to make it pass — GREEN. No extra logic.
3. Refactor if needed — improve structure without changing behavior.
4. Move to the next slice.

### Scope Creep Rule

Do not:
- Refactor code not directly related to the current slice
- Add features or improvements you notice along the way
- Extend the plan unilaterally

If you spot something that should be changed, say:
> *"I noticed [X] while implementing this slice. I have noted it as a separate task and am continuing with the current slice."*

**Exit gate:** All plan steps implemented. All tests passing. No unplanned changes introduced.

---

## Phase 8 — Post-Implementation Review

Check:
- Did the implementation match the plan? If not, document what changed and why.
- Did any new constraints or patterns surface that should be added to `CLAUDE.md`?
- Did any edge cases appear during implementation that were not in the spec?
- Does `ROADMAP.md` need updating if direction shifted?

Report findings to the user. Flag any recommended doc updates.

**Rollback signal:** If the implementation diverged significantly from the plan without documented reasoning, treat this as a signal that the spec or adversarial review was insufficient. Note this for the next planning session.

**Exit gate:** Findings reported. Doc updates flagged or completed. User sign-off received.

---

## Phase 9 — Living Document Update

After each phase and after every major step, update:
- **Work plan document** — what is done, what changed, what is next
- **`CLAUDE.md`** — if new patterns or constraints were established during this session
- **`ROADMAP.md`** — if priorities or direction shifted

### Context Window Rule

At approximately 70% context window usage, stop and say:
> *"We are approaching context limits. I will update the living work plan now so this session can be resumed without loss."*

Write the update so that a fresh session with no conversation history can resume work immediately from the document alone.

---

## Quick Reference

```
Prerequisites    Load CLAUDE.md, ROADMAP.md, relevant code — confirm with user

Phase 1          Context Priming       Confirm project understanding — user approves before Phase 2
Phase 2          Exploration           Ask only — define why + constraints + what's different
                 EXIT GATE             All 3 questions answered clearly before Phase 3
Phase 3          Spec Writing          Behavior, interfaces, edge cases, explicit assumptions
                 CHECKPOINT            Spec vs. codebase: conflicts + unverified assumptions fixed
                 OUTPUT                spec-[feature].html — sidebar nav, color-coded, assumption warnings, checklist
Phase 4          Plan Writing          Ordered steps with exit states and verification
                 CHECKPOINT            4 adversarial questions answered with specific findings
                 OUTPUT                plan-[feature].html — step cards, SVG dependency graph, checkpoint checklist
Phase 5          Adversarial Review    Break the plan — loop back by finding type
                 LOOP-BACK             Surface fix → Ph.4 | Arch issue → Ph.3 | Wrong problem → Ph.2
Phase 6          TDD Planning          Interfaces + test priority agreed before any code written
Phase 7          Implementation        Red→Green→Refactor, vertical slices, scope creep rule enforced
Phase 8          Post-Implementation   Plan vs. reality, doc updates flagged
Phase 9          Living Doc Update     After each phase + proactively at ~70% context
```

---

## Core Rule

> Generation mode finds answers. Review mode finds problems.
> Every checkpoint and exit gate in this workflow forces a mode switch at the right moment.
> Do not treat them as optional. They exist to catch the failures that look invisible until implementation.
