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
