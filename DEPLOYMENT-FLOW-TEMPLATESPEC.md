# AILZ Platform Deployment Flow (Template Spec Approach)

## Overview
This approach publishes a single Template Spec (`ts-contoso-ailz`) that includes all necessary infrastructure. Workload teams only need access to one Template Spec resource group - no ACR required.

## Complete Step-by-Step Process

### Step 1: Upstream Update (Manual)
Platform team pulls latest from Microsoft AILZ upstream:

```bash
# Fetch latest upstream
git fetch ailz-upstream

# Update /bicep folder with upstream content
git checkout ailz-upstream/main -- bicep/

# Commit and push
git commit -m "Update bicep from upstream AILZ (commit: abc123)"
git push
```

**Result**: `/bicep` folder now has latest upstream code

---

### Step 2: GitHub Actions Workflow (Automatic)

Triggered by push to `/bicep/**` or `/platform/**`

#### Single Job: Prepare & Publish
```
┌─────────────────────────────────────────┐
│  1. Run preprovision.sh                 │
│     ├─ Create /bicep/deploy/            │
│     ├─ Overlay custom wrappers          │
│     │  (from platform/infra/contoso/   │
│     │   wrappers/ if any exist)         │
│     ├─ Build wrapper template specs     │
│     │  └─ ts-main-wrp-avm.res.*.bicep  │
│     └─ Replace wrappers with TS refs    │
│        in deploy/main.bicep             │
├─────────────────────────────────────────┤
│  2. Verify deploy/main.bicep exists     │
├─────────────────────────────────────────┤
│  3. Publish Contoso AILZ Template Spec  │
│     Source: platform/infra/contoso/     │
│            main.bicep                   │
│     Module ref: ../../../bicep/deploy/  │
│                main.bicep               │
│     ├─ Name: ts-contoso-ailz           │
│     ├─ Version: v20241107-a1b2c3d      │
│     └─ Version: latest                  │
└─────────────────────────────────────────┘
```

**What Gets Published**:
1. **Wrapper Template Specs** (referenced by deploy/main.bicep):
   - `ts-main-wrp-avm.res.key-vault.vault`
   - `ts-main-wrp-avm.res.storage.storage-account`
   - `ts-main-wrp-avm.res.*.bicep` (all wrappers)

2. **Single Contoso Template Spec** (workload teams use this):
   - `ts-contoso-ailz:v20241107-a1b2c3d`
   - `ts-contoso-ailz:latest`

**Key Difference from ACR Approach**: 
- ✅ Everything bundled in ONE template spec
- ✅ File system reference (`../../../bicep/deploy/main.bicep`) works during publishing
- ✅ No ACR needed
- ✅ Workload teams only need Template Spec RG access

---

### Step 3: Platform Team Updates (Manual)

Platform team can make two types of changes:

#### Option A: Add Contoso-Specific Resources
Edit `/platform/infra/contoso/main.bicep` to add corporate standards, policies, or additional resources:

```bash
# Edit platform/infra/contoso/main.bicep
# Add corporate standards, policies, etc.

git add platform/
git commit -m "Add App Service support to platform"
git push
```

#### Option B: Customize Upstream Wrappers
Create custom versions of wrappers in `/platform/infra/contoso/wrappers/`:

```bash
# Copy wrapper you want to customize
cp bicep/infra/wrappers/avm.res.key-vault.vault.bicep \
   platform/infra/contoso/wrappers/

# Edit the custom wrapper
# platform/infra/contoso/wrappers/avm.res.key-vault.vault.bicep

git add platform/
git commit -m "Add custom key vault wrapper with Contoso policies"
git push
```

**How Custom Wrappers Work:**
- Preprovision script automatically overlays custom wrappers from `/platform/infra/contoso/wrappers/`
- Custom wrappers overwrite upstream versions in `/bicep/deploy/wrappers/`
- Template specs are built from the customized wrappers
- No need to modify upstream `/bicep/` folder

**Result**: Workflow re-runs, publishes NEW version of `ts-contoso-ailz`

---

### Step 4: Workload Teams Consume (Separate Repos)

Workload teams deploy using Template Spec ID:

#### Option A: Azure CLI
```bash
# Get Template Spec ID
TEMPLATE_SPEC_ID=$(az ts show \
  --name ts-contoso-ailz \
  --version v20241107-a1b2c3d \
  --resource-group rg-platform-templatespecs \
  --query id -o tsv)

# Deploy using Template Spec
az deployment sub create \
  --name my-workload-deployment \
  --location eastus2 \
  --template-spec "$TEMPLATE_SPEC_ID" \
  --parameters deployToggles='{ "logAnalytics": true, ... }' \
               contosoToggles='{ "appService": true }' \
               resourceIds='{ ... }'
```

#### Option B: Bicep Reference
```bicep
// workload-app1-repo/main.bicep

// Reference the platform Template Spec
module infrastructure 'ts/rg-platform-templatespecs:ts-contoso-ailz:v20241107-a1b2c3d' = {
  name: 'contoso-platform-infra'
  params: {
    deployToggles: {
      logAnalytics: true
      appInsights: true
      containerEnv: true
      containerRegistry: true
      cosmosDb: false
      keyVault: true
      storageAccount: true
      searchService: false
      // ... all base toggles
    }
    contosoToggles: {
      appService: true
      sql: false
    }
    resourceIds: {
      // ... existing resource IDs
    }
  }
}

// Workload-specific resources
module myApp './app.bicep' = {
  name: 'my-workload-app'
  params: {
    keyVaultName: infrastructure.outputs.keyVaultName
    // Use outputs from infrastructure module
  }
}
```

---

## Published Artifacts Summary

### All Template Specs (in Platform RG)
| Name | Purpose | Used By |
|------|---------|---------|
| `ts-main-wrp-*` | Individual AVM wrappers | Base AILZ (internal) |
| `ts-contoso-ailz` | **Complete platform infrastructure** | **Workload teams** |

**No ACR modules needed** - everything is Template Specs!

---

## Update Cadence

### Upstream Updates
- **When**: Microsoft releases new AILZ version
- **Who**: Platform team
- **Action**: Pull upstream → Workflow publishes new `ts-contoso-ailz`
- **Impact**: Workload teams choose when to update their Template Spec version reference

### Platform Updates
- **When**: New corporate standards/policies needed
- **Who**: Platform team
- **Action**: Edit `/platform/infra/contoso/` → Workflow publishes new version
- **Impact**: Workload teams pin to specific version, upgrade when ready

### Workload Updates
- **When**: Ready to adopt new platform version
- **Who**: Workload teams
- **Action**: Update Template Spec version in deployment command/bicep
- **Impact**: Only that workload team

---

## Version Pinning Strategy

### Recommended Approach
```bash
# ✅ GOOD: Pin to specific version in production
az deployment sub create --template-spec \
  "ts/rg-platform-templatespecs:ts-contoso-ailz:v20241107-a1b2c3d"

# ⚠️ CAUTION: Use latest only in dev/test
az deployment sub create --template-spec \
  "ts/rg-platform-templatespecs:ts-contoso-ailz:latest"
```

### Platform Team
- **Development**: Can test with `:latest` locally
- **Production**: Tag and publish specific versions

### Workload Teams
- **Development**: Can use `:latest` for quick testing
- **Production**: MUST pin to specific version (e.g., `v20241107-a1b2c3d`)

---

## Rollback Procedure

### If bad platform version published:
```bash
# Workload teams: Use previous version
az deployment sub create --template-spec \
  "ts/rg-platform-templatespecs:ts-contoso-ailz:v20241106-xyz123"
```

### If bad base AILZ version:
```bash
# Platform team: Revert upstream update
git revert HEAD
git push

# Workflow republishes ts-contoso-ailz with previous upstream code
# New version tag reflects new commit, but contains reverted content
```

---

## Access Control

### What Workload Teams Need
1. **Template Spec Reader** role on `rg-platform-templatespecs`
2. **Contributor** role on their own resource groups/subscriptions
3. **No ACR access needed** ✅

### What Platform Team Needs
1. **Template Spec Contributor** on `rg-platform-templatespecs`
2. **Contributor** on target subscription (for deploying wrappers during preprovision)
3. GitHub repository secrets configured (see below)

---

## Required GitHub Secrets

Configure in GitHub repository settings (`Settings > Secrets > Actions`):

| Secret | Example Value | Purpose |
|--------|---------------|---------|
| `AZURE_CLIENT_ID` | `a1b2c3d4-...` | Service principal for OIDC auth |
| `AZURE_TENANT_ID` | `e5f6g7h8-...` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | `i9j0k1l2-...` | Target subscription |
| `AZURE_LOCATION` | `eastus2` | Azure region for Template Specs |
| `AZURE_RESOURCE_GROUP` | `rg-platform-main` | Main resource group (for preprovision) |
| `AZURE_TS_RG` | `rg-platform-templatespecs` | Template Spec resource group |

**Note**: No `AZURE_CONTAINER_REGISTRY_NAME` needed for this approach!

---

## Local Development

### Running Preprovision Locally
```bash
cd bicep

# Set environment variables
export AZURE_LOCATION="eastus2"
export AZURE_RESOURCE_GROUP="rg-platform-main"
export AZURE_TS_RG="rg-platform-templatespecs"

# Run script
./scripts/preprovision.sh

# Verify deploy folder created and custom wrappers applied
ls -la deploy/
ls -la deploy/wrappers/  # Check if custom wrappers were overlayed
```

### Creating Custom Wrappers
```bash
# Create wrappers directory if it doesn't exist
mkdir -p platform/infra/contoso/wrappers

# Copy wrapper you want to customize
cp bicep/infra/wrappers/avm.res.key-vault.vault.bicep \
   platform/infra/contoso/wrappers/

# Edit the custom wrapper
code platform/infra/contoso/wrappers/avm.res.key-vault.vault.bicep

# Test locally by running preprovision
cd bicep
./scripts/preprovision.sh

# Verify your custom wrapper was used
cat deploy/wrappers/avm.res.key-vault.vault.bicep
```

### Testing Platform Module Locally
```bash
cd platform/infra/contoso

# Build to verify syntax
az bicep build --file main.bicep

# Deploy directly (without publishing Template Spec)
az deployment sub create \
  --name test-deployment \
  --location eastus2 \
  --template-file main.bicep \
  --parameters @test.bicepparam
```

---

## Comparison: Template Spec vs ACR Approach

| Aspect | Template Spec Approach | ACR Approach |
|--------|----------------------|--------------|
| **Workload Access** | Template Spec RG only | Template Spec RG + ACR |
| **Artifacts** | Single Template Spec | Template Specs + 2 ACR modules |
| **Workflows** | 1 workflow | 2 workflows |
| **Complexity** | Lower | Higher |
| **Flexibility** | Less (single bundle) | More (layered modules) |
| **Use Case** | Simpler ops, single team | Enterprise, multiple platform teams |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Microsoft AILZ Upstream (GitHub)                           │
│  github.com/Azure/AI-Landing-Zone                           │
└────────────────────┬────────────────────────────────────────┘
                     │ git fetch/checkout
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Platform Repo: <your-org>/ailz-platform                    │
│                                                              │
│  /bicep/                       (pristine upstream)          │
│  /bicep/deploy/                (generated by preprovision)  │
│  /platform/infra/contoso/      (platform customizations)    │
│    ├── main.bicep              (Contoso-specific resources) │
│    └── wrappers/               (custom wrapper overrides)   │
│         └── avm.res.*.bicep    (optional customizations)    │
└────────────────────┬────────────────────────────────────────┘
                     │ GitHub Actions
                     │ (publish-contoso-templatespec.yml)
                     │ preprovision overlays custom wrappers
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Azure Template Spec Resource Group                         │
│  rg-platform-templatespecs                                  │
│                                                              │
│  ├─ ts-main-wrp-avm.res.key-vault.vault                    │
│  ├─ ts-main-wrp-avm.res.storage.storage-account            │
│  ├─ ts-main-wrp-avm.res.*  (all wrappers)                  │
│  │                                                           │
│  └─ ts-contoso-ailz  ◄─── Workload teams reference this    │
│     ├─ v20241107-a1b2c3d                                    │
│     └─ latest                                                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Workload Team Repo: workload-app1                          │
│                                                              │
│  main.bicep references:                                     │
│  ts/rg-platform-templatespecs:ts-contoso-ailz:v20241107     │
└─────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### Error: "Could not find file bicep/deploy/main.bicep"
**Cause**: preprovision.sh hasn't run yet  
**Fix**: Run locally or wait for GitHub Actions to complete

### Error: "Template spec not found"
**Cause**: Workflow hasn't published yet, or wrong resource group  
**Fix**: Check workflow status, verify `AZURE_TS_RG` secret

### Error: "Deployment template validation failed"
**Cause**: Missing required parameters or syntax error  
**Fix**: Run `az bicep build` locally to check syntax

### Workflow fails at preprovision step
**Cause**: Missing Azure secrets or insufficient permissions  
**Fix**: Verify all 6 required secrets are configured with correct values

### Custom wrapper not being used
**Cause**: File name doesn't match exactly or wrong directory  
**Fix**: 
- Ensure wrapper file name matches exactly: `avm.res.key-vault.vault.bicep`
- Place in `/platform/infra/contoso/wrappers/` directory
- Check preprovision logs for "Applying custom wrappers" message

### Want to revert to upstream wrapper
**Cause**: Custom wrapper causing issues  
**Fix**: Delete custom wrapper file and re-run preprovision
```bash
rm platform/infra/contoso/wrappers/avm.res.key-vault.vault.bicep
cd bicep
./scripts/preprovision.sh
```
