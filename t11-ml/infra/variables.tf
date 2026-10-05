# prefix, owner, suffix, project, region and placefinder_image are set by
# tools/tofu.sh from config.env

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

variable "placefinder_image" {
  description = "Image repository of PlaceFinder without tag"
  type        = string
}

variable "image_tag" {
  description = "Image with the /estimate endpoint"
  type        = string
  default     = "t11"
}

variable "model_object" {
  description = "Object name of the trained model in the bucket"
  type        = string
  default     = "models/estimate/model.joblib"
}
