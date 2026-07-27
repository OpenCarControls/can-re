#!/bin/bash
set -e

# Navigate to the project root regardless of where the script is called from
cd "$(dirname "$0")/.."

echo "Preparing plugins for wheel..."
rm -rf backend/plugins_dist
mkdir -p backend/plugins_dist

for plugin in plugins/*; do
  if [ -d "$plugin" ]; then
    plugin_name=$(basename "$plugin")
    echo "Packaging plugin: $plugin_name"
    mkdir -p backend/plugins_dist/$plugin_name
    cp $plugin/manifest.json backend/plugins_dist/$plugin_name/ 2>/dev/null || true
    
    if [ -d "$plugin/backend" ]; then
      cp -r $plugin/backend backend/plugins_dist/$plugin_name/
    fi
    
    if [ -d "$plugin/frontend/dist" ]; then
      mkdir -p backend/plugins_dist/$plugin_name/frontend
      cp -r $plugin/frontend/dist backend/plugins_dist/$plugin_name/frontend/
    fi
  fi
done

# Clean up pycache from copied plugins
find backend/plugins_dist -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find backend/plugins_dist -type f -name "*.pyc" -delete 2>/dev/null || true

echo "Building Python backend wheel..."
cd backend
uv build --wheel

echo "Copying wheel to frontend/public/wheels..."
mkdir -p ../frontend/public/wheels
rm -f ../frontend/public/wheels/*.whl
cp dist/*.whl ../frontend/public/wheels/

echo "Building pure python dependencies for Pyodide..."
rm -f ../frontend/public/wheels/bitstruct*.whl
# Force bitstruct to build as pure python instead of compiling C extensions
BITSTRUCT_EXT=0 uvx pip wheel bitstruct==8.19.0 --no-deps --no-binary bitstruct -w ../frontend/public/wheels/
# Rename to pure python wheel so Pyodide accepts it
mv ../frontend/public/wheels/bitstruct-8.19.0-*.whl ../frontend/public/wheels/bitstruct-8.19.0-py3-none-any.whl

echo "Generating wheels.json manifest..."
cd ../frontend/public/wheels
# Create a JSON array of all wheel paths
node -e 'console.log(JSON.stringify(require("fs").readdirSync(".").filter(f => f.endsWith(".whl")).map(f => "./wheels/" + f)))' > wheels.json

echo "Done!"
