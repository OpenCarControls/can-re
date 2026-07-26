import React from 'react';

export interface PanelConfig {
  id: string;
  name: string;
  component: React.ComponentType<any>;
  defaultZone: 'primary' | 'secondary';
  allowMultiple?: boolean;
}

class Registry {
  private panels: Map<string, PanelConfig> = new Map();

  register(config: PanelConfig) {
    if (this.panels.has(config.id)) {
      console.warn(`Panel with id ${config.id} is already registered. Overwriting.`);
    }
    this.panels.set(config.id, config);
  }

  getPanel(id: string): PanelConfig | undefined {
    return this.panels.get(id);
  }

  getAllPanels(): PanelConfig[] {
    return Array.from(this.panels.values());
  }
}

export const PanelRegistry = new Registry();
