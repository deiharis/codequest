# CodeQuest — Architecture Overview

**Engine:** Godot 4.7.2 · **Language:** GDScript · **Design resolution:** 1152 × 648, `canvas_items` / `expand`
**Companion documents:** `docs/DECISIONS.md` (25 ADRs), `docs/ART_SPEC.md` (visual contract)

This document describes the system as built. Where the implementation departs
from the Master Project Brief, the departure is stated and the deciding ADR is
named rather than the difference being quietly smoothed over.

---

## 1. Design goal

One requirement shapes almost every structural decision in this project:

> The battle system must be generic and reusable for all Generals and the Bug
> Lord. *(Master Brief §5)*

There are nine fights in the game — seven Generals, the Bug Lord encounter
repeated per world, and the final confrontation. There is **one battle scene**.
No enemy is named anywhere in the battle code. A fight is produced by handing
the controller a data object; everything the fight looks like, is worth, and
behaves as, comes from that object.

The same principle governs worlds, questions and progression: **behaviour lives
in scripts, content lives in resources and one CSV**, and the two never mix.

---

## 2. Layer model

```
┌──────────────────────────────────────────────────────────────┐
│  PRESENTATION            scenes/                             │
│  Main · SpaceMap · RocketTravel · Battle · QuestionPanel      │
│  · Victory                                                    │
│  Scenes own nodes, animation and input. They read data; they  │
│  never define it.                                             │
└───────────────┬──────────────────────────────────────────────┘
                │
┌───────────────▼──────────────────────────────────────────────┐
│  SESSION / FLOW          scripts/autoload/  (singletons)     │
│  SceneRouter — every scene change, with a fade and a payload  │
│  GameState   — campaign progress, Bug Lord HP, save/load      │
└───────────────┬──────────────────────────────────────────────┘
                │
┌───────────────▼──────────────────────────────────────────────┐
│  DATA                    scripts/data/  ·  resources/  · data/│
│  WorldData · WorldDatabase · EnemyData · HeroData             │
│  QuestionData · QuestionBank ← data/questions.csv             │
│  Inert. No behaviour beyond lookup.                           │
└──────────────────────────────────────────────────────────────┘
```

Dependencies point downward only. A resource never reaches up into a scene; a
scene never writes to another scene. The two autoloads are the only globals,
and each owns exactly one concern.

---

## 3. Component inventory

### 3.1 Data layer — `scripts/data/`

| Type | File | Responsibility |
|---|---|---|
| `WorldData` | `world_data.gd` | One world: id, display name, SDLC phase, its General (`EnemyData`), planet frames, map position, order index, storm flag |
| `WorldDatabase` | `world_database.gd` | The explicit ordered list of worlds. `in_order()`, `by_id()`, cached `load_default()` |
| `EnemyData` | `enemy_data.gd` | One enemy: identity, four `SpriteFrames`, presentation (scale, ground offset, attack scale, arena texture), combat values, timer settings |
| `HeroData` | `hero_data.gd` | The single hero: combat values, two animation sets (General fight, Bug Lord fight), the Ultimate |
| `QuestionData` | `question_data.gd` | One question: text, options, correct index, explanation, time limit |
| `QuestionBank` | `question_bank.gd` | Parses `data/questions.csv` once, caches it, serves one enemy's pool shuffled |

`WorldData`, `EnemyData`, `HeroData` and `QuestionData` are `Resource`
subclasses with `class_name`, so they are authored and edited in the Godot
Inspector. `QuestionBank` and `WorldDatabase` are lookup services, not content.

### 3.2 Session layer — `scripts/autoload/`

| Autoload | Responsibility |
|---|---|
| `SceneRouter` | Owns every scene transition. Fades to black through a `CanvasLayer` at layer 128, frees the old scene, instantiates the new one, and — critically — calls an optional `setup` callable on the new scene **before** adding it to the tree, so a scene has its data before its own `_ready()` runs |
| `GameState` | Which worlds are cleared, the Bug Lord's persistent HP, and the save file. Emits `progress_changed` |

### 3.3 Battle layer — `scripts/battle/`

| Type | File | Responsibility |
|---|---|---|
| `BattleRequest` | `battle_request.gd` | The complete description of one fight: hero, enemy, questions, mode, world id. `RefCounted`, not `Resource` — it is runtime state, never saved |
| `Combatant` | `combatant.gd` | One fighter. The hero and every enemy are the same class. Owns its sprite, HP and movement. Knows nothing about questions or turns |
| `BattleController` | `BattleController.gd` | Runs one battle. State machine, question flow, animation sequencing, HP bars, arena, timer, outcome routing |
| `LightningStrike` | `lightning_strike.gd` | Procedural black-and-red lightning, used only where a world asks for it |

### 3.4 Presentation — `scenes/`

| Scene | Role |
|---|---|
| `main/Main.tscn` | Boot scene and title screen. Starfield, logo, Continue / New Game / Quit, campaign status line |
| `space_map/SpaceMap.tscn` | The galaxy map. Builds planets from `WorldDatabase`, draws the spline route and starfield, handles hover and selection |
| `travel/RocketTravel.tscn` | The journey to a world. On arrival, builds the `BattleRequest` and routes into the battle |
| `battle/Battle.tscn` | **All nine fights.** Placeholders in the scene are replaced at runtime by real `Combatant`s |
| `battle/QuestionPanel.tscn` | Reusable question display: up to four options, unused ones hidden, feedback colouring, explanation |
| `victory/Victory.tscn` | Shown when the Bug Lord's persistent HP reaches zero |

---

## 4. Principal flows

### 4.1 Boot

```
Main.tscn  →  GameState._ready() loads user://savegame.json
           →  title screen shows Continue if progress exists
```

### 4.2 Selecting a world

```
SpaceMap: planet pressed
   └─ guard: locked worlds report their name and refuse the click
   └─ SceneRouter.goto_scene(RocketTravel, setup = scene.setup(world_data))

RocketTravel: launch → approach → arrival
   └─ BattleRequest.for_world(world)
        ├─ world's General is the Bug Lord (Bugfall) → for_bug_lord()
        └─ otherwise → the General fight
   └─ SceneRouter.goto_scene(Battle, setup = scene.setup(request))
```

### 4.3 The General fight

```
INTRO → QUESTION → RESOLVING → QUESTION → … → ENDING → FINISHED
```

Correct answer: hero lunges, strikes, enemy takes `hero.attack_damage`, reacts,
hero returns. Wrong answer: the same sequence with the arguments swapped. The
fight ends when either side reaches 0 HP.

### 4.4 The Bug Lord encounter

Entered **only** by defeating that world's General. It is an exam, not an HP
fight *(ADR-025)*:

```
boss arrival (rises from below, arena floods to his colour)
   → 10 questions drawn from that world's own pool, 15–30s each
   → correct answer: hero attacks for ZERO damage (feedback only)
   → wrong answer  : Bug Lord strikes, hero loses HP
   → 7 correct  → Ultimate → 1000 off persistent HP → he withdraws
   → 4 wrong    → failed  → back to that world's General
```

The two failure modes coincide by construction: ten questions at 70% allows
three wrong answers, and the fourth wrong answer is also the hit that empties a
100 HP hero against a 25-damage boss.

### 4.5 Progression and persistence

```
Bug Lord encounter passed
   → GameState.clear_world(world_id)
        ├─ already cleared → no-op (a world cannot be farmed)
        └─ otherwise → append, subtract 1000, emit, save
   → bug_lord_hp == 0 ? Victory : SpaceMap
```

---

## 5. Three mechanisms worth understanding

### 5.1 Animation sequencing — three guards

The hardest correctness requirement in the game is that **a question must not
appear until the attack and damage it caused have finished playing** *(Brief
§6)*. Three independent mechanisms enforce it, and all three are deliberate:

1. **A state gate.** Answers are accepted only in `State.QUESTION`.
2. **A UI lock.** `QuestionPanel` disables its buttons the instant one is
   pressed, so a fast double-click cannot fire two answers.
3. **One awaited chain.** `_resolve_answer()` does not return until the last
   animation has played, and nothing after it runs early.

Any one of these would usually be enough. Together they mean a bug in one does
not produce an unplayable battle.

### 5.2 Animation timing without `animation_finished`

Every `SpriteFrames` resource in the project has `loop = 1`. Godot never emits
`animation_finished` for a looping animation, so the obvious implementation
would hang the battle forever on the first attack.

`Combatant.play_once()` instead waits on a timer computed from the animation's
own frame count and speed. Timing from the data is immune to the loop flag and
required no edits to 41 resource files.

*This is a deliberate shortcut with a known ceiling; see item 8 in the backlog.*

### 5.3 Sprite scale normalisation

The sheets were generated in separate sessions and differ in two independent
ways: the frame is a different height, and the character occupies a different
fraction of that frame.

The first is mechanical — `Combatant` rescales every sheet to a common
reference height as it is swapped in. The second is an authoring choice and
cannot be inferred, so it is corrected by an `attack_scale` value per character
*(ADR-021)*.

---

## 6. Content pipeline

| Content | Authored in | Loaded by |
|---|---|---|
| Worlds | 8 `.tres` files + `world_database.tres` | `WorldDatabase` |
| Enemies | 8 `.tres` files | Referenced from `WorldData.general` |
| Animations | 41 `SpriteFrames` `.tres` over 43 PNG sheets | Referenced from `EnemyData` / `HeroData` |
| Questions | **one CSV**, `data/questions.csv`, 129 rows | `QuestionBank` |
| Arenas, title, backdrop | PNG in `assets/` | Referenced from resources or scene exports |

`questions.csv` is set to Godot's `keep` importer. Without that, Godot's
`csv_translation` importer treats the header row as locale codes and the raw
file is never packed into an exported build *(ADR-022)*.

---

## 7. Extension points

Each of these is a content change with no code change:

- **Add a question** — one row in `data/questions.csv`.
- **Retune a fight** — HP, damage, scale, arena and timer are all fields on that enemy's `.tres`.
- **Add a world** — create a `WorldData`, add it to `world_database.tres`, add its question rows.
- **Change the map layout** — `map_position` on each world; the route follows.

---

## 8. Divergences from the Master Brief

| Brief | As built | Why |
|---|---|---|
| §7 Bug Lord has a 500 HP encounter pool | Field exists, unused. The encounter is a 70% exam | ADR-025 — an HP boss is a longer General; an exam tests the thing the game teaches |
| §8 One countdown per Bug Lord fight; expiry returns to the General | Per-question timer, 15–30s; expiry counts as a wrong answer | ADR-023 — a single countdown ends winnable fights on one slow question and charges the player for animation time |
| §9 Completed worlds not replayable | Replayable, but `clear_world` is idempotent | Replay costs nothing and cannot advance the campaign twice |
| §12–13 Nested `assets/sprites/…` naming | Flat sheet-per-animation naming | The art was produced that way; the contract follows the assets |
| §15 Cutout rigs (ADR-017) | Frame sheets | ADR-024 — rigs were decided and never implemented; the reasons did not survive contact |

---

## 9. Known constraints

1. **VRAM at full roster is unmeasured.** ADR-017 projected 200 MB+ for frame
   sheets and chose rigs to avoid it; ADR-024 reversed that decision on other
   grounds. The memory question was never re-tested. This is an open risk, not
   a solved one.
2. **The game has never been exported.** Two export-specific failures are
   already fixed by design (the CSV importer, `WorldDatabase` replacing a
   `DirAccess` scan). Others may exist.
3. **No audio.** No music, sound effects or UI feedback sounds exist.
4. **`project.godot` must only be edited with Godot closed** — the editor holds
   project settings in memory and rewrites the file on close.

---

## 10. ADR index by component

| Component | ADRs |
|---|---|
| Battle system | 004 (two HP concepts), 023 (timer), 025 (Bug Lord as exam) |
| World progression | 002 (World 8 has no General), 003 (persistent HP), 012 (WorldDatabase) |
| Scene flow | 011 (one transition path) |
| Persistence | 013 (JSON in `user://`, versioned) |
| Presentation | 009/015 (design resolution), 016 (house style), 021 (scale + proportions) |
| Art pipeline | 006/017/024 (frame sheets, superseding chain), 019 (ART_SPEC), 020 (roster variety) |
| Content | 022 (questions in CSV) |
