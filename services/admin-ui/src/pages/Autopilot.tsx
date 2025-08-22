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
