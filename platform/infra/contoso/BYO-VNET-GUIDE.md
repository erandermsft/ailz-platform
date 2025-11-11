# BYO VNet Implementation Guide

## Overview

Use this guide when you want the Contoso workload to land on an **existing virtual network** that you manage. The BYO flow expects the VNet *and every required subnet* to exist before the main deployment template runs.

> **Heads up:** The quickest path is a two-step flow—deploy `vnet-prerequisites.bicep` first, then run `main-byo-vnet.bicep`. See `BYO-VNET-DEPLOYMENT.md` for the exact commands.

## Compare Deployment Modes

| Aspect | Standard (`main.bicep`) | BYO (`main-byo-vnet.bicep`) |
| --- | --- | --- |
| VNet lifecycle | Created by template | Pre-created outside template |
| Toggle | `virtualNetwork: true` | `virtualNetwork: false` |
| Subnets | Created by AILZ helper modules | Must already exist (prereq template) |
| Inputs | No VNet reference needed | `existingVNetName` (name or resource ID) |

## Template Touchpoints

```bicep
@description('Required. Name or Resource ID of existing VNet (with subnets already created)')
param existingVNetName string

module baseInfra '../../../bicep/deploy/main.bicep' = {
  params: {
    deployToggles: union(deployToggles, {
      virtualNetwork: false
    })
    resourceIds: union(resourceIds, {
      virtualNetworkResourceId: contains(existingVNetName, '/')
        ? existingVNetName
        : resourceId('Microsoft.Network/virtualNetworks', existingVNetName)
    })
  }
}
```

- `existingVNetName` accepts either the VNet name in the current subscription/resource group or a full resource ID for cross-subscription scenarios.
- `deployToggles.virtualNetwork` is forced to `false`; nothing in the BYO template tries to create the VNet or subnets.
- `baseInfra.outputs.virtualNetworkResourceId` is reused by the SQL and App Service modules for private endpoints and VNet integration.

## Prerequisite Subnet Layout

`vnet-prerequisites.bicep` creates the canonical `/22` network with the required slices. Run it (or create the equivalent manually) before the main deployment.

| Subnet | CIDR | Notes |
| --- | --- | --- |
| `agent-subnet` | 192.168.0.0/25 | AI Foundry agents, delegated to `Microsoft.App/environments` |
| `pe-subnet` | 192.168.0.128/26 | Private endpoints, policies disabled |
| `appgw-subnet` | 192.168.0.192/26 | Application Gateway |
| `AzureBastionSubnet` | 192.168.1.0/26 | Bastion |
| `sql-subnet` (opt) | 192.168.1.64/27 | Enabled when `deploySql=true`, NSG optional |
| `appservice-subnet` (opt) | 192.168.1.96/27 | Delegated to `Microsoft.Web/serverFarms` |
| `devops-agents-subnet` | 192.168.1.112/28 | DevOps agents |
| `apim-subnet` | 192.168.1.128/27 | API Management |
| `jumpbox-subnet` | 192.168.1.160/28 | Jump box VMs |
| `aca-env-subnet` | 192.168.1.176/28 | Azure Container Apps, delegated |
| `AzureFirewallSubnet` | 192.168.1.192/26 | Azure Firewall |

> Tweak CIDRs only if you fully understand the downstream policies; overlapping or undersized ranges will block the deployment.

## Deploy Sequence (Condensed)

1. **Prep VNet:** `az deployment group create --template-file platform/infra/contoso/vnet-prerequisites.bicep ...`
2. **Run BYO template:** `az deployment group create --template-file platform/infra/contoso/main-byo-vnet.bicep ...`

- Pass `deploySql` / `deployAppService` to the prerequisites template to provision—or omit—the Contoso subnets.
- Keep the same values for `deployToggles` / `contosoToggles` that you would use for the standard deployment. Only the VNet toggle changes.

## Validation Checklist

- All required subnets exist in the target VNet before Step 2.
- The identity running the deployment has `Network Contributor` on the VNet scope.
- `deployToggles.virtualNetwork` remains `false` (do not override in parameters files).
- Private endpoints land in `pe-subnet`; App Service integrates with `appservice-subnet` when enabled.
- No address space overlaps with existing hub/spoke peers.

## Troubleshooting Quick Hits

- **Template fails on subnet creation:** A subnet is missing; rerun `vnet-prerequisites.bicep` or add it manually.
- **"Subnet not found" during private endpoint creation:** Name mismatch between the prerequisite template and the live VNet.
- **Cross-subscription deployment fails:** Supply the full VNet resource ID and ensure RBAC is granted at or above that resource.
- **App Service integration errors:** Confirm the subnet is delegated to `Microsoft.Web/serverFarms` and has space (at least `/27`).

For end-to-end commands, sample `az deployment` invocations, and output expectations, continue with `BYO-VNET-DEPLOYMENT.md`.
