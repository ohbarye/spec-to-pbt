---
name: implementation-retrospective
description: Extract learnings, discoveries, design implications, and follow-up actions after implementation work, and save the result under docs/implementation-retrospectives/ by default. Use when the user asks what was learned from a change, asks for a reflection after coding, wants to capture insights or discoveries from implementation, wants to record engineering learnings, asks for a retrospective, asks for findings/insights/洞察/学び/発見 from completed work, or when implementation has just finished and it would help to turn the work into reusable engineering knowledge even if the user did not explicitly name the skill.
---

# Implementation Retrospective

Extract the durable learnings from implementation work. Focus on insight, not changelog.

## Workflow

1. Reconstruct the implementation surface.
   - Read the relevant diff, touched files, tests, and any failures or fixes encountered during the work.
   - If the work is too broad, focus on the files and tests most central to the user's goal.

2. Separate execution facts from insights.
   - Facts: what changed, what failed, what needed adjustment.
   - Insights: what those facts mean for the design, architecture, workflow, or future work.

3. Identify the strongest learnings.
   - Prefer learnings that change future decisions.
   - Prefer boundary discoveries over implementation trivia.
   - Prefer “this class of problem is really about X, not Y” over “I edited file Z”.

4. Distill the result into a small set of high-signal points.
   - Keep the number of main insights small unless the user explicitly wants a full write-up.
   - Merge overlapping observations.
   - Drop low-signal notes that do not affect future implementation choices.

5. End with implications.
   - State what should be generalized.
   - State what should remain local or config-owned.
   - State what to test, document, or evaluate next.

6. Save the retrospective by default.
   - Unless the user explicitly asks not to save, write the retrospective to `docs/implementation-retrospectives/`.
   - Create the directory if it does not exist.
   - Prefer a filename of the form `YYYY-MM-DD-short-topic.md`.
   - Derive `short-topic` from the implementation theme, not from a vague label like `retrospective`.
   - If the work already has a clear topic name, reuse it.

## Heuristics

- Treat “what was hard” as raw material, not the final answer.
- Look for mismatches between the original expectation and what implementation revealed.
- Highlight recurring patterns, hidden constraints, and misleading assumptions.
- Prefer causal explanations over surface descriptions.
- Avoid praising the work unless it clarifies why a pattern is worth reusing.
- Avoid turning the output into a file-by-file summary.

## Good Insight Shapes

- The real difficulty was semantic classification, not parsing.
- This feature needs better diagnostics, not broader inference.
- The frontend can stay thin if the semantic hints are rich enough.
- Explicit unchanged updates are syntax-level noise and should not drive model inference.
- The implementation exposed a recurring family worth promoting.
- The implementation looked general, but is still domain-specific and should stay config-owned.

## Output Shape

Use a concise structure that fits the request. Default to:

1. `What changed`
2. `What we learned`
3. `Design implications`
4. `Next follow-up`

For deeper write-ups, add:

- `What surprised us`
- `What not to generalize yet`
- `What to record in docs`

After writing the content:

- save it to `docs/implementation-retrospectives/` by default
- return a concise summary in the conversation
- include the saved path in the response

## Repo-Aware Guidance

When working in a generator-heavy repo like this one, explicitly test whether the insight belongs to one of these buckets:

- parser / frontend limitation
- semantic hint extraction limitation
- analyzer limitation
- generator UX / diagnostics limitation
- config boundary issue
- runtime / environment issue
- evidence / evaluation issue

This classification usually produces better follow-up decisions than a generic retrospective.

## Default Artifact

The default artifact is a short markdown note under `docs/implementation-retrospectives/`.

Use this default shape unless the user asked for something else:

- title
- date
- scope
- what changed
- what we learned
- design implications
- next follow-up

Keep the saved note tighter than the reasoning used to derive it. The note should be reusable by a future implementation pass, not a transcript of the whole session.
