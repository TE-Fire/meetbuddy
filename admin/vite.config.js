import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// 管理端开发服务：同源跑在 5173，/api 与 /admin 由下面的代理转发到本地后端 8099，
// 避免跨域，也免去后端反复改 CORS。后端端口以 MEETBUDDY_SERVER_PORT 为准（默认 8099）。
export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    proxy: {
      '/api': { target: 'http://localhost:8099', changeOrigin: true },
      '/admin': { target: 'http://localhost:8099', changeOrigin: true }
    }
  },
  build: { outDir: 'dist' }
})
