export interface ApiClient {
  load_dbc: () => Promise<any>;
  load_log: () => Promise<any>;
  get_log_chunk: (start: number, length: number, reverse: boolean) => Promise<any[]>;
  get_settings: (namespace: string) => Promise<any>;
  set_settings: (namespace: string, data: any) => Promise<any>;
  [key: string]: any; // Allow for dynamic plugin methods
}

let mode: 'desktop' | 'web' | null = null;

export const initApi = (pywebview: any, pyodide: any) => {
  if (pywebview && pywebview.api) {
    // pywebview natively returns Promises for all method calls
    window.api = pywebview.api;
    mode = 'desktop';
  } else if (pyodide) {
    // Web File Proxy for Pyodide
    window.webFileProxy = async (fileTypes: string[] | null) => {
      return new Promise((resolve) => {
        const input = document.createElement('input');
        input.type = 'file';
        
        // Simple mapping of file_types tuple to accept string if provided
        if (fileTypes && fileTypes.length > 0) {
          const acceptMatch = fileTypes[0].match(/\(([^)]+)\)/);
          if (acceptMatch) {
            input.accept = acceptMatch[1].replace(/\*/g, '').replace(/;/g, ',');
          }
        }

        input.onchange = async (e: any) => {
          const file = e.target?.files?.[0];
          if (file) {
            const buffer = await file.arrayBuffer();
            const uint8Array = new Uint8Array(buffer);
            resolve({ name: file.name, content: uint8Array });
          } else {
            resolve(null);
          }
        };
        
        input.oncancel = () => {
          resolve(null);
        };

        input.click();
      });
    };

    // Inject the Python API into window.__pyodide_api
    pyodide.runPython(`
from can_re.main import Api
import js
js.window.__pyodide_api = Api()
    `);

    const pyodideApi = window.__pyodide_api;

    // Create a Proxy to ensure all calls return Promises and convert to JS objects
    window.api = new Proxy({}, {
      get: (_, methodName: string) => {
        return async (...args: any[]) => {
          const pythonMethod = pyodideApi[methodName];
          if (!pythonMethod) {
            throw new Error(`Method ${methodName} not found on Python API`);
          }
          
          // Call Python method via Pyodide FFI
          let result;
          try {
              result = pythonMethod(...args);
          } catch (e: any) {
              console.error(`Error calling Python method ${methodName}:`, e);
              throw e;
          }
          
          // If the Python method is async, await it
          if (result && typeof result.then === 'function') {
              result = await result;
          }
          
          // Convert Pyodide proxies (dicts, lists) to native JS objects
          if (result && typeof result.toJs === 'function') {
            return result.toJs({ dict_converter: Object.fromEntries });
          }
          return result;
        };
      }
    });

    mode = 'web';
  }
};

export const getApi = (): ApiClient => {
  if (!window.api) {
    throw new Error("API not initialized");
  }
  return window.api as ApiClient;
};

export const getMode = () => mode;
