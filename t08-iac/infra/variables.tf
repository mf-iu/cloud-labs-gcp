# prefix, owner, suffix, project, region, placefinder_image and admin_cidrs
# are set by tools/tofu.sh from config.env

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
  description = "Google Cloud project id"
  type        = string
}

variable "region" {
  type = string
}

variable "placefinder_image" {
  description = "Image repository of PlaceFinder without tag (PLACEFINDER_IMAGE in config.env)"
  type        = string
}

variable "image_tag" {
  description = "Image tag to deploy"
  type        = string
  default     = "t07"
}

variable "enable_database" {
  description = "Create the Cloud SQL instance (costs money, delete it after the lab)"
  type        = bool
  default     = false
}

variable "admin_cidrs" {
  description = "Networks that may connect to the database; tools/tofu.sh sets your IP"
  type        = list(string)
  default     = []
}
