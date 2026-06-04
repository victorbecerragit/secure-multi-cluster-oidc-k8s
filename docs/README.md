# Documentation

Complete technical documentation for secure multi-cluster Kubernetes OIDC federation project.

---

## 📑 Quick Navigation

### Phase 6.5: CI/CD Pipeline & Application Delivery ✅ COMPLETE

- **[phase-6.5-summary.md](./phase-6.5-summary.md)** - **START HERE**: Executive summary with quick reference, 14 features, architecture overview
- **[phase-6.5-features.md](./phase-6.5-features.md)** - Comprehensive feature inventory with validation status, security highlights, metrics
- **[phase-6.5-ci-cd-pipeline.md](./phase-6.5-ci-cd-pipeline.md)** - Detailed technical guide for `.github/workflows/ci-cd-eks.yml` (285 lines)

**Key Deliverables:**
- ✅ GitHub Actions CI/CD workflow (two-job: build + deploy)
- ✅ OIDC authentication (zero static credentials)
- ✅ Flask application with health checks
- ✅ Helm chart (multi-environment: staging/prod)
- ✅ Branch-based promotion (develop→staging, main→prod)
- ✅ Atomic deployments with rollback
- ✅ Comprehensive pre/post-deployment validation

### Security Review Reference

- **[security-assessment-2026-06-04.md](./security-assessment-2026-06-04.md)** - Independent architecture and configuration assessment with prioritized hardening recommendations

---

## 🏗️ Architecture & Design

- **[access-model.md](./access-model.md)** - OIDC federation, RBAC model, least-privilege authorization
- **[ci-cd-oidc.md](./ci-cd-oidc.md)** - CI/CD OIDC integration, GitHub trust relationships, role policies
- **[aws-eks-github-oidc.md](./aws-eks-github-oidc.md)** - AWS infrastructure setup, EKS cluster, OIDC provider configuration
- **[eks-vs-kind-auth.md](./eks-vs-kind-auth.md)** - Authentication differences between EKS and kind clusters

---

## 🧪 Testing & Validation

- **[local-testing.md](./local-testing.md)** - Local development workflow: Docker build, Flask testing, Helm deployment on kind
- **[local-validation.md](./local-validation.md)** - Validation procedures for local clusters
- **[security-hardening.md](./security-hardening.md)** - Security best practices, guardrails, threat mitigation

---

## 📊 Project Structure

```
kube-secure-oicd/
├── docs/                          # Documentation (this folder)
│   ├── phase-6.5-summary.md      # Executive overview [START HERE]
│   ├── phase-6.5-features.md     # 14 features detailed
│   ├── phase-6.5-ci-cd-pipeline.md # Workflow technical guide
│   ├── access-model.md            # OIDC + RBAC architecture
│   ├── ci-cd-oidc.md             # OIDC integration guide
│   └── security-hardening.md     # Security best practices
│
├── .github/workflows/             # GitHub Actions
│   └── ci-cd-eks.yml             # Production CI/CD (285 lines)
│
├── app/                          # Flask Application
│   ├── Dockerfile                # Python 3.12-slim base
│   ├── requirements.txt           # Flask + gunicorn
│   └── src/app.py                # REST endpoints
│
├── helm/charts/myapp/            # Helm Chart
│   ├── Chart.yaml
│   ├── values.yaml               # Shared defaults
│   ├── values-staging.yaml       # 1 replica (develop)
│   ├── values-prod.yaml          # 2 replicas (main)
│   └── templates/
│       ├── deployment.yaml       # Kubernetes Deployment
│       └── service.yaml          # ClusterIP Service
│
├── infra/terraform/              # Infrastructure as Code
│   ├── aws/
│   │   ├── bootstrap/
│   │   │   ├── k8s-namespaces/  # app-prod, app-staging
│   │   │   └── k8s-rbac/        # github-ci-deployer role
│   │   ├── environments/dev/    # EKS cluster config
│   │   └── modules/eks-cluster/ # Reusable Helm
│   └── environments/             # Multi-cluster config
│
├── kind/                         # Local Testing
│   ├── manager.yaml              # Manager cluster config
│   └── workload.yaml             # Workload cluster config
│
├── rbac/                         # RBAC Policies
│   ├── manager/                  # Manager plane RBAC
│   └── workload/                 # Workload plane RBAC
│
├── policies/                     # Network Policies
│   ├── admission/                # Admission policies
│   └── network/                  # NetworkPolicy manifests
│
├── scripts/                      # Automation Scripts
│   ├── bootstrap-kind.sh         # Local cluster setup
│   ├── setup-keycloak.sh         # OIDC provider setup
│   ├── validate-oidc.sh          # OIDC validation
│   └── run-integration-tests.sh  # Test automation
│
├── tools/
│   ├── fcli/                     # Kubernetes auth CLI
│   └── bootstrap-oidc/           # OIDC provisioning
│
└── README.md                     # Project overview
```

---

## 🔐 Security Model

### Authentication: OIDC (Zero Static Credentials)
- GitHub Actions OIDC token
- AWS STS AssumeRoleWithWebIdentity
- 3600-second TTL (automatic expiration)
- No manual credential rotation

### Authorization: Least Privilege
- Dual IAM roles: build (ECR) + deploy (Kubernetes)
- Namespace-scoped RoleBindings
- Deny cluster RBAC mutations
- Deny secret access (guardrails)

### Validation: Symmetric Pattern
- Pre-deployment: 6 checks (positive + guardrails)
- Post-deployment: 3 checks (symmetry + rollout + image)

---

## 🚀 Quick Start

### 1. View Phase 6.5 Documentation
```bash
# Start with executive summary
cat docs/phase-6.5-summary.md

# Deep dive into features
cat docs/phase-6.5-features.md

# Technical details on workflow
cat docs/phase-6.5-ci-cd-pipeline.md
```

### 2. Set GitHub Secrets
```bash
# Add to GitHub repository settings
AWS_GITHUB_BUILD_ROLE_ARN=arn:aws:iam::{account}:role/github-build-role
AWS_GITHUB_DEPLOY_ROLE_ARN=arn:aws:iam::{account}:role/github-deploy-role
AWS_REGION=us-east-1
AWS_EKS_CLUSTER_NAME=app-eks-dev
```

### 3. Deploy Application
```bash
# Staging (develop branch)
git push origin develop

# Production (main branch)
git push origin main
```

### 4. Monitor Workflow
```bash
# GitHub Actions UI
# → Actions tab → Select workflow → View logs

# Check deployment
kubectl get deployments -n app-staging
kubectl logs -n app-staging -l app.kubernetes.io/instance=myapp
```

---

## 📖 Documentation by Topic

### Application Development
- Flask application: `app/src/app.py`
- Container image: `app/Dockerfile`
- Python dependencies: `app/requirements.txt`

### Kubernetes Deployment
- Helm chart: `helm/charts/myapp/`
- Deployment template: `helm/charts/myapp/templates/deployment.yaml`
- Service template: `helm/charts/myapp/templates/service.yaml`
- Environment values: `helm/charts/myapp/values-*.yaml`

### CI/CD Pipeline
- Workflow definition: `.github/workflows/ci-cd-eks.yml`
- Build job: Docker + ECR push
- Deploy job: Helm + validation

### Infrastructure
- EKS cluster: `infra/terraform/aws/modules/eks-cluster/`
- Bootstrap: `infra/terraform/aws/bootstrap/`
- OIDC: `infra/terraform/aws/modules/github-oidc-role/`

### Authorization & Security
- RBAC: `rbac/` (manager + workload clusters)
- Network policies: `policies/network/`
- Admission policies: `policies/admission/`

### Testing
- Local development: `kind/` (manager.yaml, workload.yaml)
- Scripts: `scripts/` (bootstrap, validation, testing)
- Test guide: [local-testing.md](./local-testing.md)

---

## 🎯 Project Phases

| Phase | Topic | Status |
|-------|-------|--------|
| 1 | Multi-cluster OIDC federation | ✅ Complete |
| 2 | RBAC manifests (least privilege) | ✅ Complete |
| 3 | Bootstrap provisioning (Terraform) | ✅ Complete |
| 4 | EKS deploy pattern (eks-deploy.yml) | ✅ Complete |
| 5 | Reference validation patterns | ✅ Complete |
| 6.5 | CI/CD pipeline + app delivery | ✅ Complete |

---

## 📚 Related Guides

- **[README.md](../README.md)** - Project overview
- **[AGENTS.md](../AGENTS.md)** - Agent patterns and architecture
- **Terraform:** [infra/terraform/README.md](../infra/terraform/README.md)
- **Helm:** [helm/README.md](../helm/README.md)
- **RBAC:** [rbac/README.md](../rbac/README.md)
- **Policies:** [policies/README.md](../policies/README.md)

---

## 🔗 External Resources

- [GitHub Actions OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS STS AssumeRoleWithWebIdentity](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html)
- [Kubernetes RBAC Best Practices](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)

---

## ✅ Validation Status

- ✅ Documentation comprehensive
- ✅ Code examples verified
- ✅ Local testing completed
- ✅ Kind cluster validation passed
- ✅ OIDC authentication working
- ✅ Dual IAM roles functioning
- ✅ CI/CD pipeline production-ready
- ✅ Application endpoints responding
- ✅ Helm deployments stable
- ✅ Security guardrails enforced

---

**Last Updated:** May 14, 2026 (Phase 6.5 Complete)

