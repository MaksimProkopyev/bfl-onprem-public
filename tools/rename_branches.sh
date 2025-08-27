#!/usr/bin/env sh
set -eu
# пары OLD NEW
cat <<'MAP' | while read OLD NEW; do
  [ -z "$OLD" ] && continue
  [ "$OLD" = "main" ] && { echo "skip main"; continue; }
  git show-ref --verify --quiet "refs/heads/$OLD" || { echo "skip $OLD (no local branch)"; continue; }
  git show-ref --verify --quiet "refs/heads/$NEW" && { echo "skip $OLD -> $NEW (target exists)"; continue; }

  echo "Renaming $OLD -> $NEW"
  git branch -m "$OLD" "$NEW"
  # переустановим upstream на origin
  git push origin -u "$NEW"
  # удалим старую ветку на origin (если была)
  git push origin ":$OLD" || true

  # если есть PR с этой веткой — обновим head
  if gh pr list --state all --json number,headRefName -q ".[] | select(.headRefName==\"$OLD\") | .number" | grep -q '^[0-9]'; then
    for PR in $(gh pr list --state all --json number,headRefName -q ".[] | select(.headRefName==\"$OLD\") | .number"); do
      gh pr edit "$PR" --head "$NEW" || true
    done
  fi
done
exit 0
MAP
