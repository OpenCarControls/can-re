from mcp.server.fastmcp import FastMCP

# Initialize FastMCP server
mcp = FastMCP("CAN_AI_Debugger")

@mcp.tool()
def get_can_status() -> str:
    """Return the current status of the CAN bus."""
    return "CAN bus is connected and running."

@mcp.tool()
def hello_world() -> str:
    """A simple hello world tool."""
    return "Hello from CAN AI Debugger MCP Server!"

if __name__ == "__main__":
    # In desktop mode, we might run this in a separate thread or process
    # For now, it's accessible via stdio for standard MCP integration
    mcp.run(transport='stdio')
