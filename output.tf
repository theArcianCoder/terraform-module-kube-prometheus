output "namespace" {
  description = "The name of the created Kubernetes namespace."
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "helm_release_name" {
  description = "The name of the created Helm release."
  value       = helm_release.kube-prometheus.metadata[0].name
}

output "helm_release_namespace" {
  description = "The namespace of the created Helm release."
  value       = helm_release.kube-prometheus.metadata[0].namespace
}
