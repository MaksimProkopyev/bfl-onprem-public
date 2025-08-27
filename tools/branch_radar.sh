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
echo "\n## Done" >> "$OUT"
