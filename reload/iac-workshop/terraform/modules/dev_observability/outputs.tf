output "grafana_url" {
  value       = "http://localhost:${var.grafana_http_port}"
  description = "URL de acceso a Grafana"
}
