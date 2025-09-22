#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-}"
PR_NUMBER="${PR_NUMBER:-}"
COMMENT_BODY="${COMMENT_BODY:-}"
DISPATCH_VM="${DISPATCH_VM:-}"
DISPATCH_ALLOW_FROM="${DISPATCH_ALLOW_FROM:-}"
DISPATCH_DRY_RUN="${DISPATCH_DRY_RUN:-}"

YC_CLOUD_ID="${YC_CLOUD_ID:-}"
YC_FOLDER_ID="${YC_FOLDER_ID:-}"
YC_SA_KEY_JSON="${YC_SA_KEY_JSON:-}"
YC_SG_ID="${YC_SG_ID:-}"

j() { gh api "$@" ; }
say() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

RAW="${COMMENT_BODY}"
if [[ -z "${RAW}" && -n "${DISPATCH_VM}" ]]; then
  RAW="@codex cloud fix-metadata vm=${DISPATCH_VM}"
  [[ -n "${DISPATCH_ALLOW_FROM}" ]] && RAW="${RAW} allow_from=${DISPATCH_ALLOW_FROM}"
  RAW="${RAW} dry_run=${DISPATCH_DRY_RUN:-true}"
fi
[[ -z "${RAW}" ]] && fail "No command text or workflow_dispatch inputs."

VM_ID="$(printf "%s\n" "$RAW" | sed -n 's/.*[[:space:]]vm=\([^[:space:]]\+\).*/\1/p' | head -n1)"
ALLOW_FROM="$(printf "%s\n" "$RAW" | sed -n 's/.*[[:space:]]allow_from=\([^[:space:]]\+\).*/\1/p' | head -n1 || true)"
DRY_RUN_RAW="$(printf "%s\n" "$RAW" | sed -n 's/.*[[:space:]]dry_run=\([^[:space:]]\+\).*/\1/p' | head -n1 || true)"
[[ -z "${VM_ID}" ]] && fail "vm=<VM_ID> is required."

DRY_RUN="true"
if [[ -n "${DRY_RUN_RAW}" ]]; then
  case "${DRY_RUN_RAW,,}" in false|0|no) DRY_RUN="false" ;; *) DRY_RUN="true" ;; esac
fi

if [[ -n "${ALLOW_FROM}" ]]; then
  if [[ "$ALLOW_FROM" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then ALLOW_FROM="${ALLOW_FROM}/32"; fi
  if ! [[ "$ALLOW_FROM" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/(32|3[0-1]|[12]?[0-9])$ ]]; then
    warn "allow_from invalid, ignore: $ALLOW_FROM"; ALLOW_FROM=""
  fi
fi

MARK_HEAD="Codex-Cloud:"
RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${REPO}/actions/runs/${GITHUB_RUN_ID:-}"
STATUS_LINE="${MARK_HEAD} vm=${VM_ID} allow_from=${ALLOW_FROM:-none} dry_run=${DRY_RUN}  ${RUN_URL}"

update_marker() {
  [[ -z "${PR_NUMBER}" ]] && return 0
  local id body
  id="$(j "/repos/${REPO}/issues/${PR_NUMBER}/comments" --jq 'map(select(.body|startswith("'"$MARK_HEAD"'")))[0].id' 2>/dev/null || echo "null")"
  body="$(j "/repos/${REPO}/issues/${PR_NUMBER}/comments" --jq 'map(select(.body|startswith("'"$MARK_HEAD"'")))[0].body' 2>/dev/null || echo "")"
  if [[ "$id" != "null" && "$body" == "$STATUS_LINE" ]]; then
    say "Marker up-to-date (#$id)."
  elif [[ "$id" != "null" ]]; then
    say "Updating marker (#$id)."; j -X PATCH "/repos/${REPO}/issues/comments/${id}" -F body="$STATUS_LINE" >/dev/null
  else
    say "Creating marker."; j -X POST "/repos/${REPO}/issues/${PR_NUMBER}/comments" -F body="$STATUS_LINE" >/dev/null
  fi
}
update_marker

# DRY RUN path or missing secrets -> plan only, exit 0
MISSING_SECRETS=""
[[ -z "$YC_CLOUD_ID" ]] && MISSING_SECRETS="${MISSING_SECRETS} YC_CLOUD_ID"
[[ -z "$YC_FOLDER_ID" ]] && MISSING_SECRETS="${MISSING_SECRETS} YC_FOLDER_ID"
[[ -z "$YC_SA_KEY_JSON" ]] && MISSING_SECRETS="${MISSING_SECRETS} YC_SERVICE_ACCOUNT_KEY_JSON"

PLAN=$(cat <<EOF
Plan:
  - (lazy) install yc only for live runs
  - Auth with SA key
  - yc compute instance get --id ${VM_ID}
  - If .cloud/metadata/user-data.yaml exists:
      yc compute instance update --id ${VM_ID} --metadata-from-file user-data=.cloud/metadata/user-data.yaml
  - If allow_from and YC_SG_ID:
      ensure ingress tcp/22 from ${ALLOW_FROM:-<none>}
EOF
)

if [[ "$DRY_RUN" == "true" || -n "$MISSING_SECRETS" ]]; then
  say "DRY-RUN or missing secrets -> no cloud changes."
  [[ -n "$MISSING_SECRETS" ]] && warn "Missing secrets:${MISSING_SECRETS}"
  echo "---- DRY RUN PLAN ----"; echo "$PLAN"; exit 0
fi

# -------- LIVE RUN --------
say "Ensuring YC CLI present"
if ! command -v yc >/dev/null 2>&1; then
  curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
  export PATH="${HOME}/yandex-cloud/bin:${PATH}"
fi

say "Config YC profile"
KEY_FILE="$(mktemp)"; printf "%s" "$YC_SA_KEY_JSON" > "$KEY_FILE"
export PATH="${HOME}/yandex-cloud/bin:${PATH}"
yc config set cloud-id "$YC_CLOUD_ID"
yc config set folder-id "$YC_FOLDER_ID"
yc config set service-account-key "$KEY_FILE" || true
yc config set format json

say "Verify instance exists"; yc compute instance get --id "$VM_ID" >/dev/null

if [[ -f ".cloud/metadata/user-data.yaml" ]]; then
  say "Update metadata from .cloud/metadata/user-data.yaml"
  yc compute instance update --id "$VM_ID" \
    --metadata-from-file user-data=.cloud/metadata/user-data.yaml
else
  warn "No .cloud/metadata/user-data.yaml; skip metadata update."
fi

if [[ -n "${ALLOW_FROM:-}" && -n "${YC_SG_ID:-}" ]]; then
  say "Ensure SG ${YC_SG_ID} has ingress tcp/22 from ${ALLOW_FROM}"
  if yc vpc security-group get --id "$YC_SG_ID" | grep -q "$ALLOW_FROM"; then
    say "Rule already present."
  else
    yc vpc security-group update-rules --id "$YC_SG_ID" \
      --add-rule direction=ingress,protocol=tcp,port=22,v4-cidr="$ALLOW_FROM"
    say "Rule added."
  fi
else
  say "No allow_from or YC_SG_ID; skipping SG update."
fi

say "Done."
exit 0
