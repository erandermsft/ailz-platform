# Contoso Platform Extension – Azure SQL & App Service

This guide documents the current SQL and App Service implementation that layers on top of the AILZ baseline from `platform/infra/contoso/main.bicep`.

## What the Template Adds

- **Network security groups**
  - `nsg-sql-<token>` allows only VNet-sourced inbound traffic.
  - `nsg-appservice-<token>` permits App Service management traffic (TCP 454/455) plus VNet inbound.
- **Custom subnets** appended to the AILZ VNet after it is created.
  - `sql-subnet` → `192.168.1.64/27`, delegated for private endpoints, NSG attached.
  - `appservice-subnet` → `192.168.1.96/27`, delegated to `Microsoft.Web/serverFarms`, NSG attached.
- **Azure SQL Server (Basic tier)** with system-assigned managed identity, private endpoint, and public network access disabled.
- **Linux App Service Plan (P1v3)** and App Service with VNet integration, private endpoint, and managed identity connection string to SQL.

All resources inherit the deployment location (default `swedencentral`) and follow the deterministic `baseName` token generated in the template.

## High-Level Flow

1. `baseInfra` module deploys the upstream AILZ stack (including the default VNet and `pe-subnet`).
2. When SQL and/or App Service toggles are enabled:
   - NSGs are created.
   - `deploy-subnets-to-vnet` helper adds `sql-subnet` and/or `appservice-subnet` to the existing VNet.
3. Workload resources deploy and bind to those subnets:
   - SQL private endpoint → `pe-subnet`.
   - App Service outbound integration → `appservice-subnet`.
   - App Service private endpoint → `pe-subnet`.

The template does **not** mutate the upstream modules; everything stays inside `platform/infra/contoso`.

## Key Parameters

```bicep
param deployToggles baseDeployToggles
param contosoToggles contosoDeployTogglesType

var deploySql = contosoToggles.?azureSql ?? false
var deployAppService = contosoToggles.?appService ?? false
```

- Turn on SQL/App Service by setting `contosoToggles.azureSql` / `contosoToggles.appService` to `true`.
- Leave `deployToggles.virtualNetwork` set to `true` so the base template creates the VNet.
- Provide `resourceIds.virtualNetworkResourceId` only when overriding upstream behavior (not needed for the default path).

## Deployment Notes

- The helper module derives the VNet name from `baseInfra.outputs.virtualNetworkResourceId`; no manual VNet name input is required.
- Address prefixes are currently hard-coded to the `192.168.0.0/22` plan used by `vnet-prerequisites.bicep`. Adjust the CIDRs in `contosoSubnets` if you change that plan.
- The SQL module uses Azure AD-only authentication. Replace the placeholder `sid` (`00000000-...`) with the object ID of your admin group or user before production use.
- App Service’s connection string is set to use managed identity. Grant the identity access inside the database after deployment.

## Running Locally

1. From the repo root, generate the `bicep/deploy` folder if it does not exist:
   ```bash
   cd bicep
   ./scripts/preprovision.sh
   ```
2. Deploy the Contoso overlay (example parameters shown):
   ```bash
   cd ../platform/infra/contoso
   az deployment sub create \
     --name contoso-sql-app \
     --location swedencentral \
     --template-file main.bicep \
     --parameters \
       deployToggles='{"virtualNetwork": true, "logAnalytics": true, "keyVault": true}' \
       contosoToggles='{"azureSql": true, "appService": true}' \
       resourceIds='{}'
   ```

For template spec deployments, supply the same parameter sets when invoking the published spec.

## Post-Deployment Checklist

- SQL Server exists with public network access disabled and a private endpoint in `pe-subnet`.
- `sql-subnet` and `appservice-subnet` show up in the target VNet with their NSGs attached.
- App Service Plan (`asp-<token>`) and App (`app-<token>`) are provisioned, with VNet integration pointing to `appservice-subnet`.
- App Service private endpoint is created and healthy.
- Managed identity access to SQL is configured (create database user / assign roles).

## Troubleshooting Tips

- **Subnet not found:** Ensure the deployment account has `Network Contributor` on the VNet and that `deployToggles.virtualNetwork` remains `true` so the base VNet is present.
- **Address conflicts:** Update the `addressPrefix` values in `contosoSubnets` if your environment already uses the default ranges.
- **Managed identity connection fails:** Grant database permissions using `CREATE USER ... FROM EXTERNAL PROVIDER;` and add the identity to the needed roles.
- **App Service integration error:** Confirm the subnet retains the `Microsoft.Web/serverFarms` delegation after deployment.
