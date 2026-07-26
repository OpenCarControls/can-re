import React, { createContext, useContext } from 'react';
import { Model, Actions, DockLocation } from 'flexlayout-react';
import { PanelRegistry } from '../components/layout/PanelRegistry';

interface LayoutContextValue {
  model: Model | null;
  openPanel: (panelId: string) => void;
}

export const LayoutContext = createContext<LayoutContextValue>({
  model: null,
  openPanel: () => {
    console.warn("LayoutContext is not initialized");
  }
});

export const useLayout = () => useContext(LayoutContext);

interface LayoutProviderProps {
  model: Model | null;
  children: React.ReactNode;
}

export const LayoutProvider: React.FC<LayoutProviderProps> = ({ model, children }) => {
  const openPanel = (panelId: string) => {
    if (!model) return;

    const config = PanelRegistry.getPanel(panelId);
    if (!config) {
      console.error(`Panel configuration for "${panelId}" not found in registry.`);
      return;
    }

    // Check if it's already open and allowMultiple is false/undefined
    if (!config.allowMultiple) {
      // Find anywhere in the model:
      let foundNode = null;
      model.visitNodes((node) => {
        if (node.getType() === 'tab' && (node as any).getComponent() === panelId) {
          foundNode = node;
        }
      });

      if (foundNode) {
        model.doAction(Actions.selectTab((foundNode as any).getId()));
        return;
      }
    }

    // Determine target zone
    const targetZoneId = config.defaultZone;

    model.doAction(Actions.addNode({
      type: 'tab',
      component: config.id,
      name: config.name,
      id: config.allowMultiple ? undefined : config.id,
    }, targetZoneId, DockLocation.CENTER, -1));
  };

  return (
    <LayoutContext.Provider value={{ model, openPanel }}>
      {children}
    </LayoutContext.Provider>
  );
};
