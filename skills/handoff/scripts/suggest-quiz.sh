#!/usr/bin/env bash
#
# handoff — Stop hook: non-blocking suggestion to run /handoff after a large diff.
#
# Reads the Stop hook JSON event on stdin and, if the working-tree diff exceeds a
# threshold, prints a JSON object whose `systemMessage` nudges the developer to run
# /handoff. It NEVER blocks the stop and NEVER forces the quiz.
#
# Thresholds (override via env):
#   CC_HANDOFF_LINES  default 80   # min changed lines (added + removed) to suggest
#   CC_HANDOFF_FILES  default 4    # min changed files to suggest
#
# Dependencies: none to install. JSON is parsed with `node` (always present, since
# Claude Code runs on Node), falling back to `jq` if available. `git` is used to
# measure the diff. The hook exits silently if it cannot parse the event or is not
# in a git repo.

set -euo pipefail

INPUT="$(cat)"

# Extract the two fields we need (stop_hook_active, cwd) from the event JSON.
# Output: line 1 = "1" if stop_hook_active else "0"; line 2 = cwd.
parse_event() {
  if command -v node >/dev/null 2>&1; then
    printf '%s' "$INPUT" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const o=JSON.parse(s);process.stdout.write((o.stop_hook_active?"1":"0")+"\n"+(o.cwd||""));}catch(e){process.stdout.write("0\n");}});'
  elif command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '(if .stop_hook_active then "1" else "0" end), (.cwd // "")'
  fi
}

PARSED="$(parse_event)"
ACTIVE="$(printf '%s\n' "$PARSED" | sed -n '1p')"
CWD="$(printf '%s\n' "$PARSED" | sed -n '2p')"

# No parser available, or could not read the event → do nothing.
[ -n "$PARSED" ] || exit 0

# Avoid loops: if we are already continuing because of a stop hook, stay silent.
[ "$ACTIVE" = "1" ] && exit 0

[ -n "$CWD" ] && cd "$CWD" 2>/dev/null || exit 0

# Only act inside a git repo.
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

LINES_THRESHOLD="${CC_HANDOFF_LINES:-80}"
FILES_THRESHOLD="${CC_HANDOFF_FILES:-4}"

# Count changed lines and files across tracked (staged + unstaged) changes.
read -r TRACKED_LINES TRACKED_FILES <<EOF
$(git diff HEAD --numstat 2>/dev/null | awk '
  { added += ($1 == "-" ? 0 : $1); removed += ($2 == "-" ? 0 : $2); files += 1 }
  END { printf "%d %d", added + removed, files }
')
EOF
TRACKED_LINES="${TRACKED_LINES:-0}"; TRACKED_FILES="${TRACKED_FILES:-0}"

# Also count untracked files (new files Claude created but not yet `git add`ed),
# which git diff does not report. Count them as files and add their line counts.
UNTRACKED_FILES=0; UNTRACKED_LINES=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  UNTRACKED_FILES=$(( UNTRACKED_FILES + 1 ))
  if [ -f "$f" ]; then
    UNTRACKED_LINES=$(( UNTRACKED_LINES + $(wc -l < "$f" 2>/dev/null || echo 0) ))
  fi
done < <(git ls-files --others --exclude-standard 2>/dev/null)

FILES=$(( TRACKED_FILES + UNTRACKED_FILES ))
TOTAL_LINES=$(( TRACKED_LINES + UNTRACKED_LINES ))

if [ "$TOTAL_LINES" -ge "$LINES_THRESHOLD" ] || [ "$FILES" -ge "$FILES_THRESHOLD" ]; then
  # Message content is fully controlled (only numbers), so printf is safe JSON.
  printf '{"systemMessage":"This session changed %s file(s) / %s line(s). Run /handoff to verify you understood the code before shipping."}\n' \
    "$FILES" "$TOTAL_LINES"
fi

exit 0
