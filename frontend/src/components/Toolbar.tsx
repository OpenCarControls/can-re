import { Box, Button, Typography } from '@mui/material';
import FolderOpenIcon from '@mui/icons-material/FolderOpen';
import StorageIcon from '@mui/icons-material/Storage';
import { getApi, getMode } from '../api';
import { useRef, useState } from 'react';

export const Toolbar = () => {
  const [dbcName, setDbcName] = useState<string | null>(null);
  const [logName, setLogName] = useState<string | null>(null);
  
  const dbcInputRef = useRef<HTMLInputElement>(null);
  const logInputRef = useRef<HTMLInputElement>(null);

  const handleDbcLoad = async () => {
    if (getMode() === 'desktop') {
      const res = await getApi().prompt_load_dbc();
      if (res.success) {
        setDbcName(res.file);
        window.dispatchEvent(new CustomEvent('dbcLoaded'));
      } else if (res.error) {
        alert("Error loading DBC: " + res.error);
      }
    } else {
      dbcInputRef.current?.click();
    }
  };

  const handleLogLoad = async () => {
    if (getMode() === 'desktop') {
      const res = await getApi().prompt_load_log();
      if (res.success) {
        setLogName(res.file);
        window.dispatchEvent(new CustomEvent('logLoaded', { detail: { count: res.total_count } }));
      } else if (res.error) {
        alert("Error loading Log: " + res.error);
      }
    } else {
      logInputRef.current?.click();
    }
  };

  const onWebFileChange = async (e: React.ChangeEvent<HTMLInputElement>, type: 'dbc' | 'log') => {
    const file = e.target.files?.[0];
    if (!file) return;

    try {
      if (type === 'dbc') {
        const text = await file.text();
        const res = await getApi().load_dbc_from_buffer(text, file.name);
        if (res.success) {
          setDbcName(res.file);
          window.dispatchEvent(new CustomEvent('dbcLoaded'));
        } else {
          alert("Error: " + res.error);
        }
      } else {
        // Logs can be binary, pass as text for now if it's asc, but we should handle buffer
        // Pyodide's runPython doesn't easily pass ArrayBuffer directly without some memory view tricks, 
        // passing as string might fail for binary BLF. We'll pass as string for text logs (asc, csv).
        // Since we didn't implement binary pass, we'll use text. 
        const text = await file.text();
        const res = await getApi().load_log_from_buffer(text, file.name);
        if (res.success) {
          setLogName(res.file);
          window.dispatchEvent(new CustomEvent('logLoaded', { detail: { count: res.total_count } }));
        } else {
          alert("Error: " + res.error);
        }
      }
    } catch (err) {
      console.error(err);
      alert("Failed to read file.");
    }
    
    // Clear the input
    if (e.target) {
      e.target.value = '';
    }
  };

  return (
    <Box sx={{ display: 'flex', alignItems: 'center', p: 1, gap: 2 }}>
      <input type="file" ref={dbcInputRef} style={{ display: 'none' }} accept=".dbc" onChange={(e) => onWebFileChange(e, 'dbc')} />
      <input type="file" ref={logInputRef} style={{ display: 'none' }} accept=".asc,.blf,.csv,.trc" onChange={(e) => onWebFileChange(e, 'log')} />
      
      <Button 
        variant="text" 
        size="small" 
        startIcon={<FolderOpenIcon />}
        onClick={handleDbcLoad}
        sx={{ color: 'text.secondary' }}
      >
        Load DBC
      </Button>
      {dbcName && <Typography variant="caption" color="primary">{dbcName}</Typography>}

      <Button 
        variant="text" 
        size="small" 
        startIcon={<StorageIcon />}
        onClick={handleLogLoad}
        sx={{ color: 'text.secondary' }}
      >
        Load Log
      </Button>
      {logName && <Typography variant="caption" color="primary">{logName}</Typography>}
    </Box>
  );
};
