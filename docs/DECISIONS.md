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
