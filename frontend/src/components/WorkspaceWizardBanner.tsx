import React, { useState, useEffect } from 'react';
import { Box, Typography, Button, Paper } from '@mui/material';
import FolderOpenIcon from '@mui/icons-material/FolderOpen';
import { getMode } from '../api';

export const WorkspaceWizardBanner: React.FC = () => {
  const [showBanner, setShowBanner] = useState(false);
  const [isSupported, setIsSupported] = useState(true);

  useEffect(() => {
    // Only show the wizard if we're in the web environment
    if (getMode() === 'web') {
      // Check if a workspace is already configured (this would be checked in settings in the future)
      const workspaceConfigured = false; // TODO: read from local storage or settings
      if (!workspaceConfigured) {
        setShowBanner(true);
      }

      // Check if File System Access API is supported
      if (!('showDirectoryPicker' in window)) {
        setIsSupported(false);
      }
    }
  }, []);

  const handleSetupWorkspace = async () => {
    if (!isSupported) return;

    try {
      const dirHandle = await (window as any).showDirectoryPicker();
      
      // In the future:
      // 1. Sync dirHandle files into Pyodide virtual file system
      // 2. Call backend api.discover_web_plugins('/mounted_path')
      // 3. Save the dirHandle to IndexedDB for persistent access
      
      console.log('Workspace mounted:', dirHandle.name);
      
      // Hide banner on success
      setShowBanner(false);
    } catch (err) {
      console.error('Failed to setup workspace:', err);
    }
  };

  if (!showBanner) return null;

  return (
    <Paper 
      elevation={0}
      sx={{ 
        p: 1.5, 
        bgcolor: 'primary.dark', 
        color: 'white',
        display: 'flex', 
        alignItems: 'center', 
        justifyContent: 'space-between',
        borderRadius: 0,
        zIndex: 1000
      }}
    >
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
        <FolderOpenIcon />
        <Box>
          <Typography variant="subtitle2" sx={{ fontWeight: 'bold' }}>
            Workspace Not Configured
          </Typography>
          <Typography variant="body2" sx={{ opacity: 0.8 }}>
            {isSupported 
              ? 'Select a local folder to store your settings, projects, and third-party plugins.'
              : 'Your browser does not support the File System Access API (or it is disabled by privacy shields in browsers like Brave). Please use Chrome, Edge, or Opera to load local plugins and projects.'}
          </Typography>
        </Box>
      </Box>
      {isSupported && (
        <Button 
          variant="contained" 
          color="inherit" 
          size="small"
          onClick={handleSetupWorkspace}
          sx={{ color: 'primary.main', fontWeight: 'bold' }}
        >
          Setup Workspace
        </Button>
      )}
    </Paper>
  );
};
