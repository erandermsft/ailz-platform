# AILZ Platform Deployment Flow

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

#### Job 1: Publish Template Specs
```
┌─────────────────────────────────────────┐
│  Run preprovision.sh                    │
│  ├─ Create /bicep/deploy/               │
│  ├─ Build wrapper template specs        │
│  │  └─ ts-main-wrp-avm.res.*.bicep     │
│  └─ Replace wrappers with TS refs       │
│     in deploy/main.bicep                │
└─────────────────────────────────────────┘
          ↓
  Upload bicep/deploy/ as artifact
```

**Publishes to Platform RG**:
- `ts-main-wrp-avm.res.key-vault.vault`
- `ts-main-wrp-avm.res.storage.storage-account`
- `ts-main-wrp-avm.res.*.bicep` (all wrappers)

#### Job 2: Publish Base AILZ Template Spec
```
┌─────────────────────────────────────────┐
│  Download bicep/deploy/                 │
│  Build deploy/main.bicep → main.json    │
│  Publish template spec:                 │
│  ├─ Name: ts-ailz-platform-base        │
│  ├─ Version: v20241106-a1b2c3d          │
│  └─ Version: latest                     │
└─────────────────────────────────────────┘
```

**Publishes to Platform RG**:
- `ts-ailz-platform-base:v20241106-a1b2c3d`
- `ts-ailz-platform-base:latest`

#### Job 3: Publish to ACR
```
┌─────────────────────────────────────────────────────────┐
│  Publish Base AILZ Module                               │
│  ├─ br:myacr.azurecr.io/bicep/ailz/base:v20241106      │
│  └─ br:myacr.azurecr.io/bicep/ailz/base:latest         │
│                                                          │
│  Publish Contoso Platform Module                        │
│  ├─ br:myacr.azurecr.io/bicep/platform/contoso:v20241106│
│  └─ br:myacr.azurecr.io/bicep/platform/contoso:latest  │
└─────────────────────────────────────────────────────────┘
```

**Publishes to Central ACR**:
- `bicep/ailz/base:v20241106-a1b2c3d` ← Transformed main.bicep with TS refs
- `bicep/ailz/base:latest`
- `bicep/platform/contoso:v20241106-a1b2c3d` ← Platform team's customizations
- `bicep/platform/contoso:latest`

---

### Step 3: Platform Team Updates (Manual)
Platform team makes changes to `/platform/infra/contoso/`:

```bash
# Edit platform/infra/contoso/main.bicep
# Add corporate standards, policies, etc.

git add platform/
git commit -m "Add Azure SQL support to platform"
git push
```

**Result**: Workflow re-runs, publishes NEW version of `bicep/platform/contoso`

---

### Step 4: Workload Teams Consume (Separate Repos)

Workload teams reference the platform module:

```bicep
// workload-app1-repo/main.bicep
module infrastructure 'br:myacr.azurecr.io/bicep/platform/contoso:v20241106-a1b2c3d' = {
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
  }
}

// Workload-specific resources
module myApp './app.bicep' = {
  name: 'my-workload-app'
  params: {
    // Use outputs from infrastructure module
  }
}
```

---

## Published Artifacts Summary

### Template Specs (in Platform RG)
| Name | Purpose | Used By |
|------|---------|---------|
| `ts-main-wrp-*` | Individual AVM wrappers | Base AILZ module |
| `ts-ailz-platform-base` | Transformed main.bicep | (Optional) Direct consumption |

### ACR Modules (in Central ACR)
| Path | Purpose | Used By |
|------|---------|---------|
| `bicep/ailz/base` | Base AILZ infrastructure | Platform team |
| `bicep/platform/contoso` | Platform + corporate standards | Workload teams |

---

## Update Cadence

### Upstream Updates
- **When**: Microsoft releases new AILZ version
- **Who**: Platform team
- **Action**: Pull upstream → Workflow publishes new base
- **Impact**: Platform team decides when to update `main.bicep` reference

### Platform Updates
- **When**: New corporate standards/policies needed
- **Who**: Platform team
- **Action**: Edit `/platform/infra/contoso/` → Workflow publishes new version
- **Impact**: Workload teams pin to specific version, upgrade when ready

### Workload Updates
- **When**: Ready to adopt new platform version
- **Who**: Workload teams
- **Action**: Update module version in their repo
- **Impact**: Only that workload team

---

## Version Pinning Strategy

### Recommended Approach
```bicep
// ✅ GOOD: Pin to specific version in production
module infra 'br:myacr.azurecr.io/bicep/platform/contoso:v20241106-a1b2c3d' = {

// ⚠️ CAUTION: Use latest only in dev/test
module infra 'br:myacr.azurecr.io/bicep/platform/contoso:latest' = {
```

### Platform Team
- **Development**: Reference `bicep/ailz/base:latest` in `bicepconfig.json`
- **Production**: Pin to specific version when stable

### Workload Teams
- **Development**: Can use `:latest` for quick testing
- **Production**: MUST pin to specific version (e.g., `v20241106-a1b2c3d`)

---

## Rollback Procedure

### If bad platform version published:
```bash
# Workload teams: Use previous version
module infra 'br:myacr.azurecr.io/bicep/platform/contoso:v20241105-xyz123' = {
```

### If bad base AILZ version:
```bash
# Platform team: Revert upstream
git revert HEAD
git push
# Workflow republishes previous version with new tag
```

---

## Required Secrets

Configure in GitHub repository settings:

- `AZURE_CLIENT_ID` - Service principal for authentication
- `AZURE_TENANT_ID` - Azure tenant ID
- `AZURE_SUBSCRIPTION_ID` - Target subscription
- `AZURE_CONTAINER_REGISTRY_NAME` - ACR name (without .azurecr.io)
- `AZURE_LOCATION` - Azure region (e.g., eastus2)
- `AZURE_RESOURCE_GROUP` - Main resource group
- `AZURE_TS_RG` - Template Spec resource group (platform team's RG)
