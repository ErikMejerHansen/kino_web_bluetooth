/// <reference types="vitest" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: "../assets",
    rollupOptions: {
      preserveEntrySignatures: 'exports-only',
      input: {
        dev: 'index.html',
        main: 'src/main.tsx'
      },
      output: {
        entryFileNames: `[name].js`,
        chunkFileNames: `[name].js`,
        assetFileNames: `[name].[ext]`
      }
    }
  },
  test: {
    // TODO: Try happy-dom, see it it's faster
    environment: 'jsdom',
    globals: true,
    setupFiles: './test-setup.ts'
  }
})
