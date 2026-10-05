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

variable "schedule" {
  description = "When the update runs (cron, time zone Europe/Berlin)"
  type        = string
  default     = "30 6 * * *"
}

variable "database_url" {
  description = "Optional PostgreSQL connection string; empty = only store the files"
  type        = string
  default     = ""
  sensitive   = true
}
