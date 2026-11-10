import { defineConfig } from 'vite';

export default defineConfig({
  base: './',
  cacheDir: '.dev/cache/vite',
  server: { host: '127.0.0.1', port: 5173, strictPort: true },
  build: { outDir: 'dist', target: 'es2022' },
});
