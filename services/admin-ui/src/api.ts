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
