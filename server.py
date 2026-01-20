"""
MCP Instructions Server
Exposes team instructions as Resources and Prompts for Claude clients.
"""

import sys
import yaml
import logging
from pathlib import Path
from functools import lru_cache

from mcp.server.fastmcp import FastMCP

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    stream=sys.stderr,
)
logger = logging.getLogger(__name__)

mcp = FastMCP("team-instructions")
INSTRUCTIONS_FILE = Path(__file__).parent / "instructions.yaml"


@lru_cache(maxsize=1)
def load_instructions() -> dict:
    """Load instructions YAML safely with basic validation and logging."""
    if not INSTRUCTIONS_FILE.exists():
        logger.warning("Instructions file %s not found", INSTRUCTIONS_FILE)
        return {}

    try:
        raw_text = INSTRUCTIONS_FILE.read_text(encoding="utf-8")
    except OSError as exc:
        logger.error("Failed reading %s: %s", INSTRUCTIONS_FILE, exc)
        return {}

    try:
        data = yaml.safe_load(raw_text) or {}
    except yaml.YAMLError as exc:
        logger.error("Failed parsing %s: %s", INSTRUCTIONS_FILE, exc)
        return {}

    if not isinstance(data, dict):
        logger.error(
            "Instructions file must contain a mapping, got %s", type(data).__name__
        )
        return {}

    if not data:
        logger.warning("Instructions file is empty")
    else:
        logger.info(
            "Loaded %d instruction sections: %s",
            len(data),
            ", ".join(sorted(data.keys())),
        )

    return data


def get_section(key: str) -> str:
    instructions = load_instructions()
    content = instructions.get(key)
    if not content:
        logger.warning("Requested missing instruction section '%s'", key)
        return f"Section '{key}' not found."
    return content


# =============================================================================
# RESOURCES
# =============================================================================


@mcp.resource("instructions://core")
def r_core() -> str:
    """Core principles that always apply."""
    return get_section("core_principles")


@mcp.resource("instructions://production")
def r_production() -> str:
    """Production context guidelines."""
    return get_section("context_production")


@mcp.resource("instructions://checklist")
def r_checklist() -> str:
    """Delivery checklist for production code."""
    return get_section("review_checklist")


@mcp.resource("instructions://all")
def r_all() -> str:
    """All instructions combined."""
    sections = [
        (key, value) for key, value in sorted(load_instructions().items()) if value
    ]
    if not sections:
        return "No instructions available."

    return "\n\n---\n\n".join(
        f"# {key.replace('_', ' ').title()}\n\n{value}" for key, value in sections
    )


# =============================================================================
# PROMPTS
# =============================================================================


@mcp.prompt()
def production() -> str:
    """Activate production mode - strict, follows team standards."""
    return f"""You are in PRODUCTION mode. Follow these instructions:

{get_section("core_principles")}

{get_section("context_production")}

{get_section("review_checklist")}"""


@mcp.prompt()
def freestyle() -> str:
    """No rules mode - full freedom, no guidelines loaded."""
    return """You are in FREESTYLE mode. No specific instructions or guidelines.

Do whatever makes sense for the task at hand. Full creative freedom."""


@mcp.prompt()
def code_review(code: str, language: str = "python") -> str:
    """Review code with team standards."""
    return f"""{get_section("core_principles")}

{get_section("context_production")}

{get_section("review_checklist")}

## Code to Review
```{language}
{code}
```

Be direct. If unsure about something, say so."""


# =============================================================================
# TOOLS
# =============================================================================


@mcp.tool()
def help() -> str:
    """List available prompts and what they do."""
    return """# Available Commands

## Prompts
| Prompt       | Description                         |
|--------------|-------------------------------------|
| production   | Strict mode, team standards         |
| freestyle    | No rules, full freedom              |
| code_review  | Review code with standards          |

## Tools
| Tool    | Description                         |
|---------|-------------------------------------|
| help    | Show this list                      |
| refresh | Reload instructions from file       |

## Resources
| Resource                  | Description                |
|---------------------------|----------------------------|
| instructions://core       | Core principles            |
| instructions://production | Production guidelines      |
| instructions://checklist  | Delivery checklist         |
| instructions://all        | All sections combined      |
"""


@mcp.tool()
def refresh() -> str:
    """Reload instructions from file."""
    load_instructions.cache_clear()
    sections = list(load_instructions().keys())
    return f"Reloaded {len(sections)} sections: {', '.join(sections)}"


# =============================================================================
# MAIN
# =============================================================================

if __name__ == "__main__":
    import os

    transport = os.getenv("MCP_TRANSPORT", "stdio")
    port = int(os.getenv("PORT", os.getenv("MCP_PORT", "8080")))

    if transport == "sse":
        logger.info("Starting MCP server (SSE) on port %d", port)

        from starlette.applications import Starlette
        from starlette.responses import JSONResponse
        from starlette.routing import Route, Mount

        async def health(request):
            """Health check endpoint."""
            sections = list(load_instructions().keys())
            return JSONResponse({
                "status": "ok",
                "transport": "sse",
                "instructions_loaded": len(sections),
                "sections": sections
            })

        sse_app = mcp.sse_app()

        # Wrapper to bypass host validation for Railway proxy
        class HostFixMiddleware:
            def __init__(self, app):
                self.app = app

            async def __call__(self, scope, receive, send):
                if scope["type"] == "http":
                    # Override host to localhost to pass validation
                    headers = [(k, v) for k, v in scope["headers"] if k != b"host"]
                    headers.append((b"host", b"localhost"))
                    scope = dict(scope, headers=headers)
                await self.app(scope, receive, send)

        base_app = Starlette(
            routes=[
                Route("/health", health),
                Mount("/", app=sse_app),
            ]
        )

        # Apply middleware to entire app
        app = HostFixMiddleware(base_app)

        import uvicorn
        uvicorn.run(app, host="0.0.0.0", port=port)
    else:
        logger.info("Starting MCP server (STDIO)")
        mcp.run()
