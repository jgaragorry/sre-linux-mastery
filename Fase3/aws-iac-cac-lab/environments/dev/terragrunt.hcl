include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/aws_ec2"
}

inputs = {
  environment   = "dev"
  instance_type = "t3.micro"
  project_name  = "sre-lab"
}
