import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  base: './',
  plugins: [react()],
  server: {
    fs: {
      allow: ['..']
    }
  },
  resolve: {
    alias: {
      'react': '/workspaces/can-re/frontend/node_modules/react',
      'react-dom': '/workspaces/can-re/frontend/node_modules/react-dom',
      'react/jsx-runtime': '/workspaces/can-re/frontend/node_modules/react/jsx-runtime',
      '@mui/material': '/workspaces/can-re/frontend/node_modules/@mui/material',
      '@emotion/react': '/workspaces/can-re/frontend/node_modules/@emotion/react',
      '@emotion/styled': '/workspaces/can-re/frontend/node_modules/@emotion/styled'
    }
  }
})
