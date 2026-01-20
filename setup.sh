#!/usr/bin/env bash
# =============================================================================
# MCP Instructions Server - Setup Script
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================"
echo "MCP Instructions Server - Setup"
echo "============================================"

# Find Python 3.10+
find_python() {
    for py in python3.12 python3.11 python3.10 python3; do
        if command -v "$py" &>/dev/null; then
            version=$("$py" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
            major=$(echo "$version" | cut -d. -f1)
            minor=$(echo "$version" | cut -d. -f2)
            if [ "$major" -ge 3 ] && [ "$minor" -ge 10 ]; then
                echo "$py"
                return 0
            fi
        fi
    done
    return 1
}

PYTHON=$(find_python)
if [ -z "$PYTHON" ]; then
    echo "ERROR: Python 3.10+ required but not found."
    echo ""
    echo "Install with:"
    echo "  brew install python@3.12    # macOS"
    echo "  sudo apt install python3.12 # Ubuntu/Debian"
    exit 1
fi

echo "Using: $PYTHON ($($PYTHON --version))"

# Create venv if not exists
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    "$PYTHON" -m venv .venv
fi

# Activate venv
if [ -f ".venv/Scripts/activate" ]; then
    source .venv/Scripts/activate
else
    source .venv/bin/activate
fi

echo "Installing dependencies..."
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet

echo ""
echo "============================================"
echo "Setup complete!"
echo "============================================"
echo ""
echo "To test:"
echo "  source .venv/bin/activate"
echo "  python test_client.py"
echo ""
echo "To run server:"
echo "  python server.py"
echo ""
