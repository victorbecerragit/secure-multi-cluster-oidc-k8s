provider "aws" {
  region = "us-east-1"
}

module "manager_cluster" {
  source       = "../../modules/eks"
  cluster_name = "manager-controller"
  vpc_id       = "vpc-xxxxxxxx"
  subnet_ids   = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]
}

# Example of GitHub Actions OIDC Trust at the Infra level
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Application of RBAC manifests using a provisioner (example)
# resource "null_resource" "apply_rbac" {
#   provisioner "local-exec" {
#     command = "kubectl apply -f ../../../rbac/manager/bindings/ --context ${module.manager_cluster.cluster_name}"
#   }
# }
