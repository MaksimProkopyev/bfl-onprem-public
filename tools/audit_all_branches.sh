#!/usr/bin/env sh
set -eu
OUTDIR="audit"
mkdir -p "$OUTDIR"
CURRENT=$(git rev-parse --abbrev-ref HEAD)

# Все локальные ветки (кроме HEAD)
for BR in $(git for-each-ref --format='%(refname:short)' refs/heads | grep -v '^HEAD$'); do
  echo "=== AUDIT $BR ==="
  git switch "$BR" >/dev/null 2>&1 || git checkout "$BR"
  SAFE=$(echo "$BR" | sed 's#[^A-Za-z0-9._-]#_#g')
  if [ -x audit/bfl_audit.sh ]; then
    bash audit/bfl_audit.sh | tee "$OUTDIR/audit-$SAFE.txt"
  else
    echo "audit/bfl_audit.sh отсутствует в $BR, пропускаю" | tee "$OUTDIR/audit-$SAFE.txt"
  fi
done

# Вернёмся
git switch "$CURRENT" >/dev/null 2>&1 || git checkout "$CURRENT"
echo "DONE. См. папку audit/"
