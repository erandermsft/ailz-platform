# Onboarding Terraform Module

This folder contains the Terraform configuration that provisions the prerequisites to onboard the Azure AI Landing Zone. The automation creates:

- A private GitHub repository prepared for the landing zone workload
- An Azure AD application and service principal bound to the target subscription
- Supporting GitHub Actions variables and federated credentials for OIDC-based automation

## Prerequisites

- Terraform v1.5 or later installed locally, or the GitHub Actions workflow in `.github/workflows/onboard.yml`
- Azure CLI or `azurerm` provider authentication with rights to the target subscription
- Access to create repositories within the configured GitHub organization

## Usage

```bash
terraform init
terraform plan -var "ONBOARD_SUB_ID=<subscription-guid>" -var "APPID=<appid>" -var "GITHUB_ORG=<org-name>"
terraform apply -auto-approve
```

Alternatively, trigger the **Onboard AI Landing Zone** workflow and supply the required inputs (`subscription_id` and `appid`). The workflow runs the same Terraform configuration to provision the assets listed above and seeds the new repository with the landing zone workload.

## Outputs

Run `terraform output` to inspect provisioning details, including repository identifiers and URLs needed for post-deployment steps.
