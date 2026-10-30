# CodeQuest — Literature Survey source material

Researched 14 October 2026. Every entry below was retrieved and read, except
those marked **UNVERIFIED**, which must be checked before submission.

---

## A. Game-based learning and gamification — effectiveness

**A1. Sailer, M. & Homner, L. (2020).** "The Gamification of Learning: a
Meta-analysis." *Educational Psychology Review* 32(1), 77–112.
doi:10.1007/s10648-019-09498-w

Random-effects meta-analysis. Cognitive g = .49 (k = 19), motivational g = .36
(k = 16), behavioural g = .25 (k = 9). **The caveat matters more than the
headline:** restricted to higher-rigour designs, the cognitive effect held
(g = .42) but motivational (g = .22) and behavioural (g = .27) effects became
non-significant. Heterogeneity I² 64–75%; possible publication bias; few delayed
post-tests. Competitive-and-collaborative designs beat purely competitive ones.

**A2. Gui, Y., Cai, Z., Yang, Y., Kong, L., Fan, X., Tai, R. H. et al. (2023).**
"Effectiveness of digital educational game and game design in STEM learning: a
meta-analytic review." *International Journal of STEM Education* 10, art. 36.
doi:10.1186/s40594-023-00424-9

Digital game-based STEM learning vs conventional instruction: g = 0.624
[0.457, 0.790], 136 effect sizes from 86 studies. Adding game-design elements to
a base game: g = 0.301, 81 effect sizes from 44 studies. Elements added to
support *content learning* outperformed elements added for gaming experience —
directly relevant to CodeQuest making the question the attack rather than
bolting points onto a quiz.

**A3. Almeida, C., Kalinowski, M., Uchôa, A. & Feijó, B. (2023).** "Negative
Effects of Gamification in Education Software: Systematic Mapping and
Practitioner Perceptions." *Information and Software Technology*.
doi:10.1016/j.infsof.2022.107142 · preprint arXiv:2305.08346

Systematic mapping of 87 papers on *undesired* effects. Badges, leaderboards,
competition and points are most often implicated. Most-cited harms: no effect,
worsened performance, motivational damage, lack of understanding, perceived
irrelevance; gaming-the-system and cheating recur. Developers in a focus group
were largely unaware of these risks. **Use this as the limitations citation.**

**A4. Ishaq, K., Mat Zin, N. A., Rosdi, F., Jehanghir, M., Ishaq, S. & Abid, A.
(2021).** "Mobile-assisted and gamification-based language learning: a systematic
literature review." *PeerJ Computer Science* 7, e496. doi:10.7717/peerj-cs.496

67 studies, simple vs gamified mobile learning apps. Note the authors' own
quality caveats: title-only Web of Science search, 2010–2020, English only.
**Does not discuss Duolingo by name — do not cite it as a Duolingo source.**

---

## B. Software engineering education

**B1. Souza, M. R. de A., Veado, L., Moreira, R. T., Figueiredo, E. & Costa, H.
(2018).** "A systematic mapping study on game-related methods for software
engineering education." *Information and Software Technology*. PII
S0950584917303518 — *volume, pages and DOI still to be filled in from the
publisher page.*

156 primary studies, 1974–2016. Game-based learning ≈88, game-development-based
≈60, gamification ≈11. By area: Software **Process** 92 studies (59%), Software
Design 60 (38.5%), Professional Practice 48 (30.8%); Software Quality and
Modelling only 10 each (6.4%). **The single most important source for the
novelty discussion** — software process is the *most*-studied area, not an
untouched one.

**B2. Kosa, M., Yilmaz, M., O'Connor, R. V. & Clarke, P. M. (2016).** "Software
Engineering Education and Games: A Systematic Literature Review." *Journal of
Universal Computer Science* 22(12), 1558–1574. doi:10.3217/jucs-022-12-1558

350 papers screened, 53 retained, five categories: games students play, games
students build, curriculum proposals, new approaches/tools, other. CodeQuest is
a "game students play." Use as the taxonomy citation.

**B3. de França Tonhão, S., Herculani, J., Shigenaga, M. Y., Medeiros, A. S. S.,
Amaral, A. M. M. M., Silva, W., Colanzi, T. E. & Steinmacher, I. F. (2023).**
"Gamification in Software Engineering Education: a Tertiary Study." *SBES 2023*,
358–367. English version arXiv:2405.05209

Tertiary study over 10 secondary studies. Nearly all work uses *structural*
gamification; **no included study used content gamification alone.** Testing and
Quality are the most gamified areas; Maintenance and Configuration Management
barely appear. Narrative, storytelling and time pressure are rarely explored.
**This is the paper that makes CodeQuest's actual contribution defensible.**

**B4. Wang, T., Trimble, M. & Brown, C. (2025).** "DevCoach: Supporting Students
Learning the Software Development Life Cycle with a Generative AI Powered
Multi-Agent System." *FSE Companion '25*, ACM.

Five SDLC phases with six LLM role-playing agents. n = 20 between-subjects:
pre-to-post gain 2.2 vs 0.2 for the baseline, Mann-Whitney U = 22.0, p = 0.034.
Limitations: n = 20, one institution, one project, single session. The closest
contemporary work on phase-structured SDLC learning, though a tutor rather than
a game.

**B5. Kharbouch, M., Vizcaíno, A., García-Berná, J. A., García, F., Toval, A.,
Pedreira, O., Idri, A. & Fernández-Alemán, J. L. (2025).** "Uncharted dimensions,
gaps, and future trends of serious games in software engineering." *Computer
Standards & Interfaces* 92. doi:10.1016/j.csi.2024.103915

**UNVERIFIED findings.** Metadata confirmed from the university repository;
full text could not be retrieved. Do not attribute specific findings until the
abstract is read.

---

## C. Existing systems

### C1. SimSE — the one that matters

Navarro, E. O. & van der Hoek, A., "SimSE: An Interactive Simulation Game for
Software Engineering Education," *CATE 2004*; and "Comprehensive Evaluation of
an Educational Software Engineering Simulation Environment," *CSEET 2007*.

**SimSE teaches SE process, not coding, and has since 2004.** Single-player;
the player is a *project manager* hiring, firing, assigning tasks, buying tools
and monitoring progress in a graphical virtual office. Explicitly targets
Brooks' Law, configuration management, life-cycle model choice and trade-offs.
Ships a model builder for instructors.

**Its own evaluation is mixed-to-negative, and that is the opening for
CodeQuest.** CSEET 2007, 19 students randomised to SimSE / reading / lecture:
time played correlated strongly with process-knowledge gain (r = 0.81,
p < 0.001), **but no SimSE subject completed the assigned play, and the SimSE
group improved least.** 11 of 30 initial subjects dropped out; instructions
caused frustration; extended play felt repetitive; students with no prior SE
background learned least. The authors conclude SimSE complements instruction
rather than replacing it.

### C2–C6. The coding games and the motivation model

| System | Teaches | Mechanism | Covers SE process? |
|---|---|---|---|
| **CodeCombat** | Python, JavaScript, HTML | Typed code drives a character through puzzle levels | No |
| **CodinGame** | 25+ languages, algorithms | Puzzles, bot programming, competitive events | No |
| **Lightbot** | Computational thinking — procedures, loops, conditionals | Sequencing instructions to light tiles | No |
| **Human Resource Machine** | Assembly-language concepts | Office metaphor: inbox/outbox, registers, jumps | No |
| **Duolingo** | Languages — cited for its *motivational model only* | Streaks, XP, leagues, hearts, gems | N/A |

**CodeCombat evaluation:** Kroustalli, C. & Xinogalos, S. (2021), "Studying the
effects of teaching programming to lower secondary school students with a
serious game: a case study with Python and CodeCombat," *Education and
Information Technologies* 26(5), 6069–6095. doi:10.1007/s10639-021-10596-y —
59 students; the game group scored higher but **the difference was not
statistically significant**; behavioural intention to keep using it was neutral.

**Duolingo mechanics** are from the official documentation: streaks and Streak
Freeze, XP with time-of-day and milestone bonuses, weekly Leagues, hearts lost
on wrong answers, gems, Friends Quests.

---

## Synthesis — what CodeQuest can honestly claim

The evidence splits cleanly. Gamified instruction produces real but **modest**
gains, and the motivational benefit — the one a game like CodeQuest most wants
to claim — does not survive rigorous designs (A1). Game elements tied to
*content* outperform elements added for feel (A2), and badge-and-leaderboard
gamification carries documented harms (A3).

The commercial field is uniformly about writing code or low-level computation.
None of CodeCombat, CodinGame, Lightbot or Human Resource Machine models
requirements, architecture, version control, deployment or maintenance as
process activities. Duolingo supplies only the retention loop.

**The counter-argument, which the report should state rather than hide.** The
claim "educational games teach coding, not software engineering" is **false as
stated.** SimSE has taught SE process in a game since 2004, and Souza et al.
(B1) find software process is the *most* represented area in game-related SE
education — 59% of 156 studies. Writing the survey as though the field were
empty would be the easiest thing for a marker to disprove.

**The defensible claim is narrower.** SimSE is a manager-role *simulation*
whose own evaluation found its group improved least, with heavy drop-off and
play described as repetitive. CodeQuest differs in genre — a narrative RPG with
an explicitly taught lesson before each encounter, assessment as the combat
mechanic itself, and progression gating. Tonhão et al. (B3) report that content
gamification alone appears in **no** reviewed study, that narrative and time
pressure are rarely explored, and that Maintenance and Configuration Management
are nearly absent — which is precisely where CodeQuest's Legacyon and Gitforge
worlds sit. That is a real gap, and a smaller, truer claim than the one we
started with.

---

## Before submission — four checks, about 15 minutes

1. **Souza et al. (B1)** — get volume, pages and DOI from the publisher page.
2. **Kharbouch et al. (B5)** — read the abstract or drop the citation.
3. **Lightbot's academic evaluation** — author list and venue unconfirmed. Cite
   the game itself, not the paper, until verified.
4. **Shortt et al., Duolingo systematic review** (*CALL*,
   doi:10.1080/09588221.2021.1933540) — unverified; publisher blocked the fetch.

A dead citation is spotted faster than a thin one.
