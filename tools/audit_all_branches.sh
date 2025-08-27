#!/usr/bin/env sh
set -eu
OUTDIR="audit"
mkdir -p "$OUTDIR"
CUR=$(git rev-parse --abbrev-ref HEAD)
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
git switch "$CUR" >/dev/null 2>&1 || git checkout "$CUR"
echo "DONE"
