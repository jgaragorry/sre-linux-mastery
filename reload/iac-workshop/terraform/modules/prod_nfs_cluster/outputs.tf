output "server_ip" {
  value       = cidrhost(var.subnet_cidr, 10)
  description = "Dirección IP interna del Servidor NFS"
}

output "client_ip" {
  value       = cidrhost(var.subnet_cidr, 20)
  description = "Dirección IP interna del Cliente NFS"
}
