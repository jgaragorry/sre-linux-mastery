include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../terraform/modules/dev_observability"
}

inputs = {
  environment       = "dev"
  grafana_http_port = 3000
}
