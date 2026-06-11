# AI PR Review Rules

This repository is a GitOps homelab (Flux + Talos). Most PRs are Renovate dependency
updates. Your review is the **second set of eyes that catches what CI cannot** — the
*substance* of a change — so the maintainer can make an informed merge decision.

## Your job — actively surface these (and `request_changes` when they need a decision)
- **New or changed options / features.** An upgrade that adds a config knob, a new
  capability worth enabling, or changes a default — call it out so the maintainer can
  decide whether to adopt or tune it.
- **Behavioral, breaking, or deprecation changes** stated in the release notes or
  evident in the diff (renamed/removed fields, changed defaults, required migrations,
  new mandatory values).
- **Security-relevant changes** — permissions, exposure, auth, default hardening.
- **Manual action required before/after merge** — a migration step, a new required
  secret/value, a flag that must change.
- **Risky or surprising diffs** — large version jumps (skipped majors), a digest that
  doesn't match the stated tag, value changes that look unintended.

When something above genuinely needs the maintainer's attention or action before
merging, **`request_changes` is correct** — that is the point of this review.

## What CI already owns — do not re-litigate or block on it
- Automated checks run on every PR (Flate render/diff, Kubernetes, Lint, GitGuardian
  secret scan) and are authoritative for build/render/lint/secret correctness. You do
  **not** see their output, and that is expected.
- Do **not** raise a finding, and never `request_changes`, because you cannot confirm
  that tests/CI/a "full test suite" ran, or to ask the author to "run the tests" or
  "verify it works on the cluster." Inability to see CI is not a property of the change
  and is not a defect. Assume CI ran and passed.

## Verdict & severity
- Base every finding on evidence actually in the diff, release notes, or linked sources
  — never on the absence of test/CI output.
- `request_changes` → a concrete defect, **or** a substantive change above that the
  maintainer should consciously act on/decide before merging.
- `approve` → the change is sound and there is nothing the maintainer needs to act on.
  A routine version/digest bump with no notable changes is an approve.
- `major` is for real defects or decisions-needed-before-merge. `info` is for FYIs and
  optional "you can now enable X" notes. Do not inflate "I couldn't verify X" into
  `major`.
