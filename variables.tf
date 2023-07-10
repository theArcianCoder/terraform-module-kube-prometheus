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
