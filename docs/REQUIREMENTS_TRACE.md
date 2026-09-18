# CodeQuest — Requirements Traceability Matrix

**Source of requirements:** `CodeQuest_Master_Project_Brief.pdf`, sections 1–21
and Appendices A–B.
**Traced against:** the implementation as of this document's date.
**Companion documents:** `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/ART_SPEC.md`

Every requirement in the brief is listed, including the ones not met. A trace
that only lists successes proves nothing, because the reader cannot tell
whether the gaps were considered or simply missed.

---

## Status key

| Status | Meaning |
|---|---|
| **Met** | Implemented and verified by running the game |
| **Partial** | Implemented in part; the remainder is stated in the row |
| **Diverged** | Deliberately built differently; the deciding ADR is named |
| **Open** | Not implemented. Still intended |
| **Deferred** | Not implemented. Explicitly out of scope for this version |

## Summary

| Status | Count |
|---|---|
| Met | 107 |
| Partial | 8 |
| Diverged | 6 |
| Open | 14 |
| Deferred | 2 |
| **Total** | **137** |

---

## FR-1 Game concept · Brief §2

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| FR-1.1 | Player explores 8 worlds | `WorldDatabase` + 8 `WorldData` resources | Met |
| FR-1.2 | Each world holds a software-engineering-themed General | `WorldData.general → EnemyData` | Met |
| FR-1.3 | Questions answered during combat | `QuestionPanel` inside `Battle.tscn` | Met |
| FR-1.4 | Defeating enemies progresses the player | `GameState.clear_world()` | Met |
| FR-1.5 | Player eventually faces the Bug Lord | Bug Lord encounter per world; final confrontation in Bugfall | Met |
| FR-1.6 | Content integrated into gameplay, not a separate quiz app | Questions drive attack/damage; explanations shown in-fight | Met |

## FR-2 Worlds and Generals · Brief §3

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| FR-2.1 | World 1 Ambiguous Client | `reqoria.tres` → `ambiguous_client.tres` | Met |
| FR-2.2 | World 2 Spaghetti Architect | `architara.tres` | Met |
| FR-2.3 | World 3 Infinite Loop Beast | `codexis.tres` | Met |
| FR-2.4 | World 4 Regression Dragon | `testara.tres` | Met |
| FR-2.5 | World 5 Merge Conflict Titan | `gitforge.tres` | Met |
| FR-2.6 | World 6 Production Nightmare | `deployon.tres` | Met |
| FR-2.7 | World 7 Technical Debt King | `legacyon.tres` | Met |
| FR-2.8 | World 8 is the Bug Lord, not another General | `bugfall.tres` → `bug_lord.tres`; `BattleRequest.for_world()` routes straight to the encounter | Met — ADR-002 |
| FR-2.9 | Bug Lord is the threat connecting the worlds | Persistent HP is the campaign's progress bar | Met — ADR-003 |

## FR-3 Space Map · Brief §4

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| FR-3.1 | Space Map with 8 planets | `SpaceMap.gd` builds from `WorldDatabase` | Met |
| FR-3.2 | Reqoria unlocked initially | `GameState.is_world_unlocked(order_index)`; Reqoria is index 0 | Met |
| FR-3.3 | Other worlds locked and dimmed | Locked planets tinted; click guarded | Met |
| FR-3.4 | Select world → rocket travel scene | `SceneRouter.goto_scene(RocketTravel, setup)` | Met |
| FR-3.5 | Rocket faces east / right | Rocket travels left → right | Met |
| FR-3.6 | Rocket launches | Phase A tween | Met |
| FR-3.7 | Destination planet appears ahead / right | `_show_destination()` | Met |
| FR-3.8 | Rocket approaches destination | Phase B, eased | Met |
| FR-3.9 | Arrival completes, battle begins | `_arrive()` → `_enter_battle()` | Met |
| FR-3.10 | Starfield during travel | `$Stars` particles | Met |
| FR-3.11 | Particles during travel | Same node; no impact or thruster particles | Partial |
| FR-3.12 | Acceleration / deceleration | Two-phase tween, linear then eased | Met |
| FR-3.13 | Destination planet animation | `AnimatedSprite2D`, 30 frames | Met |
| FR-3.14 | Arrival transition | `SceneRouter` fade | Met |
| FR-3.15 | Reusable world destination logic | `setup(WorldData)`; no world named in the scene | Met |

## FR-4 Battle system · Brief §5

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| FR-4.1 | One generic battle system for all Generals and the Bug Lord | One `Battle.tscn`; no enemy named in battle code | Met |
| FR-4.2 | Hero bottom-left, faces top-right | `hero_pos_general`; 3/4 rear frames | Met |
| FR-4.3 | Enemy top-right, faces bottom-left | `enemy_pos_general` | Met |
| FR-4.4 | Hero uses 3/4 rear-side perspective | Art contract, `ART_SPEC` §2 | Met |
| FR-4.5 | Enemies show front / front-side | Art contract, `ART_SPEC` §2 | Met |

## FR-5 General battle flow · Brief §6

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| FR-5.1 | General enters | `_start()` intro beat | Partial — the pause exists; there is no entrance animation |
| FR-5.2 | Question appears | `_next_question()` | Met |
| FR-5.3 | Correct → hero attacks, enemy loses HP | `_exchange_blow(hero, enemy, hero.attack_damage)` | Met |
| FR-5.4 | Wrong → enemy attacks, hero loses HP | Same call, arguments swapped | Met |
| FR-5.5 | Next question only after animation finishes | Three guards: state gate, UI lock, single awaited chain | Met |
| FR-5.6 | Question panel unavailable during attack / damage | `QuestionPanel.lock()` + `hide_panel()` | Met |
| FR-5.7 | Ordered sequence: question → answer → verdict → attack → damage → HP → next | `_resolve_answer()` reads in that order | Met |

## FR-6 Bug Lord system · Brief §7

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| FR-6.1 | Bug Lord appears after the General is defeated | `_leave()` routes General victory into `for_bug_lord()` | Met |
| FR-6.2 | Countdown timer starts | Per-question timer, boss mode only | Diverged — ADR-023 |
| FR-6.3 | Player completes a timed challenge | 10 questions, 70% pass, per-question limits | Diverged — ADR-025 |
| FR-6.4 | Hero performs the Ultimate | `_play_ultimate()`, `hero_ultimate_part1/2` | Met |
| FR-6.5 | Bug Lord persistent HP decreases | `GameState.clear_world()` subtracts 1000 | Met |
| FR-6.6 | Bug Lord escapes | `_boss_withdraws()`; plays `defeat` instead when HP reaches 0 | Met |
| FR-6.7 | Next world becomes available | Unlock derived from `defeated_generals.size()` | Met |
| FR-6.8 | 500 HP encounter pool | Field present on `bug_lord.tres`, **unused** | Diverged — ADR-025 |
| FR-6.9 | 8000 persistent campaign HP | `GameState.bug_lord_hp` | Met — ADR-004 |
| FR-6.10 | The two HP concepts stay separate | Different objects: one on `EnemyData`, one on `GameState` | Met — ADR-004 |

## FR-7 Bug Lord timer · Brief §8

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| FR-7.1 | A countdown exists in every Bug Lord fight | `has_timer` on `bug_lord.tres`; every encounter uses it | Met |
| FR-7.2 | No countdown during General fights | Timer built only when the enemy requests one | Met |
| FR-7.3 | Hero HP 0 → return to that world's General | `_goto_general()` | Met |
| FR-7.4 | Timer 0 → return to that world's General | Timer expiry now counts as a wrong answer instead | Diverged — ADR-023 |
| FR-7.5 | The General must be beaten again before retrying the Bug Lord | Failure routes to the General fight, not the map | Met |

## FR-8 Replay · Brief §9

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| FR-8.1 | Completed worlds not replayable | Replayable, but `clear_world()` is idempotent, so a cleared world cannot damage the Bug Lord twice | Diverged |

## FR-9 Hero · Brief §10

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| FR-9.1 | One persistent playable character | `hero.tres`, single `HeroData` | Met |
| FR-9.2 | Battle orientation bottom-left → top-right | `hero_pos_general`, `lunge_offset` | Met |
| FR-9.3 | Idle state | `idle_frames` | Met |
| FR-9.4 | Normal attack state | `attack_frames` | Met |
| FR-9.5 | Taking damage state | `damage_frames` | Met |
| FR-9.6 | Ultimate attack state | `ultimate_frames`, two sheets as one move | Met |
| FR-9.7 | Normal attack lunges toward the enemy and returns | `play_attack()` / `return_home()` | Met |
| FR-9.8 | Ultimate used against the Bug Lord, more dramatic | Fires only on a passed encounter | Met |
| FR-9.9 | Lunge handled in Godot, not baked into the sprite | Tween on the node's `position`; `_home` restored | Met |

## FR-10 Enemy animation · Brief §11

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| FR-10.1 | Every General and the Bug Lord have Idle / Attack / Damage / Defeat | 8 × 4 `SpriteFrames` | Met |
| FR-10.2 | Enemy orientation top-right → bottom-left | `enemy_pos_general`, negative lunge | Met |
| FR-10.3 | Animations data-driven and reusable | Frames are fields on `EnemyData`; `Combatant` is enemy-agnostic | Met |

## FR-11 Assets · Brief §12–13

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| FR-11.1 | Hero sheets complete | 10 sheets, including the Bug Lord set and defeat | Met |
| FR-11.2 | Bug Lord sheets complete | 5 sheets | Met |
| FR-11.3 | All seven Generals' sheets complete | 7 × 4 = 28 sheets | Met |
| FR-11.4 | Hero Ultimate as two 10-frame sheets played as one 20-frame move | Both sheets in one `SpriteFrames` | Met |
| FR-11.5 | Nested `assets/sprites/{hero,generals/<name>,bug_lord}/` naming | Flat sheet-per-animation naming instead | Diverged — the art was authored that way; contract follows assets |

## FR-12 Sprite / visual requirements · Brief §14

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| FR-12.1 | Consistent design, angle, proportions, style | `ART_SPEC.md` §2, §4; 22-point acceptance checklist | Met |
| FR-12.2 | Consistent scale, baseline, anchor | Normalised in code to a reference frame height, plus a per-character `attack_scale` | Met — ADR-021 |
| FR-12.3 | Transparent backgrounds, frame isolation | Asset contract | Met |
| FR-12.4 | No frame bleeding or row-to-row shifts | Verified by eye per sheet | Partial — no automated check |
| FR-12.5 | No character overlap | Layout tuned per mode | Met |
| FR-12.6 | `AnimatedSprite2D` / `SpriteFrames` or equivalent | Exactly that | Met |

## FR-13 Godot architecture · Brief §15

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| FR-13.1 | `EnemyData` resource with the listed fields | `enemy_data.gd`; all listed fields present | Met |
| FR-13.2 | `QuestionData` resource | `question_data.gd`, plus `explanation` and `time_limit` | Met |
| FR-13.3 | `WorldData` with identity, destination, progression and assets | `world_data.gd` | Met |
| FR-13.4 | Battle Controller stays generic | No enemy named in `BattleController.gd` | Met |
| FR-13.5 | Question Panel stays reusable | Used unchanged by all nine fights | Met |

## FR-14 Question system · Brief §16

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| FR-14.1 | Questions may have 2, 3 or 4 options | Panel shows and hides per question | Met |
| FR-14.2 | Up to four buttons, unused hidden | `show_question()` | Met |
| FR-14.3 | Load → display → select → correct/wrong signal → controller resolves | `answer_selected(index, is_correct)` | Met |
| FR-14.4 | Question content for all nine fights | 129 questions in `data/questions.csv`; 49 General, 80 Bug Lord | Met |
| FR-14.5 | No question repeats within or across encounters | Verified programmatically across all 129 | Met — ADR-025 |

## NFR-1 Visual polish · Brief §17

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| NFR-1.1 | Attack anticipation | — | Open |
| NFR-1.2 | Lunge | `play_attack()` | Met |
| NFR-1.3 | Follow-through | — | Open |
| NFR-1.4 | Impact frames | `impact_pause` before damage lands | Partial |
| NFR-1.5 | Damage reactions | `play_damage()` | Met |
| NFR-1.6 | Hit flashes | `Combatant.flash()` | Met |
| NFR-1.7 | Screen shake | — | Open |
| NFR-1.8 | Camera zoom | — | Open |
| NFR-1.9 | Damage numbers | — | Open |
| NFR-1.10 | Particles / VFX | Lightning in Bugfall; rocket starfield | Partial |
| NFR-1.11 | Boss entrance | Rise from below, arena floods to his colour | Met |
| NFR-1.12 | Boss defeat | Defeat animation on the final Ultimate | Met |
| NFR-1.13 | Animated HP bars | `_tween_bar()` | Met |
| NFR-1.14 | Button feedback | Colour on answer; no press animation | Partial |
| NFR-1.15 | Countdown animation | Numeric, turns red under 5s; no animation | Partial |
| NFR-1.16 | Rocket acceleration | Two-phase tween | Met |
| NFR-1.17 | Starfield | Rocket travel, Space Map and menu | Met |
| NFR-1.18 | Planet reveal | `_show_destination()` | Met |
| NFR-1.19 | Transitions | `SceneRouter` fade on every change | Met |
| NFR-1.20 | Sound timing | No audio exists | Open |
| NFR-1.21 | Dramatic timing | `feedback_hold`, `impact_pause`, `result_hold`, `boss_arrival_time` — all tunable | Met |

## NFR-2 Software engineering requirements · Brief §18

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| NFR-2.1 | Avoid one giant script | 12 scripts, largest ~520 lines, single responsibility each | Met |
| NFR-2.2 | Modular scenes | 6 scenes, each independently runnable | Met |
| NFR-2.3 | Reusable components | `Combatant`, `QuestionPanel`, `SceneRouter`, `LightningStrike` | Met |
| NFR-2.4 | Resources / data objects | 6 resource types | Met |
| NFR-2.5 | Clear responsibilities | Documented in `ARCHITECTURE.md` §3 | Met |
| NFR-2.6 | Signals / events | `answer_selected`, `hp_changed`, `died`, `battle_finished`, `progress_changed`, `scene_changed` | Met |
| NFR-2.7 | State machines where useful | `BattleController.State`, five states with guards | Met |
| NFR-2.8 | Separation of data / gameplay / presentation | Three-layer model, dependencies one-way | Met |
| NFR-2.9 | Architecture documentation | `ARCHITECTURE.md`, `DECISIONS.md` (25 ADRs), `ART_SPEC.md` | Met |
| NFR-2.10 | SRS | — | Open |
| NFR-2.11 | WBS | — | Open |
| NFR-2.12 | Use Case diagram | — | Open |
| NFR-2.13 | Class diagram | — | Open |
| NFR-2.14 | Component diagram | — | Open |
| NFR-2.15 | ER diagram | — | Open |
| NFR-2.16 | DFD | — | Open |
| NFR-2.17 | State diagram | Described in prose in `ARCHITECTURE.md` §4.3; not drawn | Partial |
| NFR-2.18 | Sequence diagram | — | Open |

## NFR-3 Tooling · Brief §19

| ID | Requirement | Implementation | Status |
|---|---|---|---|
| NFR-3.1 | Evaluate the AI development workflow | Evaluated; Claude retained. Per-change approval workflow adopted | Met |
| NFR-3.2 | Git / GitHub integration | Repository live; every change committed with a written message | Met |
| NFR-3.3 | Asset pipeline | External generation → `SpriteFrames` → `EnemyData`; contract in `ART_SPEC.md` | Met |
| NFR-3.4 | Documentation tooling | Markdown in-repo, versioned with the code | Met |
| NFR-3.5 | Recommend only tools that materially help | Higgsfield and Leonardo evaluated for art; no plugins adopted | Met |

## OUT Deferred · Brief §9, §20

| ID | Requirement | Status |
|---|---|---|
| OUT-1 | Replay of completed worlds as a designed feature | Deferred |
| OUT-2 | Difficulty settings, multiple save slots, accessibility options | Deferred — never requested |

---

## Gaps, ranked

**1. Nine of the eighteen SE documents in §18 are not produced** (NFR-2.10 to
NFR-2.18). This is the largest single gap in the project, and it is
documentation rather than code. The system itself already satisfies the
structural requirements those diagrams would describe — the information exists,
it has not been drawn.

**2. No audio at all** (NFR-1.20). The only requirement in §17 with nothing
behind it whatsoever.

**3. Six visual-polish items are open** (anticipation, follow-through, screen
shake, camera zoom, damage numbers, and the polish half of particles). None is
structural; each is an addition to `Combatant` or `BattleController`.

**4. Automated verification covers data and progression logic only.** Five
checks (T1–T5, 1159 assertions) run headless and all pass. Everything visual —
including FR-12.4 — is checked by eye. That boundary is deliberate and stated
in `TEST_STRATEGY.md` §8.

**5. The game has never been exported**, so no requirement in this matrix is
verified outside the editor.
