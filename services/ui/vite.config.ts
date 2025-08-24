import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: '/autopilot/',
  server: {
    host: '127.0.0.1',
    port: 5174,
    strictPort: true,
    proxy: {
      '/api': 'http://127.0.0.1:8000',
      '/metrics': 'http://127.0.0.1:8000'
    }
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true
  }
})
