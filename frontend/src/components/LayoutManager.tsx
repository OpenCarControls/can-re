import { useState, useEffect } from 'react';
import { Model, Layout, TabNode, Actions } from 'flexlayout-react';
import type { IJsonModel } from 'flexlayout-react';
import { getApi } from '../api';
import 'flexlayout-react/style/dark.css';
import './flexlayout-mui.css';
import { Box, GlobalStyles, useTheme, alpha } from '@mui/material';
import CloseIcon from '@mui/icons-material/Close';
import CropSquareIcon from '@mui/icons-material/CropSquare';
import FilterNoneIcon from '@mui/icons-material/FilterNone';
import MoreVertIcon from '@mui/icons-material/MoreVert';
import PushPinIcon from '@mui/icons-material/PushPin';

import { Toolbar } from './Toolbar';
import { WorkspaceWizardBanner } from './WorkspaceWizardBanner';
import { PanelRegistry } from './layout/PanelRegistry';
import { LayoutProvider } from '../context/LayoutContext';




const FlexLayoutStyles = () => {
  const theme = useTheme();

  return (
    <GlobalStyles styles={{
      '.flexlayout__layout': {
        '--font-family': theme.typography.fontFamily,
        '--color-background': theme.palette.background.default,
        '--color-base': theme.palette.background.default,
        '--color-tabset-background': theme.palette.background.default,
        '--color-tabset-background-selected': theme.palette.background.default,
        '--color-tab-content': theme.palette.background.paper,
        '--color-text': theme.palette.text.primary,
        '--color-tab-selected': theme.palette.primary.main,
        '--color-tab-selected-background': 'transparent',
        '--color-tab-unselected': theme.palette.text.secondary,
        '--color-tab-unselected-background': 'transparent',
        '--color-splitter': theme.palette.background.default,
        '--color-splitter-hover': theme.palette.action.hover,
        '--color-splitter-drag': theme.palette.primary.main,
        '--color-tabset-divider-line': theme.palette.divider,
        '--color-border-divider-line': theme.palette.divider,
        '--color-drag1': theme.palette.primary.main,
        '--color-drag2': theme.palette.primary.main,
        '--color-drag1-background': alpha(theme.palette.primary.main, 0.15),
        '--color-drag2-background': alpha(theme.palette.primary.main, 0.15),
        '--color-icon': theme.palette.text.secondary,
        '--color-focus': alpha(theme.palette.primary.main, 0.5),
      },
      '.flexlayout__tabset-selected': {
        backgroundImage: 'none !important',
      },
      '.flexlayout__tabset-selected::after': {
        content: '""',
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        pointerEvents: 'none',
        boxShadow: `inset 0 0 0 1px ${alpha(theme.palette.primary.main, 0.5)}`,
        zIndex: 10,
      },
      '.flexlayout__tabset-maximized': {
        backgroundImage: 'none !important',
      },
      '.flexlayout__tab_button--selected': {
        borderBottom: `2px solid ${theme.palette.primary.main} !important`,
      },
      '.flexlayout__tab_button:hover': {
        backgroundColor: theme.palette.action.hover,
        color: theme.palette.text.primary,
      },
      '.flexlayout__tabset_tabbar_outer': {
        borderBottom: `1px solid ${theme.palette.divider}`,
        backgroundColor: `${theme.palette.background.default} !important`,
      },
      '.flexlayout__tab_button_trailing:hover': {
        backgroundColor: theme.palette.action.hover,
      },
      '.flexlayout__tab_toolbar_button, .flexlayout__tab_button_trailing': {
        color: theme.palette.text.secondary,
      }
    }} />
  );
};

const defaultLayout: IJsonModel = {
  global: {
    tabEnableClose: true,
    tabSetEnableMaximize: true,
  },
  borders: [],
  layout: {
    type: "row",
    weight: 100,
    children: [
      {
        type: "tabset",
        weight: 100,
        id: "primary",
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
        id: "secondary",
        children: [
          {
            type: "tab",
            name: "Frame Details",
            component: "frameDetails",
            id: "frameDetailsTab"
          }
        ]
      }
    ]
  }
};

const PanelWrapper = ({ node, config }: { node: TabNode, config: any }) => {
  useEffect(() => {
    if (node.getName() !== config.name) {
      node.getModel().doAction(Actions.renameTab(node.getId(), config.name));
    }
  }, [node, config.name]);

  const Component = config.component;
  return <Component node={node} />;
};

export const LayoutManager = () => {
  const [model, setModel] = useState<Model | null>(null);

  useEffect(() => {
    const loadSettings = async () => {
      try {
        const savedLayout = await getApi().get_settings('core.layout');
        if (savedLayout) {
          setModel(Model.fromJson(savedLayout));
          return;
        }
      } catch (e) {
        console.warn("Failed to load layout from API:", e);
      }
      setModel(Model.fromJson(defaultLayout));
    };
    loadSettings();
  }, []);

  const factory = (node: TabNode) => {
    const componentId = node.getComponent();
    if (!componentId) return null;

    const config = PanelRegistry.getPanel(componentId);
    if (config) {
      return <PanelWrapper node={node} config={config} />;
    }
    return null;
  };

  const onModelChange = (newModel: Model) => {
    try {
      getApi().set_settings('core.layout', newModel.toJson());
    } catch (e) {
      console.error("Failed to save layout via API:", e);
    }
  };

  if (!model) {
    return null;
  }

  return (
    <LayoutProvider model={model}>
      <FlexLayoutStyles />
      <Box sx={{ display: 'flex', flexDirection: 'column', height: '100vh', width: '100vw' }}>
        <WorkspaceWizardBanner />
        {/* Toolbar area */}
        <Box sx={{ height: 48, flexShrink: 0, bgcolor: 'background.default', borderBottom: 1, borderColor: 'divider' }}>
          <Toolbar />
        </Box>

        {/* Main layout area */}
        <Box sx={{ flexGrow: 1, position: 'relative' }}>
          <Layout
            model={model}
            factory={factory}
            onModelChange={onModelChange}
            icons={{
              close: <CloseIcon sx={{ fontSize: 18 }} />,
              closeTabset: <CloseIcon sx={{ fontSize: 18 }} />,
              maximize: <CropSquareIcon sx={{ fontSize: 18 }} />,
              restore: <FilterNoneIcon sx={{ fontSize: 18 }} />,
              more: <MoreVertIcon sx={{ fontSize: 18 }} />,
              pin: <PushPinIcon sx={{ fontSize: 18 }} />
            }}
          />
        </Box>
      </Box>
    </LayoutProvider>
  );
};
