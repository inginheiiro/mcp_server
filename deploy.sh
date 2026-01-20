#!/usr/bin/env bash
# =============================================================================
# Deploy MCP Server to Azure VM (SSE mode for team access)
# =============================================================================
set -e

# Config
RG="rg-mcp-server"
LOCATION="westeurope"
VM="mcp-server"
SIZE="Standard_B1ls"
IMAGE="Canonical:ubuntu-24_04-lts:minimal:latest"
DISK_SIZE=4
MCP_PORT=8080

# Check prereqs
command -v az &>/dev/null || { echo "Install Azure CLI first"; exit 1; }
[ -f ~/.ssh/id_rsa.pub ] || { echo "Generate SSH key: ssh-keygen -t rsa -b 4096"; exit 1; }

az account show &>/dev/null || az login

echo "Deploying: $VM"
echo "  Size: $SIZE (0.5 GB RAM, 1 vCPU)"
echo "  Image: Ubuntu 24.04 Minimal"
echo "  Disk: ${DISK_SIZE} GB"
echo "  Port: $MCP_PORT (streamable-http)"
echo "  Est. cost: ~\$4/month"
read -p "Continue? [y/N] " -n 1 -r && echo
[[ $REPLY =~ ^[Yy]$ ]] || exit 0

# Create RG
az group create -n $RG -l $LOCATION -o none

# Create VM
az vm create \
    -g $RG -n $VM \
    --image $IMAGE \
    --size $SIZE \
    --os-disk-size-gb $DISK_SIZE \
    --storage-sku StandardSSD_LRS \
    --admin-username azureuser \
    --ssh-key-values ~/.ssh/id_rsa.pub \
    --public-ip-sku Basic \
    -o none

# Open MCP port
az vm open-port -g $RG -n $VM --port $MCP_PORT --priority 1001 -o none

# Get IP
IP=$(az vm show -g $RG -n $VM -d --query publicIps -o tsv)
echo "VM ready: $IP"

# Copy files
scp server.py instructions.yaml requirements.txt azureuser@$IP:/tmp/

# Setup VM with systemd service
ssh azureuser@$IP << EOF
sudo apt-get update && sudo apt-get install -y --no-install-recommends python3 python3-venv
sudo mkdir -p /opt/mcp && sudo cp /tmp/*.py /tmp/*.yaml /tmp/*.txt /opt/mcp/
cd /opt/mcp && sudo python3 -m venv venv && sudo ./venv/bin/pip install --no-cache-dir -r requirements.txt

# Create systemd service (SSE mode)
sudo tee /etc/systemd/system/mcp.service > /dev/null << SERVICE
[Unit]
Description=MCP Instructions Server
After=network.target

[Service]
Type=simple
User=nobody
WorkingDirectory=/opt/mcp
Environment=MCP_TRANSPORT=streamable-http
Environment=MCP_PORT=$MCP_PORT
ExecStart=/opt/mcp/venv/bin/python server.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable --now mcp
EOF

echo ""
echo "====================================="
echo "MCP Server deployed!"
echo "====================================="
echo ""
echo "URL for devs: http://$IP:$MCP_PORT/mcp"
echo ""
echo "Claude Desktop config (~/.config/claude/claude_desktop_config.json):"
echo "{"
echo "  \"mcpServers\": {"
echo "    \"team-instructions\": {"
echo "      \"type\": \"streamable-http\","
echo "      \"url\": \"http://$IP:$MCP_PORT/mcp\""
echo "    }"
echo "  }"
echo "}"
