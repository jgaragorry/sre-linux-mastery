# Red aislada para Dev
resource "docker_network" "dev_net" {
  name = "${var.environment}-network"
}

# 1. Definición declarativa del Datasource (TestData nativo)
locals {
  datasources_yaml = <<-EOT
    apiVersion: 1
    datasources:
      - name: AutoTestData
        type: testdata
        access: proxy
        isDefault: true
        editable: false
  EOT

  dashboards_provider_yaml = <<-EOT
    apiVersion: 1
    providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: true
        editable: true
        options:
          path: /etc/grafana/provisioning/dashboards
  EOT

  # Dashboard que genera métricas en tiempo real (ventana de 2 minutos)
  sample_dashboard_json = jsonencode({
    annotations = { list = [] }
    editable    = true
    fiscalYearStartMonth = 0
    graphTooltip = 0
    links       = []
    liveNow     = true
    panels = [
      {
        type  = "timeseries"
        title = "Tráfico en Tiempo Real (Últimos 2 Minutos)"
        gridPos = {
          h = 9
          w = 12
          x = 0
          y = 0
        }
        id = 1
        targets = [
          {
            datasource = {
              type = "testdata"
              uid  = "AutoTestData"
            }
            scenarioId = "random_walk"
            seriesCount = 1
            alias       = "Transacciones/seg"
            refId       = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            custom = {
              drawStyle = "line"
              lineInterpolation = "smooth"
            }
          }
        }
      },
      {
        type  = "stat"
        title = "Estado del Servicio"
        gridPos = {
          h = 9
          w = 12
          x = 12
          y = 0
        }
        id = 2
        targets = [
          {
            datasource = {
              type = "testdata"
              uid  = "AutoTestData"
            }
            scenarioId = "random_walk"
            refId       = "B"
          }
        ]
      }
    ]
    refresh       = "5s"
    schemaVersion = 38
    style         = "dark"
    tags          = ["workshop", "dev"]
    time = {
      from = "now-2m"
      to   = "now"
    }
    timepicker = {
      refresh_intervals = ["5s", "10s", "30s"]
    }
    timezone = "browser"
    title    = "Métricas Rápidas Dev (Auto-Provisioned)"
    version  = 1
  })
}

# Creación de archivos en el host para montarlos como volúmenes
resource "local_file" "ds_file" {
  content  = local.datasources_yaml
  filename = "${path.module}/provisioning/datasources/datasources.yaml"
}

resource "local_file" "dash_provider_file" {
  content  = local.dashboards_provider_yaml
  filename = "${path.module}/provisioning/dashboards/provider.yaml"
}

resource "local_file" "dash_json_file" {
  content  = local.sample_dashboard_json
  filename = "${path.module}/provisioning/dashboards/realtime-sample.json"
}

resource "docker_image" "grafana" {
  name         = "grafana/grafana:latest"
  keep_locally = true
}

resource "docker_container" "grafana" {
  name  = "${var.environment}-grafana"
  image = docker_image.grafana.image_id

  networks_advanced {
    name = docker_network.dev_net.name
  }

  ports {
    internal = 3000
    external = var.grafana_http_port
  }

  env = [
    "GF_SECURITY_ADMIN_USER=admin",
    "GF_SECURITY_ADMIN_PASSWORD=admin",
    "GF_AUTH_ANONYMOUS_ENABLED=true",
    "GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer"
  ]

  volumes {
    host_path      = abspath(local_file.ds_file.filename)
    container_path = "/etc/grafana/provisioning/datasources/datasources.yaml"
    read_only      = true
  }

  volumes {
    host_path      = abspath(local_file.dash_provider_file.filename)
    container_path = "/etc/grafana/provisioning/dashboards/provider.yaml"
    read_only      = true
  }

  volumes {
    host_path      = abspath(local_file.dash_json_file.filename)
    container_path = "/etc/grafana/provisioning/dashboards/realtime-sample.json"
    read_only      = true
  }
}
