#!/usr/bin/env sh
set -eu
BASE="${1:-origin/main}"
OUT="audit/branch-radar.md"
BRANCHES=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes | grep -v ' -> ')
mkdir -p "$(dirname "$OUT")"
printf "# Branch Radar\n_Base for diff: %s_\n\n" "$BASE" > "$OUT"
echo "| Branch | Ahead | Behind | Last Commit | 8000:8000 in compose | override 127.0.0.1:18000 | Dockerfile USER non-root | /livez+/readyz | Security docs | CI workflow |" >> "$OUT"
echo "|---|---:|---:|---|---|---|---|---|---|---|" >> "$OUT"
for B in $BRANCHES; do
  [ "$B" = "HEAD" ] && continue
  AHEAD_BEHIND=$(git rev-list --left-right --count "$B...$BASE" 2>/dev/null || echo "0	0")
  AHEAD=$(echo "$AHEAD_BEHIND" | awk '{print $1}'); BEHIND=$(echo "$AHEAD_BEHIND" | awk '{print $2}')
  LAST=$(git log -1 --format='%h %cs %s' "$B" 2>/dev/null || echo "-")
  HAS_8000=$(git show "$B:docker-compose.yml" 2>/dev/null | grep -q '8000:8000' && echo "⚠️ yes" || echo "✅ no")
  HAS_OVERRIDE=$(git show "$B:docker-compose.override.yml" 2>/dev/null | grep -q '127.0.0.1:18000:8000' && echo "✅ yes" || echo "—")
  NONROOT=$(git show "$B:services/api/Dockerfile" 2>/dev/null | grep -q '^USER ' && echo "✅ yes" || echo "❌ no")
  LIVEZ=$(git show "$B:services/api/app/main.py" 2>/dev/null | grep -q '@app.get("/livez")' && echo "✅" || echo "❌")
  READYZ=$(git show "$B:services/api/app/main.py" 2>/dev/null | grep -q '@app.get("/readyz")' && echo "✅" || echo "❌")
  DOCS=$(git ls-tree -r "$B" --name-only 2>/dev/null | grep -E -q '^docs/(RUNBOOK|SECURITY)\.md$' && echo "✅" || echo "❌")
  CI=$(git ls-tree -r "$B" --name-only 2>/dev/null | grep -E -q '^\.github/workflows/.+\.yml$' && echo "✅" || echo "❌")
  printf "| %s | %s | %s | %s | %s | %s | %s | %s%s | %s | %s |\n" \
    "$(echo "$B" | sed 's#^origin/##')" "$AHEAD" "$BEHIND" "$LAST" "$HAS_8000" "$HAS_OVERRIDE" "$NONROOT" "$LIVEZ" "$READYZ" "$DOCS" "$CI" >> "$OUT"
done
echo "\n## Per-branch change focus vs $BASE" >> "$OUT"
for B in $BRANCHES; do
  [ "$B" = "HEAD" ] && continue
  echo "\n### $(echo "$B" | sed 's#^origin/##')" >> "$OUT"
  echo '```' >> "$OUT"
  git diff --name-only "$BASE...$B" 2>/dev/null \
    | awk -F/ '{print $1"/"$2}' | sed 's#/$##' \
    | sort | uniq -c | sort -nr | head -n 12 >> "$OUT" || true
  echo '```' >> "$OUT"
done
echo "\n## Potential security flags in cookie setter (grep snapshot)" >> "$OUT"
for B in $BRANCHES; do
  CS=$(git show "$B:services/api/app/auth.py" 2>/dev/null | grep -n 'set_cookie' || true)
  [ -n "$CS" ] && { echo "\n### $(echo "$B" | sed 's#^origin/##')" >> "$OUT"; printf '```\n%s\n```\n' "$CS" >> "$OUT"; }
done
echo "Wrote $OUT"
