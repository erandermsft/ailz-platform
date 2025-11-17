terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

// Create a GitHub Repository

resource "github_repository" "ailz-repo" {
  name        = "az-ailz-${var.APPID}"
  description = "Repository for Azure AI Landing Zone - ${var.APPID}"
  auto_init   = true
  visibility  = "private"
}

// Creating Azure AD Application and Service Principal

data "azuread_client_config" "current" {}

resource "azuread_application" "ai-lz-app" {
  display_name = "app-${var.APPID}"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "ai-lz-sp" {
  client_id = azuread_application.ai-lz-app.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

// Role Assignment to the Service Principal

resource "azurerm_role_assignment" "ai-lz-sp-role-assignment" {
  scope                            = "/subscriptions/${var.ONBOARD_SUB_ID}"
  role_definition_name             = "Contributor"
  principal_id                     = azuread_service_principal.ai-lz-sp.object_id
  skip_service_principal_aad_check = true

  depends_on = [
    azuread_service_principal.ai-lz-sp
  ]
}

// --
// TODO: Add RBAC assignments as needed
// --


// Create a federated identity credential for GitHub Actions

resource "azuread_application_federated_identity_credential" "fc_ai-lz-app_github" {
  application_id = azuread_application.ai-lz-app.id
  display_name   = "fc-az-ailz-${var.APPID}-main"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.GITHUB_ORG}/az-ailz-${var.APPID}:ref:refs/heads/main"
}

// Add variables to GitHub Actions
//TODO: Add more variables as needed

resource "github_actions_variable" "clientid" {
  repository    = github_repository.ailz-repo.name
  variable_name = "CLIENTID"
  value         = azuread_application.ai-lz-app.client_id
}

resource "github_actions_variable" "appname" {
  repository       = github_repository.ailz-repo.name
  variable_name    = "NAME"
  value            = "${var.APPID}"
}

resource "github_actions_variable" "subscriptionid" {
  repository       = github_repository.ailz-repo.name
  variable_name    = "SUBSCRIPTIONID"
  value            = var.ONBOARD_SUB_ID
}

// TODO Fix this:
// Assign GitHub Team to the Repository
// Strategy - sync github teams with security groups in azure ad

/*
resource "github_team" "ailz-team" {
  name        = "ghtm-${var.APPID}-1"
  description = "AI LZ Team - ${var.APPID}"
  privacy     = "closed"

  create_default_maintainer = true
}

resource "github_team_members" "ailz-team-members" {
  team_id = github_team.ailz-team.id

  members {
    username = "xxxxx"
  }
}

resource "github_team_repository" "ailz-team-repo" {
  team_id    = github_team.ailz-team.id
  repository = github_repository.ailz-repo.name
  permission = "admin"
}

*/