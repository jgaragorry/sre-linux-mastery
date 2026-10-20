variable "environment" {
  type        = string
  description = "Nombre del ambiente (dev)"
  default     = "dev"
}

variable "grafana_http_port" {
  type        = number
  description = "Puerto externo para Grafana"
  default     = 3000
}
