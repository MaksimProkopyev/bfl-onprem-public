# Finish: OS Login, SSH hardening, CI & protection

## Context (fixed)
- Cloud ID: b1g0r1ratit5lvjmi68o
- Folder ID: b1gj6os8m6vmq2l7gbc2
- Org ID: bpfdkn227rbkv9ov9tlo
- Zone: ru-central1-a
- VM: bfl-onprem-cloudinit-20250911-121313 (ID fhmmngh9gks1mv7v2l03), IP 89.169.156.2
- Subnet: e9b6okd8v5dpjebhlro4
- SG: enps3subet8bapnvj3qt (INGRESS tcp/22 from 87.239.249.137/32; EGRESS any 0.0.0.0/0)
- OS Login: iv.msu@yandex.ru (userAccount.id ajeq67g6ls68cnk0ql5o, posix ivmsu)

## Tasks
1. Ensure OS Login roles on Folder+Instance (compute.osLogin, compute.osAdminLogin) for the userAccount.
2. Ensure instance metadata: enable-oslogin=true, serial-port-enable=1, ssh-authorization=oslogin.
3. SSH as ivmsu with key ~/.ssh/cloudshell_oslogin (fallback ~/.ssh/id_ed25519); print whoami/id/groups; retries.
4. Hardening: DenyUsers ubuntu; remove /home/ubuntu/.ssh/authorized_keys; reload sshd; verify sshd -T.
5. Verify SG has exactly 2 rules (ingress 22 from the fixed /32; egress any).
6. CI green; optionally enable branch protection requiring "linters / shell-yaml-actions".
7. Post a short SUMMARY with commands for manual verification.

## Acceptance Criteria
- Idempotent commands; short step logs; wait loops where needed.
- No destructive infra changes beyond the scope above.
- SSH works for ivmsu; hardening applied; CI success; (optional) branch protection enabled.
