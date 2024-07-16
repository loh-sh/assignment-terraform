locals {
  project_name = "mbb-assigment"
  common_tags = {
    Project   = local.project_name
    ManagedBy = "Terraform"
  }
}