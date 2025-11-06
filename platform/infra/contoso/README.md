# Contoso AILZ Platform

This folder contains Contoso's customizations on top of the base AILZ platform.

## Architecture Layers

### Layer 1: Microsoft AILZ Upstream
- Source: https://github.com/Azure/AI-Landing-Zone
- Maintained in `/bicep/infra/ailz/`
- Template specs for all AVM wrappers

### Layer 2: Platform Team (This Repo)
- Runs preprovision script to create template specs
- Publishes `ts-ailz-platform-base` template spec (transformed main.bicep)
- Provides stable base for workload teams

### Layer 3: Workload Teams
- Reference `ts-ailz-platform-base` from parameters
- Add workload-specific resources

## Deployment Options

### Option 1: Reference Local Files (Development)
Deploy using local files for testing:
```bash
az deployment group create \
  --resource-group rg-contoso-dev \
  --template-file bicep/infra/contoso/main.bicep \
  --parameters bicep/infra/contoso/main.bicepparam
```

### Option 2: Reference Published Template Spec (Production)
Manually update the module reference in `main.bicep`:

```bicep
// Replace this line:
module baseInfra '../ailz/main.bicep' = {

// With template spec reference (update subscription/RG):
module baseInfra 'ts:00000000-0000-0000-0000-000000000000/rg-platform-templates/ts-ailz-platform-base:latest' = {
```

Or use Azure CLI to deploy with overrides:
```bash
# First, get the template spec ID
TS_ID=$(az ts show \
  --resource-group rg-platform-templates \
  --name ts-ailz-platform-base \
  --version latest \
  --query id -o tsv)

# Deploy referencing the template spec
# (This requires modifying main.bicep to accept module path as parameter)
```

### Option 3: Publish Contoso Module to ACR
The GitHub workflow publishes the contoso module to ACR:
```bicep
module contosoInfra 'br:myacr.azurecr.io/modules/bicep/contoso/ailz:latest' = {
  name: 'contoso-infrastructure'
  params: {
    // your params
  }
}
```

## Template Spec Publishing

The GitHub Actions workflow (`/.github/workflows/publish-bicep.yml`) automatically:

1. **Publishes wrapper template specs** → `ts-{env}-wrp-{wrapper-name}`
2. **Publishes base AILZ template spec** → `ts-ailz-platform-base`
3. **Publishes to ACR** → `br:myacr.azurecr.io/modules/bicep/contoso/ailz`

## Required Secrets

Configure these in GitHub repository settings:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_CONTAINER_REGISTRY_NAME`
- `AZURE_LOCATION`
- `AZURE_RESOURCE_GROUP`
- `AZURE_TS_RG` (central template spec resource group)
