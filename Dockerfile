# =============================================================================
# Multi-stage build with slim image
# =============================================================================

FROM python:3.12-slim AS builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# -----------------------------------------------------------------------------
FROM python:3.12-slim AS runtime

RUN useradd --system --no-create-home --shell /bin/false mcp

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY --chown=mcp:mcp server.py .
COPY --chown=mcp:mcp instructions.yaml .

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV MCP_TRANSPORT=streamable-http
ENV MCP_PORT=8080

USER mcp

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request,json; urllib.request.urlopen(urllib.request.Request('http://localhost:8080/mcp', data=json.dumps({'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2024-11-05','capabilities':{},'clientInfo':{'name':'healthcheck','version':'1.0'}}}).encode(), headers={'Content-Type':'application/json','Accept':'application/json, text/event-stream'}))" || exit 1

CMD ["python", "server.py"]
