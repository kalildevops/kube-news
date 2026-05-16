terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

locals {
  oidc_provider = replace(var.oidc_provider_url, "https://", "")
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca)
  token                  = data.aws_eks_cluster_auth.this.token
}

# ── Fetch DataDog API key from Secrets Manager ────────────────────────────────

data "aws_secretsmanager_secret_version" "datadog_api_key" {
  secret_id = var.datadog_api_key_secret_name
}

# ── Namespace + Secret ────────────────────────────────────────────────────────

resource "kubernetes_namespace" "datadog" {
  metadata {
    name = "datadog"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_secret" "datadog_api_key" {
  metadata {
    name      = "datadog-secret"
    namespace = kubernetes_namespace.datadog.metadata[0].name
  }

  data = {
    api-key = jsondecode(data.aws_secretsmanager_secret_version.datadog_api_key.secret_string)["api_key"]
  }
}

# ── DataDog Agent Helm Release ────────────────────────────────────────────────

resource "helm_release" "datadog" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  namespace  = kubernetes_namespace.datadog.metadata[0].name
  version    = "3.57.2"

  values = [
    yamlencode({
      datadog = {
        site = var.datadog_site

        # API key from K8s Secret (never passed as plain value)
        apiKeyExistingSecret = kubernetes_secret.datadog_api_key.metadata[0].name

        clusterName = var.cluster_name

        env = [
          { name = "DD_ENV", value = var.environment }
        ]

        tags = [
          "env:${var.environment}",
          "project:kube-news",
          "cluster:${var.cluster_name}",
        ]

        # APM
        apm = {
          enabled            = true
          portEnabled        = true
          socketEnabled      = true
        }

        # Log collection from all containers
        logs = {
          enabled                = true
          containerCollectAll    = true
          containerCollectUsingFiles = true
        }

        # Prometheus scraping — picks up /metrics from pods with annotations
        prometheusScrape = {
          enabled          = true
          serviceEndpoints = true
          additionalConfigs = [{
            kubernetes_pod_annotations = {
              "ad.datadoghq.com/kube-news.checks" = jsonencode({
                openmetrics = {
                  instances = [{
                    openmetrics_endpoint = "http://%%host%%:8080/metrics"
                    namespace            = "kube_news"
                    metrics              = ["http_requests_total", "nodejs_*", "process_*"]
                  }]
                }
              })
            }
          }]
        }

        # Infrastructure monitoring
        collectEvents      = true
        leaderElection     = true
        processAgent = {
          enabled            = true
          processCollection  = true
        }

        networkMonitoring = {
          enabled = true
        }
      }

      # DaemonSet for node-level metrics
      agents = {
        tolerations = [{
          operator = "Exists"
        }]
        resources = {
          requests = { cpu = "100m", memory = "256Mi" }
          limits   = { cpu = "300m", memory = "512Mi" }
        }
      }

      # Cluster Agent for Kubernetes state metrics
      clusterAgent = {
        enabled  = true
        replicas = var.environment == "prod" ? 2 : 1
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "200m", memory = "256Mi" }
        }
        admissionController = {
          enabled = true
          # Auto-injects DD_AGENT_HOST and DD_ENTITY_ID into pods
          mutateUnlabelled = false
        }
      }

      # Kube State Metrics
      kubeStateMetricsCore = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_secret.datadog_api_key]
}
