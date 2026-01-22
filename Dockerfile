# =============================================================================
# Single-stage build with GitHub Container Registry image
# Alternative: python:3.12-slim (Docker Hub) if accessible
# =============================================================================

FROM ghcr.io/astral-sh/uv:python3.12-alpine

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY server.py .
COPY instructions.yaml .

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV MCP_TRANSPORT=streamable-http
ENV MCP_PORT=8080

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request,json; urllib.request.urlopen(urllib.request.Request('http://localhost:8080/mcp', data=json.dumps({'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2024-11-05','capabilities':{},'clientInfo':{'name':'healthcheck','version':'1.0'}}}).encode(), headers={'Content-Type':'application/json','Accept':'application/json, text/event-stream'}))" || exit 1

CMD ["python", "server.py"]
