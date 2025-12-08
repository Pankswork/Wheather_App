# ============================================================================
# Grafana Dashboard Infrastructure
# ============================================================================

# Grafana ConfigMap
resource "kubernetes_config_map" "grafana_config" {
  count = var.enable_grafana ? 1 : 0
  metadata {
    name      = "grafana-config"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
  }

  data = {
    "grafana.ini" = <<-EOT
      [server]
        domain = ""
        root_url = %(protocol)s://%(domain)s:%(http_port)s/
        serve_from_sub_path = true

      [database]
        type = sqlite3
        path = /var/lib/grafana/grafana.db

      [security]
        admin_user = admin
        admin_password = ${var.grafana_admin_password}
        secret_key = ${var.grafana_admin_password}

      [users]
        allow_sign_up = false
        auto_assign_org_role = Viewer

      [log]
        mode = console
        level = info

      [analytics]
        check_for_updates = false
        reporting_enabled = false

      [dashboards]
        default_home_dashboard_path = /var/lib/grafana/dashboards/default.json
    EOT

    "datasources.yml" = yamlencode({
      apiVersion = 1
      datasources = [
        {
          name = "Prometheus"
          type = "prometheus"
          access = "proxy"
          url = "http://prometheus:9090"
          isDefault = true
          editable = true
        }
      ]
    })
  }
}

# Grafana Deployment
resource "kubernetes_deployment" "grafana" {
  count = var.enable_grafana ? 1 : 0
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
    labels = {
      app = "grafana"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }

      spec {
        container {
          name  = "grafana"
          image = "grafana/grafana:9.3.0"

          port {
            container_port = 3000
            name        = "grafana"
          }

          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = var.grafana_admin_password
          }

          env {
            name  = "GF_INSTALL_PLUGINS"
            value = "grafana-piechart-panel,grafana-worldmap-panel"
          }

          volume_mount {
            name       = "grafana-config-volume"
            mount_path = "/etc/grafana/"
          }

          volume_mount {
            name       = "grafana-storage-volume"
            mount_path = "/var/lib/grafana/"
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "2Gi"
            }
          }

          liveness_probe {
            http_get {
              path = "/api/health"
              port = "grafana"
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/api/health"
              port = "grafana"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }

        volume {
          name = "grafana-config-volume"
          config_map {
            name = kubernetes_config_map.grafana_config[0].metadata[0].name
          }
        }

        volume {
          name = "grafana-storage-volume"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.grafana[0].metadata[0].name
          }
        }
      }
    }
  }
}

# Grafana PVC
resource "kubernetes_persistent_volume_claim" "grafana" {
  count = var.enable_grafana ? 1 : 0
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${var.grafana_storage_size}Gi"
      }
    }
  }
}

# Grafana Service
resource "kubernetes_service" "grafana" {
  count = var.enable_grafana ? 1 : 0
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
    labels = {
      app = "grafana"
    }
    annotations = {
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/load-balancer-name" = "${var.project_name}-grafana-alb-${var.environment}"
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\":80}]"
    }
  }

  spec {
    selector = {
      app = "grafana"
    }

    port {
      port        = 80
      target_port = 3000
      name        = "grafana"
    }

    type = "ClusterIP"
  }
}

# Grafana Ingress
resource "kubernetes_ingress_v1" "grafana" {
  count = var.enable_grafana ? 1 : 0
  metadata {
    name      = "grafana-ingress"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/load-balancer-name" = "${var.project_name}-grafana-alb-${var.environment}"
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\":80}]"
    }
    labels = {
      app = "grafana"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.grafana[0].metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}