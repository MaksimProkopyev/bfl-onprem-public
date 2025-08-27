# Branch Radar
_Base for diff: origin/main_

| Branch | Ahead | Behind | Last Commit | 8000:8000 in compose | override 127.0.0.1:18000 | Dockerfile USER non-root | /livez+/readyz | Security docs | CI workflow |
|---|---:|---:|---|---|---|---|---|---|---|
| codex/create-text-file-for-codex-gpt-prompts | 2 | 3 | 7fb7a29 2025-08-24 chore(codex): add system/user prompts for Codex runs | ⚠️ yes | — | ❌ no | ❌❌ | ❌ | ✅ |
| main | 0 | 0 | e4bf0ad 2025-08-25 feat(auth): restore login for /autopilot via cookie gate + docs | ⚠️ yes | — | ❌ no | ❌❌ | ❌ | ✅ |
| HEAD | 0 | 0 | e4bf0ad 2025-08-25 feat(auth): restore login for /autopilot via cookie gate + docs | ⚠️ yes | — | ❌ no | ❌❌ | ❌ | ✅ |
| ci-pr-review | 1 | 8 | d7d2b59 2025-08-23 ci: PR review via GPT-5 Thinking + usage + $ estimation | ✅ no | — | ❌ no | ❌❌ | ❌ | ✅ |
| codex/create-text-file-for-codex-gpt-prompts | 2 | 3 | 7fb7a29 2025-08-24 chore(codex): add system/user prompts for Codex runs | ⚠️ yes | — | ❌ no | ❌❌ | ❌ | ✅ |
| main | 0 | 0 | e4bf0ad 2025-08-25 feat(auth): restore login for /autopilot via cookie gate + docs | ⚠️ yes | — | ❌ no | ❌❌ | ❌ | ✅ |
| vscode-ru | 4 | 8 | 106192c 2025-08-24 chore(ci): deploy workflow + minimal vite/FastAPI files | ✅ no | — | ❌ no | ❌❌ | ❌ | ✅ |
| public/codex/create-text-file-for-codex-gpt-prompts | 2 | 3 | 7fb7a29 2025-08-24 chore(codex): add system/user prompts for Codex runs | ⚠️ yes | — | ❌ no | ❌❌ | ❌ | ✅ |
| public/main | 0 | 0 | e4bf0ad 2025-08-25 feat(auth): restore login for /autopilot via cookie gate + docs | ⚠️ yes | — | ❌ no | ❌❌ | ❌ | ✅ |
\n## Per-branch change focus vs origin/main
\n### codex/create-text-file-for-codex-gpt-prompts
```
   1 codex/codex-user.txt
   1 codex/codex-system.txt
   1 codex-bfl-prompts.txt
```
\n### main
```
```
\n### HEAD
```
```
\n### ci-pr-review
```
   1 .github/workflows
```
\n### codex/create-text-file-for-codex-gpt-prompts
```
   1 codex/codex-user.txt
   1 codex/codex-system.txt
   1 codex-bfl-prompts.txt
```
\n### main
```
```
\n### vscode-ru
```
   2 .github/workflows
   1 services/ui
   1 services/api
   1 docs/runbooks
   1 .vscode/settings.json
   1 .vscode/extensions.json
```
\n### public/codex/create-text-file-for-codex-gpt-prompts
```
   1 codex/codex-user.txt
   1 codex/codex-system.txt
   1 codex-bfl-prompts.txt
```
\n### public/main
```
```
\n## Potential security flags in cookie setter (grep snapshot)
\n### main
```
96:        resp.set_cookie(COOKIE, tok, httponly=True, samesite="lax", secure=False, path="/")
```
\n### HEAD
```
96:        resp.set_cookie(COOKIE, tok, httponly=True, samesite="lax", secure=False, path="/")
```
\n### main
```
96:        resp.set_cookie(COOKIE, tok, httponly=True, samesite="lax", secure=False, path="/")
```
\n### public/main
```
96:        resp.set_cookie(COOKIE, tok, httponly=True, samesite="lax", secure=False, path="/")
```
