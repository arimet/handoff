# Installing `handoff`

## 1. Install the skill

Copy or symlink the skill folder into your personal skills directory so Claude
Code discovers it:

```bash
# Symlink (recommended while developing — edits stay live)
ln -s "$(pwd)/skills/handoff" ~/.claude/skills/handoff

# …or copy
cp -r skills/handoff ~/.claude/skills/handoff
```

Once installed, invoke it manually any time with `/handoff`, or just ask Claude
to "quiz me on what you built" / "vérifie que j'ai compris".

## 2. (Optional) Enable the auto-suggestion Stop hook

The hook nudges you to run `/handoff` when a session produced a large diff. It
is **non-blocking** — it only prints a suggestion, never forces the quiz, and
never blocks Claude from stopping.

### Requirements

- `git` available on your `PATH`. The hook exits silently if you are not in a
  git repo.
- **No extra install needed for JSON parsing.** The hook parses the event with
  `node` (always present — Claude Code runs on Node), and falls back to `jq` if
  it happens to be installed.
- Make sure the script is executable: `chmod +x ~/.claude/skills/handoff/scripts/suggest-quiz.sh`

### Register the hook

Add this to `~/.claude/settings.json` (user-wide) or a project's
`.claude/settings.json`:

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

> If you copied (not symlinked) the skill elsewhere, point `command` at the real
> path of `scripts/suggest-quiz.sh`.

### Tune the thresholds

The hook suggests `/handoff` when the working-tree change reaches **either**
threshold. Override the defaults with environment variables:

| Variable           | Default | Meaning                                   |
| ------------------ | ------- | ----------------------------------------- |
| `CC_HANDOFF_LINES` | `80`    | Min changed lines (added + removed) to suggest |
| `CC_HANDOFF_FILES` | `4`     | Min changed files to suggest              |

The line/file counts include both tracked changes (staged + unstaged) and new
untracked files, so freshly created files are counted.

## 3. Verify it works

- **Below threshold:** make a tiny change, let Claude stop → no suggestion.
- **Above threshold:** make a large change (or set `CC_HANDOFF_LINES=1`) → you
  see "Run /handoff to verify you understood the code before shipping."
- **No git:** run in a non-git folder → the hook stays silent.
