# CodeQuest — Art Specification

**Status:** proposed, awaiting approval
**Version:** 0.1 · 2026-09-17
**Governs:** every visual asset in CodeQuest — characters, environments, props, UI, VFX

---

## 0. How to use this document

This is the **single visual contract** for CodeQuest. Every asset is generated
against it and judged against it.

Two rules make it work:

1. **Nothing is generated without filling in a template from §12.** Freestyled
   prompts are how nine characters end up looking like nine different games.
2. **Nothing is accepted without passing the checklist in §13.** If an asset
   fails a check, it is regenerated, not patched.

When this document and a generated asset disagree, the document wins — or the
document is amended deliberately and the change is recorded in
`docs/DECISIONS.md`. It is never silently ignored.

**Related decisions:** ADR-016 (house style), ADR-017 (cutout rigs, supersedes
the old 320x320 frame box), ADR-018 (art runs parallel to code).

---

## 1. Visual pillars

Five non-negotiables. Every asset satisfies all five.

| # | Pillar | What it means in practice |
| --- | --- | --- |
| 1 | **Silhouette first** | ~70% of a character's readability is its outline. Every design must be identifiable in solid black at 25% size. Detail is added only after the silhouette works. |
| 2 | **One illustrated language** | Painted, semi-realistic, clean confident brushwork. Not pixel art, not flat vector, not photoreal, not cel-shaded anime. Applies equally to planets, rocket and UI — no asset gets an exemption. |
| 3 | **Concept legible in one frame** | Each antagonist must communicate its software-engineering idea visually. A player who has never read the name should get *something* from the design. A generic fantasy monster is a failed design regardless of quality. |
| 4 | **Readable at battle scale** | Characters appear at roughly 300–600px tall in a 1152x648 frame. Fine filigree, small text and thin tracery disappear. Big shapes, strong value steps, few accent colours. |
| 5 | **Hero is order, enemies are entropy** | The Hero is the only character built from clean, precise, manufactured forms. Every antagonist is broken, tangled, unstable or corrupted in some specific way. This opposition is the game's core visual idea. |

---

## 2. Battle composition contract

**This is the section that gets forgotten. Read it before every generation.**

The battle is a fixed diagonal:

```
                                    ENEMY  ↙
                                  (top-right)
                                  faces DOWN-LEFT


        HERO  ↗
     (bottom-left)
     faces UP-RIGHT
```

### Required view per character type

| Character type | Position | Faces | View generated | What we see |
| --- | --- | --- | --- | --- |
| **Hero** | Bottom-left | Up-right ↗ | **3/4 REAR** | His back and the far side of his face. Cape prominent. |
| **Generals** | Top-right | Down-left ↙ | **3/4 FRONT** | Their face and chest. Never their back. |
| **Bug Lord** | Top-right | Down-left ↙ | **3/4 FRONT** | Face and chest, wings spread. |

### Why this matters

The current Generals are all generated **front-facing to the viewer**, not
angled down-left toward the Hero. Placed in the battle scene they appear to be
staring past the Hero at the camera. It reads as two characters ignoring each
other rather than fighting.

### Angle definition

- **3/4 rear** = the camera is behind and to one side. Roughly 135° from the
  character's facing direction. Both shoulders visible, one more than the other;
  a sliver of cheek or jaw visible past the head.
- **3/4 front** = the camera is in front and to one side. Roughly 45° from the
  character's facing direction. Full face visible, turned slightly away.

### Camera

Eye level, no perspective distortion, no dramatic low or high angle, no
foreshortening toward the viewer. All characters share one camera so they read
as occupying the same space.

### Ground

Characters stand on an implied flat ground plane. Feet at a consistent baseline
(§3). No cast shadow is baked into the art — shadows are drawn in-engine so they
can move with the character.

---

## 3. Canvas, files and naming

### Master canvas

| Property | Value |
| --- | --- |
| Dimensions | **2048 x 2048 px** |
| Format | PNG, **transparent background** |
| Colour | sRGB, 8-bit |
| Character height | ~90% of canvas height, centred horizontally |
| Baseline | Feet at **y = 1900** (92.8% down), consistent across all characters |
| Margin | Minimum 64px clear on all sides, including weapons and wings |

Every master is generated at full canvas height regardless of how large the
character appears in battle. **Relative size is applied in-engine** via
`EnemyData.display_scale` (§4), never by drawing a character smaller. This keeps
detail density even across the roster.

2048px gives roughly 4x headroom over in-game size, which leaves room to cut
clean rig parts and to raise the game's resolution later without redrawing.

### Folder structure

```
assets/sprites/
  hero/
    masters/      hero_master.png              the approved illustration
    parts/        hero_cape.png, hero_torso.png, ...   cut for the rig
  generals/
    ambiguous_client/
      masters/    ambiguous_client_master.png
      parts/      ...
    spaghetti_architect/
    infinite_loop_beast/
    regression_dragon/
    merge_conflict_titan/
    production_nightmare/
    technical_debt_king/
  bug_lord/
    masters/      bug_lord_master.png
    parts/        ...
  worlds/         planet_<world_id>.png
  ui/             rocket.png, icons, frames
  vfx/            impact_slash.png, glow_ring.png, ...
```

The existing frame-sheet PNGs stay where they are until each character is
replaced, then are deleted in the same commit.

### Naming

| Asset | Pattern | Example |
| --- | --- | --- |
| Master | `{character_id}_master.png` | `spaghetti_architect_master.png` |
| Rig part | `{character_id}_{part}.png` | `spaghetti_architect_front_arm_lower.png` |
| Planet | `planet_{world_id}.png` | `planet_reqoria.png` |
| VFX | `vfx_{effect}.png` | `vfx_impact_slash.png` |

Lowercase, underscores, no spaces, no capitals. `character_id` matches
`EnemyData.enemy_id` exactly so art and data stay traceable to each other.

---

## 4. Scale and proportion system

### Human proportion baseline

The Hero is **8 heads tall** — heroic but not stylised-chibi and not
superhero-9-heads. Humanoid Generals stay within 7.5–8.5 heads. Non-humanoid
Generals ignore this and are governed by their silhouette instead.

### Relative battle scale

`display_scale` values, relative to the Hero at 1.00. Applied in `EnemyData`,
not baked into the art.

| Character | Scale | Rationale |
| --- | --- | --- |
| Hero | **1.00** | The reference |
| Ambiguous Client | 1.05 | First General — barely above the player, beatable |
| Spaghetti Architect | 1.10 | |
| Infinite Loop Beast | 1.30 | First genuinely large enemy |
| Regression Dragon | 1.60 | Draconic bulk |
| Merge Conflict Titan | 1.75 | "Titan" must feel like one |
| Production Nightmare | 1.45 | Wide rather than tall |
| Technical Debt King | 1.35 | Bloated, not towering |
| **Bug Lord** | **2.10** | Must dwarf everything. Largest thing in the game. |

Scale is not strictly monotonic — pure escalation gets monotonous. What matters
is that the Bug Lord is unmistakably the biggest, and that World 1's General is
the smallest.

---

## 5. Shape language system

Shape communicates role before colour or detail does.

| Shape | Reads as | Used for |
| --- | --- | --- |
| **Triangle** | Danger, speed, aggression, purpose | Hero (heroic drive), aggressive Generals |
| **Square / rectangle** | Stability, weight, reliability, structure | Hero's armour, structural Generals |
| **Circle / curve** | Softness, friendliness, harmlessness | Used *sparingly* — mostly absent from this roster |
| **Spiral / knot** | Confusion, entanglement, recursion | Spaghetti Architect, Infinite Loop Beast |
| **Fracture / shard** | Corruption, breakage, instability | Bug Lord, Merge Conflict Titan |

### Assignments

- **Hero** — triangle-dominant with square support. Wide pauldrons tapering to
  a narrow waist; the greatsword as one long diagonal. Squares in chestplate and
  shoulders for solidity. Almost no circles. Reads as *ordered force*.
- **Generals** — one dominant shape each, chosen to express the concept (§9).
  No two adjacent worlds share a dominant shape.
- **Bug Lord** — fracture-dominant. The silhouette should look like it is coming
  apart at the edges.

### The silhouette rule

Before any detail is added, the design must pass: **fill the shape solid black,
scale to 25%, and it is still identifiable as that specific character.** If two
characters' black silhouettes could be confused, one of them is redesigned.

---

## 6. Colour system

### Global

| Role | Hex | Use |
| --- | --- | --- |
| Space background | `#0A0E1A` | Space Map, rocket travel, engine clear colour |
| Battle background base | `#12162A` | Battle scenes, tinted per world |
| Neutral UI dark | `#1A1F33` | Panels, HP bar backgrounds |
| Neutral UI light | `#C7D0E0` | Body text, inactive icons |

### Hero — blue and cyan are his, exclusively

| Role | Hex |
| --- | --- |
| Armour dark | `#1B2438` |
| Armour mid | `#2E3A55` |
| Gunmetal edge | `#5A6780` |
| Cape | `#1E50C8` |
| Cape shadow | `#14357F` |
| Circuit accent | `#4FE3FF` |
| Blade glow | `#9BE8FF` |
| Skin | `#E3B48C` |
| Hair | `#4A3426` |

### Bug Lord — corrupted red and void violet

| Role | Hex |
| --- | --- |
| Body void | `#17101C` |
| Corrupt red | `#C81E32` |
| Glow red | `#FF3B4E` |
| Glitch magenta | `#FF4FD8` (accents only, under 5% of surface) |

### Generals — one distinct hue family each

No General may use the Hero's cyan `#4FE3FF` or the Bug Lord's `#C81E32` as a
primary. This keeps the blue-versus-red narrative legible.

Separation is achieved on **three axes**, not hue alone. Two characters can share
a hue if they are separated by value or saturation, and relying on hue alone is
what makes a roster look samey.

| General | Colour identity | Primary | Accent | Separated by |
| --- | --- | --- | --- | --- |
| Ambiguous Client | Shifting iridescent magenta | `#C94FD8` | `#FFD84F` | Hue 295° |
| Spaghetti Architect | Warm ochre and oxblood | `#C98A2E` | `#8B1E1E` | Hue 38° |
| Infinite Loop Beast | Toxic acid green | `#7FD13B` | `#1E6B4F` | Hue 92° |
| Regression Dragon | Bone white and ember | `#DCD2C0` | `#E8622D` | **Value** — the lightest silhouette in the game |
| Merge Conflict Titan | Split mint and coral | `#3FB950` / `#FF6B5A` | `#8B949E` | **Composition** — 50/50 vertical split |
| Production Nightmare | Void charcoal, white-hot | `#22242B` | `#FFE9A8` / `#FF8A2B` | **Value** — the darkest silhouette, the brightest accents |
| Technical Debt King | Verdigris and tarnish | `#4E7F6B` | `#9A7B3F` | Hue 160°, low saturation |

### Hue spread check

Plotted on the colour wheel, ignoring the two value-identified characters:

```
   0°  Bug Lord red (reserved)
  38°  Spaghetti Architect
  92°  Infinite Loop Beast
 140°  Merge Conflict Titan (mint half)
 160°  Technical Debt King
 205°  HERO CYAN (reserved)
 295°  Ambiguous Client
```

No two hue-identified Generals sit within 40° of each other, and neither
reserved colour is encroached on. Regression Dragon and Production Nightmare
are deliberately near-neutral — they are told apart by being the lightest and
darkest characters in the game respectively, which is a stronger distinction at
small size than any hue difference.

> **Note on Merge Conflict Titan.** Its coral `#FF6B5A` is warmer and lighter
> than the Bug Lord's `#C81E32`, and it never appears alone — it is always half
> of a hard vertical split against mint green. The composition does the
> separating, not the hue.

### Value hierarchy

Three separated value bands per character: **dark mass** (armour, body),
**mid** (secondary material), **bright accent** (glow, cape, weapon). The
silhouette must sit at least three value steps away from `#0A0E1A` so characters
never sink into the background.

Accent glow covers **under 15%** of any character's surface area. Glow
everywhere destroys the hierarchy that makes a design readable.

---

## 7. Lighting and rendering

| Property | Rule |
| --- | --- |
| Key light | Upper-left, cool white, consistent on every character |
| Fill | Soft, from lower-right, subtle |
| Rim light | Thin, on the side facing the opponent — separates character from background |
| Self-shadow | Painted into the master; soft-edged, not hard cel bands |
| Cast shadow | **Never baked in.** Drawn in-engine as a soft ellipse so it moves with lunges |
| Ambient occlusion | Soft darkening where parts meet, so cut rig parts still read as connected |
| Rendering | Painted, semi-realistic. Visible brushwork, clean edges. No lineart outline, no cel bands, no airbrushed gradients |
| Materials | Differentiated — matte composite, brushed metal, cloth, leather, crystal each read distinctly |

Because all characters are lit identically, they composite together without
looking pasted on.

---

## 8. Cutout rig part contract

Per ADR-017 each character is one master, cut into parts, rigged with
`Skeleton2D` and animated with `AnimationPlayer`.

### Required parts — humanoid

Listed in draw order, back to front:

| # | Part | Notes |
| --- | --- | --- |
| 1 | `cape_back` | Hero only. The largest single motion element |
| 2 | `back_leg_upper` | |
| 3 | `back_leg_lower` | Includes the foot |
| 4 | `back_arm_upper` | |
| 5 | `back_arm_lower` | Includes the hand |
| 6 | `torso` | Hips to neck, drawn complete |
| 7 | `head` | Includes the neck stub |
| 8 | `hair` | Separate so it can lag behind motion |
| 9 | `front_leg_upper` | |
| 10 | `front_leg_lower` | Includes the foot |
| 11 | `front_arm_upper` | |
| 12 | `front_arm_lower` | Includes the hand |
| 13 | `weapon` | Separate, pivots at the grip |
| 14 | `cape_front` | Optional, if the cape crosses the body |

Non-humanoid characters substitute equivalents (wing segments, tentacle
segments, floating fragments) but follow the same back-to-front ordering.

### Generation rules that make cutting possible

These go into every prompt. They matter more than any aesthetic instruction.

1. **Limbs clear of the torso.** Arms held away from the body, legs apart. No
   arm crossing the chest, no hand resting on a hip.
2. **Weapon clear of the body.** Held out, not across the torso.
3. **Cape swept to one side**, not draped over the shoulders and body.
4. **No occluded joints.** Every shoulder, elbow, hip and knee visible.
5. **Neutral open pose**, not a dynamic action pose. Action comes from the rig.
6. **No overlapping elements of the same colour** — a dark arm against a dark
   torso cannot be cut cleanly.

Each violation costs manual inpainting later. A good pose is worth roughly half
an hour per character.

### Joint placement

Pivots go at anatomical joint centres. Where a part is cut, the piece underneath
must extend **at least 40px past the cut line**, so rotation never reveals a gap.

---

## 9. Character bible

### 9.1 Hero — *the ordered one*

| | |
| --- | --- |
| **Concept** | A modern knight. Clean, precise, engineered. The only character in the game built from intact, deliberate forms. |
| **View** | 3/4 rear, facing up-right |
| **Shape** | Triangle-dominant, square support |
| **Scale** | 1.00 |
| **Palette** | Navy `#1B2438`, cape `#1E50C8`, cyan `#4FE3FF` |

**Design.** Segmented hard-surface plate in matte deep navy and gunmetal
composite. Precise moulded panel seams, subtle venting — sculpted like modern
motorsport protective gear, not hammered medieval steel. **No filigree, no
rivets, no chainmail, no scrollwork.** Large angular pauldrons, articulated
gauntlets, reinforced greaves, dark fitted under-layer.

Thin luminous cyan circuit lines trace sparingly along the armour seams and
across the chestplate. **Sparingly** is load-bearing — this is an accent, not a
finish.

Long royal blue cape clasped at both shoulders, sweeping clear of the body. The
cape is the single strongest silhouette element and the best rig part in the
game; it is never cut short or removed.

Large geometric greatsword, clean faceted blade, cool blue crystalline edge
glow. Held well away from the torso.

No helmet — the face is needed for the Ultimate's dramatic beat. Short tousled
dark brown hair, mature adult features.

**Why modern reads as modern:** it comes from manufacturing language (moulded
panels, precise seams, exposed joints), not from bolting sci-fi gadgets onto a
medieval knight.

---

### 9.2 Bug Lord — *the corrupting one*

| | |
| --- | --- |
| **Concept** | Not a demon. The embodiment of corrupted code — a thing made of broken systems, fragmenting at its own edges. |
| **View** | 3/4 front, facing down-left |
| **Shape** | Fracture-dominant |
| **Scale** | 2.10 — the largest thing in the game |
| **Palette** | Void `#17101C`, corrupt red `#C81E32`, glow `#FF3B4E` |

**Design.** Towering, broad-shouldered, insectile-humanoid. The body is
matte void-black, so dark it reads as absence. Along the limbs and torso the
form **fragments into floating angular blocks** — displaced, offset, glitched
out of alignment, with corrupt red light bleeding from the gaps. The silhouette
should look unstable, as though the creature is mid-crash.

Wings are not feathered or membranous but **shattered planes** — jagged
geometric shards held in a wing-like arrangement, some detached and drifting.

Head: no face in the conventional sense. A dark angular mask with a horizontal
band of red light where eyes would be, broken into uneven segments like a
corrupted display.

**Deliberate departure from the existing art.** The current Bug Lord is a
red-and-black winged demon. It's well rendered but would sit unremarked in any
fantasy game. The redesign keeps the menace, the scale and the red, and replaces
generic demonic anatomy with corruption-as-form.

**Restraint:** glitch effects live at the edges and the gaps. The core mass stays
solid and dark, or the silhouette dissolves and the character stops reading.

---

### 9.3 The Generals

Each entry states what the design must *communicate*, not just what it looks
like. A General that is beautiful but doesn't express its concept has failed
pillar 3.

#### Build and archetype variety

Nine characters that share one humanoid build is a roster that reads as one
character in seven costumes. Builds are deliberately spread:

| Character | Archetype | Build | Silhouette class |
| --- | --- | --- | --- |
| Hero | Male knight | Athletic humanoid, 8 heads | Tall, caped, triangular |
| Ambiguous Client | **Female** executive | Slender, elegant, imperious | Narrow, trailing, vertical |
| Spaghetti Architect | Androgynous hooded figure | Hunched, swallowed by its own tangle | Wide, knotted, shapeless |
| Infinite Loop Beast | **Beast**, non-humanoid | Serpentine quadruped | Looping, horizontal |
| Regression Dragon | **Beast**, draconic | Winged, lean, long-necked | Angular, wide wingspan |
| Merge Conflict Titan | **Two-gendered** colossus | Colossal humanoid, split down the centre | Massive, bilateral, four-armed |
| Production Nightmare | **Machine construct** | Sprawling, top-heavy, collapsing | Wide, unstable, tower-like |
| Technical Debt King | Male monarch | Obese, enthroned, layered | Broad, squat, pyramidal |
| Bug Lord | Insectile overlord | Towering, fragmenting | Huge, jagged, winged |

No two characters share a silhouette class. Test: at 25% size in solid black,
every one of the nine should be identifiable by outline alone.

---

#### World 1 · Ambiguous Client — *Reqoria*

| | |
| --- | --- |
| **Archetype** | Female. A client, not a monster. |
| **Build** | Slender, tall, elegant. Narrow vertical silhouette. |
| **Must communicate** | Requirements that will not hold still. Contradiction. |
| **Shape** | Unstable, asymmetric — left and right halves deliberately mismatched |
| **Palette** | Magenta `#C94FD8`, yellow `#FFD84F` |
| **Scale** | 1.05 |

**Design.** An imperious woman in a long, sharply-tailored coat-dress that
trails behind her — corporate rather than fantastical. Her outline is **doubled
and ghosted**, as though drawn twice slightly out of register, so her edges
never quite settle. Her face shifts between two expressions, both visible at
once, neither resolving.

Translucent magenta document-panels orbit her at different depths, each showing
a different contradictory layout. One hand gestures one way; the other, in a
mismatched sleeve, gestures the opposite way. Her hair drifts as though in a
different gravity to the rest of her.

**Keep from existing:** the floating translucent panels — a genuinely good hook.
**Drop:** the blue crystalline sword. It competes directly with the Hero.

She should look like she could be *reasoned with*, and like reasoning would not
help.

---

#### World 2 · Spaghetti Architect — *Architara*

| | |
| --- | --- |
| **Archetype** | Androgynous hooded figure. Gender unreadable and intentionally so. |
| **Build** | Hunched, wide, lost inside its own tangle |
| **Must communicate** | Over-complicated structure. Nothing separable. |
| **Shape** | Spiral / knot dominant |
| **Palette** | Ochre `#C98A2E`, oxblood `#8B1E1E` |
| **Scale** | 1.10 |

**Design.** A hooded figure in heavy cream and ochre robes, its body lost inside
a dense snarl of cables, pipes and conduits that loop out and back with no
discernible start or end. Several cables plug back into the figure itself.
Carries a lantern-staff with a glowing rune.

The tangle should be dense enough that where the figure ends and the mess begins
is genuinely ambiguous — that ambiguity *is* the design.

**Keep from existing:** nearly everything. This is the strongest design you
have. Needs re-angling to 3/4 front, denser cabling, and its palette pushed
warmer to separate from the Debt King.

---

#### World 3 · Infinite Loop Beast — *Codexis*

| | |
| --- | --- |
| **Archetype** | **Beast.** Wholly non-humanoid. No face, no hands, no clothing. |
| **Build** | Serpentine quadruped, long-bodied, low to the ground |
| **Must communicate** | Recursion. Something that cannot stop. |
| **Shape** | Spiral, ouroboros |
| **Palette** | Acid green `#7FD13B`, deep green `#1E6B4F` |
| **Scale** | 1.30 |

**Design.** A long serpentine creature on many legs, whose body **loops through
itself** — the tail enters its own flank and emerges at the shoulder, so the
form has no beginning. Concentric ring structures orbit the torso, each smaller
and nested inside the last.

The legs repeat in a diminishing series down the body, more of them than anatomy
justifies, each smaller than the one before. Its head is a blunt, eyeless wedge —
this thing does not think, it only continues.

Horizontal, low silhouette. The only character in the roster that is wider than
it is tall.

---

#### World 4 · Regression Dragon — *Testara*

| | |
| --- | --- |
| **Archetype** | **Beast.** Draconic, winged. |
| **Build** | Lean, long-necked, wide wingspan. Not bulky — worn. |
| **Must communicate** | Old problems returning. Damage that will not stay fixed. |
| **Shape** | Triangle, angular |
| **Palette** | Bone `#DCD2C0`, ember `#E8622D` — **the lightest character in the game** |
| **Scale** | 1.60 |

**Design.** A gaunt, pale dragon the colour of old bone and dry ash. Its body is
a map of repairs: stitched plates, patched scales in mismatched tones, surgical
staples, bindings. Several patches have **split open again**, ember-orange light
showing through the gaps like something reignited underneath.

Sections of the body appear to be reverting — a foreleg rendered in a cruder,
earlier form than the rest, as though that part of it rolled back.

Its pale value is deliberate. Against the dark battle background it is the
brightest silhouette in the game, and it is the only enemy that reads light-on-dark.

---

#### World 5 · Merge Conflict Titan — *Gitforge*

| | |
| --- | --- |
| **Archetype** | Colossus. **Two incompatible versions of one being** — one half male, one half female. |
| **Build** | Colossal humanoid, four arms, split vertically down the centre |
| **Must communicate** | Two versions of the same thing that cannot reconcile. |
| **Shape** | Fracture, bilateral split |
| **Palette** | Mint `#3FB950` and coral `#FF6B5A`, split 50/50, seam grey `#8B949E` |
| **Scale** | 1.75 |

**Design.** A colossus split vertically down its exact centre line. The two
halves are the **same being built two different ways**: the left half male,
heavier, older armour, weathered; the right half female, leaner, newer armour,
unweathered. Different proportions, different silhouette, fused along a jagged
seam that glows grey-white.

Four arms — two per version — each pair mid-gesture in a *conflicting* action:
one pair reaching forward, the other pair pulling back.

The gender split is the clearest possible expression of "two incompatible
versions of the same entity", and it makes the character unmistakable in the
roster.

The seam is the focal point. Everything else serves it.

---

#### World 6 · Production Nightmare — *Deployon*

| | |
| --- | --- |
| **Archetype** | **Machine construct.** Not a creature. Nothing organic. |
| **Build** | Sprawling, top-heavy, wider than tall, actively collapsing |
| **Must communicate** | Everything failing at once, in public. |
| **Shape** | Unstable tower |
| **Palette** | Void charcoal `#22242B`, white-hot `#FFE9A8`, warning `#FF8A2B` — **the darkest character in the game** |
| **Scale** | 1.45 |

**Design.** A hulking mass assembled from server racks, cable bundles, cooling
units and scaffolding, stacked precariously and **leaning past its own centre of
gravity**. Almost black — the darkest silhouette in the roster.

Against that darkness, violent brightness: white-hot light blasting from vents
and cracks, amber warning strobes across its face, small fires in the recesses.
Components are visibly detaching and falling away mid-collapse.

No face, no eyes, no limbs in any conventional sense. It should not read as
alive — it should read as an *incident*.

Its identity is value, not hue: the blackest mass and the brightest accents in
the game, in the same silhouette.

---

#### World 7 · Technical Debt King — *Legacyon*

| | |
| --- | --- |
| **Archetype** | Male monarch, enthroned. |
| **Build** | Obese, squat, broad. Pyramidal — wide base, small head. |
| **Must communicate** | Decades of shortcuts, propped up, still somehow running. |
| **Shape** | Square, layered strata |
| **Palette** | Verdigris `#4E7F6B`, tarnish `#9A7B3F` |
| **Scale** | 1.35 |

**Design.** An enormously fat enthroned figure in decayed finery, wearing a
crown gone green with corrosion. His body is visibly composed of **strata** —
older layers showing through newer ones like sediment, each addition laid over
the last, nothing ever removed.

Held together with visible tape, clamps, rope, wedges and improvised braces. The
verdigris corrosion spreading across the brass is what separates him from the
Spaghetti Architect's warm ochre — cold green rot against warm tangle.

He should look as though pulling any single prop would bring the whole thing
down, and as though he has looked like this for a very long time.

---

## 10. Environments and props

### Planets

Eight planets on the Space Map. Current versions are 85x85 pixel art and are
**replaced** — they violate pillar 2.

| Property | Value |
| --- | --- |
| Canvas | 1024 x 1024, transparent PNG |
| Style | Painted, semi-realistic, soft terminator between lit and dark sides |
| Lighting | Lit from upper-left, matching character lighting |
| Colour | Each planet carries its General's palette, desaturated ~30% |
| Detail | Readable at 128px on the map and at 800px on arrival |

Planets are **static images with an in-engine rotation or shimmer**, not frame
animations. One image per world, not thirty frames.

### Rocket

Current rocket is pixel art at 198x198 and is replaced.

| Property | Value |
| --- | --- |
| Canvas | 1024 x 1024, transparent PNG |
| Orientation | **Drawn facing right (east)** — never drawn facing up and rotated in-engine |
| Style | Matches the Hero: matte navy and gunmetal panels, cyan accent trim |
| Shape | Sleek triangular profile, clean panel seams |
| Parts | Hull, and engine-glow as a **separate layer** so it can pulse independently |

Drawing it facing east removes the non-uniform scale and rotation hack currently
in `RocketTravel.tscn`.

### Battle backgrounds

One per world, `1920 x 1080`, painted, heavily atmospheric and **low contrast** —
a background that competes with the characters is a failed background.

Base value darker than any character's darkest mass. Each carries its world's
hue at low saturation. Suggestion rather than detail: silhouetted forms, haze,
depth, a light source consistent with §7.

---

## 11. UI and VFX language

### UI

| Property | Rule |
| --- | --- |
| Panels | Dark `#1A1F33`, subtle border, slight transparency, soft corner radius |
| Borders | 2px, cyan `#4FE3FF` when active, grey `#5A6780` when inactive |
| Typography | One display face for headings and numbers, one clean sans for body. Fonts to be chosen in Phase 7 |
| HP bar — Hero | Fill `#3FB950`, warning `#F0A030`, critical `#F85149` |
| HP bar — enemy | Fill `#C81E32` on `#1A1F33` |
| Bug Lord persistent bar | Distinct treatment: thicker, `#FF3B4E`, sitting above the encounter bar |
| Timer | Cyan at rest, shifts to `#F85149` under 10 seconds |

UI is part of the art direction, not a separate concern. Default engine styling
fails pillar 2.

### VFX

| Effect | Treatment |
| --- | --- |
| Hero attack impact | Cyan-white slash arc, sharp, 3–4 frames |
| Enemy attack impact | The attacker's accent colour, shape matching its concept |
| Hit flash | Solid white overlay at 80% for ~0.08s |
| Damage numbers | Display font, white for hero damage dealt, `#F85149` for damage taken |
| Ultimate | The only place cyan is allowed to dominate the frame. Full-screen, brief |
| Bug Lord aura | Slow-drifting red fragments, low opacity |

**Restraint rule:** at most **two** simultaneous VFX elements on screen. The
Ultimate is the single exception.

---

## 12. Prompt templates

Fill every slot. Do not freestyle.

### Master template — enemies (3/4 front)

```
Full-body character reference of a single original {ARCHETYPE} for a 2D
fantasy RPG, three-quarter FRONT view, the character faces toward the lower
left of frame at roughly 45 degrees, eye-level camera, no perspective
distortion.

{CONCEPT SENTENCE — what the creature IS, one line}

{DESIGN PARAGRAPH — form, materials, distinctive features, from §9}

Shape language: {SHAPE} dominant, bold readable silhouette.
Colour palette strictly limited to {PRIMARY HEX} as primary, {ACCENT HEX} as
accent, with dark neutral mass. Glowing accents cover less than 15% of the
surface.

Pose: neutral and open, standing, arms held clear of the torso, legs apart,
weapon held away from the body, every joint visible, nothing overlapping
anything else of a similar colour.

Lighting: cool key light from the upper left, soft fill from the lower right,
thin rim light on the left edge. Soft painted self-shadow. No cast shadow on
the ground.

Painted 2D game concept art, semi-realistic stylised rendering, clean confident
brushwork, visible material differentiation, detailed but readable at small
size, professional character concept art, sharp, 4K, transparent background.

Single subject only, exactly one original character, no other figures, no
background scenery, no ground plane, no cast shadow, no text, no watermark, no
logos, no labels, no frame borders, no distorted anatomy, no extra fingers.
```

### Master template — Hero (3/4 rear)

Identical, with the view clause replaced:

```
three-quarter REAR view, the character faces AWAY from the viewer toward the
upper right at roughly 135 degrees, we see his back and shoulders with a sliver
of his cheek visible past the head, cape sweeping clear of the body to one side
```

### Slot values

| Slot | Source |
| --- | --- |
| `{ARCHETYPE}` | §9 entry, first line |
| `{CONCEPT SENTENCE}` | §9 "Must communicate" |
| `{DESIGN PARAGRAPH}` | §9 "Design" |
| `{SHAPE}` | §9 "Shape" |
| `{PRIMARY HEX}` / `{ACCENT HEX}` | §6 palette table |

### Generation practice

- **16:9 or 1:1**, minimum 2048px on the long edge
- **Generate 4 variants**, always. Model sheets and complex characters fail often
- Judge only against §13 — not against "which looks coolest"

---

## 13. Acceptance checklist

Every master passes **all** of these before it enters the project. A failure is
regenerated, not patched.

**Composition**

- [ ] Correct view — 3/4 rear for Hero, 3/4 front for enemies
- [ ] Faces the right direction — Hero up-right, enemies down-left
- [ ] Eye-level camera, no perspective distortion
- [ ] Whole character in frame with 64px+ margin, nothing clipped

**Readability**

- [ ] Fill solid black at 25% size — still identifiable as this character
- [ ] Not confusable with any other character's black silhouette
- [ ] Converted to greyscale — still reads, three distinct value bands
- [ ] Placed on `#0A0E1A` — silhouette does not sink into the background

**Concept**

- [ ] The software-engineering idea is visible without explanation
- [ ] Would not be mistaken for a generic fantasy monster
- [ ] Distinct from every other General at a glance

**Palette**

- [ ] Uses only its assigned hue family from §6
- [ ] Does not use Hero cyan or Bug Lord red as a primary
- [ ] Glowing accents under 15% of surface area

**Rig readiness**

- [ ] All limbs clear of the torso
- [ ] Weapon clear of the body
- [ ] Every joint visible and unoccluded
- [ ] No same-colour overlaps that cannot be cut apart
- [ ] Neutral open pose, not a dynamic action pose

**Technical**

- [ ] 2048x2048, transparent background
- [ ] Feet at the y=1900 baseline
- [ ] No baked cast shadow
- [ ] No text, watermark, logo, label or border anywhere in the image

---

## 14. Deliberately out of scope

Recorded so they are not revisited by accident:

- **Frame-by-frame sprite sheets** — superseded by rigs (ADR-017)
- **Multiple hero costumes or equipment variants** — no equipment system exists
- **Walk cycles / overworld sprites** — the game has no walkable world
- **Facial expression sets** — battle characters are seen too small for this
- **Environment tilesets** — battles use a single painted background per world
- **Normal maps / dynamic lighting** — lighting is painted in
- **Hero variants per world** — one hero, one look

---

## 15. Open questions

1. **Do the existing Ambiguous Client and Spaghetti Architect get regenerated, or
   re-angled and kept?** Both are decent; both face the wrong way. Regenerating
   is cleaner but loses work already done.
2. **Is a General's design approved on the master alone, or on the master plus a
   test rig?** Recommend master plus rig for the Hero only, then masters alone
   once the pipeline is proven.
3. **Font selection** — deferred to Phase 7, but earlier would let UI mockups be
   evaluated properly.

---

*Amendments to this document are recorded in `docs/DECISIONS.md`.*
