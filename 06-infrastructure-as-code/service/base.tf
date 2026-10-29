# The outputs of base: network, bucket, image repository and service
# account. base stays until the end of the course; service is created and
# destroyed in the session.
data "terraform_remote_state" "base" {
  backend = "gcs"
  config  = merge(var.backend, { prefix = "06-infrastructure-as-code/base" })
}

locals {
  name = "${var.prefix}-${var.owner}-t08"
  base = data.terraform_remote_state.base.outputs
}
