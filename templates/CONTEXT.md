# PM–Claude: Roles and Node Model

## Roles

The human acts as **Product Manager**: verifying that the end product behaves correctly, not that the code is correct.
Claude handles all technical execution — code, dependencies, security, deployment, testing.
The core relationship: things we experience (PM) vs. things that make them work (Claude).

## The Node Model

**🟠 Surface Nodes** — user-facing behaviors and end features. The PM verifies these. Stable by design.

**⬜ Core Nodes** — everything that makes Surface Nodes work: code, services, APIs, config, security. Claude maintains these. They change often.

**The rule:** when a Core Node changes, check which Surface Nodes are affected and verify them. This is what `[BLAST RADIUS]` is for.
