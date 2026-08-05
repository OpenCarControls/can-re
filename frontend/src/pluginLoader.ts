import { getApi } from './api';
import { PanelRegistry } from './components/layout/PanelRegistry';
import { ToolbarRegistry } from './components/ToolbarRegistry';

// Expose ToolbarRegistry globally for the UMD wrapper to access
(window as any).ToolbarRegistry = ToolbarRegistry;

export async function loadActivePlugins() {
    try {
        const api = getApi();
        const activePlugins = await api.get_active_plugins();
        
        for (const pluginInfo of activePlugins) {
            console.log(`Loading plugin ${pluginInfo.name} (${pluginInfo.id})...`);
            try {
                if (import.meta.env.DEV && pluginInfo.id === 'org.opencarcontrols.can-viewer') {
                    // Dev mode HMR for the can-viewer plugin
                    const corePlugin = await import('../../plugins/can-viewer/frontend/src/index.ts');
                    corePlugin.setup({ 
                        registerPanel: PanelRegistry.register.bind(PanelRegistry), 
                        registerToolbarAction: (window as any).ToolbarRegistry.register.bind((window as any).ToolbarRegistry),
                        unregisterToolbarAction: (window as any).ToolbarRegistry.unregister.bind((window as any).ToolbarRegistry),
                        api 
                    });
                    console.log(`Successfully loaded frontend for plugin ${pluginInfo.name}`);
                    continue;
                }

                // Fetch JS bundle content from backend
                const bundleStr = await api.get_plugin_bundle(pluginInfo.id);
                if (!bundleStr) {
                    console.warn(`No frontend bundle found for ${pluginInfo.id}`);
                    continue;
                }
                
                // Simulate a CommonJS environment to safely evaluate the UMD bundle
                const module = { exports: {} as any };
                const requireFn = (id: string) => {
                    if (id === 'react') return (window as any).React;
                    if (id === 'react-dom') return (window as any).ReactDOM;
                    if (id === 'react-dom/client') return (window as any).ReactDOMClient;
                    if (id === 'react/jsx-runtime') return (window as any).ReactJsxRuntime;
                    if (id === '@mui/material') return (window as any).MuiMaterial;
                    if (id === '@mui/icons-material') return (window as any).MuiIconsMaterial;
                    if (id === '@emotion/react') return (window as any).EmotionReact;
                    if (id === '@emotion/styled') return (window as any).EmotionStyled;
                    if (id === 'flexlayout-react') return (window as any).FlexLayout;
                    throw new Error(`Plugin required unknown module: ${id}`);
                };

                const executePlugin = new Function('module', 'exports', 'require', bundleStr);
                executePlugin(module, module.exports, requireFn);
                
                const pluginModule = module.exports;
                
                if (typeof pluginModule.setup === 'function') {
                    pluginModule.setup({ 
                        registerPanel: PanelRegistry.register.bind(PanelRegistry),
                        registerToolbarAction: (window as any).ToolbarRegistry.register.bind((window as any).ToolbarRegistry),
                        unregisterToolbarAction: (window as any).ToolbarRegistry.unregister.bind((window as any).ToolbarRegistry),
                        api 
                    });
                    console.log(`Successfully loaded frontend for plugin ${pluginInfo.name}`);
                } else {
                    console.warn(`Plugin ${pluginInfo.id} has no frontend setup() function.`);
                }
            } catch (e) {
                console.error(`Failed to load frontend for plugin ${pluginInfo.id}:`, e);
            }
        }
    } catch (e) {
        console.error("Failed to fetch active plugins:", e);
    }
}
