variable "ONBOARD_SUB_ID" {
  description = "The Azure Subscription ID for onboarding"
  type        = string
}

variable "GEO" {
  description = "The Azure region to use"
  type        = string
  default     = "swdn"
}

variable "APPID" {
  description = "The application ID"
  type        = string
}

variable "RANDOM" {
  description = "Random string to append to resource names"
  type        = string
}

variable "GITHUB_ORG" {
  description = "GitHub organization name"
  type        = string
}


