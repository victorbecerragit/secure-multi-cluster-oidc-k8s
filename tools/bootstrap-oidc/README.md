
1. cd infra/terraform/aws/bootstrap

2. Copy & edit terraform.tfvars with your GitHub repo details

3. terraform init && terraform apply (run locally)

4. terraform output github_oidc_role_arn (copy to GitHub secret)

5. Workflows can now assume the role via OIDC

6. Deploy EKS stack via workflow with full CI/CD permissions

IAM User - one shot

aws iam create-policy \
  --policy-name bootstrap-oidc-policy \
  --policy-document file://bootstrap-oidc-policy.json

aws iam attach-user-policy \
  --user-name eks-admin \
  --policy-arn arn:aws:iam::200227xxxxxxx:policy/bootstrap-oidc-policy

