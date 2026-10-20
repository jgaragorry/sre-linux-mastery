output "public_ip" {
  value       = aws_instance.server.public_ip
  description = "Dirección IP Pública del nodo"
}

output "private_key_path" {
  value       = local_sensitive_file.private_key.filename
  description = "Ruta de la llave privada SSH"
}
