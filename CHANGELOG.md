# Changelog
## v0.2.0 (Sprint 2)
- Security: CSRF double-submit, строгие cookie-флаги.
- Observability: Prometheus метрики, /livez /readyz /api/health.
- Rate limiting: Redis asyncio + in-memory fallback.
- Deployment: Dockerfile USER non-root; compose override loopback.
- CI: lint/test/build, SBOM (Syft), smoke + artifacts.
