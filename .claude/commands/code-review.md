# Code Review: Maintainability Assessment

Review the recently changed files in this Flutter game project for maintainability issues. Use `git diff HEAD` or `git diff main` to get the diff, then read each changed file before assessing.

## Process

1. Run `git diff HEAD` (or the specific commit/branch provided as $ARGUMENTS) to see what changed.
2. Read each modified source file in full — diff alone misses context.
3. Work through the checklist below. For each issue found, note: **file:line**, **severity**, and a one-line fix.
4. At the end, give a **verdict**: PASS (ship it), REVISE (fix before merge), or REWRITE (too coupled/fragile to carry forward).

---

## Maintainability Checklist

### HIGH severity — fix before merge

**1. Platform imports in game logic**
- `dart:html`, `dart:io`, or `dart:js` inside `lib/game/`, `lib/models/`, or `lib/game/systems/`
- These files compile only on specific targets and break `flutter test`
- Fix: extract behind an abstract interface; keep platform code in a platform-specific layer

**2. Non-injectable `Random()` instances**
- `math.Random()` constructed inline inside any `update()`, system method, or model
- Makes tests nondeterministic; any positional or outcome test will flake
- Fix: inject `Random` via constructor parameter or pass as argument to the method

**3. Cross-system direct calls in `update()` hot path**
- A system (e.g. `BallSystem`) calling another system's mutable methods (e.g. `CombatSystem.applyDamage`) inside the per-frame `update()` loop
- Creates hidden coupling that makes unit tests require fully initialised multi-system state
- Fix: emit an event/command object; let a coordinator apply it — OR accept the coupling but document it and ensure tests exercise the integrated path

**4. `.toList()` or `List(...)` allocation inside `update()` / paint callbacks**
- Any `someIterable.toList()`, `[...someList]`, or `List.of(...)` called every frame
- Causes GC pressure at 60 fps; measurable frame drops on mobile
- Fix: cache the list; only rebuild on `markRosterDirty()`-equivalent events

**5. Side-effecting getters**
- A getter that mutates state, triggers a cache rebuild, or calls listeners
- Example: `get fieldPlayers { if (_dirty) _rebuild(); return _cache; }` — mutates `_dirty` on read
- These are invisible to callers and ordering-sensitive
- Flag but do not require rewrite; add a comment explaining the invariant

**6. State machine missing exit condition**
- A boolean flag or enum that is set to `true`/`entering` but never cleared back to `false`/`idle` except via unrelated code paths
- Example: `showingRosterScreen = true` set in `endAct()` but cleared in `startNextAct()` — any code path that skips `startNextAct()` leaves the flag stuck
- Fix: pair every setter with an explicit exit path or a TTL

---

### MEDIUM severity — address or document before merge

**7. Magic numbers in game logic**
- Unnamed numeric literals in damage formulas, timers, cooldowns, radii, speed values
- Makes balance tuning require grep + search rather than a constants file
- Threshold: more than one use of the same literal, OR any literal in a formula
- Fix: extract to named `static const` in the owning class

**8. Duplicated logic blocks (DRY violations)**
- The same guard pattern, formula, or multi-step operation appearing 3+ times
- Common in this codebase: Sprint ability duplicated per player class; ball-drop code in 4 systems
- Fix: extract a shared static helper; accept minor coupling if the helper is simpler than an abstraction

**9. Testability blockers — private state, no injection point**
- Private mutable state with no test-accessible constructor or factory
- Private maps/caches built only in `initialize()` that tests cannot populate
- Flag: name the class and field; recommend `ClassName.forTesting({...})` factory

**10. Single responsibility violations**
- A method or class doing: rendering + logic, or: scoring + player-selection + ball-reset
- Identify the unrelated responsibilities and flag them
- Do not demand refactor on the first occurrence; require it only on 3+ responsibilities in one method

---

### LOW severity — note only, no block

**11. Naming that requires context to understand**
- Single-letter variables outside of loop indices and math
- Abbreviations that aren't universal (`gs` is fine for `GameState`; `t` for target is borderline)

**12. Dead code / commented-out blocks**
- Commented code, `// TODO` older than the current sprint, unreachable `else` branches
- Remove or file a ticket

---

## Verdict Criteria

| Verdict | Condition |
|---------|-----------|
| **PASS** | Zero HIGH issues; MEDIUM issues are documented or trivially fixable inline |
| **REVISE** | 1–2 HIGH issues that can be fixed in < 30 min without API changes |
| **REWRITE** | 3+ HIGH issues, OR any HIGH issue that requires changing the public API of multiple systems, OR the feature is demonstrably untestable |

---

## Output Format

```
## Files reviewed
- path/to/file.dart (N lines changed)

## Issues

### HIGH
- ball_system.dart:103 — `math.Random()` inline in update(). Inject via parameter.
- game_state.dart:211 — `dart:html` transitively imported via game_data_collector. Already fixed via GameDataSink abstraction.

### MEDIUM
- combat_system.dart:48 — magic number `2.5` (melee range) appears 14×. Extract to `static const meleeRange = 2.5`.

### LOW
- act_system.dart:200 — variable `t` used for target player; rename to `target`.

## Verdict: PASS / REVISE / REWRITE
Reason: one sentence.
```
