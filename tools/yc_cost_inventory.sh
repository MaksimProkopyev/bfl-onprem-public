#!/usr/bin/env bash
set -euo pipefail
: "${YC_CLOUD_ID:?}"; : "${YC_FOLDER_ID:?}"; : "${YC_ZONE:?}"; : "${YC_SA_KEY_JSON:?}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
echo "$YC_SA_KEY_JSON" > "$WORK/sa.json"
if ! command -v yc >/dev/null; then curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash >/dev/null; export PATH="$HOME/yandex-cloud/bin:$PATH"; fi
command -v jq >/dev/null || { sudo apt-get update -y && sudo apt-get install -y jq >/dev/null; }
yc config profile create ci-cost || true; yc config profile activate ci-cost
yc config set service-account-key "$WORK/sa.json"
yc config set cloud-id "$YC_CLOUD_ID"; yc config set folder-id "$YC_FOLDER_ID"; yc config set compute-default-zone "$YC_ZONE"
mkdir -p out; OUT=out
yc compute instance list --format json > "$OUT/instances.json"
yc compute disk list --format json > "$OUT/disks.json"
yc compute snapshot list --format json > "$OUT/snapshots.json" || echo "[]" > "$OUT/snapshots.json"
yc vpc address list --format json > "$OUT/addresses.json" || echo "[]" > "$OUT/addresses.json"
jq -r '["name","status","preemptible","cores","memory_gb","zone","public_ip_count"],(.[]|[.name,.status,(.scheduling_policy.preemptible//false),(.resources.cores//0),((.resources.memory//0)/1073741824),.zone_id,([.network_interfaces[]?.primary_v4_address?.one_to_one_nat?.address]|map(select(.!=null))|length)])' "$OUT/instances.json" > "$OUT/instances.csv"
jq -r '["id","name","type","size_gb","zone"],(.[]|select((.instance_ids|length)==0)|[.id,.name,.type,((.size//0)/1073741824),.zone_id])' "$OUT/disks.json" > "$OUT/unattached_disks.csv"
jq -r '["id","address","type","reserved","zone"],(.[]|[.id,.external_ipv4_address.address, (.type//""),(.reserved//false),(.external_ipv4_address.zone_id//"")])' "$OUT/addresses.json" > "$OUT/public_ips.csv" 2>/dev/null || true
RUNNING=$(jq '[.[]|select(.status=="RUNNING")]|length' "$OUT/instances.json"); STOPPED=$(jq '[.[]|select(.status=="STOPPED")]|length' "$OUT/instances.json"); PRE=$(jq '[.[]|select(.scheduling_policy.preemptible==true)]|length' "$OUT/instances.json"); UNATT=$(jq 'map(select((.instance_ids|length)==0))|length' "$OUT/disks.json")
echo "## Yandex Cloud Cost Inventory — Summary" > "$OUT/summary.md"
echo "- VMs: RUNNING **$RUNNING**, STOPPED **$STOPPED**, preemptible **$PRE**" >> "$OUT/summary.md"
echo "- Unattached disks: **$UNATT**" >> "$OUT/summary.md"
tar -C "$OUT" -czf yc_inventory.tgz .
sed -n '1,200p' "$OUT/summary.md"
