# MCP Instructions Server

Shared Claude instructions for teams. Edit `instructions.yaml`, everyone gets updates.

## Quick Start

### Option 1: Docker (Recommended)

```bash
docker compose up -d
# Server runs at http://localhost:8080/mcp
```

### Option 2: Python

```bash
# macOS / Linux
./setup.sh
python server.py

# Windows
python -m venv .venv && .venv\Scripts\activate && pip install -r requirements.txt
python server.py
```

### Option 3: Cloud (Railway)

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template)

Set environment variables:
```
MCP_TRANSPORT=streamable-http
PORT=8080
```

### Option 4: Azure Container Instances

```bash
./deploy.sh
```

Requirements: Azure CLI (`az`) and Docker installed.

The script creates:
- Resource Group
- Azure Container Registry
- Container Instance with public URL

**Redeploy after changes:**
```bash
# Set your ACR name (check Azure portal or use: az acr list -g rg-mcp-server --query "[0].name" -o tsv)
ACR=your-acr-name

# Build, push and restart
az acr login -n $ACR
docker build -t $ACR.azurecr.io/mcp-server:latest .
docker push $ACR.azurecr.io/mcp-server:latest
az container restart -g rg-mcp-server -n mcp-server
```

**Useful commands:**
```bash
az container logs -g rg-mcp-server -n mcp-server      # View logs
az container restart -g rg-mcp-server -n mcp-server   # Restart
az group delete -n rg-mcp-server --yes                # Delete all
```

## Which Option to Choose?

| Mode | Best For | Cost | Latency |
|------|----------|------|---------|
| **stdio** (local Python) | Personal use | Free | ~0ms |
| **Docker** | Local dev/testing | Free | ~10ms |
| **Railway** | Quick deploy | Pay per use | ~100ms+ |
| **Azure ACI** | Team sharing, Azure users | ~$1-2/month | ~100ms+ |

**Note:** The server only gets called when you invoke a prompt (`/team-instructions:production`, etc.). Normal Claude messages don't hit the server. Instructions are loaded once into the conversation context.

## Connect Claude Code

Create config file:
- **Global** (all projects): `~/.claude/mcp.json`
- **Per-repo** (this project only): `.mcp.json` in repo root

### Remote server (Docker/Railway/Cloud)

```json
{
  "mcpServers": {
    "team-instructions": {
      "type": "streamable-http",
      "url": "https://your-server-url/mcp"
    }
  }
}
```

### Local Python (STDIO)

macOS / Linux:
```json
{
  "mcpServers": {
    "team-instructions": {
      "command": "/absolute/path/to/.venv/bin/python",
      "args": ["/absolute/path/to/server.py"]
    }
  }
}
```

Windows:
```json
{
  "mcpServers": {
    "team-instructions": {
      "command": "C:\\path\\to\\.venv\\Scripts\\python.exe",
      "args": ["C:\\path\\to\\server.py"]
    }
  }
}
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MCP_TRANSPORT` | `stdio` | Transport: `stdio`, `streamable-http`, or `sse` |
| `PORT` | `8080` | Server port (for HTTP transports) |
| `MCP_PORT` | `8080` | Alternative port variable |

## Available Commands

### Prompts

| Prompt | Description |
|--------|-------------|
| `production` | Strict mode with team standards |
| `freestyle` | No rules, full freedom |
| `code_review` | Review code with standards |

### Tools

| Tool | Description |
|------|-------------|
| `help` | List all commands |
| `refresh` | Reload instructions from file |

### Resources

| Resource | Description |
|----------|-------------|
| `instructions://core` | Core principles |
| `instructions://production` | Production guidelines |
| `instructions://checklist` | Delivery checklist |
| `instructions://all` | All sections combined |

## Edit Instructions

1. Edit `instructions.yaml`
2. Call `refresh` tool (or restart server)
3. Done - all connected clients get updates

## Transports

| Transport | Use Case | Endpoint |
|-----------|----------|----------|
| `streamable-http` | Remote/Cloud (recommended) | `/mcp` |
| `sse` | Remote/Cloud (legacy) | `/sse` |
| `stdio` | Local Python execution | N/A |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Server not found | Use absolute paths, check JSON syntax |
| Python errors | Need Python 3.10+, run `pip install -r requirements.txt` |
| Connection refused | Check `MCP_TRANSPORT` and port settings |
| Invalid Host header | Server needs `MCP_TRANSPORT=streamable-http` or `sse` |

## Test Server

```bash
# Health check (SSE transport only - not available in streamable-http)
curl http://localhost:8080/health

# Test streamable-http endpoint
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
```

**Note:** The `/health` endpoint only exists when using SSE transport. For streamable-http, use the MCP endpoint test above.
