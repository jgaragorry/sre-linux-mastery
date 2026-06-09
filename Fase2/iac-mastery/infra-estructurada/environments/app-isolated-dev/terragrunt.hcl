terraform {
  # Apuntamos al nuevo módulo de red aislada
  source = "../../modules/app-red-aislada"
}

inputs = {
  nombre_red     = "red-interna-dev"
  nombre_app     = "apache-dev"
  puerto_externo = 8091
}
