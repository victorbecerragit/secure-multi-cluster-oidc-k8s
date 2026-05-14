variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "VPC ID for the cluster."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets used by the control plane and nodes."
  type        = list(string)
}

variable "node_group_name" {
  description = "Name for the default managed node group."
  type        = string
  default     = "default"
}

variable "create_node_group" {
  description = "Whether to create the default managed node group."
  type        = bool
  default     = false 
}

variable "node_instance_types" {
  description = "Instance types for the default managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired size for the default managed node group."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum size for the default managed node group."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum size for the default managed node group."
  type        = number
  default     = 3
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS endpoint is publicly reachable."
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Whether the EKS endpoint is privately reachable."
  type        = bool
  default     = true
}

variable "access_entries" {
  description = "IAM principals that should receive EKS access entries and policy associations. Set policy_arn to null for group-only entries whose permissions are managed entirely by Kubernetes RBAC."
  type = map(object({
    principal_arn     = string
    kubernetes_groups = optional(list(string), [])
    policy_arn        = optional(string, null)
    access_scope_type = optional(string, "none")
    namespaces        = optional(list(string), [])
  }))
  default = {}
}

variable "create_cluster_encryption" {
  description = "Whether to create a KMS key for EKS cluster encryption."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the cluster and related resources."
  type        = map(string)
  default     = {}
}
