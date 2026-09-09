variable "environment" {
  type        = string
  description = "Nombre del ambiente (prod)"
  default     = "prod"
}

variable "subnet_cidr" {
  type        = string
  description = "Subred para los contenedores"
  default     = "172.28.0.0/16"
}
