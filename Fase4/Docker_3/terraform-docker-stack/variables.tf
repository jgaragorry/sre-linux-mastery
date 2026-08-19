variable "environment" {
  type        = string
  description = "Ambiente de despliegue"
  default     = "production"
}

variable "frontend_port" {
  type        = number
  description = "Puerto expuesto en el Host para el Proxy NGINX"
  default     = 8080
}

variable "db_password" {
  type        = string
  description = "Clave del usuario postgres"
  default     = "SreMasterySecret2026"
  sensitive   = true
}
