# DA-2 Report Plan — BCSE301L Software Engineering

**Deliverable:** one Word document, Times New Roman 13, 18 sections as specified
in `Project_Report_Format.docx`. Original prose (plagiarism-checked).

---

## 1. What the format asks for, and where the content already is

| # | Section | Source | New writing needed |
|---|---|---|---|
| 1 | Title page | Template in the format file (logo included) | Names + register numbers only |
| 2 | Table of contents | Generated last, after pagination | None |
| 3 | Abstract (1 page) | — | **All** (~350 words) |
| 4 | Introduction | Master Brief §1–2 | **All** (~2 pages) |
| 5 | Literature survey / Related works | — | **All — needs real sources** |
| 6 | Existing work / system | — | **All** — comparison of 4–5 existing products |
| 7 | Proposed work / system | `ARCHITECTURE.md` §1, Brief §2–3 | Rewrite for a reader |
| 8 | SRS | `REQUIREMENTS_TRACE.md` (137 requirements) | Reformat to IEEE-style SRS |
| 9 | System design / Architecture | `ARCHITECTURE.md` §2–5 | Rewrite + **diagrams** |
| 10 | Technology Stack | `ARCHITECTURE.md`, `project.godot` | ~1 page |
| 11 | Working modules | `ARCHITECTURE.md` §3 (component inventory) | Light rewrite |
| 12 | Module descriptions + diagrams | `ARCHITECTURE.md` §3–4 | **Diagrams** + per-module prose |
| 13 | Test Plan and Test Suite | `TEST_STRATEGY.md` (near-complete) | Light rewrite |
| 14 | Screenshots | — | **Capture needed** (~12–16 shots) |
| 15 | Conclusion | — | **All** (~1 page) |
| 16 | Future work | `REQUIREMENTS_TRACE.md` "Gaps, ranked" | Needs refresh (see §3) |
| 17 | References | From section 5 | **All** |
| 18 | Appendix: Implementation | Repo | Select ~8 listings |

**Roughly:** 60% is re-packaging of documents that already exist, 25% is new
prose, 15% is diagrams and screenshots that do not exist yet.

---

## 2. The three things that are not yet written and cannot be re-packaged

### A. Literature survey + Existing systems (sections 5, 6, 17)

The only part of this report that needs outside research. Plan: 8–12 real,
citable sources across three themes —

1. **Game-based learning / serious games** — does game framing improve
   retention of technical material? (Peer-reviewed; e.g. the gamification and
   educational-games literature.)
2. **Teaching software engineering specifically** — SE education papers on
   SDLC pedagogy, since CodeQuest's eight worlds *are* the SDLC phases.
3. **Existing products** — CodeCombat, CodinGame, LightBot, Human Resource
   Machine, Duolingo's streak/XP model. Each gets: what it teaches, how it
   teaches, and the gap CodeQuest fills (they teach *coding*; CodeQuest teaches
   *software engineering process*, which is the novelty worth claiming).

I will search for and verify these; every claim gets a real citation. Nothing
invented.

### B. The nine SE diagrams (sections 9, 12)

Still the largest open item in `REQUIREMENTS_TRACE.md` (NFR-2.10–2.18). The
structural information all exists in the code — it has never been drawn. Plan
for nine:

| Diagram | Content |
|---|---|
| Use case | Player ↔ study lesson, travel, fight General, face Bug Lord, save/load |
| Class | `WorldData`, `WorldDatabase`, `QuestionBank`, `LessonBank`, `Combatant`, `BattleController`, `GameState` |
| Sequence ×2 | (i) General fight; (ii) Bug Lord exam incl. per-question timer |
| Activity | Full world loop: LEARN → UNDERSTAND → APPLY → TEST → PROGRESS |
| State chart | `BattleController` states; and Bug Lord persistent-HP states |
| Component | Autoloads, data layer, flow layer, battle layer, scenes |
| Deployment | Godot editor → export template → Windows build |
| DFD (L0 + L1) | `savegame.json`, `questions.csv`, `lessons/*.json` |
| ER / data model | The save file and content resources |

Rendered as PNG from text sources (PlantUML/Graphviz) so they are editable and
regenerable, committed to `docs/diagrams/`.

### C. Screenshots (section 14)

Needs an **exported build** — which is also the mandatory test-suite exit
criterion (`TEST_STRATEGY.md` §6.6, M25–M28, marked not waivable). One
playthrough serves both purposes. Shot list: title, Space Map (locked and
unlocked), Sifu lesson beats (×3), Bugfall Archive, General fight, question
panel + explanation plate, Bug Lord HP bar + timer, Ultimate cinematic,
victory screen, pause menu, settings.

---

## 3. One problem to fix before the SRS is written

`REQUIREMENTS_TRACE.md` was last modified **before** the audio, VFX, Ultimate,
pause, transition and music work. It currently states *"No audio at all — the
only requirement in §17 with nothing behind it whatsoever"* and lists six
visual-polish items as open. All of that is now built (ADR-028 to ADR-044).

Consequence if not fixed: sections 8 and 16 would understate the project by
seventeen ADRs, and the Future Work section would list things that are done.

Fix: re-walk NFR-1 and NFR-2 against ADR-028–044 and re-count the summary
table before writing the SRS section. One pass, ~20 requirement rows.

---

## 4. Order of work

1. **Refresh `REQUIREMENTS_TRACE.md`** against ADR-028–044. Blocks sections 8, 16.
2. **Literature survey research.** Independent of everything else; longest lead time.
3. **Draw the nine diagrams.** Blocks sections 9, 12. Also closes the biggest
   remaining requirements gap.
4. **Export the build and play it through.** Yields screenshots (14) *and*
   satisfies M25–M28. If this uncovers defects, better now than after the report
   describes behaviour that does not work.
5. **Write the document** in this order: 7, 9, 10, 11, 12, 13 (the re-packaging
   sections, fastest) → 4, 5, 6, 16, 18 → 3, 15 (abstract and conclusion last,
   once the content is fixed) → 17 → 1 → 2 (ToC last, after pagination).
6. **Plagiarism pass.** Every section written from the sources rather than
   assembled from them; the existing docs are our own text, so the risk is
   concentrated in sections 5 and 6.

---

## 5. What I need from you

1. **Team member names and register numbers** (the title page template has two slots).
2. **Page target / limit**, if the course specifies one.
3. **Submission date.**
4. Whether diagrams should be **PlantUML/Graphviz-rendered** (clean, regenerable,
   my recommendation) or hand-drawn in draw.io to look student-made.
