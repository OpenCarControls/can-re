import { useState, useEffect } from 'react'
import { Button, Container, Typography, Paper, CircularProgress, Box } from '@mui/material'

interface VersionInfo {
  version: string;
  hash: string;
}

declare global {
  interface Window {
    pywebview?: any;
    loadPyodide?: any;
  }
}

function App() {
  const [status, setStatus] = useState<string>('Initializing...')
  const [isDesktop, setIsDesktop] = useState<boolean>(false)
  const [pyResponse, setPyResponse] = useState<string>('')
  const [pyodide, setPyodide] = useState<any>(null)
  const [versionInfo, setVersionInfo] = useState<VersionInfo | null>(null)

  useEffect(() => {
    fetch('./version.json')
      .then(res => res.json())
      .then(data => {
        setVersionInfo(data);
        document.title = `CAN-RE v${data.version} (${data.hash})`;
      })
      .catch(() => {
        document.title = 'CAN-RE (dev)';
      });

    const init = async () => {
      // Check for PyWebView (Desktop Mode)
      if (window.pywebview) {
        setIsDesktop(true)
        setStatus('Connected to Python Backend (Desktop Mode)')
        return;
      }

      // Check for Pyodide (Web Mode)
      if (window.loadPyodide) {
        setIsDesktop(false)
        setStatus('Loading Pyodide WebAssembly...')
        try {
          const loadedPyodide = await window.loadPyodide();
          await loadedPyodide.loadPackage("micropip");
          const micropip = loadedPyodide.pyimport("micropip");
          const wheelsReq = await fetch('./wheels/wheels.json');
          const wheelsList = await wheelsReq.json();
          await micropip.install(wheelsList);
          setPyodide(loadedPyodide);
          setStatus('Pyodide Loaded! (Web Mode)')
        } catch (e) {
          console.error("Pyodide init error:", e);
          setStatus(`Failed to load Pyodide: ${String(e)}`);
        }
        return;
      }
      
      setStatus('Waiting for pywebview or pyodide...')
    }

    // pywebview might take a moment to be injected
    window.addEventListener('pywebviewready', init)
    // Also try immediately
    init()

    return () => window.removeEventListener('pywebviewready', init)
  }, [])

  const handleTestBridge = async () => {
    if (isDesktop && window.pywebview?.api) {
      const response = await window.pywebview.api.hello_from_python("Hello from React!");
      setPyResponse(response)
    } else if (pyodide) {
      try {
        const response = await pyodide.runPythonAsync(`
from can_debug.main import Api
api = Api()
api.hello_from_python("Hello from React! (Web Mode)")
        `);
        setPyResponse(response);
      } catch (err) {
        setPyResponse(`Error running Python in Pyodide: ${err}`);
      }
    } else {
      setPyResponse("Pyodide not loaded yet.")
    }
  }

  return (
    <Container maxWidth="sm" sx={{ mt: 5 }}>
      <Paper elevation={3} sx={{ p: 4, textAlign: 'center' }}>
        <Typography variant="h4" gutterBottom>
          CAN AI Debugger
        </Typography>
        <Box sx={{ my: 3 }}>
          {status === 'Initializing...' || status.includes('Loading') ? (
            <CircularProgress />
          ) : null}
          <Typography variant="subtitle1" color="textSecondary" sx={{ mt: 2 }}>
            {status}
          </Typography>
        </Box>
        
        <Button 
          variant="contained" 
          color="primary" 
          onClick={handleTestBridge}
          disabled={!isDesktop && !status.includes('Loaded')}
        >
          Test Bridge
        </Button>

        {pyResponse && (
          <Typography variant="body1" sx={{ mt: 3, p: 2, bgcolor: '#f5f5f5', borderRadius: 1, color: '#333' }}>
            {pyResponse}
          </Typography>
        )}
      </Paper>
      
      {versionInfo && (
        <Typography 
          variant="caption" 
          sx={{ position: 'fixed', bottom: 8, right: 16, color: 'text.disabled' }}
        >
          v{versionInfo.version} ({versionInfo.hash})
        </Typography>
      )}
    </Container>
  )
}

export default App
