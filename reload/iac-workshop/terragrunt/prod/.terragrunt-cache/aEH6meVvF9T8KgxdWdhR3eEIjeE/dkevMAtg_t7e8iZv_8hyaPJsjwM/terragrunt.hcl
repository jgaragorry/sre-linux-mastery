include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../terraform/modules/prod_nfs_cluster"
}

inputs = {
  environment = "prod"
  subnet_cidr = "172.28.0.0/16"
}
