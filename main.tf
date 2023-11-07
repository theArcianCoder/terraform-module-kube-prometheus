terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0.0"
    }
  }
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
  }
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

resource "aws_ebs_volume" "prometheus_volume" {
  count             = 1
  availability_zone = var.az
  size              = 80
  type              = "gp2"

  tags = {
    Name = "prometheus-data-volume"
  }
}

resource "aws_ebs_volume" "grafana_volume" {
  count             = 1
  availability_zone = var.az
  size              = 80
  type              = "gp2"

  tags = {
    Name = "grafana-data-volume"
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_persistent_volume" "pv-grafana" {
  metadata {
    name      = "kube-grafana-stack-pv"
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    capacity = {
      storage = "80Gi"
    }
    persistent_volume_source {
      aws_elastic_block_store {
        volume_id = aws_ebs_volume.grafana_volume[0].id
        fs_type   = "ext4"
      }
    }

    storage_class_name = "gp2"
  }
}

resource "kubernetes_persistent_volume" "pv-prometheus" {
  metadata {
    name      = "kube-prometheus-stack-pv"
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    capacity = {
      storage = "80Gi"
    }
    persistent_volume_source {
      aws_elastic_block_store {
        volume_id = aws_ebs_volume.prometheus_volume[0].id
        fs_type   = "ext4"
      }
    }

    storage_class_name = "gp2"
  }
}

resource "kubernetes_persistent_volume_claim" "pvc-prometheus" {
  metadata {
    name      = "kube-prometheus-stack-pvc"
    namespace = "monitoring"
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
    volume_name = "kube-prometheus-stack-pv"
  }
}

resource "kubernetes_persistent_volume_claim" "pvc-grafana" {
  metadata {
    name      = "kube-grafana-stack-pvc"
    namespace = "monitoring"
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
    volume_name = "kube-grafana-stack-pv"
  }
}

resource "helm_release" "kube-prometheus" {
  depends_on = [
    kubernetes_persistent_volume.pv-grafana,
    kubernetes_persistent_volume.pv-prometheus,
    kubernetes_persistent_volume_claim.pvc-prometheus,
    kubernetes_persistent_volume_claim.pvc-grafana,
  ]

  name       = var.stack_name
  namespace  = var.namespace
  repository = "https://raw.githubusercontent.com/theArcianCoder/helm-chart-ttn/main"
  chart      = "kube-prometheus-stack"

  set {
    name  = "grafana.ingress.enabled"
    value = "true"
  }
  set {
    name  = "grafana.ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "alb"
  }
  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }
  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }
  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/healthcheck-protocol"
    value = "HTTP"
  }
  set {
    name  = "alertmanager.persistentVolume.existingClaim"
    value = "kube-prometheus-stack-pvc"
  }
  set {
    name  = "server.persistentVolume.existingClaim"
    value = "kube-prometheus-stack-pvc"
  }

  set {
    name  = "prometheus.prometheusSpec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key"
    value = "topology.kubernetes.io/zone"
  }
  set {
    name  = "prometheus.prometheusSpec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator"
    value = "In"
  }
  set {
    name  = "prometheus.prometheusSpec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]"
    value = "${var.az}"
  }
  set {
    name  = "grafana.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key"
    value = "topology.kubernetes.io/zone"
  }
  set {
    name  = "grafana.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator"
    value = "In"
  }
  set {
    name  = "grafana.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]"
    value = "${var.az}"
  }
  set {
    name  = "prometheus.prometheusSpec.additionalScrapeConfigs[0].job_name"
    value = "Elastic-Mongo-Exporter"
  }
  set {
    name  = "prometheus.prometheusSpec.additionalScrapeConfigs[0].scrape_interval"
    value = "5m"
  }
  set {
    name  = "prometheus.prometheusSpec.additionalScrapeConfigs[0].scrape_timeout"
    value = "1m"
  }
  set {
    name  = "prometheus.prometheusSpec.additionalScrapeConfigs[0].static_configs[0].targets[0]"
    value = "${var.mongo_db_expo_ip}"
  }
  set {
    name  = "prometheus.prometheusSpec.additionalScrapeConfigs[0].static_configs[0].targets[1]"
    value = "${var.elasticsearch_expo_ip}"
  }
}
