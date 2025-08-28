## CI: Remote Smoke — SSH quick notes
- Если у ВМ включён OS Login, используйте `VM_LOGIN=yc-user` (а не `ubuntu`), иначе получите: “OS login info not found…”.
- Эфемерный ключ через метаданные (`ssh-keys`) работает только при разрешённой авторизации по метаданным; на OS Login-only он игнорируется.
- `yc compute ssh` теперь сам определяет режим авторизации, `--auth-type` указывать не нужно.
- Пустой `-i` в `yc compute ssh` больше не нужен: переданный ключ используется автоматически.
- Три главные причины падений и решения:
  1) **yc не найден (exit 127)** → ставим `yc`, добавляем в PATH в *том же шаге*.
  2) **yc init с SA JSON** → используем `yc config profile activate` и `yc config set service-account-key sa.json`.
  3) **yc compute ssh с пустым -i или OS Login-only** → передавать ключ через `env` и/или ставить `VM_LOGIN=yc-user`, либо переключать авторизацию ВМ на метаданные/смешанную.
