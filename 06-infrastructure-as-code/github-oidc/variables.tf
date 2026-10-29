# prefix, owner, suffix, project and region are set by tools/tofu.sh

variable "prefix" {
  type = string
}

variable "owner" {
  type = string
}

variable "suffix" {
  type = string
}

variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "github_repository" {
  description = "Repository that may deploy, e.g. \"jdoe/placefinder\""
  type        = string
}

variable "github_branch" {
  description = "Only workflow runs on this branch get credentials"
  type        = string
  default     = "master"
}

variable "pool_id" {
  description = "Pool id; deleted pools stay reserved for 30 days, so choose a new one after a destroy"
  type        = string
  default     = null
}
