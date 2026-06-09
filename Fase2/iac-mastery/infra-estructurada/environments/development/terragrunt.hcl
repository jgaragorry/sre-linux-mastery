# Le decimos a Terragrunt dónde está el molde único de Terraform
terraform {
  source = "../../modules/contenedor-base"
}

# Le pasamos los valores específicos para el entorno de DESARROLLO
inputs = {
  nombre_contenedor = "web-entorno-dev"
  puerto_externo    = 8081
}
