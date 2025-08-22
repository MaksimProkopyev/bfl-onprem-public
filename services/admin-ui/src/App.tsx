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
