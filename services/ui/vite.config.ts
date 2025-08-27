import { defineConfig, Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import fs from 'node:fs';
import path from 'node:path';

export default defineConfig(() => ({
  base: "/autopilot/",

  plugins: [react(), mountAtAutopilot()],

  server: {
    host: '127.0.0.1',
    port: 5174,
    strictPort: true,
    open: false,
    headers: { 'Cache-Control': 'no-store' },
    proxy: {
      '^/api': 'http://127.0.0.1:8000',
      '^/metrics': 'http://127.0.0.1:8000'
    }
  },

  preview: {
    host: '127.0.0.1',
    port: 5174,
    strictPort: true
  },

  build: {
    outDir: 'dist',
    sourcemap: true,
    emptyOutDir: false
  }
}));

function mountAtAutopilot(): Plugin {
  return {
    name: 'mount-at-autopilot',
    configureServer(server) {
      const root = server.config.root || process.cwd();
      const indexPath = path.resolve(root, 'index.html');

      server.middlewares.use(async (req, res, next) => {
        const url = new URL(req.url || '/', 'http://local');
        const p = url.pathname;

        // /autopilot -> 302 /autopilot/
        if (p === '/autopilot') {
          res.statusCode = 302;
          res.setHeader('Location', '/autopilot/');
          return res.end();
        }

        // Прод-ассеты не трогаем
        const isProdAsset =
          p.startsWith('/autopilot/assets/') ||
          /\.(js|mjs|css|map|json|png|jpg|jpeg|gif|svg|ico|txt|webp|woff2?|ttf)$/.test(p);

        // Dev служебные пути — переписываем в корень dev-сервера
        if (p.startsWith('/autopilot/@vite/')) {
          req.url = p.replace('/autopilot/@vite/', '/@vite/') + url.search;
          return next();
        }
        if (p.startsWith('/autopilot/@react-refresh')) {
          req.url = p.replace('/autopilot/@react-refresh', '/@react-refresh') + url.search;
          return next();
        }
        if (p.startsWith('/autopilot/src/')) {
          req.url = p.replace('/autopilot/', '/') + url.search;
          return next();
        }

        // Главный случай: любые SPA-пути под /autopilot/* отдаем index.html,
        // но пропускаем прод-ассеты и dev-служебные пути (выше уже обработали)
        if (p === '/autopilot/' || (p.startsWith('/autopilot/') && !isProdAsset)) {
          try {
            const raw = fs.readFileSync(indexPath, 'utf8');
            const html = await server.transformIndexHtml('/', raw);
            res.statusCode = 200;
            res.setHeader('Content-Type', 'text/html; charset=utf-8');
            return res.end(html);
          } catch (e) {
            // если что-то пошло не так — пусть дальше обрабатывает Vite
          }
        }

        return next();
      });
    }
  };
}
