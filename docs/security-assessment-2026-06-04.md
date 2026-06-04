# Security Assessment - 2026-06-04

## Scope
Architectural and configuration review of IAM, OIDC trust, Kubernetes RBAC, CI/CD workflows, and workload security hardening.

This document captures recommendations only. No project files were changed as part of the assessment itself.

## Executive Summary
The project has a strong security direction (OIDC federation, separation of deploy/build roles, and namespace-scoped deployment intent), but there are several high-impact gaps that should be addressed before a production rollout.

Most important themes:
- Remove broad IAM defaults.
- Tighten Kubernetes deploy permissions and remove edit-level drift.
- Eliminate hardcoded demo credentials from executable paths.
- Use private network paths for production CI runners and EKS API access.

## Findings

### Critical

1. Bootstrap IAM role defaults to account-wide AdministratorAccess.
- Location: infra/terraform/aws/bootstrap/variables.tf
- Risk: Full account compromise blast radius if CI role is abused.
- Recommendation: Replace with scoped policies and require explicit opt-in for elevated permissions.

2. Local CI deployer RBAC still uses built-in edit role.
- Locations:
  - rbac/manager/bindings/ci-deployer-binding.yaml
  - rbac/workload/bindings/ci-deployer-binding.yaml
- Risk: edit includes broad write surfaces and can expose sensitive resources.
- Recommendation: Standardize on the narrower github-ci-deployer ClusterRole pattern across all environments.

### High

3. Hardcoded default credentials in scripts, values, and docs.
- Locations include:
  - helm/values/keycloak-values.yaml
  - scripts/setup-keycloak.sh
  - scripts/validate-oidc.sh
  - README.md
- Risk: Credential leakage and insecure default reuse.
- Recommendation: Generate ephemeral local credentials and require environment overrides for any shared environments.

4. EKS public endpoint defaults and incomplete CIDR wiring.
- Locations:
  - infra/terraform/aws/environments/dev/variables.tf
  - infra/terraform/aws/modules/eks-cluster/main.tf
- Risk: Public API reachability without strict source restrictions.
- Recommendation: For production, private endpoint only; if public is temporarily needed, enforce explicit CIDR allow-lists.

5. Build role uses broad managed ECR policy.
- Location: infra/terraform/aws/environments/dev/main.tf
- Risk: Unnecessary registry-wide privileges.
- Recommendation: Use repository-scoped inline permissions required for build and push only.

6. Terraform identity defaults to cluster-admin EKS access policy.
- Location: infra/terraform/aws/environments/dev/variables.tf
- Risk: Over-privileged automation identity.
- Recommendation: Namespace-scoped access where feasible and strict separation of infra and deploy identities.

### Medium

7. CI workflows reference a missing helper script.
- Locations:
  - .github/workflows/ci-cd-eks.yml
  - .github/workflows/eks-deploy.yml
- Risk: Guardrail checks may fail or be bypassed unintentionally.
- Recommendation: Add the helper script or inline the checks directly in workflows.

8. Workload runtime hardening controls are not enforced in the Helm deployment template.
- Locations:
  - helm/charts/myapp/templates/deployment.yaml
  - app/Dockerfile
- Risk: Containers may run with permissive defaults.
- Recommendation: Enforce non-root, no privilege escalation, dropped capabilities, read-only root filesystem, and RuntimeDefault seccomp.

9. Duplicate/empty RBAC file may cause operational drift.
- Locations:
  - deploy/eks/github-oidc/rbac/clusterrole-ci-deployer.yaml (empty)
  - infra/terraform/aws/bootstrap/k8s-rbac/clusterrole-ci-deployer.yaml (authoritative)
- Risk: Confusion about source of truth and inconsistent applies.
- Recommendation: Keep one authoritative role definition and document ownership clearly.

## Production Guidance
For production environments:
- Use private GitHub runners in the same VPC/network domain as EKS.
- Use private EKS API endpoint access only.
- Keep public endpoint exposure as a temporary demo/bootstrap exception only.

Private GitHub runner deployment and operations are out of scope for this project.

## Priority Remediation Plan
1. Remove AdministratorAccess default and tighten IAM role scope.
2. Align all CI deploy RBAC to the custom narrower role.
3. Remove hardcoded credentials and enforce safe defaults.
4. Enforce private endpoint production pattern and source restrictions.
5. Add workload runtime hardening controls to Helm templates.
6. Ensure CI security guardrails are executable in workflow jobs.
