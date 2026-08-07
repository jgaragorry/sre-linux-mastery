variable "environment" {
  type        = string
  description = "Entorno objetivo de despliegue"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Instancia compatible con AWS Free Tier"
}

variable "project_name" {
  type        = string
  default     = "sre-lab"
  description = "Identificador general del proyecto"
}

variable "allowed_ssh_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "Segmento IP autorizado para SSH"
}
