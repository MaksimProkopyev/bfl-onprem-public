# SECURITY
- Cookie flags из ENV (Secure/HttpOnly/SameSite/Path/Domain).
- CSRF double-submit (cookie `bfl_csrf` + header `X-CSRF-Token`).
- Rate-limit на Redis с graceful fallback.
- Security headers: `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`.
- Контейнер non-root (`USER bfl`).
