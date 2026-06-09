# Apuntamos exactamente al mismo molde único
terraform {
  source = "../../modules/contenedor-base"
}

# Le pasamos los valores específicos para el entorno de PRODUCCIÓN
inputs = {
  nombre_contenedor = "web-entorno-prod"
  puerto_externo    = 8082
}
