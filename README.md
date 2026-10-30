# CodeQuest

A game-based learning system for software engineering education, built in Godot 4.7.2.

Eight worlds, one per phase of the software development lifecycle. Each world teaches a
lesson, then tests it in a battle where **the question is the turn** — a correct answer is
the hero's attack, an incorrect one is the enemy's. There is no attack button. The
assessment is not wrapped around the game; it is the mechanic.

Built for BCSE301L Software Engineering at VIT Chennai.

---

## Why this repository might interest you

The game is the artefact. The engineering is the point.

**The architecture rule is enforced by a test, not by convention.**
Three layers — Presentation, Session, Data — with dependencies pointing downward only.
An automated check scans every script for an import that crosses a layer upward and fails
the build if it finds one. Adding a ninth world touches three content files and no
gameplay code, because no gameplay script names a world.

**State is derived, not stored.**
World unlock is computed from the cleared set. The Bug Lord's health is derived as
`8000 − 1000 × worlds_cleared` and never written down. Neither can drift out of agreement
with progression, because neither is a second copy of a fact that already exists.
`clear_world()` appends only if the id is absent, so replaying a cleared world cannot
advance the campaign twice.

**One battle scene runs nine different fights.**
No enemy is named anywhere in the battle code. A fight is produced by handing the
controller a data object; its appearance, values, timers and ending condition all come
from that object. A General fight is attrition; the Bug Lord is a timed pass-or-fail
examination of ten questions. Both run the same five-state machine, parameterised by a
request object.

**The test suite was chosen by risk, not by coverage.**
Five automated checks, 1,159 assertions, zero failures. Not a suite — five checks, each
selected by multiplying the probability of a defect class against the cost of missing it.
A 2D game's animation cannot be meaningfully asserted at this size; data integrity and
progression arithmetic can be asserted exactly, headlessly, in under a second.

**The defect log is the evidence for the strategy, not a postscript to it.**
Fourteen defects recorded with their class. Five were the engine behaving correctly in a
way the design had not anticipated — looping animations never emit `animation_finished`,
timers keep running while the tree is paused. Two would only ever have appeared in an
exported build, because Godot's importer claims `.csv` and `.json` for its own pipeline
and neither file would have shipped.

And one test reported a pass having asserted nothing. It had been launched with
`--script`, where autoloads do not exist, so the class under test failed to compile and no
assertion ever ran. A test that silently skips itself is worse than no test: it converts a
known unknown into a false assurance. The runner now fails any zero-assertion run.
(`docs/TEST_STRATEGY.md`, defect #14.)

---

## Running it

**Requirements:** Godot 4.7.2 (stable), GL Compatibility renderer. No external
dependencies, no package manager, no build step.

```bash
git clone https://github.com/deiharis/codequest.git
cd codequest
godot project.godot          # or open the folder from the Godot project manager
```

Design resolution is 1152 × 648, `canvas_items` stretch with `expand` aspect.

### Tests

```bash
godot --headless res://tests/TestRunner.tscn
```

Run it as a **scene**, not with `--script`. Under `--script` the autoloads do not exist,
the checks that depend on them cannot compile, and the run reports success having verified
nothing. This is defect #14 above, and the reason the runner now refuses a zero-assertion
run.

---

## Content pipeline

Three formats, each chosen against a named alternative, selected by editing profile rather
than by preference:

| Format | Holds | Why not the alternative |
|---|---|---|
| Godot `.tres` | Worlds, Generals, the hero | Editable in the inspector, referenceable by other resources, diffable as text |
| CSV | 129 questions | 129 rows of identical flat shape. A spreadsheet is the right tool for that |
| JSON | Lesson content | A beat is polymorphic — a `compare` beat and a `steps` beat carry different fields, which CSV cannot express without a column per field of every type |

Both `.csv` and `.json` carry a sibling `.import` file specifying `importer="keep"`.
Without it Godot's own import system claims them and an exported build ships with no
questions and no lessons — while working perfectly in the editor.

**Adding a world** is one `.tres` resource, a block of rows in `data/questions.csv`, and
one JSON lesson file. No gameplay script is edited.

---

## Layout

```
scripts/data/        Typed Resources, @export fields only. Content is data, not code
scripts/autoload/    Session services: GameState, SceneRouter, AudioManager, PauseMenu
scripts/lesson/      Lesson loading and playback, the Archive, the transition function
scripts/battle/      The encounter: state machine, damage, animation, impact feedback
scenes/              Presentation controllers, one per scene. No gameplay rules here
data/                questions.csv and the eight world lesson files
resources/           World, enemy and hero definitions
tools/               Python asset generators (audio, sprites) and a lesson validator
tests/               TestRunner.tscn and the five checks
docs/                Architecture, ADRs, traceability, test strategy, diagrams
```

Audio is generated, not sourced: 16 sound effects and 5 music loops are synthesised by the
Python scripts in `tools/` using NumPy, SciPy and Pillow, so they are original and
regenerable rather than licensed.

---

## Documentation

| Document | Contents |
|---|---|
| `docs/ARCHITECTURE.md` | The layer model, component inventory, data and control flow |
| `docs/DECISIONS.md` | 44 architecture decision records, each with its alternatives and why they were rejected |
| `docs/REQUIREMENTS_TRACE.md` | 137 requirements traced to components and to the check that verifies each |
| `docs/TEST_STRATEGY.md` | The five checks, how they were selected, the defect log, the manual suite |
| `docs/LITERATURE_SOURCES.md` | Survey of game-based software engineering education |
| `docs/diagrams/` | 12 UML and software-engineering diagrams |
| `docs/CodeQuest_Project_Report.pdf` | Full project report |
| `docs/CodeQuest_Presentation.pdf` | Presentation deck |

---

## Scope and status

Playable end to end: eight worlds, seven General fights, the Bug Lord examination, save
and load with schema versioning, and the Bugfall Archive for re-reading lessons.

Not done: verification against an exported build beyond the manual cases (M25–M28),
per-question failure rates aggregated across a class, and an evaluation with a pre-test,
post-test and delayed post-test design.

None of the four structural contributions — the single transition function, the
editing-profile content pipeline, progression by derivation, and two encounter types on
one state machine — depends on the subject being software engineering. Replace the eight
world resources, the question bank and the lesson files, and the gameplay code is
untouched.

---

## Credits

Submitted as Digital Assignment 2 for BCSE301L by B Haris Ahamed (24BCE1136) and
Shaili H (24BCE1970). Implementation by B Haris Ahamed.
