# CodeQuest — Architecture Decision Log

Short, dated records of architectural decisions and why they were made.
Append new entries at the bottom; never rewrite an old one. If a decision is
reversed, add a new entry that supersedes it rather than editing history.

Format: **Decision** / **Why** / **Rejected alternative**.

---

## ADR-001 — Content is defined by Resources, not code
**Date:** 2026-09-17 (records a decision made earlier in the project)

**Decision.** Game content (worlds, enemies, questions, hero) is defined by
custom `Resource` subclasses with `@export`ed fields, authored as `.tres` files.
Scripts read them; they never hardcode content.

**Why.** It is what allows a single battle scene to serve all eight bosses.
Adding a General becomes authoring data, not editing `BattleController`.

**Rejected.** Hardcoded enemy definitions in GDScript; a scene per enemy.

---

## ADR-002 — World 8 (Bugfall) has no General
**Date:** 2026-09-17

**Decision.** There are seven Generals, in Worlds 1–7. World 8 is the final
Bug Lord confrontation and contains no General battle.

**Why.** The brief names seven Generals plus the Bug Lord as an overarching
threat. `bugfall.tres` had `general_name = "Bug Lord"`, which conflated the two.
This resolves it and removes the need for an eighth character's art.

**Rejected.** Inventing an eighth General; giving World 8 a General fight before
the finale.

---

## ADR-003 — Bug Lord persistent HP reduces by 1000 per world
**Date:** 2026-09-17

**Decision.** The Bug Lord has 8000 campaign-wide persistent HP. Each successful
Bug Lord encounter reduces it by 1000 (`WorldData.bug_lord_damage`). The eighth
victory brings it to exactly 0 and completes the campaign.

**Why.** Eight equal reductions make 8000 a meaningful number rather than an
arbitrary one, and the final blow landing on exactly zero is a clean ending beat.

**Rejected.** Variable per-world damage; a separate final-boss HP pool.

---

## ADR-004 — Encounter HP and persistent HP live in different objects
**Date:** 2026-09-17

**Decision.** The 500 HP encounter pool is `EnemyData.max_hp`, copied into
`Combatant.current_hp` at battle start and destroyed with the battle scene. The
8000 persistent HP is `GameState.bug_lord_persistent_hp` and is saved.

**Why.** Storing them in different kinds of object makes them physically
impossible to confuse. Encounter HP cannot leak across retries because it does
not outlive the scene; persistent HP has exactly one place it can be written.

**Rejected.** Both values on one resource; both in `GameState`.

---

## ADR-005 — Linear texture filtering
**Date:** 2026-09-17

**Decision.** `rendering/textures/canvas_textures/default_texture_filter = 1`
(Linear), changed from 0 (Nearest).

**Why.** The artwork is painted and high-resolution, not pixel art. Nearest
filtering produces hard, aliased edges — visible especially in Rocket Travel,
which magnifies an 85px planet sprite roughly 10x.

**Rejected.** Nearest (appropriate only for true pixel art).

---

## ADR-006 — Fixed 320x320 animation frame contract
**Date:** 2026-09-17

**Decision.** All character sprite sheets (hero, Generals, Bug Lord) use a fixed
320x320 frame box, with a consistent baseline and horizontal anchor. Per-character
size differences are expressed as `EnemyData.display_scale` (a single uniform
float), never as a baked scene scale.

**Why.** `Battle.tscn` carried a hand-tuned non-uniform scale of (0.644, 0.754)
because frame sizes differed per character. That scale distorts the sprite and is
wrong for every enemy but the one it was tuned for. A shared frame box removes the
problem at its source and roughly halves texture memory.

**Rejected.** Per-enemy scale values tuned by eye in the scene.

---

## ADR-007 — Hero HP resets at the start of every encounter
**Date:** 2026-09-17

**Decision.** The hero begins each encounter — General and Bug Lord alike — at
full HP. HP does not carry over between them.

**Why.** Carrying damage forward would make the Bug Lord unwinnable after a close
General fight, through no fault the player can correct.

**Rejected.** Persistent hero HP across a world; healing items.

---

## ADR-008 — `general_defeated` is persisted to the save file
**Date:** 2026-09-17

**Decision.** `WorldProgress.general_defeated` is written to the save file, not
held only in memory for the session.

**Why.** A player who beats the General and then quits before attempting the Bug
Lord should not lose that victory. Failing the Bug Lord still clears the flag —
that is the brief's retry rule — but quitting is not failing.

**Rejected.** Session-only flag.

---

## ADR-009 — Design resolution 1920x1080, canvas_items stretch
**Date:** 2026-09-17

**Decision.** Viewport set explicitly to 1920x1080 with `canvas_items` stretch and
`expand` aspect.

**Why.** The viewport size was previously unset, silently defaulting to 1152x648
while scenes hardcoded rectangles at that size. The art is high-resolution and
designing below it wastes detail.

**Rejected.** 1152x648; `viewport` stretch mode (would letterbox rather than adapt).

---

## ADR-010 — The Bug Lord reuses the General battle loop
**Date:** 2026-09-17

**Decision.** Bug Lord encounters use the same `Battle.tscn`, the same question →
answer → attack → damage loop, and the same `BattleController`. The differences
are data plus one `BattleRequest.Mode` flag: a countdown timer, the 500 HP pool,
a second HP bar, and an Ultimate-based victory sequence.

**Why.** It is the entire justification for a reusable battle framework. Code
branches on the mode in exactly three narrow places; a fourth would be a signal
that something belongs in data instead.

**Rejected.** A separate Bug Lord scene; a distinct puzzle or minigame system.

---

## ADR-011 — One scene-transition path, with payload passing
**Date:** 2026-09-17

**Decision.** `SceneManager` is replaced by a `SceneRouter` autoload that handles
fades and carries a payload to the next scene. All scene changes go through it.

**Why.** `SceneManager` could not pass data, so `SpaceMap` hand-rolled its own
transition to hand a `WorldData` to Rocket Travel. Two divergent transition paths
already existed and the Battle scene would have needed a third.

**Rejected.** Keeping `SceneManager` and passing data through a global variable.

---

## ADR-012 — Worlds are listed in a WorldDatabase resource
**Date:** 2026-09-17
**Status:** IMPLEMENTED 2026-09-18. `resources/worlds/world_database.tres` now
holds all eight worlds and `SpaceMap` reads it; the `DirAccess` scan is gone.

**Second defect found on implementation.** The scan loaded every `.tres` in the
worlds folder as a `WorldData`, including `architara_frames.tres`, which is a
`SpriteFrames`. That fault was present in the editor too, not only on export —
it was simply never noticed. An explicit list cannot make this mistake, which
is a second, unplanned argument for the same decision.

**Decision.** An explicit `WorldDatabase` resource holds an ordered
`Array[WorldData]`. `SpaceMap` loads it instead of scanning `res://resources/worlds/`
with `DirAccess` at runtime.

**Why.** Runtime directory enumeration over `res://` is not reliable in exported
builds — packed resources can be remapped, so the editor and the export disagree.
The bug would surface late, at export time. An explicit list also makes world
order visible and editable in the inspector.

**Rejected.** `DirAccess` scanning with a sort by `order_index`.

---

## ADR-013 — Save as JSON in `user://`, with a version field
**Date:** 2026-09-17

**Decision.** Campaign state is saved as JSON to `user://codequest_save.json`,
carrying a `version` integer. Battle state is never saved.

**Why.** JSON is human-readable, which matters a great deal while debugging; it
tolerates added fields when versioned; and it avoids `ResourceSaver`'s ability to
execute script on load. Saving only campaign state removes an entire class of bugs
around restoring half-finished animation sequences.

**Rejected.** `ResourceSaver` on a custom `Resource`; binary `ConfigFile`.

---

## ADR-014 — Version control established
**Date:** 2026-09-17

**Decision.** Git initialised; initial commit `b02b8df` captures the project state
before architecture work began. Pushed to a private GitHub repository.

**Why.** The project had `.gitignore` and `.gitattributes` but no repository, so no
change was reversible and a disk failure would have ended the project. The commit
history also serves as evidence of development process for the academic report.

**Rejected.** Git LFS (sprite sheets are 1–2.6 MB each, far below GitHub's limits).

---

## ADR-015 — Design resolution reverted to 1152x648 (supersedes ADR-009)
**Date:** 2026-09-17

**Decision.** Viewport returns to 1152x648 with `canvas_items` stretch. The default
clear colour is set to the scenes' background navy so no region of the window is
ever left grey.

**Why.** ADR-009 rested on a false premise: that a lower design resolution wastes
high-resolution art. It does not. Under `canvas_items` stretch, the design
resolution is only a coordinate system — 2D is rendered at the window's real
resolution and textures are sampled there, so sharpness is unaffected by the
number in this setting.

Meanwhile the change had a real cost. Every scene positions content in 1152x648
coordinates (planet `map_position` values, background rectangles, HP bar offsets).
Reinterpreting those against a 1920x1080 viewport pushed all content into the
upper-left ~60% of the screen and left the remainder uncovered.

Raising the design resolution would require repositioning all authored content.
That work belongs with the Space Map rebuild in Phase 5, not ahead of it.

**Rejected.** Keeping 1920x1080 and repositioning eight worlds' map coordinates
plus several scenes' hardcoded rectangles as an unplanned step.

---

## ADR-016 — House visual style: polished illustrated 2D RPG
**Date:** 2026-09-17

**Decision.** One visual language across every asset: detailed illustrated sprite
work, not chunky pixel art. Consistent character proportions, 3/4 battle
perspective, strong silhouettes, clean shading, controlled VFX. Hero, Generals,
Bug Lord, rocket, planets, UI and environments all follow it.

**Why.** The project currently mixes two languages: painted characters at ~415px
per frame beside pixel-art planets at 85px and a pixel-art rocket at 198px. They
read as assets from different games. A single language is the difference between
"student project" and "a game", and it is also what makes a style contract
checkable.

**Consequence.** The planets and rocket are in scope for replacement, not just the
characters. The pixel-art assets currently in the project are placeholders.

**Rejected.** Pixel art (would mean discarding the existing character work);
stylised flat vector (easiest to produce, but a weaker fit for a boss-battle RPG).

---

## ADR-017 — Cutout rigs, not frame-by-frame sheets (supersedes ADR-006)
**Date:** 2026-09-17
**Status:** SUPERSEDED by ADR-024. This decision was made but never carried out;
the project uses frame sheets. Kept for the record.

**Decision.** Each character is one master illustration, cut into parts and
animated in Godot with `Skeleton2D` + `AnimationPlayer`. Animations are authored
in-engine, not generated as frames.

**Why.** Three reasons, in order of weight:

1. **Consistency becomes structural.** Frame-to-frame style drift was the single
   largest risk in this project. With a rig, every frame is literally the same
   artwork, so drift cannot occur.
2. **Volume drops from ~340 generated frames to ~9 master images.** For a solo
   developer on a deadline this is the difference between finishable and not.
3. **Memory.** The audit projected 200+ MB of VRAM at full roster. One master per
   character is roughly an order of magnitude less.

Secondary benefits: new animations need no new art; timing is tunable in the
editor, which is where combat feel actually comes from; and a rigged, data-driven
animation system is a stronger architecture story than 340 PNGs.

**Cost accepted.** The result reads as cutout animation rather than hand-drawn
frames, and each master needs manual separation into parts in an image editor.

**Supersedes ADR-006.** The fixed 320x320 frame box no longer applies — a rig has
no frame grid. It is replaced by a master canvas size and a part-separation
contract, recorded in `docs/ART_SPEC.md`.

**Rejected.** Frame-by-frame sheets (the current approach); a hybrid using frames
only for attacks (retains the drift risk where motion is most visible).

---

## ADR-018 — Art and code proceed in parallel
**Date:** 2026-09-17

**Decision.** Phase 1 onward continues while the art is redone. Nothing in Phases
1-6 waits on final art.

**Why.** The battle engine is built against the placeholder and real art swaps in
through `EnemyData`. Art has long feedback loops; code does not. Serialising them
would idle one while the other runs.

**Rejected.** Pausing development until the art is settled.

---

## ADR-019 — `docs/ART_SPEC.md` is the single visual contract
**Date:** 2026-09-17

**Decision.** All visual assets are generated against, and accepted against,
`docs/ART_SPEC.md`. No asset is generated without filling a template from its
§12, and none enters the project without passing the 22-point checklist in §13.

**Why.** Consistency across nine characters, eight planets, a rocket and a UI
cannot be held in someone's head across weeks of work. Writing the contract down
turns "consistent" from a feeling into something checkable, and it makes a failed
asset a regeneration rather than an argument.

The spec also caught two errors that had already shipped into the project: every
existing General is drawn facing the viewer rather than down-left at the Hero,
and the first palette draft put four of seven Generals inside a 24-degree wedge
of the colour wheel.

**Key contents.** Battle-angle contract (3/4 rear for the Hero, 3/4 front for
enemies); 2048x2048 transparent masters with a fixed baseline; colour separation
on three axes (hue, value, saturation) rather than hue alone; nine distinct
silhouette classes and builds; the 14-part cutout rig list; prompt templates;
acceptance checklist.

**Rejected.** Per-asset judgement calls with no written contract; a style
reference board of images without written rules (cannot be checked against).

---

## ADR-020 — Character roster varies by gender, species and build
**Date:** 2026-09-17

**Decision.** The nine characters use nine distinct silhouette classes. Notably:
Ambiguous Client is female; Merge Conflict Titan is split half male, half
female; Infinite Loop Beast and Regression Dragon are non-humanoid beasts;
Production Nightmare is a machine construct with no face or limbs.

**Why.** The first draft defaulted almost every character to a humanoid male
build, which reads as one character in seven costumes. The names themselves
imply otherwise — a Client is a person, a Beast is not, a Titan is colossal, a
King is enthroned. Variety in build is also the cheapest way to make characters
distinguishable at battle scale, where fine detail is invisible.

Merge Conflict Titan's gender split does double duty: it is the clearest
possible visual for "two incompatible versions of the same entity".

**Rejected.** A uniformly humanoid roster differentiated only by costume and
colour.

---

## ADR-021 — Sprite size is normalised in code, corrected in data
**Date:** 2026-09-18

**Decision.** `Combatant` rescales every `SpriteFrames` to a common
`REFERENCE_FRAME_HEIGHT` (443px) the moment it is swapped in, so a character
cannot change size when it changes animation. Residual per-character error is
corrected by an `attack_scale` field on `HeroData` and `EnemyData`, tuned by
eye, defaulting to `1.0`.

**Why.** The sheets were generated in separate sessions and differ in two
independent ways: the frame is a different height, and the character occupies a
different fraction of that frame. The first is mechanical and is fixed in code.
The second is an authoring choice — the hero is simply drawn smaller in his
attack sheet — and cannot be inferred, because normalising by the character's
measured height would scale a crouching attack pose up to match a standing idle
and look worse. A tuning knob is one float per character and takes seconds to
set; the alternative is re-exporting 43 PNGs.

The hero needed ~1.10. Every other character sat within tolerance at 1.0.

**Rejected.** Re-authoring all sheets to a uniform frame and character size
(correct, but expensive and blocks progress); auto-fitting by content bounding
box (breaks any pose that is deliberately not full height).

---

## ADR-022 — Questions live in one CSV, not in .tres resources
**Date:** 2026-09-18

**Decision.** All question content lives in `data/questions.csv`, one row per
question, keyed by `enemy_id`. `QuestionBank` reads the file once at runtime and
builds `QuestionData` objects in memory. No question is saved as a `.tres`.

**Why.** Fifty-seven questions is fifty-seven resource files to create by hand in
the Inspector, and the Inspector is a poor editor for prose. A spreadsheet is
the right tool: rows can be sorted, reviewed by someone who has never opened
Godot, diffed in git as text, and bulk-edited. The whole set is visible at once,
which is how you notice that every correct answer is option A — a real defect
caught this way during authoring.

`QuestionData` remains a `Resource` subclass so the Inspector can still display
one, and so a hand-authored `.tres` would still work if ever needed.

**Consequence.** Godot does not include `.csv` in an exported build by default.
`*.csv` must be added to the non-resource export filter or the exported game
ships with no questions and fails silently.

**Rejected.** One `.tres` per question (unmaintainable at this count); a
`QuestionBank` resource holding an array (still edited through the Inspector,
same problem); JSON (no worse technically, but not editable in Excel, which was
the point).

---

## ADR-023 — The Bug Lord timer is per question, and expiry is a wrong answer
**Date:** 2026-09-18

**Decision.** The Bug Lord fight times each question individually rather than
the encounter as a whole. The limit runs from 15 to 30 seconds, derived from the
combined character count of the question and its four options, overridable by an
optional `seconds` column. Running out is resolved as a wrong answer: the Bug
Lord attacks, the hero loses HP, the fight continues. The clock runs only while
a question is on screen — never during the arrival, the attack animations, or
the ending. Generals have no timer at all.

**Why.** A single encounter-wide countdown punishes the wrong thing. It makes
a fight you are winning end abruptly, and it charges the player for time spent
watching animations they cannot skip. Per-question timing turns the clock into
pressure rather than a second, parallel lose condition — and the fight still
resolves through the HP system that already exists, so there is one way to lose
instead of two.

Scaling by reading length is a proxy for difficulty, not a measure of it. It was
chosen because it needs no per-question authoring and is roughly right; the
override column exists for the cases where it is not.

**Consequence.** `Outcome.TIMER_EXPIRED` was removed. There are now exactly two
outcomes, `VICTORY` and `HERO_DEFEATED`.

**Rejected.** One 60s countdown for the whole encounter (the original design —
ends winnable fights on a single slow question); a fixed 15s for everything
(unfair on long questions); a display-only timer (pressure without stakes).

---

## ADR-024 — Frame sheets, not cutout rigs (supersedes ADR-017)
**Date:** 2026-09-18

**Decision.** Every character is animated from pre-rendered sprite sheets — one
sheet per animation, loaded as a `SpriteFrames` resource. No `Skeleton2D`, no
cutout rig, no in-engine animation authoring. 43 sheets across nine characters.

**Why.** ADR-017 chose rigs and was never implemented. Recording the reason
matters more than recording the intent.

The rig decision assumed art would be produced as single master illustrations and
separated into parts by hand. In practice the art was generated as complete
animation sheets, which made the rig work pure overhead: the frames already
existed, and cutting them apart to reassemble them in Godot would have destroyed
the drawn motion to rebuild a worse version of it.

The three arguments for rigs did not survive contact:

1. **Consistency.** The drift ADR-017 feared did appear, but as a *size*
   inconsistency between sheets, not a style one. It was solved in code by
   normalising every sheet to a reference frame height (ADR-021), which cost one
   constant and one function.
2. **Volume.** 43 sheets were generated in about two days. The projection of
   "340 frames is unfinishable" was wrong, because generation is not hand-drawing.
3. **Memory.** Untested at full roster, and now a real open risk. If VRAM becomes
   a problem the fix is compression and atlas packing, not re-rigging.

**Cost accepted.** New animations need new art rather than new keyframes. Timing
is fixed by the sheet's frame count and fps rather than tunable in the editor.
Memory use is unmeasured at full roster.

**Consequence.** The rig part contract in `docs/ART_SPEC.md` section on rigging
no longer applies. The sheet-per-animation naming convention that the assets
actually follow is the live contract.

**Rejected.** Retrofitting rigs to the existing sheets (destroys finished work to
satisfy a document); quietly leaving ADR-017 in place (a decision record that
misdescribes the system is worse than no record).

---

## ADR-025 — The Bug Lord encounter is a pass/fail exam, not an HP fight
**Date:** 2026-09-18

**Decision.** Defeating a General does not clear a world. It opens the Bug Lord
encounter, which is what clears it.

The encounter is a fixed-length exam: ten questions drawn from that world's own
Bug Lord pool, pass mark 70%. A correct answer plays the hero's normal attack
for **zero damage** — feedback only. Reaching seven correct fires the Ultimate,
which takes 1000 off the Bug Lord's persistent HP; he then withdraws rather than
dying. A wrong answer costs the hero 25 HP as usual. Failing returns the player
to that world's General.

Each of the eight worlds has its own pool of ten Bug Lord questions, keyed
`bug_lord_<world_id>`. No question is shared between pools, or with any
General's set, so a full campaign presents 80 distinct boss questions and no
repeats anywhere.

**Why.** The Bug Lord is the campaign's progress bar, not an opponent to be
worn down eight times. Making his encounter an exam separates the two things
the game is actually measuring: the General fight tests whether you can survive
a topic, and the boss encounter tests whether you have understood it well
enough to pass. Chipping his HP with correct answers would have made the two
fights identical in feel and reduced the boss to a longer General.

Zero-damage normal attacks exist because the alternative — the hero standing
still on a correct answer — reads as a bug. The animation confirms the answer;
the Ultimate is the event.

**The two failure modes coincide by construction.** Ten questions at 70% allows
three wrong answers. The boss deals 25 and the hero has 100 HP, so the fourth
wrong answer is simultaneously the one that makes 7/10 impossible and the one
that empties the hero. Failing by knowledge and failing by attrition land on the
same question without either number being tuned to the other.

**Consequences.**
- `bug_lord.tres`'s `max_hp` of 500 is now unused in the encounter. It stays
  only so the resource remains valid; nothing reads it.
- His HP bar displays the persistent 8000 from `GameState`, not an encounter
  pool, because a bar that never moves would misrepresent the fight.
- `GameState.complete_world` became `clear_world`, called from the Ultimate.
  It returns whether anything changed, and replaying a cleared world costs him
  nothing — the first world cannot be farmed to finish the campaign.
- The hero enters the encounter at full HP; the General fight's damage does not
  carry over. Deliberate, and reversible in one line if playtesting disagrees.

**Rejected.** Correct answers damaging the boss (makes him a longer General);
a shared Bug Lord question pool across worlds (guarantees repeats by world
three); ending the encounter only after all ten questions regardless of the
result (asks questions whose answers cannot change anything).

---

## ADR-026 — A lesson precedes each fight, and lessons are JSON

**Status.** Accepted.

**Context.** Every battle in the game asks multiple-choice questions about
software engineering, but nothing in the game had ever taught the material. A
player who did not already know what a non-functional requirement is could only
guess. That makes the battle an exam rather than a lesson, which inverts the
thing the project is for.

**Decision.** Each world plays a short taught sequence — narrated by a mentor,
**Sifu, The Wise** — between the rocket's arrival and the General fight. The
world loop becomes LEARN → UNDERSTAND → APPLY → TEST → PROGRESS.

A lesson is a JSON document in `data/lessons/<world_id>.json`: a title, a phase
and an ordered array of *beats*. Five beat types exist, each with its own
renderer in `lesson_controller.gd`:

| Type | What it is for |
|---|---|
| `dialogue` | Sifu speaking. Voice and framing. |
| `concept` | One idea, a body of prose, and its key terms. |
| `compare` | Two labelled columns — the distinction that matters. |
| `example` | The same thing done badly and done well, plus a verdict. |
| `encounter` | The General's taunt. The last beat, and the door to the fight. |

**Why JSON and not CSV or `.tres`.** Lesson prose is multi-line, variable-length
and nested, which is what CSV is worst at and what the Inspector is tedious for.
JSON diffs as text in git and can be written by someone who never opens Godot.
Like `questions.csv` (ADR-022) it is marked `importer="keep"` so Godot's own
JSON importer does not claim it and break `FileAccess` in an exported build.

**Beats stay Dictionaries.** A `LessonBeat` resource class would add a layer
that only renames the same fields; each renderer reads its fields once.

**No `WorldFlow` orchestrator.** The sequence is Rocket → Lesson → Battle, and
the rocket already knew how to build a `BattleRequest`. Routing one step earlier
is an insertion, not a restructure. An orchestrator earns its place when there
is something to reorder; adding one now would mean rewriting working code to
gain nothing.

**Seen-state is separate from progress.** `GameState.lessons_seen` is its own
list, not derived from `defeated_generals`, because losing a fight must not
replay the lesson and clearing a world is not what marks it read. Skipping
counts as seen — forcing a lesson on someone who has chosen to pass it twice is
a punishment, not teaching. The field is absent from saves written before
lessons existed, where an empty list is the correct reading, so `SAVE_VERSION`
did not change.

**Worlds without a lesson still play.** `LessonBank.has_lesson()` is false for a
world with no file, and the rocket then routes straight to the battle exactly as
it did before. Content can land one world at a time.

**Rejected.** Teaching inside the battle scene between questions (the fight
stops being a fight); a single long lesson document for all eight worlds (one
file every world edit touches); making the lesson unskippable (a replay would
punish the player for losing).

---

## ADR-027 — Every world teaches, and Bugfall keeps the Archive

**Status.** Accepted. Extends ADR-026.

**Context.** ADR-026 built the teaching framework and one lesson. The framework
was right; one lesson was not a curriculum. The world loop is now the same
everywhere: **arrive → learn → meet the General → fight → Bug Lord**.

**Decision.** All eight worlds have lesson content, matched to their SDLC phase:

| World | Phase | Taught |
|---|---|---|
| Reqoria | Requirement Analysis | Verifiable requirements, functional vs non-functional, elicitation, scope creep |
| Architara | Software Design | Coupling and cohesion, layering, separation of concerns, patterns |
| Codexis | Implementation | Loop termination, iteration vs recursion, clean code as a debugging tool |
| Testara | Testing | Test levels, verification vs validation, what a real assertion looks like |
| Gitforge | Version Control | Branch/commit/merge, what a conflict actually is, merge vs rebase |
| Deployon | Deployment | Pipelines, blue-green and canary, configuration, rollback first |
| Legacyon | Maintenance | Technical debt as real debt, the four maintenances, the strangler pattern |
| Bugfall | Bugs & Debugging | Symptom vs root cause, the debugging method, loud vs silent failure |

**Two beat types were added** to make the lessons teach rather than narrate:

- **`steps`** reveals an ordered process one line per press. Reading a five-step
  pipeline as five arrivals is the difference between watching something happen
  and being handed a list.
- **`check`** asks one multiple-choice question with no cost attached, and will
  not let Continue through until it is answered. The General battle is the test;
  this is the rehearsal. Getting it wrong here is how a player finds out they had
  not understood, before it costs HP.

**The Bugfall Archive.** Bugfall is the last world and the only one with no
General (ADR-002), so arriving there dropped straight into the final encounter.
It now opens an Archive instead: every world's lesson, replayable on its own.
Choosing a topic plays it in *library mode*, which differs in exactly three ways
— it returns to the Archive rather than a battle, it marks nothing seen, and it
drops the `encounter` beat, because there is no General to introduce. Progress,
save state and combat are untouched by anything in that room. The one button
that starts a fight is the one labelled "Face the Bug Lord".

**`WorldFlow` now exists**, and this is the reversal of the position taken in
ADR-026. It was refused then because the sequence was Rocket → Battle and there
was nothing to reorder. Three callers now have to agree on what follows a world
— the rocket arriving, a lesson ending, and the Archive being left — and three
copies of that rule would drift apart the first time one changed. Its functions
are static and take the calling node, because a static function has no tree of
its own and that is how it reaches the autoloads.

**Validation is a script, not a hope.** `tools/validate_lessons.py` checks every
lesson against the fields each renderer reads. The renderers use
`Dictionary.get()` with defaults, so a missing field draws an empty label and
the game carries on looking fine — and a wrong `answer` index silently marks the
correct answer wrong, teaching the opposite of the lesson. Both are invisible at
runtime and obvious to a checker.

**Rejected.** A separate hub scene for Bugfall on top of the Archive (the
Archive is the hub); making the library replay mark lessons seen (revision is
not progress); putting the Archive on the Space Map instead of in Bugfall (it is
the last world's reward for arriving, and the brief placed it there).

### Amended — the shelf says what has been read

A library with no read state is a list. Each row now carries a marker — a gold
tick for a lesson studied during the campaign, a dim dot for one not yet
reached — and the header counts them: *"3 of 8 studied"*.

**The marker is its own Label beside the button, not text inside it.** The font
is proportional, so spacing a column with spaces would make the eight titles
disagree with each other row by row.

**Unread rows stay fully bright and fully clickable.** The Archive is open by
design — a player may read ahead — and dimming what has not been done yet reads
as locked rather than as unread.

**The marker reads `lessons_seen`, which library replays deliberately do not
set** (see above). So it means "met during the campaign", not "opened from this
screen", which is the more useful of the two and the only one that survives the
rule that revision is not progress.

---

## ADR-028 — Sound effects are generated, not sourced

**Status.** Accepted.

**Context.** The game had no audio at all. `assets/audio/music/` and
`assets/audio/sfx/` existed and were empty. Two routes were available: download
a free pack, or synthesise.

**Decision.** The effects are generated by `tools/make_sfx.py` — numpy, a sine,
filtered noise and an envelope, mixed and soft-clipped to 44.1kHz 16-bit mono
WAV. Ten sounds: `sword_hit`, `enemy_hit`, `answer_correct`, `answer_wrong`,
`ultimate`, `victory`, `defeat`, `boss_arrive`, `ui_click`, `ui_hover`.

Three reasons, in order of weight:

1. **Licence.** This is coursework that will be submitted. "Free to download"
   and "free to redistribute in a submitted artefact" are different permissions,
   and the second one is the one that matters. A generated file has no such
   question attached to it.
2. **Fit.** A pack's idea of "sword hit" is not this game's. `answer_correct`
   had to be short enough to sit under the green flash without delaying the
   attack that follows it; `victory` had to finish inside the banner's 1.25s
   hold. Those are numbers, and numbers are editable here.
3. **Reproducibility.** The generator is seeded, so the same run produces the
   same files. Retuning a sound is a line in a script, not a search.

The trade is honest: these are good combat and UI effects and they are not a
composed soundtrack. Music is deliberately out of scope here.

**The palette is dark fantasy, and the first attempt was not.** The first pass
used pure sines, integer overtones and a major-triad fanfare, and the verdict
from playtesting was accurate: it sounded like a casual mobile game. Four
changes fixed it, and they are the difference between the two genres:

- **Inharmonic partials.** A bell whose overtones are 2x and 3x the root is a
  toy. Ratios like 1.41 and 2.57 read as struck metal, because struck metal is
  not a harmonic oscillator.
- **Minor and modal intervals.** Victory is now root–fifth–octave with no third
  in it at all. A major third is cheerful; a bare fifth is heroic.
- **Saturation on everything tonal.** A clean sine is a synthesiser; a driven
  saw stack is an object in a room. This is also why the tonal parts are built
  from sawtooths — a sine gives the saturation nothing to bite on.
- **Low end and long tails.** Everything dropped roughly an octave, into a
  seven-tap stone-room reverb with prime-numbered delays so the echoes never
  line up into an audible pitch.

**Measured, not assumed — twice.** Spectral centroid caught two defects that
casual listening would have excused.

1. The Bug Lord's arrival measured 1.9kHz — a "low rumble" that was audibly
   bright. `finish()` was soft-clipping *before* normalising, which folds a loud
   40Hz tone into a spray of harmonics. Normalise first, clip gently after: 146Hz.
2. After the dark retune, the "low breath" hover sound measured 4.2kHz. The
   cause was the lowpass filter: one pole is -6dB/octave, so noise cut at 600Hz
   still has substantial energy at 5kHz. Cascading to four poles is -24dB/octave
   and actually dark: 217Hz.

Both checks are three lines of numpy. Neither bug was audible as "wrong" — they
were audible as "not quite right", which is the kind of defect that ships.

**Third pass: too dark is also wrong.** Playtesting reported that the hover and
the Bug Lord's arrival could not be heard at all, and that the sword read as a
club. Both findings were correct and both came from over-correcting.

- **Audibility is a band, not a level.** Every file is normalised to the same
  peak, so "quiet" was never the problem. The problem was pitch: laptop speakers
  roll off hard below roughly 200Hz, so a 165Hz hover and a 26–55Hz rumble
  simply do not exist for most players. The measure added for this was the share
  of a sound's energy landing in 250Hz–8kHz. The Bug Lord's arrival was at
  **4.9%**; it is now **23.6%**, with the sub kept as support for anyone wearing
  headphones. Soft has to mean low in *level*, not low in *pitch*.
- **A cut is defined by its first 20 milliseconds above 2kHz.** Filtering the
  highs out to escape the arcade palette turned the greatsword into a club. Both
  weapon sounds are now three staged parts: the blade passing (noise through a
  resonant band sliding down, which needed a real state-variable filter — a
  one-pole lowpass cannot make that shape), the edge biting, and only then the
  mass behind it.
- **Two sounds differ by rhythm before they differ by pitch.** `answer_correct`
  and `answer_wrong` were reported as sounding identical, and they were: two
  single strikes of similar length, differing mainly in pitch. They are now
  opposed on five axes — one strike vs two stabs, rising vs falling, 1.6s vs
  0.29s, clean resonant metal vs buzzing driven cluster, long hall vs dry.

The general lesson is that "dark and heavy" and "inaudible" are one step apart,
and only measurement tells you which side you are on.

**`AudioManager` is an autoload** with a fixed pool of ten voices, round-robin,
stealing the oldest when all are busy. Two reasons it cannot be a player per
scene: a victory sting has to outlive the scene that triggered it, since
`SceneRouter` frees the battle while the banner is still on screen; and
overlapping effects need somewhere to overlap. Stealing the oldest rather than
dropping the newest is deliberate — the hit the player just caused is the wrong
one to silence.

**Pitch jitter defaults to ±5%** and is passed 0.0 for anything musical. Two
identical samples back to back read as a machine; the same sample slightly
detuned reads as two hits. A detuned chime, however, reads as a wrong note.

**Sounds fire on the impact frame**, alongside `apply_damage` and the damage
number — not on the wind-up. The sound is what makes a hit land, so it has to
agree with the number appearing.

**Rejected.** An audio bus layout with Master/Music/SFX buses — buses earn their
place when there is a settings screen with sliders to drive them, and there
isn't one yet; `AudioManager.sfx_volume_db` is the seam for when there is.
Streaming OGG for effects (WAV is correct for short samples; OGG costs a decode
per play). Downloading a pack, for the licence reason above.

---

## ADR-029 — UI sound is wired to the tree, not to the scenes

**Status.** Accepted. Follows ADR-028.

**Context.** Every button in the game should click when pressed and whisper when
hovered. The obvious implementation is two `connect` lines per button. The game
has buttons in seven scenes, and three of those build them in loops — the Space
Map spawns eight planets, the Archive eight rows, and the lesson rebuilds its
card on every beat, including four fresh option buttons on a `check`.

**Decision.** `AudioManager` connects once to `get_tree().node_added` and hooks
any `Button` that enters the tree, anywhere, forever.

The alternative was a `hook_buttons(node)` helper called from each scene's
`_ready`. That is more code in more places, and it only works for as long as
every future scene remembers to call it — which is a rule that holds until the
day it doesn't, and fails silently when it breaks. A button that exists is a
button that is wired.

`hook_button()` is idempotent, because a node can re-enter the tree and a signal
connected twice plays the sound twice — audible as a flam rather than a click.

**Cost.** A callback on every node added to the tree, for the lifetime of the
game. At this game's scale that is unmeasurable. In something that spawns
thousands of nodes per second it would not be, and the per-scene helper would
then be correct.

**Four more sounds**, generated by the same script (ADR-028): `panel_in` and
`panel_out` for the question scroll, `page_turn` for a lesson beat, and
`type_tick` for Sifu's speech.

**`type_tick` is driven by a Timer, not by characters.** The typewriter is a
tween on `visible_ratio`, which has no per-character hook — and one tick per
character would be far too many regardless. A 45ms timer runs while text is
typing, with ±20% pitch jitter and −9dB of trim, because a run of identical
ticks reads as a machine gun. The timer stops on the tween's `finished` signal,
which fires whether the line completed on its own or the player clicked through
it, so the ticking always ends with the text. It is also stopped explicitly when
a beat changes, because killing a tween does *not* emit `finished`.

**Known and accepted.** A locked planet on the Space Map plays its click and
then does nothing. The sound confirms the press, not the outcome, and a silent
button reads as broken input rather than as a refusal.

**Per-button overrides are metadata**, not a registry. A button carrying
`set_meta("hover_sfx", &"planet_hover")` gets that sound instead of the default.
Metadata rather than a Dictionary keyed by node because metadata dies with the
node — a Dictionary would hold a reference to every button the game ever built.
The same key doubles as the already-hooked flag, so idempotency costs nothing.

**One sound is deliberately not dark-fantasy.** The Space Map's planets use
`planet_hover`: pure sines, no saturation, no stone room, a high root with a
fifth above it. The Space Map is a navigation screen rather than a place — the
one surface where the game is software instead of a world — and a modern
interface chime reads as correct there where a leather creak does not. It is the
exception that makes the rest of the palette read as deliberate.

**Rejected.** Sounds attached in the `.tscn` files (invisible in diffs, and
impossible for buttons built in code); a distinct sound per button type (nine
near-identical clicks is a library to maintain, not a design).

---

## ADR-030 — Combat VFX live in HitFeedback, and the geometry was rendered before it was written

**Status.** Accepted.

**Context.** The battle had damage numbers and screen shake (ADR-028's sibling
work) and nothing else. A hit changed a number and jolted the screen; nothing
about it said *blade*.

**Decision.** Four effects, all added to the existing `HitFeedback` node rather
than to a new one:

| Effect | When |
|---|---|
| `slash()` — a tapered crescent sweeping through the impact | every blow |
| `sparks()` — a one-shot particle burst, gold for the hero, red against him | every blow |
| `screen_flash()` — a wash of colour over everything | the Ultimate, and Bugfall's lightning |
| `shake()` / `pop()` — already there | unchanged |

**One node, not four.** `HitFeedback` already sits above the fighters and below
the UI, the battle already orders it in `_order_layers`, and it is already
called on the exact frame a blow lands. A separate effects node would have meant
a second thing to place in the tree and a second chance to place it wrong, for
no gain — these are all the same job.

**The flash is on its own `CanvasLayer`, inside that node.** A CanvasLayer
ignores its parent's transform, which matters because `HitFeedback` lives inside
the thing that shakes: a flash that shook with the screen would show the arena's
edges sliding out from under it.

**The arc is placed by its middle, not its centre.** Centring the node on the
impact point draws a curve that passes *around* the target — a halo. The node is
offset by the arc's mid-angle so the blade passes *through* it.

**The geometry was rendered before it was written.** `Slash._draw` builds a
tapered band from two arcs, and the relationship between radius, thickness and
span decides whether that reads as a sword or a leaf. Rather than guess and
iterate in-engine, the same maths was rendered to a PNG at four progress values
and three parameter sets. The first attempt — radius 96, thickness 30 — was a
fat teardrop. Radius 150 with thickness 15 is a blade. That check cost one
script and replaced at least two round trips of "it still looks wrong".

**Sparks are `CPUParticles2D`.** Built in, one configuration block, and nothing
here needs behaviour a hand-rolled particle loop would provide. The colour ramp
cools from white through the hit colour to transparent, so sparks die as they
fall rather than blinking out.

**Neither the slash nor the sparks are awaited.** They play over the damage
animation. Awaiting them would stop the fight to watch an effect finish, which
is the difference between feedback and a cutscene.

**Rejected.** A sprite-sheet slash (needs an artist, and a fixed angle); a
shader-based flash (a ColorRect and a tween is the same result in four lines);
particles for the slash trail (a solid tapered polygon is sharper and cheaper).

---

## ADR-031 — The Ultimate is a sequence, not an effect

**Status.** Accepted. Extends ADR-030.

**Context.** ADR-030 gave the Ultimate a flash, a shake, sparks and three
slashes. That reads as a bigger normal attack. The Ultimate is the payoff for
passing an entire exam and it is the only thing that damages the Bug Lord — it
should stop the game.

**Decision.** Seven beats, in order:

| | Beat | Time |
|---|---|---|
| 1 | Hero's ultimate animation | (its own) |
| 2 | White floods in until it blinds the screen | 0.80s |
| 3 | The light collapses to a point on the hero | 0.20s |
| 4 | Twenty-four slashes, with a sword hit and a small kick on each | 2.53s |
| 5 | Damage, gold flash, heavy shake, 64 sparks, HP drop | — |
| 6 | His defeat or withdrawal animation | (its own) |
| 7 | White-and-violet burst out of him, over everything | 0.22s + 0.78s |

**One node draws beats 2, 3 and 7.** `Wipe` draws a filled circle at a centre
and a radius, with an optional larger circle behind it. A light that shrinks to
nothing and an explosion that grows from nothing are the same drawing played in
opposite directions; two classes would have been the same code twice.

**It lives on the flash's `CanvasLayer`**, and its callers pass *screen*
coordinates via `get_global_transform_with_canvas().origin`, not world ones. The
CanvasLayer is what keeps the wipe steady while the battle shakes — but it also
means the wipe knows nothing of the battle's transform, so positions have to be
converted at the call site.

**The collapse uses `EASE_IN`.** Easing out would read as the light fading;
easing in accelerates as it shrinks, which reads as the light being pulled into
him.

**The sound was already the right shape.** `ultimate.wav` is a 0.75s charge
followed by an impact. Moving its trigger from before the hero's animation to
the start of the blinding fade means the charge runs under the fade and the boom
lands on the exact frame the light collapses. Nothing was re-cut; it was
triggered in the right place instead of the convenient one.

**A long flurry needs sound and motion per cut.** Twenty-four silent, still
slashes over 2.5 seconds is a slideshow. `slash_flurry` gained two optional
parameters — a per-cut sound and a per-cut shake — passed as `sword_hit` at
−9dB with heavy pitch jitter, and a fifth of the Ultimate's shake. Optional
rather than built in, because a three-cut flurry wants neither.

**`burst` is a new sound**, and deliberately the inverse of `ultimate`: no
charge, no warning, loudest at its first sample. Same measured balance
correction as `boss_arrive` — the first render put only 5.7% of its energy in
the band a laptop can reproduce and came out thin; it is now 25.2%.

**Assumption stated.** The burst fires after *whichever* exit the Bug Lord
takes — the defeat animation on the eighth world, the withdrawal on the other
seven — because the brief asked for it in every Bug Lord fight, and only one of
those eight is a death.

**Rejected.** A shader for the blinding light (a tweened circle is the same
image in far less code); particles on every one of the 24 cuts (480 particles
for no visible gain); a separate cutscene scene (the battle already owns this
moment, and leaving it would lose the arena behind the light).

---

## ADR-032 — The victory screen shows the syllabus, not the score

**Status.** Accepted.

**Context.** The victory screen predated the theme (ADR-019's Phase A) and every
visual decision after it. It was a flat rect, a 44px hardcoded label, one line of
text reading "8 worlds cleared", and a button. Reaching it after the Ultimate's
new sequence was a cliff.

**Decision.** Rebuilt against the theme, with the same three-layer backdrop the
title screen and Space Map use — flat clear colour, nebula at z −9, and a seeded
starfield drawn by the node itself. A child `ColorRect` would paint over its own
parent's `_draw` and hide the sky, which is why the background sits at z −10 and
the stars are drawn rather than placed.

**The centre of the screen is a roll of all eight worlds with their SDLC
phases**, not a count. "8 worlds cleared" is a score; *Reqoria — Requirement
Analysis, Architara — Software Design, …* is a record of what was actually
learned, and this game is about those eight subjects more than it is about the
fight. The roll is read from `WorldDatabase`, so it cannot drift from the worlds
that exist.

**It arrives rather than appearing.** Title, subtitle, roll, then each button,
each fading up and rising 18px, 0.13s apart. Nothing moves far — the effect
should be noticed only by its absence.

**A second exit was added.** The old screen offered only "New Campaign", which
erases the save. A player who wanted to stop and look at the Archive had to
destroy their progress to leave. "Title Screen" is now beside it.

**Built in code**, like the lesson and the Archive, so the layout lives in one
file instead of a scene tree and a script that have to agree with each other.
The `.tscn` keeps only the root and the background rect.

**Rejected.** Reusing the CodeQuest title art here (it belongs to the title
screen, and repeating it makes the ending feel like a return to the menu);
per-world statistics such as questions answered (`GameState` does not record
them, and adding tracking to serve one screen is the wrong order).

---

## ADR-033 — The travel rocket is drawn by a script, in the game's palette

**Status.** Accepted.

**Context.** The rocket in `RocketTravel` was a downloaded sprite sheet of a
bright cyan sci-fi fighter, seen from above. Three problems, only one of which
was taste:

1. **Wrong palette and wrong genre.** Saturated cyan and chrome against a game
   whose entire visual language is bone, gold and dark navy (ADR-019). It was
   the only asset in the game that looked like it came from somewhere else —
   because it did.
2. **Distorted by the scene.** A top-down sprite was rotated 90° and scaled
   `Vector2(1, 1.273)` to make it fly sideways. A non-uniform scale on a rotated
   sprite stretches it along a diagonal; that was the source of its odd shape,
   not the art.
3. **Unknown licence.** Same concern recorded against the boss crest. This is a
   submitted artefact and "found online" is not a licence.

**Decision.** `tools/make_rocket.py` generates the sheet: eight frames of
400×200, drawn side-on and facing right, in bone and gold over navy with the
violet from the Bug Lord's burst. The scene's rotation and non-uniform scale are
removed — the sprite now faces the direction it travels, so neither is needed.

**Drawn at 4× and downsampled**, which is what produces clean edges without
hand-antialiasing anything.

**A flat fill reads as a sticker.** The hull and nose are filled with a
top-lit vertical gradient and a bright rim along the upper edge — one light
source, consistently applied. That, plus panel lines and a row of rivets, is
the difference between a shape and an object.

**Only the flame changes between frames.** Three nested tongues, each breathing
at a different rate, so the flicker reads as heat rather than as one shape being
scaled. The hull is drawn once and composited under all eight.

**Stations are named constants** (`ENGINE_BACK`, `SHOULDER`, `NOSE_TIP`) because
those numbers are referenced from four places, and a typo in one of them is
invisible in the output.

**First attempt was wrong and the render showed it.** The nose cone ran 60% of
the body, the fins vanished into the background, and the flame was a sliver.
Rendering the frames and looking at them cost one command; shipping it would
have cost a round trip.

**The old sheet stays on disk** until it is deleted by hand — this session can
write files but not remove them.

**Rejected.** Editing the downloaded sheet's colours (it would still be someone
else's art, and still a top-down jet); a hand-pixelled sprite (no pixel artist,
and the rest of the game's generated art is vector-smooth, not pixel);
commissioning nothing and keeping it (the licence question does not go away).

### Amended — the generated rocket was replaced

Haris produced a better rocket than the script did, and then a better one than
that: the sheet in use is eight frames laid out 4x2, a steel and gold hull with
swept fins and a real flame cycle. It is his own work, so the licence problem is
solved the same way, and it looks better. The script and its output were deleted
rather than kept "in case" — a generator nothing uses is a file that rots.

Two of the three findings above survive the swap, because they were never about
the art:

- **The rotation and the non-uniform scale stay removed.** The new sheet is
  drawn side-on facing right, so the scene needs neither, and a rotated sprite
  with a `Vector2(1, 1.273)` scale would distort this one exactly as it did the
  last.
- **Frames must be aligned on the hull, not on the content.** The supplied sheet
  was not on a uniform grid — its eight frames sat at irregular spacings, and
  each frame's bounding box includes a flame whose length changes. Cutting on
  the bounding box would have made the ship jitter while the flame flickered.
  The sheet was re-cut anchored on each frame's nose tip and hull centreline,
  then verified by averaging all eight alpha channels: the hull edges come out
  crisp and only the flame smears, which is exactly the right answer.
- **Crop each frame's own columns, not a fixed window around it.** The first
  re-cut of the 4x2 sheet took a fixed-width window ending at each nose tip,
  which reached back far enough to catch the *previous* frame's nose and paste a
  ghost of it at the new frame's left edge. Invisible in a still, and a flicker
  once animated. The averaged-alpha check is what showed it — a stray shape at
  the far left that had no business being there.

---

## ADR-034 — Pause is an autoload, and the timers had to be fixed first

**Status.** Accepted.

**Context.** The game had no pause. `get_tree().paused` was never set anywhere
in the project. Escape left the Space Map and the Archive; inside a battle, a
lesson or the rocket flight it did nothing, so once a fight started the only way
out was to close the window. That is a defect, not missing polish.

**Decision.** A `PauseMenu` autoload owning a `CanvasLayer` at layer 120 — over
the game, under `SceneRouter`'s fade at 128. It offers Resume, a sound toggle
and Quit to Title.

An autoload rather than a node per scene, for the reason recorded in ADR-029:
every scene needs it, and "remember to add the pause menu to new scenes" is a
rule that holds until someone forgets, and fails silently when it breaks.

**Two bugs had to be fixed before pause could work at all.**

1. **`SceneTree.create_timer()` defaults `process_always = true`**, and all
   eleven calls in the project used the default. Every one of them kept counting
   while the tree was paused — the impact pause, the question hold, the flurry
   gap, the rocket's arrival. A pause that does not pause the fight is not a
   pause. All eleven now pass `false`.
2. **Escape on the Space Map was not marked handled.** It called `_on_back()`
   and let the event carry on, so with this autoload listening the player would
   have left the map *and* opened a pause menu over the title screen. A scene
   that acts on an input owns it.

**Input order is what keeps the existing Escape behaviour intact.** Autoloads
are added to the root before the main scene, and `_unhandled_input` propagates
from the bottom of the tree up — so the current scene is always offered the key
first. The Space Map and the Archive consume it; everywhere else it reaches this
node. No scene needed changing to opt in, and only the one that was leaking
needed changing to opt out.

**The dimmer is `MOUSE_FILTER_STOP`, deliberately.** It is what stops clicks
reaching the scene behind it. A paused battle would ignore them, but the Space
Map's planet buttons would not, and the player would launch a rocket from inside
a pause menu.

**Centring uses a `CenterContainer`, not anchor presets.** A `PanelContainer`
has no size until its children are laid out, so centring it by anchors at build
time centres a zero-sized box. The scale pivot is set in `open()` for the same
reason — a pivot of (0,0) grows the panel out of its own corner.

**A key nobody knows about is not a feature.** The first version bound Escape
and stopped there. Playtesting found it immediately: "I can't see any escape
button." Nothing on screen said pausing was possible, so it may as well not have
been. A **Pause** button now sits top-left wherever pausing is allowed, hidden
on the three screens that have their own way out and hidden while the menu
itself is open — the panel has its own Resume, and two ways to close it in the
same corner is one too many.

Its visibility follows `SceneRouter.scene_changed`, plus one deferred call at
startup: autoloads run before `current_scene` is assigned, and a scene launched
directly with F6 never emits `scene_changed` at all.

**Known limit.** Quit to Title while a battle is mid-animation frees a scene
that still has coroutines awaiting timers. If that turns out to log errors,
the fix is a validity guard at each continuation; it is not guarded
speculatively because the behaviour was not verified.

**Rejected.** Folding pause into `SceneRouter` because it is already an
always-processing autoload with a CanvasLayer (a pause menu is not scene
routing, and this project is marked on its structure); a pause option that
teleports out of a battle mid-fight (leaving a fight should be a forfeit through
the battle's own ending path, not a teleport out of a half-resolved state).

---

## ADR-035 — The campaign bar belongs on the Space Map

**Status.** Accepted.

**Context.** ADR-003 made the Bug Lord's health the campaign's progress bar:
eight worlds, a thousand points off him each, zero means the game is won. The
title screen displayed it. `SpaceMap.gd` contained no reference to
`bug_lord_hp` or `defeated_generals` at all — so the player saw their progress
once, pressed Continue, and it vanished from the one screen where they choose
what to do next.

**Decision.** A bar along the bottom strip of the map: "THE BUG LORD" and his
remaining health above it, worlds cleared below, and one tick mark per world
across it.

**The bottom strip is the only place it fits.** Planets occupy y 250–564
(lowest centre 500, half-box 64) and the title art takes y 18–158. The strip
below the constellation is the only full-width space nothing else wants, and it
was verified against the actual `map_position` of all eight worlds rather than
eyeballed.

**Drawn, not built from nodes.** This node already has a `_draw` for the
starfield and the route, and a bar is four rectangles. A `ProgressBar` plus a
`StyleBox` shaped to look like this would be more configuration than drawing.
The three labels are still nodes, because text in `_draw` means carrying a font
reference for no gain.

**The fill colour is taken from `Nameplate`, not copied.** `Nameplate.BOSS_FILL`
and `BOSS_FILL_LOW` are the same constants his battle health bar uses, so the
Bug Lord's health looks identical in both places and can only ever be changed in
one.

**One tick per world, not a smooth drain.** His health does not fall
continuously — it drops in eight steps of exactly 1000, and the bar should show
the shape of the thing it measures.

**`_draw_progress()` is called before the route's early return.** `_draw()`
bails out when there are too few worlds to build a spline; putting the bar after
that would have silently lost it in exactly the degraded case where a player
most needs to see what state the game is in.

**Rejected.** Reusing `Nameplate.setup_boss()` (the crest is 93px tall and the
plate ~100px overall — it would crowd the constellation it sits under, and the
map is not a battle); putting it top-right (only ~200px of clear width, too
narrow for a bar reading 8000); a number with no bar (the point is that it is
draining).

---

## ADR-036 — The explanation gets a plate, and the wrong options get out of its way

**Status.** Accepted.

**Context.** The question was given a bordered box when that was asked for
(ADR-019's Phase A work). The explanation underneath it never was — it stayed a
bare line of grey text hanging below the options.

**Measuring before styling found a real defect.** The scroll panel is 700×484
with 78/90 content margins, leaving **304px of inner height**. The question box
(84), four options (168) and five separations (45) already come to **297**. A
three-line explanation needs another 60. The explanation has been overflowing
the parchment in every battle since it was added, and a bordered plate would
have needed 105px more than exists.

**Decision.** When feedback shows, the options that are no longer relevant are
faded out and hidden, and the explanation appears in a bordered plate in the
freed space.

What remains on screen is exactly what the player needs: the question, the
correct answer, their own answer if it differed, and why. Hiding three options
frees 126px; the measured worst case (a wrong answer, so two options stay) now
comes to 297 of 304.

So this is a space fix and a teaching improvement at the same time — the wrong
options have done their job by the time the explanation appears, and leaving
them on screen only competes with the thing meant to be read.

**The border carries the verdict, not the text.** The plate's border and a small
`CORRECT` / `NOT QUITE` header take the correctness colour; the explanation body
stays normal reading colour. Green or red body text is harder to read, and the
body is the part that exists to be read.

**The plate is built in code and wraps the scene's existing label**, reparenting
it rather than rebuilding it, so whatever the scene set on that label survives.
Its stylebox is a duplicate of the theme's `ScrollHeader` with tighter vertical
margins — 10px instead of 14 — which is where the last 8px of the worst case
came from.

**Rejected.** Growing the scroll panel upward (it would reach into the enemy's
nameplate, and the panel draws over the plates since ADR-019's ordering fix);
scrolling the explanation inside a fixed box (a scrollbar inside parchment, and
an explanation the player must scroll is one they will not read); shrinking the
option font (it makes four unreadable options instead of two readable ones).

---

## ADR-037 — Weight: anticipation, follow-through, and recoil

**Status.** Accepted.

**Context.** A blow was: slide forward, play the attack animation, slide back.
The defender flashed white and its HP number changed. Nothing about the motion
said a body had committed to a strike or absorbed one.

**Decision.** Three additions to `Combatant`, all exported so they can be tuned
without touching code.

**Anticipation.** A 0.10s pull back *away* from the target before the lunge,
with a squash. A lunge that starts from rest reads as a drift; one that starts
from a wind-up reads as a decision. This is the oldest trick in animation and it
costs a tenth of a second per exchange.

**The lunge now eases IN, not OUT.** This was a bug dressed as a style choice.
`EASE_OUT` decelerates into the target — the fighter arrives slowing down, which
is why the old lunge felt soft no matter how far it travelled. A strike
accelerates into what it hits.

**Follow-through** on the return, which already overshot via `TRANS_BACK`, now
carries the scale back with it so the stretch resolves rather than snapping.

**Recoil.** The defender is knocked back along the line from the attacker and
settles. It takes the attacker's position as an argument, because a fighter has
no idea who hit it and the direction is the entire point. Deliberately **not**
awaitable — it plays underneath the damage animation, and awaiting it would add
a third of a second to every exchange for no added information.

**Squash and stretch multiply `_base_scale`, not `Vector2.ONE`.** Fighters are
not drawn at 1:1 — `configure()` scales each one, and the Bug Lord is scaled
further again. Tweening toward `Vector2.ONE` would have snapped every fighter to
unscaled size on the first blow. This is the kind of thing that looks right in a
test scene with one character and destroys the boss fight.

**Cost: 0.10s per exchange.** Ten questions is one extra second across a whole
battle, spent on the moment the player is watching.

**Rejected.** Anticipation on the defender too (it cannot know a blow is coming
without the controller telling it, and the controller telling it would make the
fight turn-based in a way it is not); hitstop (a freeze on impact would fight
the screen shake already there, and shake was measured as sufficient).

---

## ADR-038 — Two transition shapes, and colour for everything else

**Status.** Accepted.

**Context.** `SceneRouter` faded to black for every scene change: entering a
battle, finishing a lesson, being beaten, winning the campaign. Identical
treatment for events that mean opposite things.

**Decision.** Two shapes, and a tint.

| | Used for |
|---|---|
| **Fade**, black | everything ordinary — menus, the map, lessons |
| **Fade**, gold | leaving a fight the player just won |
| **Fade**, dark red | leaving a fight they lost |
| **Iris** — a circle closing on the centre | arriving at a battle |

**Two shapes, not six.** A fade is right for almost everything, and an iris is
right for the one moment the game narrows onto a single thing. Colour carries
the rest of the meaning far more cheaply than a shape per mood, and reads just
as clearly at a quarter of a second. Anything more would be a transition
framework, which is a lot of code for something on screen for 250ms.

**The iris is one enormously thick ring.** Godot has no "fill everything except
this circle", so it is drawn with `draw_arc`: the arc's inner edge is the hole,
and its width — twice the viewport's diagonal — carries the black past every
corner whatever the aspect ratio. The radius is a tweened property with a setter
that queues a redraw, which is what animates it.

**The iris is always black, even though fades take a tint.** A coloured hole
reads as a rendering bug rather than as mood.

**Two static-context hazards were sidestepped rather than risked.**
`WorldFlow` is a `RefCounted` with static functions, and an autoload lookup in a
*default argument* has no instance to hang off. The style parameter defaults to
`-1` and resolves to `Style.FADE` inside the body, and `IRIS` is a named local
constant. Both cost a line and remove a question that would otherwise only be
answered at runtime.

**Rejected.** A shader-based dissolve or a pixelate (a tweened circle is the
same 250ms of screen time for none of the pipeline); per-world transition
colours (eight moods nobody would be able to name); slide or push transitions
(they imply spatial continuity between scenes, and a battle is not next to the
Space Map).

---

## ADR-039 — A lesson can be re-read from its own planet

**Status.** Accepted. Extends ADR-027.

**Context.** ADR-027 made every lesson replayable — but only from the Bugfall
Archive, which sits behind seven worlds. A student who reaches Gitforge and has
forgotten what a non-functional requirement is has no way back to Reqoria's
lesson without finishing the game first.

That is the wrong way round. The material is the point of this project; it
should not be reachable only by completing the thing it exists to teach.

**Decision.** Clicking a planet whose lesson has already been played asks
first — **Study the lesson again**, **Travel there**, or **Back to the map** —
instead of launching the rocket. A world whose lesson has *not* been seen
behaves exactly as before: the rocket flies, the lesson plays, the fight starts.
No extra click is ever added to a first visit.

**A replayed lesson returns where it was opened from.** `library_mode` already
meant "marks nothing, starts nothing, drops the encounter beat"; it also
hardcoded a return to the Archive. It now carries a `return_scene`, so a lesson
opened from a planet comes back to the map instead of teleporting the player to
Bugfall. The Archive keeps its existing behaviour by passing nothing.

**It is the same library mode, not a third mode.** Progress, saves and combat
state are untouched by this path for exactly the reasons recorded in ADR-027 —
revision is not progress.

**The panel is on its own `CanvasLayer` with a `MOUSE_FILTER_STOP` dimmer**, for
the two reasons the pause menu is: `SpaceMap` is a `Node2D`, and a `Control`
anchored to a `Node2D` has no rect to anchor against; and without the dimmer
stopping clicks, a press meant for the panel falls through to the planet
underneath and launches a rocket.

**Escape closes the panel before it leaves the map.** Leaving the screen out
from under an open dialog reads as a misclick.

**Rejected.** A separate "review" button in the hover readout (the readout is
`MOUSE_FILTER_IGNORE` by design — it follows the cursor and must not catch it);
right-clicking a planet (undiscoverable); always asking, even on a first visit
(a click between the player and content they have never seen); a lessons menu on
the title screen (further from the planet than the Archive already is).

---

## ADR-040 — A lesson can move backwards

**Status.** Accepted.

**Context.** The lesson player only went forward. Click, or press space, one
time too many and the beat is gone — and since a click also completes a line
that is still typing, an impatient player can skip a paragraph they never read.
In a teaching phase that is the wrong failure to make unrecoverable.

**Decision.** A **Back** button in the footer, and the left arrow key. Disabled
on the first beat.

Going back re-renders the beat from scratch, which means a `steps` beat replays
its reveals one at a time and a `check` beat asks its question again. That is
what re-reading means, and it costs nothing — `_show_beat` was already written
to build a beat from nothing.

**Left and right arrows both work now**, alongside click and space. A lesson is
read, not played; the keys people use for reading should move it.

**Back is not blocked by an unanswered `check`.** Continue is disabled until the
question is answered, deliberately (ADR-027) — but going back to re-read the
material the question is about is exactly what a stuck player should do, so the
arrow branch is handled before the Continue guard.

**Rejected.** A beat-by-beat scrubber or dot navigation (eleven targets for a
linear document); disabling Back once a `check` has been answered (the answer is
not the point — the explanation under it is).

---

## ADR-041 — Questions answer to the number keys

**Status.** Accepted.

**Context.** Every question in the game was mouse-only. A campaign is eight
worlds, two fights each, ten questions a fight — around a hundred and sixty
answers, each one a mouse journey across the scroll to a target whose position
depends on how long the option text is.

**Decision.** `1`–`4` (and the numpad equivalents) pick an option, in battles
and in the lesson's `check` beats alike. The options are **numbered on screen**,
because a key nobody can see does not exist — the same finding the Pause button
came from (ADR-034).

**Both places, not just the battle.** The `check` beat is the rehearsal for the
question the battle will ask; operating the rehearsal differently from the test
is a small cruelty for no gain.

**The battle's guard is `is_accepting()`**, which already existed and is already
the one place that knows whether the panel is up, has finished arriving, and has
not been answered. Reusing it means a key cannot do anything a click could not —
including during the slide-in, where answering a question you have not finished
reading was already prevented.

**In the lesson, the number keys are handled before everything else**, so `1`
through `4` never double as "advance the beat" on a beat that has no options.
`_check_buttons` is empty on every other beat type, which is also how the
handler knows to ignore them.

**The key emits the button's `pressed` signal** rather than calling the handler
directly, so the click sound, the disable and the colouring all happen through
exactly the path a mouse click takes. One path, not two.

**Rejected.** A–D letter keys (the options are numbered everywhere else in the
game); arrow-key focus navigation plus Enter (three presses where one will do,
and Godot's focus ring fights the theme); making the keys configurable (a
setting nobody will open for four keys that are already where the fingers are).

---

## ADR-042 — A locked world says what unlocks it, and says no out loud

**Status.** Accepted.

**Context.** A locked planet was dimmed, its hover readout was identical to an
unlocked one, and clicking it did nothing at all. The game told the player they
were wrong without telling them what would be right, and the silence on click is
indistinguishable from a broken button.

**Decision.** Two additions.

**The hover readout gains a line**: *"Locked — clear Codexis first"*. The
blocker named is always the next uncleared world in order, because unlocking is
`order_index <= worlds cleared` — so naming that one world is both exactly
accurate and more useful than "3 more to go". The readout is lifted 18px higher
when that line is present, or its extra height reaches down over the planet it
is describing.

**Clicking refuses audibly.** The planet shakes — five tweened steps, damping to
zero — and the game plays the same thud it uses when the hero is hit, at −14dB.
A refusal should be felt. The shake always ends at the planet's home position
whatever else is in flight, so spamming the click cannot leave one stuck
off-centre.

**The world's name and its General stay visible on a locked planet**, as ADR's
original Space Map reasoning had it: a player should be able to see what is
ahead of them, just not reach it. The lock line is added to that, not swapped
for it.

**Rejected.** A modal explaining the lock (a dialog for information that fits on
one line under the cursor); hiding locked worlds entirely (the constellation is
the composition, and eight planets is the shape of the campaign); a padlock icon
(it says "locked", which the player already knows, instead of what to do).

---

## ADR-043 — Sound is settable from the title screen, and the setting persists

**Status.** Accepted.

**Context.** The pause menu owns the sound toggle, and it is deliberately hidden
on the title screen, the Space Map and the Archive (ADR-034). The consequence
was that the game's *first* screen had no way to turn the sound off — and the
setting did not survive quitting anyway.

**Decision.** A **Sound: On / Off** row on the title menu, between New Game and
Quit, and the preference written to `user://settings.cfg`.

**Settings live in their own file, not in the save game.** Muting is a
preference, not progress. Putting it in `savegame.json` would mean
`GameState.reset()` — starting a new campaign — turns the sound back on, which
is obviously wrong the moment it happens to someone.

**Muting stops what is already playing.** Setting `muted` calls `stop_all()`
rather than only suppressing the next sound. A player who reaches for mute wants
silence now, not after the current effect finishes.

**Loading the settings does not re-save them.** Both values are assigned through
their own setters, which save; a `_settings_loaded` flag is false during the
load, so that save is a no-op and the file is not rewritten with what was just
read out of it.

**The menu re-centres itself when the row is added.** A fourth button makes the
block 60px taller — 46 plus the VBox's 14px separation — and the menu is
centre-anchored while the progress line is pinned 78px off the bottom. Measured:
without compensation they overlap by 20px. Lifting the block by half the added
height keeps it centred on the same point and leaves 10px of clearance.

**Rejected.** A separate settings screen (one toggle does not need a screen, and
an empty settings menu invites filling); putting the toggle only in the pause
menu and showing the pause button on the title screen (the title screen is
already a menu — a pause button on it is a second menu button).

---

## ADR-044 — Background music: five generated loops, two players, one crossfade

**Status.** Accepted. Extends ADR-028.

**Context.** The game had effects but no music. `assets/audio/music/` had been
sitting empty since the folder was created.

**Decision.** Five looping tracks generated by `tools/make_music.py`, in the
same dark palette as the effects: minor and modal, detuned saw stacks rather
than clean sines, saturation, and a stone room.

| Track | Where | Shape |
|---|---|---|
| `title` | title screen, victory screen | D minor, i–VI–III–VII, 32s |
| `space_map` | Space Map, rocket flight | A minor, one chord per two bars, 28s |
| `lesson` | lessons, the Archive | two chords in 40s, almost no movement |
| `battle` | General fights | E minor, a constant eighth-note pulse, 16s |
| `bug_lord` | the encounter | roots a tritone apart, slower than the General's, 24s |

**These are loops, not compositions.** That limit was stated before the work
started and it is why they are built this way — a pad moving slowly under a
scene is something this approach does well, and a melody a player would hum is
not.

**Two things make a loop actually loop, and both were verified by measurement.**

1. **Bar-aligned length**, so the last bar ends exactly where the first begins.
2. **The tail is folded back.** Reverb from the final bar would otherwise be cut
   mid-decay at the seam, so the track is rendered longer than the loop and the
   overhang is added onto the opening — which is what the second pass would
   hear anyway. Checked by comparing the sample step across the wrap against the
   average step in the file: every track's seam is at or below typical, meaning
   the join is indistinguishable from any other sample.

**Tracks are matched on RMS, not on peak.** Peak normalisation left the boss
loop 3dB louder than the others — audible on every crossfade into and out of it.
RMS is what the ear compares, so that is what is matched, with a ceiling only to
stop a peaky track clipping. All five now measure −14.0 dB.

**Two music players, not one.** A crossfade needs the old track still sounding
while the new one rises; a single player can only cut. The outgoing player is
stopped by a chained callback once it is actually silent, or the next track
inherits a player that is still audible and fades twice.

**Asking for the track already playing does nothing.** Scenes call
`play_music` in `_ready`, so the Space Map → rocket → Space Map sequence would
otherwise restart the same loop three times in ten seconds. This is also what
lets the map's music run unbroken through the flight.

**Ogg streams do not loop by default.** Godot imports them with looping off, and
a background track that plays once and stops is worse than silence, because the
player notices the exact moment it ends. `_load_music` sets `loop = true` on the
stream rather than relying on an import setting that a re-import could quietly
revert.

**Music is 13dB below the effects** and has its own persisted setting. It is the
floor of the mix; a bed that competes with a sword hit is a bed nobody wanted.

**Rejected.** A dedicated music bus (buses earn their place with a settings
screen full of sliders to drive them, which this still does not have —
`music_volume_db` is the seam for when it does); per-world battle tracks (eight
variations of a 16-second loop is content nobody asked for); stopping the music
during the Ultimate (the sequence already has its own sound design, and silence
there would read as a bug).

### Amended — two playtest findings, and the measurement that explained both

Reported: *"the lesson one sounds similar to the space map one"*, and *"as for
the bug lord, it's barely hearable"*. Both were correct, and the second was
worse than it looked — it applied to all five tracks.

**The Bug Lord's roots were at 27–39Hz.** Voiced at `root / 4`, they were below
what a laptop speaker reproduces at all. But measuring the others showed the
same disease: **95% of every track's energy sat below 150Hz.** An additive saw
puts most of its energy in the fundamental, the pads were voiced at 110–155Hz,
and the filters cut everything above 1.4–2.4kHz. The files measured correctly
and were nearly inaudible.

**The loudness metric was wrong, and that is why it was not caught.** Matching
on full-spectrum RMS made all five read −14dB — while the 250Hz–8kHz band a
small speaker actually plays sat at **−27dB**. The effects, which sound right,
measure −13 to −17 there. Tracks are now matched on *band* RMS, everything below
90Hz is removed, and a +6dB tilt above 500Hz lets the mids carry the level
instead of running the peaks into the limiter. Result: **−18.6 to −22.7dB**, and
`music_volume_db` moved from −13 to −6 to match.

**The two slow tracks were 0.84 alike in spectral shape.** They shared bell
sprinkles and closely related keys. The lesson is now in C minor rather than D,
sits lower, and its signature is a damped wooden pluck instead of bells — a bell
shimmers and pulls the ear up, a pluck stays in the middle and lets go.
Correlation is now 0.38.

**Two attempts at the filter-transient seam made it worse before one worked.**
Every filter starts from zero state, so sample zero is a transient, not signal —
measured, the Space Map's join was 4.5× a normal sample step. Warming the
filters with the loop's own end made it *worse* (4–14×), twice. The blunt
version cannot fail: crossfade the last 24ms into the first and drop them, so
the opening sample continues directly from the one that now precedes it. Every
track is now at or below 1.27×.

Three separate measurements, three separate defects, none of which sounded
obviously "broken" — they sounded slightly wrong, which is the kind that ships.
