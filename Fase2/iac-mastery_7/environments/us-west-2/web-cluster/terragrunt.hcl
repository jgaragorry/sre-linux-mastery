include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules//web_node"
}

inputs = {
  ami_id        = "ami-03f1594ff9e800673" # Ubuntu 22.04 LTS en us-west-2
  instance_type = "t3.micro"
  environment   = "us-west-2-backup"
}
