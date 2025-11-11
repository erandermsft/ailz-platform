# BYO VNet Deployment Guide

## Two-Step Deployment Process

### Step 1: Create VNet with Subnets

Deploy the VNet prerequisites first to create the VNet with all required subnets:

```bash
# Deploy VNet with all subnets (AILZ defaults + Contoso custom)
az deployment group create \
  --resource-group rg-ailzwl8 \
  --template-file platform/infra/contoso/vnet-prerequisites.bicep \
  --parameters location=swedencentral \
  --parameters vnetName=vnet-ailz-contoso \
  --parameters deploySql=true \
  --parameters deployAppService=true
```

**Optional**: If you want to attach NSGs to custom subnets, create them first and pass their resource IDs:

```bash
# With NSGs (create NSGs first, then reference them)
az deployment group create \
  --resource-group rg-ailzwl8 \
  --template-file platform/infra/contoso/vnet-prerequisites.bicep \
  --parameters location=swedencentral \
  --parameters vnetName=vnet-ailz-contoso \
  --parameters deploySql=true \
  --parameters deployAppService=true \
  --parameters sqlNsgResourceId='/subscriptions/.../resourceGroups/rg-ailzwl8/providers/Microsoft.Network/networkSecurityGroups/nsg-sql' \
  --parameters appServiceNsgResourceId='/subscriptions/.../resourceGroups/rg-ailzwl8/providers/Microsoft.Network/networkSecurityGroups/nsg-appservice'
```

### Step 2: Deploy AILZ with BYO VNet

Now deploy the AILZ platform using the existing VNet:

```bash
# Deploy AILZ to existing VNet
az deployment group create \
  --resource-group rg-ailzwl8 \
  --template-file platform/deploy/main-byo-vnet.bicep \
  --parameters existingVNetName=vnet-ailz-contoso \
  --parameters '@platform/infra/contoso/main.bicepparam'
```

## What Gets Created

### Step 1 (vnet-prerequisites.bicep)
- VNet: `192.168.0.0/22` (1024 IPs)
- 9 AILZ default subnets (agent, pe, appgw, bastion, firewall, apim, jumpbox, aca-env, devops-agents)
- 2 Contoso custom subnets (sql-subnet, appservice-subnet) - if enabled

### Step 2 (main-byo-vnet.bicep)
- AILZ base infrastructure (AI Foundry, Key Vault, Storage, etc.)
- Contoso SQL Server with private endpoint
- Contoso App Service with VNet integration and private endpoint
- All resources use the pre-created subnets

## Address Space Allocation

| Subnet | Address Range | Size | Purpose |
|--------|--------------|------|---------|
| `agent-subnet` | 192.168.0.0/25 | 128 IPs | AI Foundry agents |
| `pe-subnet` | 192.168.0.128/26 | 64 IPs | Private endpoints |
| `appgw-subnet` | 192.168.0.192/26 | 64 IPs | Application Gateway |
| `AzureBastionSubnet` | 192.168.1.0/26 | 64 IPs | Bastion |
| `sql-subnet` | 192.168.1.64/27 | 32 IPs | SQL private endpoints |
| `appservice-subnet` | 192.168.1.96/27 | 32 IPs | App Service delegation |
| `devops-agents-subnet` | 192.168.1.112/28 | 16 IPs | DevOps agents |
| `apim-subnet` | 192.168.1.128/27 | 32 IPs | API Management |
| `jumpbox-subnet` | 192.168.1.160/28 | 16 IPs | Jump box VMs |
| `aca-env-subnet` | 192.168.1.176/28 | 16 IPs | Container Apps |
| `AzureFirewallSubnet` | 192.168.1.192/26 | 64 IPs | Azure Firewall |

## Why Two Steps?

The BYO VNet pattern expects the VNet and subnets to **already exist** before AILZ deployment. This avoids:
- Race conditions when creating multiple subnets simultaneously
- Address conflicts between AILZ defaults and custom subnets
- Complex subnet dependency management during AILZ deployment

By pre-creating the VNet, AILZ simply references existing subnets and deploys workloads into them.
