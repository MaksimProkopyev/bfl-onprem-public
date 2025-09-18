#!/usr/bin/env bash
# BFL: OS Login + Metadata + SG (idempotent; supports old/new yc)
set -eo pipefail
log(){ echo "[INFO] $*"; }
warn(){ echo "[WARN] $*" >&2; }
have(){ command -v "$1" >/dev/null 2>&1; }
JQ(){ if have jq; then jq "$@"; else cat; fi; }

# Fixed inputs from brief
FOLDER_ID="${FOLDER_ID:-b1gj6os8m6vmq2l7gbc2}"
VM_ID="${VM_ID:-fhmmngh9gks1mv7v2l03}"
VM_NAME="${VM_NAME:-bfl-onprem-cloudinit-20250911-121313}"
ZONE="${ZONE:-ru-central1-a}"
SG_ID="${SG_ID:-enps3subet8bapnvj3qt}"
NAT_EXPECT="${NAT_EXPECT:-89.169.156.2}"

USER_ID="${USER_ID:-ajeq67g6ls68cnk0ql5o}"
POSIX="${POSIX:-ivmsu}"
ALLOW_FROM="${ALLOW_FROM:-87.239.249.137/32}"

echo "== BFL OS Login Autopilot =="
yc --version 2>/dev/null | head -1 || true

sg_id_flag(){ yc vpc security-group add-rule --help 2>/dev/null | grep -q -- '--security-group-id' && echo "--security-group-id" || echo "--id"; }
ports_flag(){  yc vpc security-group add-rule --help 2>/dev/null | grep -q -- '--ports'            && echo "--ports"            || echo "--port"; }

has_ingress22(){
  yc vpc security-group get --id "$SG_ID" --format json \
  | jq -e --arg ip "$ALLOW_FROM" '
      ((.ingress_rules // []) | map(
        select((.protocol // "")=="tcp")
        | (if has("port") then .port==22 else ((.from_port // 0)<=22 and 22<=(.to_port // 0)) end)
        | ((.cidr_blocks // .v4_cidr_blocks // []) + (.src_cidr_blocks // [])) as $cidrs
        | ($cidrs | index($ip)) != null
      )) | any
    ' >/dev/null 2>&1
}
has_egress_any(){
  yc vpc security-group get --id "$SG_ID" --format json \
  | jq -e '
      ((.egress_rules // []) | map(
        (.protocol // "any")=="any"
        | ((.cidr_blocks // .v4_cidr_blocks // []) + (.dst_cidr_blocks // [])) as $cidrs
        | ($cidrs | index("0.0.0.0/0")) != null
      )) | any
    ' >/dev/null 2>&1
}
get_meta(){ yc compute instance get --id "$VM_ID" --format json | JQ -r ".metadata[\"$1\"] // \"\""; }
wait_meta(){
  log "Wait metadata reflection..."
  for i in $(seq 1 40); do
    en="$(get_meta enable-oslogin)"
    sp="$(get_meta serial-port-enable)"
    au="$(get_meta ssh-authorization)"
    echo "  try #$i: enable-oslogin=${en:-<none>}  serial-port-enable=${sp:-<none>}  ssh-authorization=${au:-<none>}"
    [[ "${en,,}" == "true" && "${au,,}" == "oslogin" && "$sp" =~ ^(1|true)$ ]] && return 0
    sleep 2
  done
  return 1
}

# 1) Roles (idempotent add; ignore 409)
log "Grant roles on folder+instance"
yc resource-manager folder add-access-binding --id "$FOLDER_ID" --role compute.osLogin      --subject userAccount:"$USER_ID" >/dev/null 2>&1 || true
yc resource-manager folder add-access-binding --id "$FOLDER_ID" --role compute.osAdminLogin --subject userAccount:"$USER_ID" >/dev/null 2>&1 || true
yc compute instance add-access-binding        --id "$VM_ID"     --role compute.osLogin      --subject userAccount:"$USER_ID" >/dev/null 2>&1 || true
yc compute instance add-access-binding        --id "$VM_ID"     --role compute.osAdminLogin --subject userAccount:"$USER_ID" >/dev/null 2>&1 || true

# 2) Metadata (legacy-safe: update/add, then remove+add if needed)
log "Set metadata: enable-oslogin=true, serial-port-enable=1, ssh-authorization=oslogin"
if yc compute instance update --help 2>/dev/null | grep -q -- '--metadata'; then
  yc compute instance update --id "$VM_ID" --metadata enable-oslogin=true || true
  yc compute instance update --id "$VM_ID" --metadata serial-port-enable=1 || true
  yc compute instance update --id "$VM_ID" --metadata ssh-authorization=oslogin || true
else
  yc compute instance add-metadata --id "$VM_ID" --metadata enable-oslogin=true || true
  yc compute instance add-metadata --id "$VM_ID" --metadata serial-port-enable=1 || true
  yc compute instance add-metadata --id "$VM_ID" --metadata ssh-authorization=oslogin || true
fi
if ! wait_meta; then
  warn "metadata not reflected — try remove+add"
  yc compute instance remove-metadata --id "$VM_ID" --keys enable-oslogin,serial-port-enable,ssh-authorization >/dev/null 2>&1 || true
  yc compute instance add-metadata    --id "$VM_ID" --metadata enable-oslogin=true
  yc compute instance add-metadata    --id "$VM_ID" --metadata serial-port-enable=1
  yc compute instance add-metadata    --id "$VM_ID" --metadata ssh-authorization=oslogin
  wait_meta || warn "still not visible — check IAM"
fi

# 3) Security Group (add missing only)
AF="$(sg_id_flag)"; PF="$(ports_flag)"
log "Ensure SG ingress tcp/22 from ${ALLOW_FROM}"
if has_ingress22; then echo "  ingress OK"; else yc vpc security-group add-rule "$AF" "$SG_ID" --direction ingress --protocol tcp "$PF" 22 --cidr-blocks "$ALLOW_FROM"; fi
log "Ensure SG egress any to 0.0.0.0/0"
if has_egress_any; then echo "  egress  OK"; else yc vpc security-group add-rule "$AF" "$SG_ID" --direction egress --protocol any --cidr-blocks "0.0.0.0/0"; fi

# 4) Summary
echo "---- SUMMARY ----"
yc compute instance get --id "$VM_ID" --format yaml | awk '/^(name:|id:|status:|zone_id:)/{print}'
echo "-- Metadata --"; yc compute instance get --id "$VM_ID" --format yaml | awk '/^metadata:/{p=1;print;next} p&&/^[^[:space:]]/{p=0} p{print}'
echo "-- SG (expect: IN tcp/22 87.239.249.137/32; OUT any 0.0.0.0/0) --"
yc vpc security-group get --id "$SG_ID" --format yaml | awk '/^(ingress_rules:|egress_rules:)/{p=1;print;next} p&&/^[^[:space:]]/{p=0} p{print}'
