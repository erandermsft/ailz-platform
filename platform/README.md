# Contoso Platform Team

This folder contains the platform team's customizations and corporate standards on top of the upstream Azure AI Landing Zone.

## Repository Structure

```
/bicep/                          ← Upstream AILZ (from microsoft/AI-Landing-Zone)
  infra/
    main.bicep                   ← Upstream main template
    wrappers/                    ← AVM wrappers
  scripts/
    preprovision.sh              ← Creates template specs

/platform/                       ← Platform team customizations
  infra/
    contoso/
      main.bicep                 ← Platform team's main template
      common/
        types.bicep              ← Extended types for Contoso
      components/                ← Contoso-specific components
```

## Update Flow

### 1. Pull Upstream Updates
```bash
# Fetch latest from Microsoft AILZ
git fetch ailz-upstream
git checkout ailz-upstream/main -- bicep/

# Commit the update
git commit -m "Update bicep from upstream AILZ"
```

### 2. CI/CD Automatically Publishes
When you push changes, the workflow:

1. **Runs preprovision** → Creates template specs for wrappers
2. **Publishes base AILZ template spec** → `ts-ailz-base` 
3. **Publishes base AILZ to ACR** → `br:myacr.azurecr.io/bicep/ailz/base:latest`
4. **Publishes Contoso platform to ACR** → `br:myacr.azurecr.io/bicep/platform/contoso:latest`

## Platform Team Development

Edit files in `/platform/infra/contoso/`:
- `main.bicep` - References base AILZ + adds corporate standards
- `common/types.bicep` - Extended deployment toggles
- Add custom components as needed

## Workload Team Consumption

Workload teams (in separate repos) reference the published platform module:

```bicep
// workload-team-repo/main.bicep
module contosoInfra 'br:myacr.azurecr.io/bicep/platform/contoso:v20241106' = {
  name: 'contoso-platform-infra'
  params: {
    deployToggles: {
      logAnalytics: true
      appInsights: true
      containerEnv: true
      containerRegistry: true
      // ... other base toggles
    }
    contosoToggles: {
      appService: true
      customFeatureX: false
      monitoringDashboard: true
    }
  }
}

// Workload-specific resources
module myApp './app.bicep' = {
  name: 'my-app'
  params: {
    // ...
  }
}
```

## Published Artifacts

The platform team publishes:

| Artifact | Location | Purpose |
|----------|----------|---------|
| Wrapper Template Specs | `ts-main-wrp-*` | AVM wrappers as template specs |
| Base AILZ Template Spec | `ts-ailz-base` | Transformed main.bicep with template spec refs |
| Base AILZ ACR Module | `br:myacr.azurecr.io/bicep/ailz/base` | Base AILZ for direct consumption |
| Contoso Platform ACR Module | `br:myacr.azurecr.io/bicep/platform/contoso` | Platform with corporate standards |

Workload teams typically use **Contoso Platform ACR Module** which includes everything.
