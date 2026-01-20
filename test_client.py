"""
Test client for MCP Instructions Server.
"""

import asyncio
import sys
from pathlib import Path


async def test_stdio_server():
    """Test server via STDIO transport."""
    try:
        from mcp import ClientSession, StdioServerParameters
        from mcp.client.stdio import stdio_client
    except ImportError:
        print("ERROR: mcp package not installed. Run: pip install 'mcp[cli]'")
        sys.exit(1)

    server_script = Path(__file__).parent / "server.py"

    server_params = StdioServerParameters(
        command=sys.executable,
        args=[str(server_script)],
    )

    print("=" * 60)
    print("MCP Instructions Server - Test Client")
    print("=" * 60)

    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            # Test 1: List resources
            print("\n[TEST] Listing resources...")
            resources = await session.list_resources()
            print(f"  Found {len(resources.resources)} resources:")
            for r in resources.resources:
                print(f"    - {r.uri}")

            # Test 2: Read a resource
            print("\n[TEST] Reading 'instructions://core'...")
            content = await session.read_resource("instructions://core")
            preview = str(content.contents[0])[:200]
            print(f"  Preview: {preview}...")

            # Test 3: List prompts
            print("\n[TEST] Listing prompts...")
            prompts = await session.list_prompts()
            print(f"  Found {len(prompts.prompts)} prompts:")
            for p in prompts.prompts:
                print(f"    - {p.name}: {p.description}")

            # Test 4: List tools
            print("\n[TEST] Listing tools...")
            tools = await session.list_tools()
            print(f"  Found {len(tools.tools)} tools:")
            for t in tools.tools:
                print(f"    - {t.name}: {t.description}")

            # Test 5: Call refresh tool
            print("\n[TEST] Calling 'refresh' tool...")
            result = await session.call_tool("refresh", {})
            print(f"  Result: {result.content[0].text}")

            print("\n" + "=" * 60)
            print("All tests passed!")
            print("=" * 60)


def main():
    asyncio.run(test_stdio_server())


if __name__ == "__main__":
    main()
