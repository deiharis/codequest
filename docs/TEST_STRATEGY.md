# CodeQuest — Test Strategy

**Companion documents:** `docs/ARCHITECTURE.md`, `docs/REQUIREMENTS_TRACE.md`, `docs/DECISIONS.md`

---

## 1. Current position

**Automated:** five checks, T1–T5, covering question-bank integrity,
progression arithmetic, save round-trip, the Bug Lord exam threshold, and world
database integrity. **1159 assertions, all passing.**

    godot --headless res://tests/TestRunner.tscn

Implemented in `tests/run_tests.gd` — one file, no plugin, no framework. Exits
0 on pass and 1 on failure.

**Manual:** everything else. Every requirement in `REQUIREMENTS_TRACE.md` marked
*Met* that is not covered by T1–T5 was verified by running the game and looking
at it, against an expected result written before the test was run.

What follows is: what the manual process was and why it caught more than it
looks like it should have; the defects both processes found; the risk analysis
that chose those five checks; and the manual suite that has to exist regardless.

---

## 2. What verification actually consisted of

The project ran on a **one-change-at-a-time protocol**, agreed at the start:

> Proceed one step at a time, and do not modify multiple unrelated systems in a
> single step. I will test and confirm each step before we move forward.

Each change was followed by a written handoff naming the exact steps to
perform, **the observable result to expect**, and the two or three realistic
failure modes with their symptoms. The change was not considered done until the
expected result was confirmed.

This is manual testing, but it has two properties that ad-hoc clicking does
not:

1. **The expected result was written before the test was run.** A test whose
   expectation is formed after seeing the output confirms nothing.
2. **The blast radius of each change was one system.** When something broke,
   the cause was in the diff that had just landed.

That is why a project with no test suite has a defect list this short and this
well-diagnosed.

---

## 3. Defect log

Every defect found during development, with its root cause. This is the
evidence base for the risk analysis in §4.

| # | Defect | Root cause | Class |
|---|---|---|---|
| 1 | Layout squeezed into the upper-left ~60% | Design resolution raised to 1920×1080 while all content was authored in 1152×648 coordinates | Configuration |
| 2 | `SceneRouter` autoload not found | Externally written script not yet in the UID cache; a new script needs a project reload before it can be referenced | Tooling |
| 3 | Planets unclickable after routing change | `SpaceMap` still called the replaced `SceneManager`, holding a stale autoload reference | Incomplete migration |
| 4 | Planets blurry | Global Linear texture filtering applied to deliberate pixel art | Configuration |
| 5 | Battle would hang forever on the first attack | Every `SpriteFrames` has `loop = 1`; Godot never emits `animation_finished` for a looping animation | Engine behaviour |
| 6 | Characters shrank when attacking | Sheets differ both in frame height and in how much of the frame the character fills | Asset inconsistency |
| 7 | Space Map loaded a `SpriteFrames` as a `WorldData` | `DirAccess` scan matched every `.tres` in the worlds folder | Design |
| 8 | Questions would have been absent from any exported build | Godot's `csv_translation` importer claimed the file; the raw CSV is never packed | **Export-only** |
| 9 | Title art drew at full 1949×541 | `size` set before `expand_mode`, so a TextureRect's minimum size clamped it straight back up | Engine behaviour |
| 10 | `WorldData.general` disappeared | A file rebuilt from a stale cached copy taken before the field was added | Process |
| 11 | Two shadowing warnings | A parameter named the same as a field | Hygiene |
| 12 | Bug Lord painted over the HP bars and question panel | Combatants added to the tree after the UI; Godot draws in tree order | Engine behaviour |
| 13 | Starfield invisible | A child `ColorRect` painting over its own parent's `_draw` | Engine behaviour |
| 14 | **A test suite reported a pass having checked nothing** | T4 was run with `--script`, where autoloads do not exist, so `BattleController` failed to compile and no assertion executed | **Test infrastructure** |

### What the log says

- **Five of thirteen are Godot behaving correctly in a way the author did not expect** (#2, #5, #9, #12, #13). No test suite would have predicted these; they were found by running the thing and looking.
- **Two would only ever have appeared in an exported build** (#7 export half, #8). Both were found by reading, not by running — the editor was perfectly happy. **This is the most dangerous defect class in the project**, and §4 is built around it.
- **Defect #14 is the most instructive one in the table.** A test that fails is
  useful. A test that silently skips itself and reports success is worse than
  no test at all, because it converts an unknown into a false assurance. T4 now
  records an explicit failure if it cannot load what it is meant to check.
- **Two were process failures, not code failures** (#1, #10) — both caused by acting on a stale copy of something. Both are now covered by a working rule.
- **One (#6) was an art inconsistency**, fixable only partly in code, and the rest by a tuning value per character.

---

## 4. Risk analysis

Defect probability × cost of missing it:

| Risk | Likelihood | Cost | Mitigation |
|---|---|---|---|
| **Editor-only correctness** — works in the editor, fails when exported | High. Two instances already found | Total: an exported game with no questions or no worlds is unplayable | An export build must be produced and played before submission. Nothing else finds this class |
| **Sequencing regression** — a question appears before its animation finishes | Low. Three independent guards | High: unplayable battle | Automated check on the state machine (§5) |
| **Progression corruption** — a world cleared twice, or the Bug Lord over-damaged | Low. `clear_world()` is idempotent | High: the campaign can be finished from world one | Automated check (§5) |
| **Content errors** — a wrong answer key, a duplicated question | Medium. 129 hand-written rows | Medium: an educational game that teaches something false | Automated CSV validation (§5) |
| **Save incompatibility** — a save from an older build loads partially | Low. Version field is checked and a mismatch is refused outright | High: silent corruption | Already mitigated by design |
| **Asset drift** — a new sheet at a different scale | Medium | Low: visible immediately | Normalisation in code plus `ART_SPEC` checklist |

---

## 5. Automated checks — implemented

Deliberately **five checks, not a suite.** The value is concentrated in pure
logic that can be tested without a running game; testing animation or layout
automatically would cost more than it returns for a project this size.

They run as a **scene**, not with `--script`:

    godot --headless res://tests/TestRunner.tscn

That distinction is not cosmetic. Autoloads are only created when a main scene
runs, and `BattleController` references `GameState` at compile time — so under
`--script` that script fails to compile, T4 reads nothing, and the suite
reports a pass having checked nothing. See defect #14.

| Check | Asserts | Guards |
|---|---|---|
| **T1 Question bank integrity** | All 129 rows parse; every row has 4 options; every correct index is 0–3; no question text appears twice; every enemy id referenced by a world has a non-empty pool | Content errors; the "no repeats" claim in ADR-025 |
| **T2 Progression arithmetic** | 8 successive `clear_world()` calls take 8000 → 0; clearing an already-cleared world changes nothing; `is_world_unlocked` matches the cleared count | Progression corruption; the anti-farming guard |
| **T3 Save round-trip** | Save then load reproduces state exactly; a corrupt file is refused rather than half-applied; a wrong `version` starts fresh | Save incompatibility |
| **T4 Exam threshold** | 7 correct of 10 passes, 6 fails; the 4th wrong answer both fails the exam and empties a 100 HP hero | The Bug Lord rules in ADR-025 |
| **T5 World database integrity** | 8 worlds, `order_index` 0–7 with no gaps or duplicates; every world has a `general`; every planet has frames | Defect #7's class, permanently |

All five pass as of the current build: **1159 assertions, 0 failures.**

T3 deliberately writes an invalid save and a future-version save, so a passing
run *prints* `Parse JSON failed` and `save version 999.0 is not 1`. Those lines
are the refusal logic working, not a fault.

**T1 and T5 are the highest value** — they are pure data validation, they run in
milliseconds, and they cover the two defect classes most likely to recur as
content grows.

---

## 6. Manual test suite

These cannot be automated at reasonable cost and must be performed before
submission. Each has a fixed expected result.

### 6.1 Smoke

| # | Steps | Expected |
|---|---|---|
| M1 | Launch | Title screen: starfield, logo, New Game, Quit |
| M2 | New Game on a fresh save | Space Map, Reqoria lit, other seven dimmed |
| M3 | Hover each planet, locked and unlocked | Each enlarges and names its world and General; locked ones dimmed |
| M4 | Click a locked planet | Nothing happens |
| M5 | Click Reqoria | Fade, rocket travel left to right, planet approaches, fade into battle |

### 6.2 General fight

| # | Steps | Expected |
|---|---|---|
| M6 | Answer correctly | Hero lunges, strikes, enemy flashes and loses HP, hero returns, next question |
| M7 | Answer incorrectly | The same in reverse; correct answer highlights green; explanation appears |
| M8 | Click two answers rapidly | Exactly one resolves |
| M9 | Reduce the enemy to 0 HP | Defeat animation, then the Bug Lord encounter — **not** the map |

### 6.3 Bug Lord encounter

| # | Steps | Expected |
|---|---|---|
| M10 | Observe arrival | Rises from below; arena floods from drained to his colour |
| M11 | Answer correctly | Hero attacks; the Bug Lord's bar does **not** move; counter increments |
| M12 | Let a timer expire | Counts as wrong; he attacks |
| M13 | Reach 7 correct | Ultimate plays; bar drops exactly 1000; he withdraws; map returns with the next world lit |
| M14 | Answer 4 wrong | Returns to that world's **General**, full HP |
| M15 | Replay a cleared world and win | `bug_lord_hp` unchanged; Output prints `already cleared` |

### 6.4 Bugfall

| # | Steps | Expected |
|---|---|---|
| M16 | With 7 worlds cleared, click Bugfall | Straight to the Bug Lord, no General first |
| M17 | Bug Lord attacks | Black forked lightning with red edges and a red flash |
| M18 | Any General fight | No lightning |
| M19 | Pass the final encounter | Bar to 0; he plays **defeat**, not withdraw; victory screen |
| M20 | Fail the final encounter | Returns to the map, not into the fight again |

### 6.5 Persistence

| # | Steps | Expected |
|---|---|---|
| M21 | Clear a world, quit, relaunch | Continue offered; progress and Bug Lord HP correct |
| M22 | Delete the save, relaunch | Fresh campaign; no error |
| M23 | Corrupt the save with invalid JSON, relaunch | Starts fresh; a clear error in the log; no crash |
| M24 | New Game with progress | Asks to confirm; second press erases |

### 6.6 Export — **mandatory**

| # | Steps | Expected |
|---|---|---|
| M25 | Export a build and run it outside the editor | Launches |
| M26 | Start a fight in the exported build | **Questions appear.** This is the check for defect class #8 |
| M27 | Open the Space Map in the exported build | **All 8 planets present.** This is the check for defect #7's export half |
| M28 | Clear a world in the exported build, relaunch it | Progress persisted to the exported build's `user://` |

**M26 and M27 are the two most important tests in this document.** Both cover
failures that are invisible in the editor and total in a build.

---

## 7. Exit criteria for submission

1. T1–T5 pass, or are consciously waived.
2. M1–M24 pass in the editor.
3. **M25–M28 pass in an exported build.** Not waivable.
4. The Errors tab is clear after a full playthrough.
5. `REQUIREMENTS_TRACE.md` reflects the build being submitted.

---

## 8. What is deliberately not tested

- **Animation appearance and timing.** Verified by eye. Automating it would mean golden-image comparison, which is more machinery than this project justifies.
- **Layout at non-default window sizes.** `canvas_items` stretch makes this largely structural, and the game targets one aspect ratio.
- **Performance and memory.** Not measured. ADR-024 records VRAM at full roster as an open risk; it is untested rather than acceptable.
- **Input beyond mouse and Escape.** No keyboard or gamepad navigation exists to test.
