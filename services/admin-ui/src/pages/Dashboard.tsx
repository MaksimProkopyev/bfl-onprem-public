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
