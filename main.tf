variable "eks_cluster_id" {
  description = "The ID of the EKS cluster."
}

variable "namespace" {
  description = "The name of the Kubernetes namespace."
  type        = string
}

variable "stack_name" {
  description = "The name of the Helm chart release."
  type        = string
}

resource "kubernetes_namespace" "monitoring" {
  depends_on = [
    var.eks_cluster_id
  ]

  metadata {
    name = var.namespace
  }
}

resource "helm_release" "kube-prometheus" {
  depends_on = [
    kubernetes_namespace.monitoring
  ]

  name       = var.stack_name
  namespace  = var.namespace
  version    = var.version
  repository = "https://github.com/theArcianCoder/monitoring-setup.git"
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
}
