---
name: handoff
description: >-
  Use when a feature or code change made by Claude is complete and the developer
  wants to confirm they actually understood it before shipping. Triggers on
  "handoff", "quiz me", "comprehension check", "did I understand this", "verify I
  read the code", "test my understanding", or after finishing a feature when the
  developer wants to take ownership of AI-written code. Also triggers on requests
  for an interactive or clickable quiz ("interactive mode", "let me answer with
  the mouse", "mode interactif", "je réponds à la souris"). Quizzes the developer
  on WHERE the logic lives (file/function) and WHY decisions were made
  (trade-offs, behavior, debugging), with the number of questions scaled to the
  size of the change. Multiple-choice questions are clickable by default (asked
  through `AskUserQuestion`) and fall back to typed answers. Points to file:line
  on wrong answers, allows one retry, then reveals the answer, and ends with a
  score plus the weak areas to re-read. Conducts the quiz in the developer's
  language.
---

# Handoff — verify you understood Claude's code

When Claude builds a feature, it is easy to merge the result without truly
reading or understanding it. `handoff` turns passive review into an active
check: it interviews the developer to confirm they read the code (where the
logic lives) and understood it (why decisions were made, how it behaves),
then reports a score and the spots to revisit.

This skill conducts an interactive quiz. Ask questions **one at a time** and
wait for an answer before continuing. Conduct the entire quiz in the
developer's language (match the language they are writing in).

## Step 1 — Gather the material (hybrid source)

Build the quiz from two complementary sources:

1. **Conversation context** — what was built this session: the files touched,
   the key decisions and trade-offs, what was deliberately NOT done, and what
   could plausibly break. This is the source for the "why".
2. **Git diff (when available)** — to objectively anchor "where" and check that
   nothing important is missed. Run:
   - `git rev-parse --git-dir` to confirm a repo exists.
   - `git diff --stat` then `git diff` (covers unstaged + staged) to enumerate
     changed files and lines. Use real `file:line` locations from this diff.

   If there is no git repo, degrade gracefully and rely on conversation context
   alone — still produce a useful quiz.

## Step 2 — Calibrate the number of questions

Scale to the size of the change (use the diff stat, or your best estimate from
context if there is no git):

| Change size                              | Questions |
| ---------------------------------------- | --------- |
| Small (< ~50 lines, or 1–2 files)        | 3         |
| Medium                                   | 5         |
| Large (> ~300 lines, or ≥ 5 files)       | 8–10      |

## Step 3 — Generate a mixed question set

Cover both reading and understanding. Mix these types:

- **Where (multiple choice).** "Which file/function contains X?" Provide
  plausible distractors drawn from other real files in the change.
- **Why (open-ended).** "Why was approach X chosen over Y?", "What trade-off
  does this make?", "What would have broken if we hadn't done Z?"
- **Behavior (multiple choice or open).** "If input X arrives, what happens?",
  "How would you debug it if X fails?"

Favor the parts of the change that matter most (core logic, tricky edge cases,
non-obvious decisions) over trivial boilerplate.

Write every multiple-choice question with **2 to 4 options** so it can be
answered by clicking (see Step 4).

## Step 4 — Ask one question at a time (interactive by default)

Present a single question, wait for the answer, then evaluate it before moving
on. Never dump the whole quiz at once.

### Interactive mode — clickable answers

**Multiple-choice questions are asked through the `AskUserQuestion` tool** so
the developer answers with the mouse instead of typing. Use it by default
whenever the tool is available.

One tool call = one question (never batch several questions into a single
call — that would break the one-at-a-time rule):

- `question` — the full question text. Include the `file:line` hint here on a
  retry, never the answer.
- `header` — a short topic label, ≤ 12 characters (e.g. `Où ?`, `Hook`,
  `Retry flow`).
- `options` — 2 to 4 entries, each with a short `label` (1–5 words) and a
  `description` giving the concrete detail (a real path, a behavior).
- `multiSelect: true` — only for genuine "select all that apply" questions.

Quiz-specific rules for the options:

- **Exactly one option is correct** (unless `multiSelect`), and its position is
  varied from question to question — never always first or always last.
- **Never mark the correct answer.** No `(Recommended)` suffix, no hedging
  wording in the distractors. Keep all labels and descriptions the same shape
  and roughly the same length, so the answer cannot be spotted by formatting.
- **Distractors must be real** — other files, functions or behaviors that
  actually exist in the change. Invented paths make the question trivial.
- The tool always offers an **"Other"** escape where the developer can type a
  free-form answer; grade it on its content like any typed answer.

Open-ended **"why"** questions stay typed: explaining a trade-off in your own
words is the point, and picking a rationale from a list would turn recall into
recognition. Ask them as plain text and wait for the reply.

### Falling back to typed answers

Use plain text (numbered options the developer answers with `a`/`b`/`c`) when:

- the `AskUserQuestion` tool is not available in the current environment, or
- the developer asks for it — "no clicking", "text only", "pas de clic",
  `/handoff --text`.

`/handoff --interactive` (or "quiz me with clickable answers") forces the
clickable mode back on. The quiz content, scoring and retry flow are identical
in both modes — only the input method changes.

## Step 5 — Evaluate each answer

- **Correct** → confirm briefly and move to the next question.
- **Wrong or incomplete** → point to the relevant `file:line` as a hint
  **without revealing the answer**, and invite a **second attempt**.
  - In interactive mode, the retry is a **second `AskUserQuestion` call** for
    the same question: keep the same options in the same order, and put the
    `file:line` hint in the `question` text. Do not remove the option the
    developer just picked — eliminating it would give the answer away.
  - If the second attempt is still wrong → reveal the correct answer with a
    short explanation, then continue.

Track the result of each question (correct / correct-on-retry / missed) to
build the final score.

## Step 6 — Final score and weak areas

End with:

- A score, e.g. `Score: 4/6`.
- The **weak areas**: the topics missed, each with a `file:line` pointer to
  re-read. Keep the tone encouraging, not punitive — the goal is to know what
  to revisit, not to grade harshly.

## Optional: automatic suggestion (Stop hook)

This skill ships an optional, non-blocking Stop hook that suggests running
`/handoff` when a session produced a large diff. It never forces the quiz. See
[references/install.md](references/install.md) for setup and thresholds.
