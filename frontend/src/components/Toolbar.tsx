import { AppBar, Toolbar as MuiToolbar, Button, Divider } from '@mui/material';
import { useState, useEffect } from 'react';
import { ToolbarRegistry, type ToolbarAction } from './ToolbarRegistry';

export const Toolbar = () => {
  const [actions, setActions] = useState<ToolbarAction[]>([]);

  useEffect(() => {
    const handleUpdate = () => {
      setActions(ToolbarRegistry.getActions());
    };
    
    window.addEventListener('toolbarUpdated', handleUpdate);
    handleUpdate(); // Initial load
    
    return () => window.removeEventListener('toolbarUpdated', handleUpdate);
  }, []);

  // Group actions for rendering dividers
  const groupedActions = actions.reduce((acc, action) => {
    if (!acc[action.group]) acc[action.group] = [];
    acc[action.group].push(action);
    return acc;
  }, {} as Record<string, ToolbarAction[]>);

  return (
    <AppBar position="static" color="transparent" elevation={0} sx={{ height: 48, justifyContent: 'center' }}>
      <MuiToolbar variant="dense" sx={{ gap: 2 }}>
        {Object.entries(groupedActions).map(([groupName, groupActions], index, array) => (
          <div key={groupName} style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            {groupActions.map(action => (
              <Button
                key={action.id}
                variant="text"
                size="small"
                startIcon={action.icon}
                onClick={action.onClick}
                sx={{ color: 'text.secondary' }}
              >
                {action.label}
              </Button>
            ))}
            {index < array.length - 1 && <Divider orientation="vertical" flexItem sx={{ my: 1 }} />}
          </div>
        ))}
      </MuiToolbar>
    </AppBar>
  );
};
