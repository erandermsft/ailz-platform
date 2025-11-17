locals {
	repo_metadata = {
		id             = github_repository.ailz-repo.id
		name           = github_repository.ailz-repo.name
		full_name      = github_repository.ailz-repo.full_name
		html_url       = github_repository.ailz-repo.html_url
		http_clone_url = github_repository.ailz-repo.http_clone_url
		ssh_clone_url  = github_repository.ailz-repo.ssh_clone_url
		default_branch = github_repository.ailz-repo.default_branch
	}

	workload_package = {
		source_relative_path = "workload"
		target_relative_path = "workload"
	}
}

output "github_repository" {
	description = "Metadata for the GitHub repository provisioned for this application."
	value       = local.repo_metadata
}

output "workload_package" {
	description = "Relative paths that identify how to copy the workload assets into the provisioned repository."
	value       = local.workload_package
}

output "repo_full_name" {
	description = "Full name (org/repo) of the provisioned repository."
	value       = local.repo_metadata.full_name
}

output "repo_default_branch" {
	description = "Default branch name for the provisioned repository."
	value       = local.repo_metadata.default_branch
}



