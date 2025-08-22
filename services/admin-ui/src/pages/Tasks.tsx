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
