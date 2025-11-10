# AI Landing Zone Platform Repository

> **Built on**: [Azure AI Landing Zones](https://github.com/Azure/AI-Landing-Zones) by Microsoft

This repository provides a **platform team implementation** of the Azure AI Landing Zone (AILZ), demonstrating how organizations can extend and customize the upstream AILZ for their specific enterprise requirements.

## What is Azure AI Landing Zone?

The [Azure AI Landing Zone](https://github.com/Azure/AI-Landing-Zones) is Microsoft's enterprise-scale, production-ready reference architecture for deploying secure and resilient AI Apps & Agents solutions in Azure. It:

- Provides an [application landing zone](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/#platform-landing-zones-vs-application-landing-zones) foundation for various AI use cases and scenarios
- Is based on [Azure Verified Modules (AVM)](https://aka.ms/AVM) for Bicep and Terraform
- Aligns with [Cloud Adoption Framework AI Scenario](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/ai/)
- Follows [Well-Architected Framework for AI workloads](https://learn.microsoft.com/azure/well-architected/ai/)
- Can be deployed with or without platform landing zones

### Key Features

✅ **Secure by default** - Private endpoints, managed identities, network isolation  
✅ **Production-ready** - Monitoring, logging, backup, disaster recovery  
✅ **Extensible** - Deploy with or without platform landing zones  
✅ **Multi-scenario** - Chat, Agents, RAG, Document generation, and more  
✅ **IaC-based** - Portal, Bicep, and Terraform implementations  

For complete details, see the [upstream documentation](https://github.com/Azure/AI-Landing-Zones/blob/main/README.md).

---

## About This Repository

This is a **platform customization layer** showing how enterprise platform teams can:

1. **Reference upstream AILZ** as a baseline
2. **Add corporate standards** (naming, tagging, policies, resources)
3. **Customize wrappers** for specific organizational requirements
4. **Publish versioned modules** for workload teams to consume

### Repository Structure

```
/bicep/                          # Pristine upstream AILZ (fetched from Microsoft repo)
/platform/infra/my-company/      # Your platform team's customizations
  ├── main.bicep                 # Corporate standards & additional resources
  ├── wrappers/                  # Custom wrapper overrides (optional)
  └── common/types.bicep         # Extended type definitions
/.github/workflows/              # CI/CD pipelines for publishing modules
```

---

## Deployment Approaches

This repository demonstrates **two publishing strategies**. Choose based on your needs:

### ⭐ Template Spec Approach (Recommended - Start Here)

**Best for most organizations** - simpler operations, easier to maintain

✅ **Pros:**
- Single Template Spec for workload teams to consume
- No Azure Container Registry required
- One GitHub Actions workflow
- Simpler access control (Template Spec RG only)
- Custom wrappers automatically overlayed during build

❌ **Cons:**
- Less flexible for multi-team scenarios
- Single bundle (not as composable)

📖 **Full Guide**: [DEPLOYMENT-FLOW-TEMPLATESPEC.md](DEPLOYMENT-FLOW-TEMPLATESPEC.md)

---

### 🏢 ACR Module Approach (Alternative - For Enterprise Scale)

**Best for large enterprises** with multiple platform teams or complex governance

✅ **Pros:**
- Layered modules (base AILZ + platform layer)
- More composable and flexible
- Better for multiple platform teams
- Workload teams can mix base + platform modules

❌ **Cons:**
- Requires Azure Container Registry
- Two GitHub Actions workflows to maintain
- More complex access control (ACR + Template Spec RG)
- Higher operational overhead

📖 **Full Guide**: [DEPLOYMENT-FLOW.md](DEPLOYMENT-FLOW.md)

---

**💡 Recommendation**: Start with the **Template Spec approach** unless you have specific enterprise requirements that demand the ACR layering model.

---

## Quick Start

### Prerequisites

- Azure subscription with Contributor access
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed
- [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install) installed
- GitHub repository with OIDC federation configured (for CI/CD)

### 1. Fork This Repository

```bash
# Fork this repository to your organization
# Via GitHub UI: Click "Fork" button, or via CLI:
gh repo fork <this-repo> --org your-org --clone
cd ailz-platform
```

### 2. Customize for Your Organization

```bash
# Rename "my-company" folder to your company name
mv platform/infra/my-company platform/infra/your-company

# Update all references from "my-company" to "your-company"
# in workflows, docs, and bicep files
```

### 3. Sync with Upstream AILZ

```bash
# Add Microsoft's AILZ as upstream remote
git remote add ailz-upstream https://github.com/Azure/AI-Landing-Zones.git
git fetch ailz-upstream

# Pull latest bicep folder
git checkout ailz-upstream/main -- bicep/
git commit -m "Update to AILZ version X.Y.Z"
```

### 4. Configure GitHub Secrets

Set these in `Settings > Secrets and variables > Actions`:

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Service principal client ID (OIDC) |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target subscription ID |
| `AZURE_LOCATION` | Azure region (e.g., eastus2) |
| `AZURE_RESOURCE_GROUP` | Main resource group name |
| `AZURE_TS_RG` | Template Spec resource group |
| `AZURE_CONTAINER_REGISTRY_NAME` | ACR name (ACR approach only) |

### 5. Test Locally

```bash
cd bicep

# Set environment variables
export AZURE_LOCATION="eastus2"
export AZURE_RESOURCE_GROUP="rg-platform-test"
export AZURE_TS_RG="rg-platform-templatespecs"

# Run preprovision script
./scripts/preprovision.sh

# Verify deploy folder created
ls -la deploy/
```

### 6. Deploy via GitHub Actions

Push changes to trigger the workflow:

```bash
git add .
git commit -m "Configure platform for your-company"
git push
```

---

## Use Cases Supported

The AILZ foundation supports various AI scenarios:

- **Chat Applications** using Azure AI Foundry
- **AI Agents** with tool calling and orchestration
- **RAG (Retrieval-Augmented Generation)** with vector search
- **Document Generation** and processing
- **Conversational Knowledge Mining**
- **Custom Copilots** for domain-specific tasks

See the [upstream use cases documentation](https://github.com/Azure/AI-Landing-Zones#use-cases--scenarios) for details.

---

## Design Principles

This implementation follows:

- [Cloud Adoption Framework AI Scenario](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/ai/)
- [Well-Architected Framework for AI](https://learn.microsoft.com/azure/well-architected/ai/)
- [Azure Verified Modules](https://aka.ms/AVM) standards

---

## Contributing

This is a **reference implementation** showing one way to customize AILZ. Feel free to:

- Fork and adapt for your organization
- Share improvements via pull requests
- Open issues for questions or bugs

For contributing to the **upstream AILZ**, see [Azure/AI-Landing-Zones](https://github.com/Azure/AI-Landing-Zones).

---

## Resources

- **Upstream Repository**: [Azure/AI-Landing-Zones](https://github.com/Azure/AI-Landing-Zones)
- **AILZ Documentation**: [aka.ms/ailz](https://aka.ms/ailz)
- **CAF AI Scenario**: [aka.ms/caf/ai](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/ai/)
- **WAF AI Workload**: [aka.ms/waf/ai](https://learn.microsoft.com/azure/well-architected/ai/)
- **Azure Verified Modules**: [aka.ms/avm](https://aka.ms/AVM)

---

## License

This project uses the same license as the upstream Azure AI Landing Zones.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general).