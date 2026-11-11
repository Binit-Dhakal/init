#!/usr/bin/env bash
# ============================================================================
# kiro-session-picker.sh
# ----------------------------------------------------------------------------
# A cross-workspace picker for kiro-cli sessions. Lists every saved session
# across every project (kiro's own --sessions dashboard is current-workspace
# only), lets you fuzzy-pick one with fzf, and resumes it in a NEW tmux window
# in that project's folder.
#
# Bound to <prefix> k in tmux (runs inside a tmux popup).
# ============================================================================
set -euo pipefail

command -v kiro-cli >/dev/null || { echo "kiro-cli not found"; read -r; exit 1; }
command -v jq       >/dev/null || { echo "jq not found";       read -r; exit 1; }
command -v fzf      >/dev/null || { echo "fzf not found";       read -r; exit 1; }

# Pull every session across every workspace as JSON. Each object has:
#   sessionId, title, updatedAt, messageCount, status  (grouped under a cwd)
# The --all-cwds JSON emits one envelope per cwd; flatten to rows of:
#   cwd \t sessionId \t status \t age \t title
json="$(kiro-cli chat --list-sessions --all-cwds -f json 2>/dev/null || true)"

if [ -z "$json" ]; then
  echo "No kiro sessions found."; read -r -p "Press enter to close…"; exit 0
fi

# Build the selectable list, NEWEST FIRST. The cwd is on each envelope;
# sessions are nested. We keep the real sessionId + cwd in hidden trailing
# fields (tab-separated) and show a friendly, recency-sorted line.
#
# jq emits: updatedAt \t status \t folder \t title \t cwd \t sessionId
# We sort by updatedAt descending, then format for display.
rows="$(printf '%s' "$json" | jq -r '
  (if type == "array" then .[] else . end)
  | .cwd as $cwd
  | (.sessions // .conversations // [])[]
  | [ (.updatedAt // "1970-01-01T00:00:00Z"),
      (.status // "idle"),
      ($cwd | split("/") | last),
      ((.title // "(no title)") | gsub("[\n\t]"; " ") | .[0:80]),
      $cwd,
      .sessionId
    ] | @tsv
' | sort -r -t$'\t' -k1,1)"

[ -z "$rows" ] && { echo "No sessions."; read -r -p "Press enter to close…"; exit 0; }

# Display column (what fzf shows): "<when> │ <folder> │ <title>".
# Hidden trailing columns carry cwd + sessionId for the resume action.
# 'when' is a compact date+time from the ISO updatedAt.
pick="$(printf '%s\n' "$rows" | awk -F'\t' '
  {
    iso = $1
    gsub(/T/, " ", iso); sub(/\..*$/, "", iso); sub(/Z$/, "", iso)
    when = substr(iso, 6, 11)            # MM-DD HH:MM
    printf "%-12s │ %-22s │ %s\t%s\t%s\n", when, $3, $4, $5, $6
  }' | \
  fzf --ansi --with-nth=1 --delimiter='\t' \
      --prompt="kiro sessions (newest first) ❯ " \
      --header="Enter = resume in a new tmux window │ Esc = cancel" \
      --preview-window=hidden)"

[ -z "$pick" ] && exit 0

cwd="$(printf '%s' "$pick" | cut -f2)"
sid="$(printf '%s' "$pick" | cut -f3)"

[ -z "$sid" ] && exit 0
[ -d "$cwd" ] || cwd="$HOME"

# Open a new tmux window in that folder and resume the session there.
tmux new-window -c "$cwd" "kiro-cli chat --resume-id $sid"
