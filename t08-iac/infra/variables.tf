# prefix, owner, suffix, project, region and placefinder_image are set by
# tools/tofu.sh from config.env

variable "prefix" {
  description = "Project prefix for all names"
  type        = string
}

variable "owner" {
  description = "Initials of the participant"
  type        = string
}

variable "suffix" {
  description = "Random suffix for globally unique names (.state/suffix)"
  type        = string
}

variable "project" {
  description = "Google Cloud project id"
  type        = string
}

variable "region" {
  description = "Google Cloud region"
  type        = string
}

variable "placefinder_image" {
  description = "Image repository of PlaceFinder without tag (PLACEFINDER_IMAGE in config.env)"
  type        = string
}

variable "image_tag" {
  description = "Image tag to deploy first; the pipeline deploys later versions"
  type        = string
  default     = "t08"
}

variable "enable_database" {
  description = "Create Cloud SQL for PostgreSQL with a private address (costs money, destroy it after the lab)"
  type        = bool
  default     = false
}

variable "max_instances" {
  description = "Upper limit for the number of PlaceFinder instances"
  type        = number
  default     = 2
}
