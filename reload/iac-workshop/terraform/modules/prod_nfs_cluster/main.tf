resource "docker_network" "prod_net" {
  name = "${var.environment}-network"
  ipam_config {
    subnet = var.subnet_cidr
  }
}

resource "docker_image" "ubuntu_base" {
  name         = "ubuntu:24.04"
  keep_locally = true
}

# Servidor NFS de Usuarios
resource "docker_container" "nfs_server" {
  name       = "${var.environment}-nfs-server"
  image      = docker_image.ubuntu_base.image_id
  privileged = true
  command    = ["sleep", "infinity"]

  networks_advanced {
    name         = docker_network.prod_net.name
    ipv4_address = cidrhost(var.subnet_cidr, 10)
  }
}

# Cliente NFS de Usuarios
resource "docker_container" "nfs_client" {
  name       = "${var.environment}-nfs-client"
  image      = docker_image.ubuntu_base.image_id
  privileged = true
  command    = ["sleep", "infinity"]

  networks_advanced {
    name         = docker_network.prod_net.name
    ipv4_address = cidrhost(var.subnet_cidr, 20)
  }

  depends_on = [docker_container.nfs_server]
}
