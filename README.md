# CAN Reverse Engineering app

CAN RE is a modern, web-technology-based UI for analyzing and interacting with CAN bus networks. It shares a single React codebase that operates in two environments:

- **Desktop Mode (Pro)**: A native OS executable wrapping a local Python backend (via PyWebView). It handles live hardware (SocketCAN), runs the MCP Server for AI integration, and natively loads Python plugins from the file system.
- **Web Mode (Lite)**: A zero-install website hosted on GitHub Pages. It runs a sandboxed WASM Python environment (via Pyodide) to parse static logs dragged and dropped by the user.

## Development Setup

This project requires Node.js (for the frontend) and `uv` (for the Python backend). Both are pre-configured if using the provided Dev Container.

### 1. Start the Frontend Server

The frontend is built with React and Vite. Start the Vite development server first:

```bash
cd frontend
npm install

# Build the python backend wheel for Pyodide (Web Mode)
npm run build:py

# Start the Vite development server
npm run dev
```

The React UI will run at `http://localhost:5173`. 
*(Note: Opening this URL directly in your browser will trigger Web Mode using Pyodide).*

### 2. Start the Desktop App (PyWebView)

To test the Desktop integration, the Python backend opens a native window pointing to your local Vite server (`localhost:5173`).

Open a new terminal and run:

```bash
cd backend

# Install dependencies, including desktop extras (pywebview, pyinstaller)
uv sync --extra desktop

# Launch the desktop app
uv run can-re
```

The desktop window will open, and the React UI will detect the native environment and initialize in **Desktop Mode**.

### FastMCP Server

The project includes an MCP (Model Context Protocol) server for AI integrations, located at `backend/src/can_re/mcp_server.py`.
