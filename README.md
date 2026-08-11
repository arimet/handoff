

<div align="center">

# 🤝 handoff

**Verify you actually understood the code Claude wrote — before you ship it.**

[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skill-D97757)](https://docs.claude.com/en/docs/claude-code/skills)
[![Hook](https://img.shields.io/badge/hook-bash-4EAA25?logo=gnubash&logoColor=white)](skills/handoff/scripts/suggest-quiz.sh)
[![Zero install](https://img.shields.io/badge/dependencies-none-brightgreen)](#requirements)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

</div>

---

`handoff` is a [Claude Code skill](https://docs.claude.com/en/docs/claude-code/skills)
that turns passive review of AI-written code into an active comprehension check.
When a feature is complete, it interviews you with a short quiz — **where** the
logic lives and **why** the decisions were made — then reports a score and the
exact spots to re-read.

The name captures the idea: the *handoff* of the code from Claude to you. You
shouldn't merge what you can't explain.

## Table of Contents

- [Why](#why)
- [Features](#features)
- [Demo](#demo)
- [Installation](#installation)
- [Usage](#usage)
- [Auto-suggestion hook](#auto-suggestion-hook)
- [Configuration](#configuration)
- [Requirements](#requirements)
- [Project layout](#project-layout)
- [Packaging](#packaging)
- [Contributing](#contributing)
- [License](#license)

## Why

AI writes code fast. The risk is shipping it without reading it. Tests catch
*broken* code; nothing catches code you don't *understand*. `handoff` closes
that gap by checking that the human who clicks "merge" can actually explain the
change — its location, its rationale, and its behavior.

## Features

- 🧬 **Hybrid question source** — combines conversation context (the *why*:
  decisions, trade-offs, what could break) with `git diff` (the *where*: real
  `file:line` locations), and degrades gracefully when there's no git.
- 📏 **Scaled to the change** — ~3 questions for a small diff, 5 for medium,
  8–10 for a large feature.
- 🔀 **Mixed question types** — multiple-choice for "where / what behavior",
  open-ended for "why".
- 1️⃣ **One question at a time** — you answer, it evaluates, then continues.
- 🎯 **Wrong-answer flow** — points you to the `file:line` *without* revealing
  the answer, lets you retry once, then reveals it with a short explanation.
- 🏁 **Score + weak areas** — `Score: N/total` plus the topics to revisit, each
  with a file pointer. Encouraging, not punitive.
- 🌍 **Your language** — the quiz runs in whatever language you're writing in.

## Demo

![handoff comprehension check demo](assets/demo.gif)

## Installation

### Via the Vercel `skills` CLI (recommended)

```bash
npx skills add arimet/handoff
```

This scans the repo's `SKILL.md`, detects your installed agent, and installs
`handoff` into the right path (`~/.claude/skills/` for Claude Code).

### Manually

```bash
# Symlink (handy while developing — edits stay live)
ln -s "$(pwd)/skills/handoff" ~/.claude/skills/handoff

# …or copy
cp -r skills/handoff ~/.claude/skills/handoff
```

Full instructions — including enabling and tuning the optional hook — are in
[skills/handoff/references/install.md](skills/handoff/references/install.md).

## Usage

After Claude finishes a feature, trigger it manually:

```text
/handoff
```

…or just ask in natural language: *"quiz me on what you built"*,
*"vérifie que j'ai compris"*, *"test my understanding"*, *"comprehension check"*.

## Auto-suggestion hook

An optional, **non-blocking** `Stop` hook nudges you to run `/handoff` when a
session produced a large diff. It only prints a suggestion — it never forces the
quiz and never blocks Claude. First, ensure the script is executable:

```bash
chmod +x ~/.claude/skills/handoff/scripts/suggest-quiz.sh
```

Then register it in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/skills/handoff/scripts/suggest-quiz.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

## Configuration

The hook suggests `/handoff` when **either** threshold is reached. Override the
defaults with environment variables:

| Variable           | Default | Meaning                                          |
| ------------------ | ------- | ------------------------------------------------ |
| `CC_HANDOFF_LINES` | `80`    | Min changed lines (added + removed) to suggest   |
| `CC_HANDOFF_FILES` | `4`     | Min changed files to suggest                     |

Counts include tracked changes (staged + unstaged) **and** new untracked files,
so files Claude just created are counted.

## Requirements

- **Claude Code** with skills support.
- **git** *(optional)* — anchors questions on real `file:line` locations and
  drives the hook. Without git, the skill still works from conversation context.
- **No extra tools to install.** The hook parses its event with `node` (always
  present — Claude Code runs on Node) and falls back to `jq` if available. You
  do **not** need to install `jq`.

## Project layout

```text
.
├── README.md
├── LICENSE
└── skills/
    └── handoff/
        ├── SKILL.md             # the skill: triggering + quiz procedure
        ├── scripts/
        │   └── suggest-quiz.sh  # optional, non-blocking Stop hook
        ├── references/
        │   └── install.md       # install + hook setup and thresholds
        └── evals/
            └── evals.json       # test cases (excluded from the packaged .skill)
```

## Packaging

Produce a distributable `.skill` archive (a zip with `handoff/` at its root,
excluding `evals/`):

```bash
# Using Anthropic's skill-creator
python -m scripts.package_skill skills/handoff
```

Install the result by unzipping `handoff.skill` into `~/.claude/skills/`.

## Contributing

Issues and pull requests are welcome. When changing the skill:

1. Keep `SKILL.md` lean — push detail into `references/`.
2. Update `evals/evals.json` with a test case for new behavior.
3. Run `bash -n skills/handoff/scripts/suggest-quiz.sh` and smoke-test the hook.

## License

Released under the [MIT License](LICENSE).
