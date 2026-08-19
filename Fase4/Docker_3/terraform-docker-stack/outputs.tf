output "entrypoint_url" {
  description = "URL pública de acceso al servicio"
  value       = "http://localhost:${var.frontend_port}"
}

output "private_network_name" {
  description = "Nombre de la red aislada creada"
  value       = docker_network.private_network.name
}

output "database_volume_name" {
  description = "Nombre del volumen persistente de la base de datos"
  value       = docker_volume.postgres_data.name
}
