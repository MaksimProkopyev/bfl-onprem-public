## CI: Remote Smoke — SSH quick notes
- Если у ВМ включён OS Login, используйте `VM_LOGIN=yc-user` (а не `ubuntu`), иначе получите: “OS login info not found…”.
- Эфемерный ключ через метаданные (`ssh-keys`) работает только при разрешённой авторизации по метаданным; на OS Login-only он игнорируется.
- Три главные причины падений и решения:
  1) **yc не найден (exit 127)** → ставим `yc`, добавляем в PATH в *том же шаге*.
  2) **yc init с SA JSON** → используем `yc config profile activate` и `yc config set service-account-key sa.json`.
  3) **yc compute ssh с пустым -i или OS Login-only** → передавать ключ через `env` и/или ставить `VM_LOGIN=yc-user`, либо переключать авторизацию ВМ на метаданные/смешанную.

## Yandex Cloud — Ops Quickstart

- **Maintenance Window** (`maintenance.yml`):
  - `open` — навесить NAT (public IP) на ВМ (можно указать reserved IP id).
  - `deploy` — `git pull` + `docker compose pull/up` на ВМ + smoke через SSH-туннель → затем `close`.
  - `close` — снять NAT, опционально `stop_on_close=yes` чтобы остановить ВМ.
- **Dev Auto-schedule** (`yc-auto-schedule.yml`):
  - Будни: стоп 20:00 и старт 09:00 (Europe/Helsinki) для ВМ с лейблами `env=dev, autostop=true`.
  - Пометить ВМ: `yc compute instance add-labels <VM> --labels env=dev,autostop=true`
- **Weekly Cost Inventory** (`yc-cost-inventory.yml`): артефакт `yc_inventory.tgz` (CSV со списками ВМ/дисков/IP) + краткий отчёт в Summary.

> Секреты: `YC_CLOUD_ID`, `YC_FOLDER_ID`, `YC_ZONE`, `YC_SA_KEY_JSON` должны быть заданы в репозитории.
