#!/usr/bin/env bash
set -euo pipefail
while read -r OLD NEW; do
  [[ -z "${OLD:-}" || "${OLD:0:1}" == "#" ]] && continue
  [[ "$OLD" == "main" ]] && { echo "skip main"; continue; }
  if git show-ref --verify --quiet "refs/heads/$OLD"; then
    if git show-ref --verify --quiet "refs/heads/$NEW"; then
      echo "skip $OLD -> $NEW (target exists)"; continue
    fi
    echo "Renaming $OLD -> $NEW"
    git branch -m "$OLD" "$NEW"
    git push origin -u "$NEW"
    git push origin ":$OLD" || true
  else
    echo "skip $OLD (no local branch)"
  fi
done
