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
variable "cluster_name" {
  description = "Name of the EKS cluster"
}
variable "mongo_db_expo_ip" {
  description = "The first target IP and port"
  default     = "18.236.158.154:9114"
}
variable "elasticsearch_expo_ip" {
  description = "The second target IP and port"
  default     = "18.236.158.154:9216"
}
variable "az" {
  description = "Value of the az for the prometheus pod to be deployed in"
}

