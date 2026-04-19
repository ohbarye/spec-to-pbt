# Semantic Gap Landscape: From Formal Specs to Property-Based Tests

Date: 2026-04-11

## The Semantic Gap

Between formal specifications and property-based tests lies a semantic gap.
Formal specs describe **what should hold** (declarative constraints, invariants, state transitions).
PBT frameworks require **how to explore** (executable generators, commands, preconditions, postconditions, shrinking).

| Formal Spec Side | PBT Side |
|---|---|
| Declarative constraints (∀x, P(x) → Q(x)) | Executable generator + assertion |
| Abstract state (mathematical sets, relations) | Concrete state (runtime objects) |
| Logical quantifiers | Approximation via random sampling |
| Invariants, temporal properties | Precondition / postcondition / shrinking |

The transformation is not trivial. Every tool in this space must decide **who bridges the gap, and how**.

---

## Landscape: Four Groups

### Grouping Axis

A single axis: **"How much of the spec-to-test transformation does the machine take on?"**

This is not a trade-off between fidelity and practicality. It is a spectrum of **where you draw the line** between machine responsibility and human responsibility.

### The Four Groups

- **Solver-driven** — The solver directly solves constraints in the spec to derive test cases. Humans only write the spec. Limited by bounded scope.
- **Checker-driven** — A model checker or dedicated engine explores the state space to generate traces and test sequences. Requires tight coupling between the spec language and the tool.
- **Scaffold-driven** — The machine generates a structurally safe skeleton and explicitly marks the boundary of semantic decisions, leaving them to humans. Accepts the existence of the gap as a design choice.
- **Human-driven** — Humans hand-write all models and properties. The tool only handles exploration, shrinking, and execution. Most flexible, but least scalable.

### Full Comparison Table

| Automation | Group | Tool | Spec Language | Target | Who Bridges the Gap | Key Reference |
|---|---|---|---|---|---|---|
| **Machine** | **Solver-driven** | TestEra | Alloy | Java | Solver derives test cases + oracles directly from spec constraints | Khurshid & Marinov, ASE 2004 |
| | | AUnit | Alloy | Alloy models | Eliminates the gap by testing the spec itself | Sullivan et al., ICST 2018 |
| | **Checker-driven** | TLA+ / Apalache | TLA+ | Language-agnostic | Model checker generates traces; adapter is human-written | Konnov et al., OOPSLA 2019 |
| | | QuickStrom | QuickLTL / Specstrom | Web UI | Spec language designed to be PBT-aware, minimizing the gap | Wickström et al., PLDI 2022 |
| | | Spec Explorer | Spec# / AsmL | C# / .NET | Explores model state space to generate test sequences | Veanes et al., LNCS 4949, 2008 |
| | **Scaffold-driven** | **spec-to-pbt** | **Alloy** | **Ruby / pbt** | **Machine generates structure; semantic decisions explicitly delegated to config** | **This talk** |
| | | GraphWalker | FSM / EFSM | Java | Human draws the model; tool generates traversal paths | Agrawal et al., ISEC 2021 |
| | **Human-driven** | Echidna | Solidity assertions | Solidity / EVM | Human writes properties; fuzzer explores state space | Grieco et al., ISSTA 2020 |
| | | Foundry | Solidity invariants | Solidity / EVM | Same as above | Paradigm, 2025 |
| | | Quviq QuickCheck | Erlang state machine | Erlang | Human hand-writes entire model as statem callbacks | Hughes, LNCS 9600, 2016 |
| **Human** | | Hypothesis RBSM | Python rule / invariant | Python | Human hand-writes all rules and invariants | MacIver et al., JOSS 2019 |

---

## Academic Taxonomies

### Utting, Pretschner & Legeard (2012)

**"A Taxonomy of Model-Based Testing Approaches"** — STVR, Vol.22, pp.297-312

The most widely cited MBT taxonomy. Defines 7 dimensions:

| Dimension | Classification Axis |
|---|---|
| 1. Scope | What the model describes about the SUT |
| 2. Redundancy | Whether test model = development model |
| 3. Characteristics | Timing, determinism, dynamism |
| 4. Model paradigm | state-based / transition-based / history-based / functional / operational |
| 5. Test selection | Coverage criteria (structural, data, fault-based, etc.) |
| 6. **Test generation technology** | random / graph-based / **model checking** / **symbolic execution** / **SAT/constraint solving** / theorem proving |
| 7. **Test execution** | online / offline executable / offline manual |

### Mapping Our Groups to Utting

| Our Group | Utting Dimension 6 | Utting Dimension 7 |
|---|---|---|
| Solver-driven | SAT/Constraint solving | Offline executable |
| Checker-driven | Model checking | Online / Offline |
| Scaffold-driven | **No matching category** | Offline executable |
| Human-driven | Random/Search-based | Online |

### Key Finding: Scaffold-driven Is Unnamed in Academic Taxonomies

Scaffold/template generation does not exist as a first-class category in the Utting taxonomy. However, the gap is recognized in adjacent literature:

| Paper | Authors | Year | Relevant Concept |
|---|---|---|---|
| *"A Systematic Review of State-Based Test Tools"* | Shafique & Labiche | 2015, STTT | Explicitly uses **"test scaffolding support"** as a classification axis |
| *"On Transforming Model-Based Tests into Code"* | Ferrari et al. | 2023, STVR | Formulates the **concretization problem**: abstract tests → executable tests |
| *"One Evaluation of MBT and Its Automation"* | Pretschner et al. | 2005, ICSE | Three automation levels: manual with model / automated with specs / automated without specs — scaffold sits in the unnamed gap between "automated" and "manual" |

**Talk positioning:** "The standard MBT taxonomy has no name for what we do. We stand in a principled middle ground that the field acknowledges as important but has not yet categorized."

---

## How Each Approach Ensures Test Safety

### Two Types of Unsafe Tests

| Type | Meaning | Risk |
|---|---|---|
| **False positive** | Test fails on correct implementation | Erodes developer trust |
| **False negative** | Test passes on buggy implementation | Misses bugs — more dangerous |

### Different Strategies for Test Generation Safety

- **Solver-driven:** "What we derive from the spec is correct — within bounded scope."
- **Checker-driven:** "The trace is correct — if the adapter is correct."
- **Scaffold-driven:** "What we cannot verify, we do not generate."
- **Human-driven:** "We trust the human."

### Safety Comparison

| Group | False Positive Risk | False Negative Risk | Reason |
|---|---|---|---|
| **Solver-driven** | Low | Low (within bound) | Oracle derived from spec postconditions. If spec is correct, tests are correct by construction. Beyond the bound, nothing is checked (may miss, but never lies) |
| **Checker-driven** | Low–Medium | Low (within trace) | Traces themselves are valid w.r.t. the spec. But the adapter layer (abstract trace → concrete API call) is human-written and can introduce errors |
| **Scaffold-driven** | **Low** | **Medium (intentional)** | Generates only structurally safe parts. Avoids "generating wrong tests" by "generating incomplete tests." False positives are unlikely; false negatives remain until humans fill in config |
| **Human-driven** | High | High | Everything depends on human understanding. Misreading the spec, writing wrong models, missing postconditions — all become test errors directly. No formal guarantee |

**Scaffold-driven's unique strategy:** Other groups claim correctness of what they generate. Scaffold-driven guarantees safety by **not generating what it cannot verify**. The gap is explicit, not hidden.

---

## Coverage Characteristics

### Three Layers of Coverage

| Layer | Meaning | Example |
|---|---|---|
| **Structural** | How many structural elements of the spec are covered | All commands, all transitions, all signatures |
| **Semantic** | How many semantically correct assertions / oracles are present | Postconditions, invariants, guard checks |
| **Exploratory** | How broadly the state space is explored at runtime | Input diversity, sequence length, combinations |

### Coverage by Group

| Group | Structural | Semantic | Exploratory | Constraint |
|---|---|---|---|---|
| **Solver-driven** | ★★★★★ | ★★★★★ | ★★ | Exhaustive within bounded scope. Both structural and semantic are complete within the bound. Exploration beyond the bound is impossible |
| **Checker-driven** | ★★★★ | ★★★★ | ★★★★ | Systematic state space exploration. Can guarantee transition/path coverage. Adapter layer coverage is not guaranteed |
| **Scaffold-driven** | ★★★★ | ★★ | ★★★★ | All commands and transitions from the spec are scaffolded (structural is high). Semantic depends on config. Exploratory is high because the PBT runtime handles it |
| **Human-driven** | ★★ | ★★★ | ★★★★★ | Semantic coverage can be precise for what humans write. Exploratory is the most free (PBT engine shrinking + random generation). But structural coverage depends on human thoroughness — easy to miss commands |

### Scaffold-driven Coverage Strategy

Scaffold-driven approaches **guarantee a coverage floor**: every command in the spec gets a test, every transition gets explored by the PBT runtime. What remains for the human is not *which tests to write*, but *what each test should assert*.

| Question | Scaffold's Answer |
|---|---|
| Does every command have a test? | **Yes** — auto-generated from spec |
| Is each command's assertion correct? | **Human decides** — written in config |
| Are enough input patterns explored? | **Yes** — PBT runtime handles this |

Comparison:
- Solver-driven automates all three layers but is closed within bounded scope
- Human-driven has the deepest exploration but structural gaps are invisible until a bug slips through
- Scaffold-driven plugs structural holes with the machine and hands semantic judgment to the human — **a design that guarantees a coverage floor**

---

## Key References

| Tool | Authors | Title | Venue | Year |
|---|---|---|---|---|
| TestEra | Khurshid & Marinov | Specification-Based Testing of Java Programs Using SAT | Automated Software Engineering | 2004 |
| AUnit | Sullivan, Wang, Khurshid | AUnit: A Test Automation Tool for Alloy | ICST | 2018 |
| TLA+ / Apalache | Konnov, Kukovec, Tran | TLA+ Model Checking Made Symbolic | OOPSLA | 2019 |
| TLA+ trace validation | Cirstea, Kuppe, Loillier, Merz | Validating Traces of Distributed Programs Against TLA+ Specifications | SEFM | 2024 |
| QuickStrom | Wickström, O'Connor, Arslanagic | Quickstrom: Property-Based Acceptance Testing with LTL Specifications | PLDI | 2022 |
| Spec Explorer | Veanes, Campbell, Grieskamp, Schulte, Tillmann, Nachmanson | Model-Based Testing of Object-Oriented Reactive Systems with Spec Explorer | LNCS 4949 | 2008 |
| GraphWalker | Agrawal & Chakrabarti | Model-Based Testing in Practice: An Industrial Case Study using GraphWalker | ISEC | 2021 |
| Echidna | Grieco, Song, Cygan, Feist, Groce | Echidna: Effective, Usable, and Fast Fuzzing for Smart Contracts | ISSTA | 2020 |
| Foundry | Paradigm (Konstantopoulos et al.) | Foundry documentation | — | 2025 |
| Quviq QuickCheck | Hughes | Experiences with QuickCheck: Testing the Hard Stuff and Staying Sane | LNCS 9600 | 2016 |
| Hypothesis | MacIver, Hatfield-Dodds et al. | Hypothesis: A New Approach to Property-Based Testing | JOSS | 2019 |

### Taxonomy References

| Authors | Title | Venue | Year |
|---|---|---|---|
| Utting, Pretschner, Legeard | A Taxonomy of Model-Based Testing Approaches | STVR, Vol.22 | 2012 |
| Hierons et al. | Using Formal Specifications to Support Testing | ACM Computing Surveys | 2009 |
| Pretschner et al. | One Evaluation of Model-Based Testing and Its Automation | ICSE | 2005 |
| Shafique & Labiche | A Systematic Review of State-Based Test Tools | STTT | 2015 |
| Ferrari et al. | On Transforming Model-Based Tests into Code | STVR | 2023 |

---

## Implications for the Talk

### Positioning Statement

spec-to-pbt occupies a principled middle ground in the landscape:

- Not a semantics-preserving compiler (Solver-driven)
- Not a manual translation aid (Human-driven)
- A scaffold generator that **makes the gap explicit as a design choice**

### Key Narratives Available

1. **"The standard MBT taxonomy has no name for scaffold generation"** — this is a positioning opportunity, not a weakness
2. **"What we cannot verify, we do not generate"** — the safety strategy differentiates from both ends of the spectrum
3. **"We guarantee a coverage floor"** — structural coverage from the machine, semantic coverage from the human, exploratory coverage from the PBT runtime
4. **"The gap is a feature, not a bug"** — accepting the semantic gap and designing around it is what makes the tool practically useful
