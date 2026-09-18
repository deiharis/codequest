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
