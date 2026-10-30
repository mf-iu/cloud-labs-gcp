# prefix, owner, suffix, project, region and placefinder_image are set by
# tools/tofu.sh from config.env

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

variable "prefix" {
  description = "Project prefix for all names"
  type        = string
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

variable "owner" {
  description = "Initials of the participant"
  type        = string
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

variable "suffix" {
  description = "Random suffix for globally unique names (.state/suffix)"
  type        = string
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

variable "project" {
  description = "Google Cloud project id"
  type        = string
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

variable "region" {
  description = "Google Cloud region"
  type        = string
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

variable "placefinder_image" {
  description = "Image repository of PlaceFinder without tag (PLACEFINDER_IMAGE in config.env)"
  type        = string
}
