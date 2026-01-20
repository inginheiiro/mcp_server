# MCP Instructions Server

Shared Claude instructions for teams. Edit `instructions.yaml`, everyone gets updates.

## Run the Server

### Option 1: Docker

```bash
docker compose up -d
# Server runs at http://localhost:8080/sse
```

### Option 2: Python

```bash
# macOS / Linux
python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
python server.py

# Windows
python -m venv .venv && .venv\Scripts\activate && pip install -r requirements.txt
python server.py
```

## Connect Claude Code

Create config file:
- **Global** (all projects): `~/.claude/mcp.json`
- **Per-repo** (this project only): `.mcp.json` in repo root

### If server runs via Docker or remote URL

```json
{
  "mcpServers": {
    "team-instructions": {
      "type": "sse",
      "url": "http://localhost:8080/sse"
    }
  }
}
```

Replace `localhost:8080` with your server URL if remote.

### If server runs via Python directly

macOS / Linux:
```json
{
  "mcpServers": {
    "team-instructions": {
      "command": "/absolute/path/to/mcp_claude/.venv/bin/python",
      "args": ["/absolute/path/to/mcp_claude/server.py"]
    }
  }
}
```

Windows:
```json
{
  "mcpServers": {
    "team-instructions": {
      "command": "C:\\path\\to\\mcp_claude\\.venv\\Scripts\\python.exe",
      "args": ["C:\\path\\to\\mcp_claude\\server.py"]
    }
  }
}
```

## Commands

| Prompt | Description |
|--------|-------------|
| `production` | Strict mode with team standards |
| `freestyle` | No rules, full freedom |
| `code_review` | Review code with standards |

| Tool | Description |
|------|-------------|
| `help` | List all commands |
| `refresh` | Reload instructions |

## Edit Instructions

1. Edit `instructions.yaml`
2. Call `refresh` tool or restart Claude
3. Done

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Server not found | Use absolute paths, check JSON syntax |
| Python errors | Need Python 3.10+, activate venv |
