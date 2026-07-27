import { useState, useEffect, useRef } from 'react'
import { CircularProgress, Box, Typography } from '@mui/material'
import { initApi, getApi } from './api'
import { ThemeProvider, createTheme, CssBaseline } from '@mui/material'
import { loadActivePlugins } from './pluginLoader'
import { LayoutManager } from './components/LayoutManager'

declare global {
  interface Window {
    pywebview?: any;
    loadPyodide?: any;
    api?: any;
    __pyodide_api?: any;
    webFileProxy?: any;
    React?: any;
    ReactDOM?: any;
    MuiMaterial?: any;
    EmotionReact?: any;
    EmotionStyled?: any;
    FlexLayout?: any;
  }
}

const darkTheme = createTheme({
  palette: {
    mode: 'dark',
    primary: {
      main: '#1976d2', // Customize to fit IDE look
    },
    background: {
      default: '#1e1e1e', // VS Code dark default
      paper: '#252526' // VS Code dark paper
    }
  },
  typography: {
    fontFamily: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif',
  },
  components: {
    MuiButton: { defaultProps: { size: 'small' } },
    MuiTextField: { defaultProps: { size: 'small', margin: 'dense' } },
    MuiFormControl: { defaultProps: { size: 'small', margin: 'dense' } },
    MuiList: { defaultProps: { dense: true } },
    MuiMenuItem: { defaultProps: { dense: true } },
    MuiTable: { defaultProps: { size: 'small' } },
    MuiIconButton: { defaultProps: { size: 'small' } },
  }
});

function App() {
  const [status, setStatus] = useState<string>('Initializing...')
  const [isReady, setIsReady] = useState<boolean>(false)

  const isInitializing = useRef(false);

  useEffect(() => {
    if (isInitializing.current) return;
    isInitializing.current = true;

    fetch('./version.json')
      .then(res => res.json())
      .then(data => {
        document.title = `CAN-RE v${data.version} (${data.hash})`;
      })
      .catch(() => {
        document.title = 'CAN-RE (dev)';
      });

    const init = async () => {
      if (window.pywebview) {
        initApi(window.pywebview, null);
        const api = getApi();
        
        setStatus('Installing plugin dependencies...')
        await api.install_desktop_dependencies();
        
        setStatus('Loading plugins...')
        await api.load_plugin_backends();
        await loadActivePlugins()
        setStatus('Connected to Python Backend (Desktop Mode)')
        setIsReady(true)
        return;
      }

      // Check for Pyodide (Web Mode)
      if (window.loadPyodide) {
        setStatus('Loading Pyodide WebAssembly...')
        try {
          const loadedPyodide = await window.loadPyodide();
          await loadedPyodide.loadPackage("micropip");
          await loadedPyodide.loadPackage("sqlite3");
          const micropip = loadedPyodide.pyimport("micropip");
          const wheelsReq = await fetch('./wheels/wheels.json');
          const wheelsList = await wheelsReq.json();
          await micropip.install(wheelsList);
          
          initApi(null, loadedPyodide);
          const api = getApi();
          
          setStatus('Resolving plugin dependencies...');
          const deps = await api.get_python_dependencies();
          if (deps && deps.length > 0) {
            await micropip.install(deps);
          }
          
          setStatus('Loading plugins...')
          await api.load_plugin_backends();
          await loadActivePlugins()
          
          setStatus('Pyodide Loaded! (Web Mode)')
          setIsReady(true)
        } catch (e) {
          console.error("Pyodide init error:", e);
          setStatus(`Failed to load Pyodide: ${String(e)}`);
        }
        return;
      }

      setStatus('Waiting for pywebview or pyodide...')
    }

    window.addEventListener('pywebviewready', init)
    init()

    return () => window.removeEventListener('pywebviewready', init)
  }, [])

  if (!isReady) {
    return (
      <ThemeProvider theme={darkTheme}>
        <CssBaseline />
        <Box sx={{ display: 'flex', flexDirection: 'column', height: '100vh', justifyContent: 'center', alignItems: 'center' }}>
          <CircularProgress />
          <Typography sx={{ mt: 2 }} color="textSecondary">{status}</Typography>
        </Box>
      </ThemeProvider>
    )
  }

  return (
    <ThemeProvider theme={darkTheme}>
      <CssBaseline />
      <LayoutManager />
    </ThemeProvider>
  )
}

export default App
