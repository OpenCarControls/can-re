#!/bin/bash
set -e

# Navigate to the project root regardless of where the script is called from
cd "$(dirname "$0")/.."

echo "Building Python backend wheel..."
cd backend
uv build

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
