#!/usr/bin/env bash
set -euo pipefail
cd ~/bfl-onprem

# === UI: кнопка и страница Autopilot ===
mkdir -p services/admin-ui/src/{components,pages}
cat > services/admin-ui/src/components/RunWithAutopilotButton.tsx <<'TS'
import React,{useState}from"react"
export default function RunWithAutopilotButton({type,payload={},label="Run with Autopilot"}:{type:string,payload?:Record<string,any>,label?:string}){const[l,s]=useState(false);const run=async()=>{try{s(true);const r=await fetch("/api/admin/autopilot/tasks",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({type,payload})});if(!r.ok)throw new Error(await r.text());const d=await r.json();alert("Queued: "+d.id)}catch(e:any){alert("Failed: "+String(e))}finally{s(false)}};return <button onClick={run} disabled={l} style={{padding:"8px 12px",borderRadius:8,border:"1px solid #ccc"}}>{l?"Queuing…":label}</button>}
TS

cat > services/admin-ui/src/pages/Autopilot.tsx <<'TS'
import React,{useEffect,useState}from"react"
import RunWithAutopilotButton from "../components/RunWithAutopilotButton"
export default function AutopilotPage(){const[t,setT]=useState<Record<string,string>>({});useEffect(()=>{fetch("/api/admin/autopilot/types").then(r=>r.json()).then(setT).catch(()=>setT({}))},[]);return <div style={{padding:24}}>
  <h1>Autopilot</h1>
  <div style={{display:"grid",gap:12,gridTemplateColumns:"repeat(auto-fill,minmax(280px,1fr))"}}>
    {Object.entries(t).map(([k,v])=>(
      <div key={k} style={{border:"1px solid #eee",borderRadius:12,padding:12}}>
        <div style={{fontWeight:600}}>{k}</div>
        <div style={{fontSize:12,opacity:0.7,margin:"4px 0 8px"}}>{v||"—"}</div>
        <RunWithAutopilotButton type={k} payload={k==="k6_smokes"?{base_url:"http://localhost:8000"}:{}} label="Запустить"/>
      </div>
    ))}
  </div>
</div>}
TS

cat > services/admin-ui/src/App.tsx <<'TS'
import React from "react"
import { BrowserRouter, Routes, Route, Link } from "react-router-dom"
import Autopilot from "./pages/Autopilot"
function Home(){return <div style={{padding:24}}><h1>BFL Admin</h1><p><Link to="/autopilot">Autopilot</Link></p></div>}
export default function App(){return <BrowserRouter><Routes><Route path="/" element={<Home/>}/><Route path="/autopilot" element={<Autopilot/>}/></Routes></BrowserRouter>}
TS

cat > services/admin-ui/src/main.tsx <<'TS'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><App/></React.StrictMode>)
TS

# === Makefile, .env, venv, инфра ===
cat > Makefile <<'MK'
SHELL := /bin/bash
COMPOSE_FILE ?= docker-compose.infra.yml
API_MODULE   ?= services.api.main:app
API_PORT     ?= 8000
UI_DIR       ?= services/admin-ui
.PHONY: infra infra-down api worker ui smoke-noop smoke-k6
infra: ; docker compose -f $(COMPOSE_FILE) up -d
infra-down: ; docker compose -f $(COMPOSE_FILE) down
api: ; uvicorn $(API_MODULE) --host 127.0.0.1 --port $(API_PORT)
worker: ; python -m services.workers.autopilot_runner
ui: ; cd $(UI_DIR) && (pnpm i || npm i) && (pnpm dev --host 127.0.0.1 || npm run dev -- --host 127.0.0.1)
smoke-noop: ; curl -s -X POST http://localhost:$(API_PORT)/api/admin/autopilot/tasks -H 'Content-Type: application/json' -d '{"type":"noop","payload":{}}' | jq -r '.id' || true
smoke-k6: ; curl -s -X POST http://localhost:$(API_PORT)/api/admin/autopilot/tasks -H 'Content-Type: application/json' -d '{"type":"k6_smokes","payload":{"base_url":"http://localhost:$(API_PORT)"}}' | jq -r '.id' || true
MK

cat > .env.local <<'ENV'
ALERTMANAGER_BASE_URL=http://localhost:9093
REDIS_URL=redis://localhost:6379
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
GRAFANA_BASE_URL=http://localhost:3000
ENV

# venv + зависимости
python3 -m venv .venv
source .venv/bin/activate
pip -q install --upgrade pip
test -f requirements.txt || cat > requirements.txt <<'REQ'
fastapi
uvicorn[standard]
prometheus-client
httpx
redis
pytest
REQ
pip -q install -r requirements.txt

# инфра (docker compose)
docker compose -f docker-compose.infra.yml up -d || true

echo "== OK. Дальше в 3 вкладках =="
echo "A) source .venv/bin/activate && uvicorn services.api.main:app --host 127.0.0.1 --port 8000"
echo "B) source .venv/bin/activate && python -m services.workers.autopilot_runner"
echo "C) cd services/admin-ui && (pnpm i || npm i) && (pnpm dev --host 127.0.0.1 || npm run dev -- --host 127.0.0.1)"
