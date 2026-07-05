---
description: Multi-agent code review — correctness, security, architecture, and test coverage
---

Perform a multi-agent code review of the current branch (or $ARGUMENTS if a branch/commit range is given).

## Step 1 — Gather the diff

Run `git diff main...HEAD` (or `git diff $ARGUMENTS` if arguments were provided) to get the full changeset. Collect the list of modified files.

## Step 2 — Spawn four review agents IN PARALLEL

Send a single message containing all four Agent tool calls. Each agent must:
- Receive the diff and the list of changed files in its prompt
- Read each changed file in full before assessing (diff alone misses context)
- Return findings as a list of issues: **file:line | severity | description | fix**

### Agent 1 — Correctness
Look for: logic errors, incorrect assumptions, off-by-one errors, null/null-safety violations, unhandled edge cases, race conditions in the game loop, state that can get stuck (flags set but never cleared), and incorrect math in damage/speed/timer formulas.

### Agent 2 — Security
Look for: any data that crosses a trust boundary without validation (user input, external API responses, file reads), hardcoded secrets or credentials, unsafe use of `eval`/`dart:mirrors`/dynamic dispatch, platform API misuse (`dart:html` leaking into game logic), and injection vectors. For a game codebase, focus especially on: save-file tampering surface, any networked data paths, and WebGL/canvas APIs used without sanitisation.

### Agent 3 — Architecture and maintainability
Apply the checklist from `.claude/commands/code-review.md`. Additionally flag: violation of system boundaries (a system directly mutating another system's state), abstraction inversions (low-level models importing high-level systems), and any new global mutable singletons.

### Agent 4 — Test coverage
For each changed file: identify what is now untested. Flag: new public methods with no test, new conditional branches not exercised by any test, new game-state transitions not covered, and any change to existing logic whose tests were not updated. Reference the test files in `test/` to check what currently exists.

## Step 3 — Synthesize

Collect all findings from the four agents. Deduplicate (the same issue may be flagged by multiple agents — keep the most detailed description). Group by severity:

- **Critical** — data loss, crashes, security vulnerability, or broken game state with no recovery path
- **High** — incorrect behavior, untestable code, or platform coupling that breaks `flutter test`
- **Medium** — maintainability debt, magic numbers, DRY violations, missing test coverage
- **Low** — naming, dead code, minor style

## Output format

```
## Files reviewed
- path/to/file.dart  (+N / -N lines)

## Findings

### Critical
- file.dart:line — description. Fix: one-line remedy.

### High
- file.dart:line — description. Fix: one-line remedy.

### Medium
- file.dart:line — description. Fix: one-line remedy.

### Low
- file.dart:line — description. Fix: one-line remedy.

## Verdict: PASS | REVISE | REWRITE
Reason: one sentence.
```

Verdict criteria:
- **PASS** — zero Critical or High findings
- **REVISE** — 1–3 High findings fixable without API changes; zero Critical
- **REWRITE** — any Critical finding, or 4+ High findings, or any finding that requires changing the public API of multiple systems
