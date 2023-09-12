terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
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
resource "kubernetes_namespace" "monitoring" {
  depends_on = [
    var.eks_cluster_id
  ]

  metadata {
    name = var.namespace
  }
}

resource "kubectl_manifest" "pv" {
  depends_on = [kubernetes_namespace.monitoring]
  yaml_body = <<YAML
apiVersion: v1
kind: PersistentVolume
metadata:
  name: kube-prometheus-stack-pv
  namespace: monitoring
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: "gp2"  # Update with the appropriate StorageClass name
  awsElasticBlockStore:
    volumeID: ${var.ebs_volume_id}  # Replace with your EBS volume ID
    fsType: ext4
YAML
}

resource "kubectl_manifest" "pvc" {
  depends_on = [kubectl_manifest.pv]
  yaml_body = <<YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: kube-prometheus-stack-pvc
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  volumeName: kube-prometheus-stack-pv
YAML
}

resource "helm_release" "kube-prometheus" {
  depends_on = [
    kubectl_manifest.pvc
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
    name  = "grafana.persistentVolume.existingClaim"
    value = "kube-prometheus-stack-pvc"
  }
  set {
    name  = "prometheusSpec.additionalScrapeConfigs[0].static_configs[0].targets[0]"
    value = "var.target1"
  }
  set {
    name  = "prometheus.prometheusSpec.additionalScrapeConfigs[0].static_configs[0].targets[1]"
    value = "var.target2"
  }
  set {
    name  = "prometheus.prometheusSpec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[1]"
    value = "var.az"
  }
}
