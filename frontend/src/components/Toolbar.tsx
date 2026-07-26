import { AppBar, Toolbar as MuiToolbar, Button, Typography } from '@mui/material';
import FolderOpenIcon from '@mui/icons-material/FolderOpen';
import StorageIcon from '@mui/icons-material/Storage';
import { getApi } from '../api';
import { useState } from 'react';

export const Toolbar = () => {
  const [dbcName, setDbcName] = useState<string | null>(null);
  const [logName, setLogName] = useState<string | null>(null);

  const handleDbcLoad = async () => {
    try {
      const res = await getApi().call_service('core.load_dbc');
      if (res && res.success) {
        setDbcName(res.file);
        window.dispatchEvent(new CustomEvent('dbcLoaded'));
      } else if (res && res.error) {
        alert("Error loading DBC: " + res.error);
      }
    } catch (e) {
      console.error(e);
      alert("Failed to load DBC");
    }
  };

  const handleLogLoad = async () => {
    try {
      const res = await getApi().call_service('core.load_log');
      if (res && res.success) {
        setLogName(res.file);
        window.dispatchEvent(new CustomEvent('logLoaded', { detail: { count: res.total_count } }));
      } else if (res && res.error) {
        alert("Error loading Log: " + res.error);
      }
    } catch (e) {
      console.error(e);
      alert("Failed to load Log");
    }
  };

  return (
    <AppBar position="static" color="transparent" elevation={0} sx={{ height: 48, justifyContent: 'center' }}>
      <MuiToolbar variant="dense" sx={{ gap: 2 }}>
        
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
      </MuiToolbar>
    </AppBar>
  );
};
