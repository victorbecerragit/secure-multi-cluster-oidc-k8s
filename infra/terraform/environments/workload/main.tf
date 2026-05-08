provider "aws" {
  region = "us-west-2"
}

module "workload_cluster" {
  source       = "../../modules/eks"
  cluster_name = "workload-federated"
  vpc_id       = "vpc-zzzzzzzz"
  subnet_ids   = ["subnet-zzzzzzzz", "subnet-wwwwwwww"]
}

# The workload cluster trusts the same IDP but may have different 
# RBAC mappings scoped to staging environments.
