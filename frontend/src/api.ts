export interface ApiClient {
  prompt_load_dbc: () => Promise<any>;
  prompt_load_log: () => Promise<any>;
  load_dbc_from_buffer: (content: string, filename: string) => Promise<any>;
  load_log_from_buffer: (buffer: string, filename: string) => Promise<any>;
  get_log_chunk: (start: number, length: number, reverse: boolean) => Promise<any[]>;
}

class WebApiClient implements ApiClient {
  private pyodide: any;

  constructor(pyodide: any) {
    this.pyodide = pyodide;
    // Initialize the global api instance in Python
    this.pyodide.runPython(`
from can_re.main import Api
import json
global_api = Api()
    `);
  }

  private async runMethod(method: string, args: any[]) {
    // For Pyodide, we pass arguments by converting them to JSON and back, or using pyodide globals
    const argsJson = JSON.stringify(args);
    const callId = `_pyodide_args_${Math.random().toString(36).substring(2)}`;
    (window as any)[callId] = argsJson;
    const code = `
import json
import js
args = json.loads(getattr(js, "${callId}"))
res = global_api.${method}(*args)
json.dumps(res)
    `;
    let resStr;
    try {
      resStr = await this.pyodide.runPythonAsync(code);
    } finally {
      delete (window as any)[callId];
    }
    return JSON.parse(resStr);
  }

  async prompt_load_dbc() {
    return { error: "Native dialogs not supported in web mode" };
  }

  async prompt_load_log() {
    return { error: "Native dialogs not supported in web mode" };
  }

  async load_dbc_from_buffer(content: string, filename: string) {
    return this.runMethod("load_dbc_from_buffer", [content, filename]);
  }

  async load_log_from_buffer(buffer: string, filename: string) {
    return this.runMethod("load_log_from_buffer", [buffer, filename]);
  }

  async get_log_chunk(start: number, length: number, reverse: boolean) {
    return this.runMethod("get_log_chunk", [start, length, reverse]);
  }
}

class DesktopApiClient implements ApiClient {
  private api: any;
  constructor(api: any) {
    this.api = api;
  }

  async prompt_load_dbc() {
    return this.api.prompt_load_dbc();
  }

  async prompt_load_log() {
    return this.api.prompt_load_log();
  }

  async load_dbc_from_buffer(content: string, filename: string) {
    return this.api.load_dbc_from_buffer(content, filename);
  }

  async load_log_from_buffer(buffer: string, filename: string) {
    return this.api.load_log_from_buffer(buffer, filename);
  }

  async get_log_chunk(start: number, length: number, reverse: boolean) {
    return this.api.get_log_chunk(start, length, reverse);
  }
}

let instance: ApiClient | null = null;
let mode: 'desktop' | 'web' | null = null;

export const initApi = (pywebview: any, pyodide: any) => {
  if (pywebview && pywebview.api) {
    instance = new DesktopApiClient(pywebview.api);
    mode = 'desktop';
  } else if (pyodide) {
    instance = new WebApiClient(pyodide);
    mode = 'web';
  }
};

export const getApi = (): ApiClient => {
  if (!instance) {
    throw new Error("API not initialized");
  }
  return instance;
};

export const getMode = () => mode;
