#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
UI_DIR="services/admin-ui"

echo "==> Проверки…"
[ -d "$UI_DIR" ] || { echo "Нет каталога $UI_DIR. Создай его и запусти снова."; exit 1; }
command -v node >/dev/null || { echo "Node.js не найден. Установи Node 18+."; exit 1; }
command -v npm  >/dev/null || { echo "npm не найден."; exit 1; }

cd "$UI_DIR"

echo "==> .env.development"
cat > .env.development <<'ENV'
VITE_API_BASE=/api
ENV

echo "==> vite.config.ts (бэкап при наличии)"
[ -f vite.config.ts ] && cp vite.config.ts vite.config.ts.bak || true
cat > vite.config.ts <<'TS'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  base: '/autopilot/',
  plugins: [react()],
  server: {
    host: '127.0.0.1',
    port: 5173,
    strictPort: true,
    proxy: {
      '/api':    { target: 'http://127.0.0.1:8000', changeOrigin: true, secure: false },
      '/metrics':{ target: 'http://127.0.0.1:8000', changeOrigin: true, secure: false },
    },
  },
})
TS

echo "==> package.json — создаю/обновляю"
if [ ! -f package.json ]; then
  cat > package.json <<'JSON'
{
  "name": "bfl-admin-ui",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview --host 127.0.0.1 --port 5174"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.26.1"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.1",
    "vite": "^5.4.2"
  }
}
JSON
else
  # мягкое обновление через npm pkg set (не ломаем существующее)
  npm pkg set type=module >/dev/null
  npm pkg set scripts.dev="vite" scripts.build="vite build" scripts.preview="vite preview --host 127.0.0.1 --port 5174" >/dev/null
fi

echo "==> Установка зависимостей"
npm i -D vite @vitejs/plugin-react >/dev/null
npm i react react-dom react-router-dom >/dev/null

echo "==> Файлы UI"
mkdir -p src/pages src/components

cat > index.html <<'HTML'
<!doctype html>
<html lang="ru">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>BFL Autopilot</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
HTML

cat > src/main.tsx <<'TSX'
import React from 'react'
import ReactDOM from 'react-dom/client'
import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import App from './App'
import Dashboard from './pages/Dashboard'
import Tasks from './pages/Tasks'
import Metrics from './pages/Metrics'

const router = createBrowserRouter(
  [
    {
      path: '/',
      element: <App />,
      children: [
        { index: true, element: <Dashboard /> },
        { path: 'tasks', element: <Tasks /> },
        { path: 'metrics', element: <Metrics /> },
      ],
    },
  ],
  { basename: '/autopilot' }
)

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <RouterProvider router={router} />
  </React.StrictMode>
)
TSX

cat > src/App.tsx <<'TSX'
import React from 'react'
import { Link, Outlet, useLocation } from 'react-router-dom'
import './styles.css'

export default function App() {
  const { pathname } = useLocation()
  return (
    <div className="wrap">
      <header className="topbar">
        <h1>ИИ-агент БФЛ — Autopilot</h1>
        <nav>
          <Link className={pathname === '/' ? 'active' : ''} to="/">Дашборд</Link>
          <Link className={pathname.startsWith('/tasks') ? 'active' : ''} to="/tasks">Задачи</Link>
          <Link className={pathname.startsWith('/metrics') ? 'active' : ''} to="/metrics">Метрики</Link>
        </nav>
      </header>
      <main><Outlet /></main>
    </div>
  )
}
TSX

cat > src/styles.css <<'CSS'
* { box-sizing: border-box; }
body { margin:0; font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial; }
.topbar { display:flex; align-items:center; justify-content:space-between; padding:10px 16px; border-bottom:1px solid #ddd; }
.topbar h1 { font-size:18px; margin:0; }
.topbar nav a { margin-left:14px; text-decoration:none; color:#333; padding:4px 8px; border-radius:6px; }
.topbar nav a.active { background:#efefef; }
.wrap main { padding:16px; max-width:900px; margin:0 auto; }
.card { border:1px solid #e5e5e5; border-radius:10px; padding:14px; margin-bottom:14px; }
.row { display:flex; gap:10px; flex-wrap:wrap; }
button { padding:8px 12px; border:1px solid #ccc; background:#fafafa; border-radius:8px; cursor:pointer; }
button:disabled { opacity:.5; cursor:not-allowed; }
pre { background:#0f172a; color:#e2e8f0; padding:12px; border-radius:8px; overflow:auto; }
input[type="text"] { padding:8px; border:1px solid #ccc; border-radius:8px; }
CSS

cat > src/api.ts <<'TS'
const API_BASE = import.meta.env.VITE_API_BASE || '/api'

async function req<T>(path: string, init?: RequestInit): Promise<T> {
  const r = await fetch(path.startsWith('/') ? path : `${API_BASE}/${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(init?.headers || {}) },
  })
  if (!r.ok) {
    const text = await r.text().catch(() => '')
    throw new Error(`HTTP ${r.status}: ${text}`)
  }
  return r.headers.get('content-type')?.includes('application/json')
    ? r.json()
    : (await r.text()) as unknown as T
}

export const api = {
  health: () => req<{ status: string }>(`${API_BASE}/health`),
  enqueue: (task: string, args: Record<string, unknown> = {}) =>
    req<any>(`${API_BASE}/admin/autopilot/enqueue`, {
      method: 'POST', body: JSON.stringify({ task, args }),
    }),
  noop: () => req<any>(`${API_BASE}/admin/autopilot/noop`),
  k6: () => req<any>(`${API_BASE}/admin/autopilot/k6_smokes`),
  metricsRaw: () => req<string>('/metrics'),
}
TS

cat > src/pages/Dashboard.tsx <<'TSX'
import React from 'react'
import { api } from '../api'

export default function Dashboard() {
  const [health, setHealth] = React.useState<string>('—')
  const [error, setError] = React.useState<string>('')

  const load = async () => {
    setError('')
    try {
      const h = await api.health()
      setHealth(JSON.stringify(h))
    } catch (e:any) {
      setError(e.message)
    }
  }

  React.useEffect(() => { load() }, [])

  return (
    <div className="card">
      <h2>Состояние API</h2>
      <div className="row" style={{alignItems:'center'}}>
        <button onClick={load}>Обновить</button>
        <span>Health: <b>{health}</b></span>
      </div>
      {error && <p style={{color:'crimson'}}>Ошибка: {error}</p>}
      <p style={{opacity:.7, marginTop:8}}>Эндпоинт: <code>GET /api/health</code></p>
    </div>
  )
}
TSX

cat > src/pages/Tasks.tsx <<'TSX'
import React from 'react'
import { api } from '../api'

export default function Tasks() {
  const [out, setOut] = React.useState<string>('')

  const run = async (fn: () => Promise<any>) => {
    setOut('Выполняю...')
    try {
      const r = await fn()
      setOut(JSON.stringify(r, null, 2))
    } catch (e:any) {
      setOut('Ошибка: ' + e.message)
    }
  }

  const [customTask, setCustomTask] = React.useState('noop')
  const [customArgs, setCustomArgs] = React.useState('{}')

  return (
    <div className="card">
      <h2>Задачи Autopilot</h2>
      <div className="row">
        <button onClick={() => run(api.noop)}>noop</button>
        <button onClick={() => run(api.k6)}>k6_smokes</button>
      </div>
      <div style={{marginTop:12}}>
        <h3>Универсальный enqueue</h3>
        <div className="row">
          <input type="text" value={customTask} onChange={e=>setCustomTask(e.target.value)} />
          <input type="text" value={customArgs} onChange={e=>setCustomArgs(e.target.value)} />
          <button onClick={() => {
            let parsed = {}
            try { parsed = JSON.parse(customArgs || '{}') } catch {}
            run(() => api.enqueue(customTask, parsed))
          }}>enqueue</button>
        </div>
        <p style={{opacity:.7}}>Эндпоинт: <code>POST /api/admin/autopilot/enqueue</code></p>
      </div>
      <h3>Ответ</h3>
      <pre>{out}</pre>
    </div>
  )
}
TSX

cat > src/pages/Metrics.tsx <<'TSX'
import React from 'react'
import { api } from '../api'

type Row = { name: string, value: number, labels?: Record<string,string> }

function parseProm(text: string): Row[] {
  const rows: Row[] = []
  for (const line of text.split('\n')) {
    const l = line.trim()
    if (!l || l.startsWith('#')) continue
    const space = l.lastIndexOf(' ')
    if (space < 0) continue
    const left = l.slice(0, space)
    const valStr = l.slice(space+1)
    const value = Number(valStr)
    if (Number.isNaN(value)) continue
    const brace = left.indexOf('{')
    if (brace === -1) {
      rows.push({ name: left, value })
    } else {
      const name = left.slice(0, brace)
      const labelsStr = left.slice(brace+1, left.length-1)
      const labels: Record<string,string> = {}
      for (const kv of labelsStr.split(',')) {
        if (!kv) continue
        const [k, v] = kv.split('=')
        if (!k || v === undefined) continue
        labels[k] = v.replace(/^"|"$/g,'')
      }
      rows.push({ name, value, labels })
    }
  }
  return rows
}

export default function Metrics() {
  const [rows, setRows] = React.useState<Row[]>([])
  const [error, setError] = React.useState<string>('')

  const load = async () => {
    setError('')
    try {
      const text = await api.metricsRaw()
      const parsed = parseProm(text).filter(r => r.name.startsWith('bfl_autopilot_'))
      setRows(parsed)
    } catch (e:any) {
      setError(e.message)
    }
  }

  React.useEffect(() => { load() }, [])

  return (
    <div className="card">
      <h2>Метрики Autopilot (Prometheus)</h2>
      <button onClick={load}>Обновить</button>
      {error && <p style={{color:'crimson'}}>Ошибка: {error}</p>}
      <div style={{marginTop:10}}>
        {rows.length === 0 ? <p>Нет метрик bfl_autopilot_* (выполни задачу, чтобы counters выросли).</p> :
          <table>
            <thead><tr><th>metric</th><th>labels</th><th>value</th></tr></thead>
            <tbody>
              {rows.map((r, i) => (
                <tr key={i}>
                  <td><code>{r.name}</code></td>
                  <td><code>{r.labels ? JSON.stringify(r.labels) : '-'}</code></td>
                  <td>{r.value}</td>
                </tr>
              ))}
            </tbody>
          </table>
        }
      </div>
      <p style={{opacity:.7, marginTop:8}}>Источник: <code>GET /metrics</code></p>
    </div>
  )
}
TSX

echo "==> Готово. Запуск dev-сервера:"
echo "   cd $UI_DIR && npm run dev"
echo "-> Открой: http://127.0.0.1:5173/autopilot"
