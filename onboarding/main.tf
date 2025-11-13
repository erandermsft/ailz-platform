resource "github_repository" "ailz-repo" {
  name        = "az-ailz-${var.APPID}-${var.RANDOM}"
  description = "Repository for Azure AI Landing Zone - ${var.APPID} - ${var.RANDOM}"
  auto_init   = true
  visibility = "private"
}

resource "azurerm_user_assigned_identity" "ai-lz-umi" {
  provider            = azurerm.onboarded
  name                = "umi-${var.APPID}-${var.RANDOM}"
  location            = local.geo["${var.GEO}"].location
  resource_group_name = azurerm_resource_group.rg-ai-core-infra.name
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_federated_identity_credential" "fc_ai-lz-umi_github" {
  provider = azurerm.onboarded
  audience = [
    "api://AzureADTokenExchange"
  ]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:xxxxxxx/az-ailz-${var.APPID}-${var.RANDOM}:ref:refs/heads/main" # TODO: Make repo dynamic
  parent_id           = azurerm_user_assigned_identity.ai-lz-umi.id
  name                = "fc-az-ailz-${var.APPID}-${var.RANDOM}-main"
  resource_group_name = azurerm_resource_group.rg-ai-core-infra.name
}

resource "github_actions_variable" "clientid" {
  repository       = github_repository.ailz-repo.name
  variable_name    = "CLIENTID"
  value            = azurerm_user_assigned_identity.ai-lz-umi.client_id
}

resource "github_actions_variable" "appname" {
  repository       = github_repository.ailz-repo.name
  variable_name    = "NAME"
  value            = "${var.APPID}-${var.RANDOM}"
}

resource "github_actions_variable" "subscriptionid" {
  repository       = github_repository.ailz-repo.name
  variable_name    = "SUBSCRIPTIONID"
  value            = var.ONBOARD_SUB_ID
}

/*
Needs to be part of a github organization to do this

resource "github_team" "ailz-team" {
  name        = "ghtm-${var.APPID}-${var.RANDOM}-1"
  description = "AI LZ Team - ${var.APPID} - ${var.RANDOM}"
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