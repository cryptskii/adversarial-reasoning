# Example 1: Surprise Examination Paradox

## Payload

```
QUESTION:
The Surprise Examination Paradox: A teacher announces a surprise exam next week
(Mon-Fri), saying students cannot deduce the day the evening before. Students use
backward induction to eliminate all five days, concluding no surprise exam is possible.
The teacher gives the exam Wednesday and students are surprised. What went wrong?

POSITIVE CANDIDATE:
The backward induction is self-defeating. Each elimination step is locally valid but
the final conclusion (no exam) destroys the epistemic state that made the eliminations
valid. Once students conclude no exam, any day would surprise them, making the
announcement satisfiable again. The conclusion feeds back into and contradicts the
premises.

ASSUMPTIONS:
1. Student knowledge state is dynamic
2. Backward induction requires stable premises across steps
3. The conclusion changes beliefs which changes deducibility which invalidates premises
4. The announcement is not self-contradictory (Wednesday exam proves satisfiability)
5. Surprise means logical non-deducibility the evening before

REJECTED ALTERNATIVES:
A: Announcement is self-contradictory - rejected because Wednesday exam satisfies it
B: Self-reference like the Liar - rejected as underspecified, no mechanism shown

INFERENCE CHAIN:
1. Base case: eliminate Friday requires announcement true AND no exam by Thursday - valid alone
2. Each step adds previous conclusions as premises
3. After all 5 eliminations: no exam will occur
4. No exam belief means no expectation of any day
5. No expectation means any day WOULD be surprising
6. Conclusion restores conditions making announcement true
7. Self-undermining: conclusion contradicts its own premises
8. Backward induction locally valid, globally invalid due to feedback
```

## Gemini Flash Verdict: `damaged`

```json
{
  "survival": "damaged",
  "issues": [
    {
      "label": "internal_inconsistency",
      "target": "The backward induction is self-defeating... the conclusion feeds back",
      "critique": "The argument describes the paradox's circular structure rather than resolving it. If students validly conclude 'no exam', the premise 'an exam WILL occur' is false. The proposed resolution creates a loop without escaping it.",
      "severity": "serious",
      "counterexample": null
    },
    {
      "label": "category_error",
      "target": "Wednesday exam proves announcement satisfiable",
      "critique": "Using empirical possibility to refute a logical argument conflates two categories of analysis. An empirical outcome does not logically negate an a priori deductive argument.",
      "severity": "serious",
      "counterexample": null
    }
  ],
  "hidden_assumptions_found": [
    "The argument implicitly assumes that the students' logical conclusion instantaneously alters the truth-value of the exam's occurrence, blurring belief and objective fact."
  ],
  "edge_cases_tested": [],
  "overall_note": "The argument correctly identifies the self-defeating nature but contains an internal inconsistency and a category error that damage its coherence."
}
```

## Revised Answer

The backward induction fails because it is an epistemic fixed-point problem
masquerading as a simple finite induction. The precise error: the teacher's
announcement is a conjunction of (1) an exam will occur, and (2) you won't
deduce the day beforehand. The induction assumes both conjuncts, derives that
no day satisfies conjunct (2), concluding no exam — contradicting conjunct (1).
But this only shows the announcement is unsatisfiable for a student who completes
the full chain while maintaining belief in both conjuncts. The induction
*consumes its own premises*: each step erodes confidence in the announcement,
but each step also requires continued confidence to proceed.

Key improvement from critique: the revised answer specifies the *mechanism*
(premise consumption) rather than just naming the circular structure.
