---
description: Scaffold a secure multi-cluster Kubernetes OIDC portfolio project
---

Create a repo skeleton for `secure-multi-cluster-oidc-k8s`.

Include:
- README.md
- infra/terraform/
- helm/
- rbac/
- policies/
- github-actions/
- docs/
- scripts/
- examples/

Project goals:
- Show 2 Kubernetes clusters in the design
- Show 1 central OIDC identity provider
- Show human access and GitHub Actions OIDC access
- Show RBAC roles: platform-admin, developer-readonly, ci-deployer
- Show namespace isolation and basic security policies

Also create:
- A top-level README with quick overview and next steps
- A Mermaid architecture diagram
- Minimal placeholder files with useful comments
- Short folder READMEs where helpful

After scaffolding, summarize:
1. What was created
2. What security model is represented
3. The next 5 implementation steps