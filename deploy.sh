#!/usr/bin/env bash
# =============================================================================
# Deploy MCP Server to Azure Container Instances
# =============================================================================
set -e

# Config
RG="rg-mcp-server"
LOCATION="westeurope"
CONTAINER="mcp-server"
ACR="mcpserveracr$RANDOM"
MCP_PORT=8080

# Check prereqs
command -v az &>/dev/null || { echo "Install Azure CLI first"; exit 1; }
command -v docker &>/dev/null || { echo "Install Docker first"; exit 1; }

az account show &>/dev/null || az login

echo "Deploying MCP Server to Azure Container Instances"
echo "  Location: $LOCATION"
echo "  Port: $MCP_PORT"
echo "  Est. cost: ~\$1-2/month"
read -p "Continue? [y/N] " -n 1 -r && echo
[[ $REPLY =~ ^[Yy]$ ]] || exit 0

# Create resource group
az group create -n $RG -l $LOCATION -o none

# Create Azure Container Registry
az acr create -g $RG -n $ACR --sku Basic -o none
az acr login -n $ACR

# Build and push image
ACR_LOGIN=$(az acr show -n $ACR --query loginServer -o tsv)
docker build -t $ACR_LOGIN/mcp-server:latest .
docker push $ACR_LOGIN/mcp-server:latest

# Enable admin access for ACI
az acr update -n $ACR --admin-enabled true -o none
ACR_PASS=$(az acr credential show -n $ACR --query "passwords[0].value" -o tsv)

# Deploy container
az container create \
    -g $RG \
    -n $CONTAINER \
    --image $ACR_LOGIN/mcp-server:latest \
    --registry-login-server $ACR_LOGIN \
    --registry-username $ACR \
    --registry-password "$ACR_PASS" \
    --cpu 0.5 \
    --memory 0.5 \
    --ports $MCP_PORT \
    --environment-variables MCP_TRANSPORT=streamable-http MCP_PORT=$MCP_PORT \
    --dns-name-label $CONTAINER-$(echo $RANDOM | md5sum | head -c 6) \
    --restart-policy OnFailure \
    -o none

# Get URL
FQDN=$(az container show -g $RG -n $CONTAINER --query ipAddress.fqdn -o tsv)

echo ""
echo "====================================="
echo "MCP Server deployed!"
echo "====================================="
echo ""
echo "URL: http://$FQDN:$MCP_PORT/mcp"
echo ""
echo "Claude Code config:"
echo '{'
echo '  "mcpServers": {'
echo '    "team-instructions": {'
echo '      "type": "streamable-http",'
echo "      \"url\": \"http://$FQDN:$MCP_PORT/mcp\""
echo '    }'
echo '  }'
echo '}'
echo ""
echo "Commands:"
echo "  Logs:    az container logs -g $RG -n $CONTAINER"
echo "  Restart: az container restart -g $RG -n $CONTAINER"
echo "  Delete:  az group delete -n $RG --yes"
