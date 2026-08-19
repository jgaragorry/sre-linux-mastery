# 1. Red Privada Aislada (Bridge Personalizado)
resource "docker_network" "private_network" {
  name   = "${var.environment}-tier-backend-network"
  driver = "bridge"
  ipam_config {
    subnet = "10.10.0.0/16"
  }
}

# 2. Volumen Persistente para Base de Datos
resource "docker_volume" "postgres_data" {
  name = "${var.environment}-db-data-persistent"
}

# 3. Imágenes Base Requeridas
resource "docker_image" "postgres" {
  name         = "postgres:16-alpine"
  keep_locally = true
}

resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = true
}

# 4. Construcción de Imagen del Microservicio (Distroless Hardened)
resource "docker_image" "api_app" {
  name = "api-microservice:${var.environment}"
  build {
    context = "./app"
    tag     = ["api-microservice:${var.environment}"]
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset("./app", "*") : filesha1("./app/${f}")]))
  }
}

# 5. Contenedor de Base de Datos (Aislado)
resource "docker_container" "db" {
  name         = "db-postgres"
  image        = docker_image.postgres.image_id
  restart      = "unless-stopped"
  memory       = 256
  cpu_shares   = 1024

  networks_advanced {
    name = docker_network.private_network.name
  }

  volumes {
    volume_name    = docker_volume.postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }

  env = [
    "POSTGRES_USER=postgres",
    "POSTGRES_PASSWORD=${var.db_password}",
    "POSTGRES_DB=sredb"
  ]
}

# 6. Contenedor del Microservicio API (Aislado)
resource "docker_container" "api" {
  name         = "api-service"
  image        = docker_image.api_app.image_id
  restart      = "unless-stopped"
  memory       = 128
  cpu_shares   = 512

  networks_advanced {
    name = docker_network.private_network.name
  }

  env = [
    "DB_HOST=db-postgres",
    "DB_USER=postgres",
    "DB_PASSWORD=${var.db_password}",
    "DB_NAME=sredb"
  ]

  depends_on = [docker_container.db]
}

# 7. Contenedor Reverse Proxy Frontend (Único punto de entrada público)
resource "docker_container" "proxy" {
  name       = "proxy-frontend"
  image      = docker_image.nginx.image_id
  restart    = "unless-stopped"
  memory     = 128
  cpu_shares = 512

  networks_advanced {
    name = docker_network.private_network.name
  }

  ports {
    internal = 80
    external = var.frontend_port
    ip       = "0.0.0.0"
  }

  upload {
    content = file("${path.module}/nginx.conf")
    file    = "/etc/nginx/nginx.conf"
  }

  depends_on = [docker_container.api]
}
