---
name: handoff
description: >-
  Use when a feature or code change made by Claude is complete and the developer
  wants to confirm they actually understood it before shipping. Triggers on
  "handoff", "quiz me", "comprehension check", "did I understand this", "verify I
  read the code", "test my understanding", or after finishing a feature when the
  developer wants to take ownership of AI-written code. Quizzes the developer on
  WHERE the logic lives (file/function) and WHY decisions were made (trade-offs,
  behavior, debugging), with the number of questions scaled to the size of the
  change. Points to file:line on wrong answers, allows one retry, then reveals
  the answer, and ends with a score plus the weak areas to re-read. Conducts the
  quiz in the developer's language.
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

## Step 4 — Ask one question at a time

Present a single question, wait for the answer, then evaluate it before moving
on. Never dump the whole quiz at once.

## Step 5 — Evaluate each answer

- **Correct** → confirm briefly and move to the next question.
- **Wrong or incomplete** → point to the relevant `file:line` as a hint
  **without revealing the answer**, and invite a **second attempt**.
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
