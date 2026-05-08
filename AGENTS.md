# AGENTS.md

Project: secure-multi-cluster-oidc-k8s

Purpose:
DevSecOps portfolio project showing secure access to multiple Kubernetes clusters using OIDC federation, RBAC, and GitHub Actions OIDC.

Priorities:
- Security first
- Clean repo structure
- Interview-ready documentation
- Easy to extend later

Core topics:
- Multi-cluster Kubernetes
- OIDC authentication
- Least-privilege RBAC
- Secretless CI/CD
- Namespace isolation

Default stack:
- Terraform
- Helm
- Kubernetes YAML
- Markdown
- Mermaid diagrams

Rules:
- Prefer simple, realistic architecture.
- No static secrets.
- Prefer OIDC over long-lived credentials.
- Keep files modular and readable.
- Add short docs for each major folder.
- Optimize for fintech/platform interview value.