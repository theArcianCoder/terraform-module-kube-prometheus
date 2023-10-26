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
  count             = 1  # Create 1 EBS volume for Prometheus
  availability_zone = var.az  # Use the AZ specified in the 'az' variable
  size              = 80  # Specify the size of the EBS volume for Prometheus
  type              = "gp2"  # Modify the type as needed

  tags = {
    Name = "prometheus-data-volume"
  }
}

resource "aws_ebs_volume" "grafana_volume" {
  count             = 1  # Create 1 EBS volume for Grafana
  availability_zone = var.az  # Use the AZ specified in the 'az' variable
  size              = 80  # Specify the size of the EBS volume for Grafana
  type              = "gp2"  # Modify the type as needed

  tags = {
    Name = "grafana-data-volume"
  }
}

resource "kubernetes_namespace" "monitoring" {
  depends_on = [
    aws_ebs_volume.prometheus_volume,
    aws_ebs_volume.grafana_volume
  ]

  metadata {
    name = var.namespace
  }
}

resource "kubectl_manifest" "pv-prometheus" {
  depends_on = [kubernetes_namespace.monitoring]
  yaml_body = <<YAML
apiVersion: v1
kind: PersistentVolume
metadata:
  name: kube-prometheus-stack-pv
  namespace: monitoring
spec:
  capacity:
    storage: 80Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: "gp2"  # Update with the appropriate StorageClass name
  awsElasticBlockStore:
    volumeID: aws_ebs_volume.prometheus_volume[0].id  # Use the EBS volume for Prometheus
    fsType: ext4
YAML
}

resource "kubectl_manifest" "pv-grafana" {
  depends_on = [kubernetes_namespace.monitoring]
  yaml_body = <<YAML
apiVersion: v1
kind: PersistentVolume
metadata:
  name: kube-grafana-stack-pv
  namespace: monitoring
spec:
  capacity:
    storage: 80Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: "gp2"  # Update with the appropriate StorageClass name
  awsElasticBlockStore:
    volumeID: aws_ebs_volume.grafana_volume[0].id  # Use the EBS volume for Grafana
    fsType: ext4
YAML
}

resource "helm_release" "kube-prometheus" {
  depends_on = [
    kubectl_manifest.pv-grafana
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
