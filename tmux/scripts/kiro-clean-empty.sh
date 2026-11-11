#!/usr/bin/env bash
# ============================================================================
# kiro-clean-empty.sh
# ----------------------------------------------------------------------------
# Delete every kiro-cli session that has no title / 0 messages across ALL
# workspaces. These are sessions you opened but never actually used.
#
# Bound to <prefix> K in tmux (runs inside a tmux popup).
#
# It deletes via `kiro-cli chat --delete-session`, then removes any orphaned
# session files left behind on disk (empty .jsonl with a stale .lock) — but
# ONLY when the .jsonl is 0 bytes and no process holds the files.
# ============================================================================
set -euo pipefail

command -v kiro-cli >/dev/null || { echo "kiro-cli not found"; read -r; exit 1; }
command -v jq       >/dev/null || { echo "jq not found";       read -r; exit 1; }

store="$HOME/.kiro/sessions/cli"

mapfile -t ids < <(
  kiro-cli chat --list-sessions --all-cwds -f json 2>/dev/null | jq -r '
    (if type=="array" then .[] else . end)
    | (.sessions // [])[]
    | select((.title // "")=="" or (.messageCount // 0)==0)
    | .sessionId
  '
)

if [ "${#ids[@]}" -eq 0 ]; then
  echo "No empty sessions to clean. 🎉"
  sleep 1.2
  exit 0
fi

echo "Found ${#ids[@]} empty session(s). Deleting…"
echo

deleted=0
for id in "${ids[@]}"; do
  [ -z "$id" ] && continue
  kiro-cli chat --delete-session "$id" >/dev/null 2>&1 || true

  # Clean up an orphaned file set ONLY if the transcript is genuinely empty
  # and nothing holds the files.
  jsonl="$store/$id.jsonl"
  if [ -f "$jsonl" ] && [ ! -s "$jsonl" ]; then
    if command -v lsof >/dev/null && lsof "$store/$id."* >/dev/null 2>&1; then
      echo "  • $id — files in use, left in place"
      continue
    fi
    rm -f "$store/$id.json" "$store/$id.jsonl" "$store/$id.lock"
  fi
  echo "  ✓ $id"
  deleted=$((deleted + 1))
done

echo
remaining="$(kiro-cli chat --list-sessions --all-cwds -f json 2>/dev/null | jq '[ (if type=="array" then .[] else . end) | (.sessions // [])[] | select((.title // "")=="" or (.messageCount // 0)==0) ] | length')"
echo "Done. Removed $deleted. Empty sessions remaining: $remaining"
sleep 1.6
