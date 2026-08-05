import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  define: {
    'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV || 'production')
  },
  build: {
    lib: {
      entry: resolve(__dirname, 'src/index.tsx'),
      name: 'DbcParserPlugin',
      formats: ['umd'],
      fileName: () => 'bundle.js',
    },
    outDir: 'dist',
    emptyOutDir: true,
    rollupOptions: {
      external: ['react', 'react-dom', 'react-dom/client', 'react/jsx-runtime', '@mui/material', '@mui/icons-material', '@emotion/react', '@emotion/styled', 'flexlayout-react'],
      output: {
        globals: {
          react: 'React',
          'react-dom': 'ReactDOM',
          'react-dom/client': 'ReactDOMClient',
          'react/jsx-runtime': 'ReactJsxRuntime',
          '@mui/material': 'MuiMaterial',
          '@mui/icons-material': 'MuiIconsMaterial',
          '@emotion/react': 'EmotionReact',
          '@emotion/styled': 'EmotionStyled',
          'flexlayout-react': 'FlexLayout'
        }
      }
    }
  }
});
