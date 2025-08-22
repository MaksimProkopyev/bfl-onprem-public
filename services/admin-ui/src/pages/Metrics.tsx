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
