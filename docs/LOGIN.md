# Вход в кабинет (/autopilot)

Реализована простая аутентификация через cookie токен (HMAC). Страница логина: **/autopilot/login**.
- `POST /api/auth/login` — форма `username`, `password`, выставляет cookie и делает 303 на /autopilot/
- `POST /api/auth/logout` — удаляет cookie, 303 на /autopilot/login
- `GET /api/auth/me` — проверка статуса (401/200)

Переменные окружения:
- `BFL_AUTH_ENABLED=1` — включить/выключить гейт
- `BFL_DASHBOARD_USER`, `BFL_DASHBOARD_PASS` — логин/пароль
- `BFL_SECRET` — секрет для подписи (обязательно переопредели в проде)
- `BFL_AUTH_TTL_SEC` — TTL токена (по умолчанию 7 дней)

Доступ к кабинету только через SSH-туннель (loopback), никаких внешних портов.
