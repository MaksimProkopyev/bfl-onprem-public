# Mission: Finish OS Login + SSH hardening + SG for prod VM

## Context (fixed)
- Cloud ID: b1g0r1ratit5lvjmi68o
- Folder ID: b1gj6os8m6vmq2l7gbc2
- Org ID: bpfdkn227rbkv9ov9tlo
- Zone: ru-central1-a
- Subnet ID: e9b6okd8v5dpjebhlro4
- Security Group ID: enps3subet8bapnvj3qt
- Static IP: 89.169.156.2
- Allowed SSH source: 87.239.249.137/32

## VM (do NOT create/delete)
- Name: bfl-onprem-cloudinit-20250911-121313
- ID: fhmmngh9gks1mv7v2l03
- Disk: fhm5m1gmrsr7ba1gbesj
- Required metadata: enable-oslogin=true, serial-port-enable=1, ssh-authorization=oslogin

## OS Login User
- email: iv.msu@yandex.ru
- userAccount.id: ajeq67g6ls68cnk0ql5o
- POSIX: ivmsu

## SG policy (HARD)
- INGRESS: tcp/22 only from 87.239.249.137/32
- EGRESS: ANY to 0.0.0.0/0

## Deliverables
1) Idempotent script `tools/yc-oslogin-autopilot.sh` (bash) that:
   - Grants roles (compute.osLogin, compute.osAdminLogin) on Folder **and** Instance to userAccount: ajeq67g6ls68cnk0ql5o.
   - Ensures metadata keys above (legacy `yc` safe; no `set-metadata` dependency).
   - Ensures SG has the two required rules (add-missing only).
   - Waits for RUNNING, prints concise SUMMARY.
2) PR description with acceptance criteria.
3) Keep linters green.

## Acceptance
- Roles present on folder+instance.
- `yc compute instance get` shows correct metadata.
- SG contains required IN/OUT rules.
- Script prints SUMMARY for sysadmin.

## Nice to have
- README snippet: SSH test as `ivmsu`, then hardening (DenyUsers ubuntu + purge ~ubuntu/.ssh/authorized_keys + restart sshd).
