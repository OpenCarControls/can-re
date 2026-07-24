import { useState } from 'react';
import { Model, Layout, TabNode } from 'flexlayout-react';
import type { IJsonModel } from 'flexlayout-react';
import 'flexlayout-react/style/dark.css'; // Use dark mode by default
import { Toolbar } from './Toolbar';
import { LogViewer } from './LogViewer';
import { Titlebar } from './Titlebar';
import { Box, Typography } from '@mui/material';

const defaultLayout: IJsonModel = {
  global: {
    tabEnableClose: false,
    tabSetEnableMaximize: false,
  },
  borders: [],
  layout: {
    type: "row",
    weight: 100,
    children: [
      {
        type: "tabset",
        weight: 100,
        id: "main",
        children: [
          {
            type: "tab",
            name: "CAN Log",
            component: "logViewer",
            id: "logViewerTab"
          }
        ]
      },
      {
        type: "tabset",
        weight: 30,
        id: "side",
        children: [
          {
            type: "tab",
            name: "Signal Details",
            component: "signalDetails"
          }
        ]
      }
    ]
  }
};

export const LayoutManager = () => {
  const [model] = useState(() => Model.fromJson(defaultLayout));

  const factory = (node: TabNode) => {
    const component = node.getComponent();
    if (component === "logViewer") {
      return <LogViewer />;
    }
    if (component === "signalDetails") {
      return (
        <Box sx={{ p: 2, height: '100%', overflow: 'auto', bgcolor: 'background.paper' }}>
          <Typography variant="body2" color="textSecondary">
            Select a CAN frame to view decoded signal details.
          </Typography>
        </Box>
      );
    }
    return null;
  };

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', height: '100vh', width: '100vw' }}>
      {/* Titlebar area */}
      <Titlebar />

      {/* Toolbar area */}
      <Box sx={{ height: 48, flexShrink: 0, bgcolor: 'background.default', borderBottom: 1, borderColor: 'divider' }}>
        <Toolbar />
      </Box>
      
      {/* Main layout area */}
      <Box sx={{ flexGrow: 1, position: 'relative' }}>
        <Layout 
          model={model} 
          factory={factory} 
        />
      </Box>
    </Box>
  );
};
