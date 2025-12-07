# ============================================================================
# Prometheus Monitoring Infrastructure
# ============================================================================

# Prometheus Namespace
resource "kubernetes_namespace" "monitoring" {
  count = var.enable_prometheus ? 1 : 0
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

# Prometheus ConfigMap
resource "kubernetes_config_map" "prometheus_config" {
  count = var.enable_prometheus ? 1 : 0
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
  }

  data = {
    "prometheus.yml" = yamlencode({
      global = {
        scrape_interval = "15s"
        evaluation_interval = "15s"
      }
      rule_files = ["/etc/prometheus/rules/*.yml"]
      alerting = {
        alertmanagers = [{
          static_configs = [{
            targets = ["alertmanager:9093"]
          }]
        }]
      }
      scrape_configs = [
        {
          job_name = "kubernetes-apiservers"
          kubernetes_sd_configs = [{
            role = "endpoints"
            namespaces = {
              names = ["default"]
            }
          }]
          scheme = "https"
          tls_config = {
            ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
          }
          bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
          relabel_configs = [
            {
              source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_service_name", "__meta_kubernetes_endpoint_port_name"]
              action = "keep"
              regex = "default;kubernetes;https"
            },
            {
              source_labels = ["__meta_kubernetes_endpoint_port_name"]
              target_label = "__metrics_path__"
              replacement = "/metrics"
            },
            {
              source_labels = ["__meta_kubernetes_service_name"]
              target_label = "job"
              replacement = "kubernetes-apiservers"
            },
            {
              source_labels = ["__meta_kubernetes_namespace"]
              target_label = "namespace"
              replacement = "default"
            }
          ]
        },
        {
          job_name = "kubernetes-nodes"
          kubernetes_sd_configs = [{
            role = "node"
          }]
          scheme = "https"
          tls_config = {
            ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
          }
          bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
          relabel_configs = [
            {
              action = "labelmap"
              regex = "__meta_kubernetes_node_label_(.+)"
            },
            {
              target_label = "__address__"
              replacement = "kubernetes.default.svc:443"
            },
            {
              source_labels = ["__meta_kubernetes_node_name"]
              regex = "(.+)"
              target_label = "__metrics_path__"
              replacement = "/api/v1/nodes/${1}/proxy/metrics"
            }
          ]
        },
        {
          job_name = "kubernetes-pods"
          kubernetes_sd_configs = [{
            role = "pod"
          }]
          relabel_configs = [
            {
              source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
              action = "keep"
              regex = "true"
            },
            {
              source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
              action = "replace"
              target_label = "__metrics_path__"
              regex = "(.+)"
            },
            {
              source_labels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
              action = "replace"
              regex = "([^:]+)(?::\\d+)?;(\\d+)"
              replacement = "$1:$2"
              target_label = "__address__"
            },
            {
              action = "labelmap"
              regex = "__meta_kubernetes_pod_label_(.+)"
            },
            {
              source_labels = ["__meta_kubernetes_namespace"]
              action = "replace"
              target_label = "namespace"
            },
            {
              source_labels = ["__meta_kubernetes_pod_name"]
              action = "replace"
              target_label = "pod"
            }
          ]
        }
      ]
    })
  }
}

# Prometheus Deployment
resource "kubernetes_deployment" "prometheus" {
  count = var.enable_prometheus ? 1 : 0
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
    labels = {
      app = "prometheus"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "prometheus"
      }
    }

    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }

      spec {
        service_account_name = "prometheus"
        
        container {
          name  = "prometheus"
          image = "prom/prometheus:v2.40.0"

          port {
            container_port = 9090
            name        = "prometheus"
          }

          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus/",
            "--web.console.libraries=/etc/prometheus/console_libraries",
            "--web.console.templates=/etc/prometheus/consoles",
            "--storage.tsdb.retention.time=${var.prometheus_retention_days}d",
            "--web.enable-lifecycle"
          ]

          volume_mount {
            name       = "prometheus-config-volume"
            mount_path = "/etc/prometheus/"
          }

          volume_mount {
            name       = "prometheus-storage-volume"
            mount_path = "/prometheus/"
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "2000m"
              memory = "4Gi"
            }
          }
        }

        volume {
          name = "prometheus-config-volume"
          config_map {
            name = kubernetes_config_map.prometheus_config[0].metadata[0].name
          }
        }

        volume {
          name = "prometheus-storage-volume"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.prometheus[0].metadata[0].name
          }
        }
      }
    }
  }
}

# Prometheus PVC
resource "kubernetes_persistent_volume_claim" "prometheus" {
  count = var.enable_prometheus ? 1 : 0
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${var.prometheus_storage_size}Gi"
      }
    }
  }
}

# Prometheus Service
resource "kubernetes_service" "prometheus" {
  count = var.enable_prometheus ? 1 : 0
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
    labels = {
      app = "prometheus"
    }
  }

  spec {
    selector = {
      app = "prometheus"
    }

    port {
      port        = 9090
      target_port = 9090
      name        = "prometheus"
    }

    type = "ClusterIP"
  }
}

# Prometheus ServiceAccount and RBAC
resource "kubernetes_service_account" "prometheus" {
  count = var.enable_prometheus ? 1 : 0
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
  }
}

resource "kubernetes_cluster_role" "prometheus" {
  count = var.enable_prometheus ? 1 : 0
  metadata {
    name = "prometheus"
  }

  rule {
    api_groups = [""]
    resources = ["nodes", "nodes/metrics", "services", "endpoints", "pods"]
    verbs     = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions"]
    resources = ["ingresses"]
    verbs     = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "prometheus" {
  count = var.enable_prometheus ? 1 : 0
  metadata {
    name = "prometheus"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.prometheus[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.prometheus[0].metadata[0].name
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
  }
}