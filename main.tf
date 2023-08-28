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
}
