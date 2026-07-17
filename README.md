# MySubscriptionService — CI/CD Hands-On Lab (K8s/Helm)

This lab mirrors the **billing-chargebee-buyflow-api-service** CI/CD pipeline exactly as documented. Use this to understand every job, every trigger, and every infrastructure decision — then answer interview questions with confidence.

---

## 1. Pipeline Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    GITHUB ACTIONS (.github/workflows/ci-cd.yaml)         │
│                                                                          │
│  PR MODE (validate only)              MAIN MODE (build + deliver)        │
│  ┌────────────────────────┐          ┌────────────────────────────────┐ │
│  │ get-config              │          │ get-config                    │ │
│  │ check-jira-references   │          │ semver (GitVersion)           │ │
│  │ validate-openapi-spec   │          │ terraform-validate            │ │
│  │ static-analysis (Mega)  │          │ deploy-deployment-roles-*     │ │
│  │ run-tests-and-sonarscan │          │ docker-image-build-and-push   │ │
│  │ run-pact-tests          │          │ deploy-test ─► regression     │ │
│  │ pact-publish            │          │ deploy-uat  ─► regression     │ │
│  │ docker-image-build      │          │ deploy-production ─► release  │ │
│  └────────────────────────┘          └────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    PROGRESSIVE DEPLOYMENT (TEST → UAT → PROD)           │
│                                                                          │
│  1. Terraform apply → provisions AWS IAM roles + IRSA trust policy      │
│  2. Helm upgrade --install → deploys app to K8s (PaaS generic-service)  │
│  3. Regression tests (Playwright E2E) gate each promotion               │
│  4. GitHub release created after production                             │
└─────────────────────────────────────────────────────────────────────────┘
```

### Three Trigger Paths (same workflow, conditional jobs):

| Trigger | What runs | Job count |
|---------|-----------|-----------|
| **PR** to main | Validate only — tests, lint, OpenAPI, Pact, throwaway Docker build | 8 |
| **Push** to main | Validate + version + Terraform + push image + deploy TEST→UAT→PROD | 18 |
| **workflow_dispatch** | Behaves like main push (manual trigger) | 18 |

---

## 2. Environment Map

| Environment | AWS Region | K8s Context | Hostname |
|-------------|-----------|-------------|----------|
| **Test** | ap-southeast-2 (Sydney) | `ap-southeast-2-k8s-paas-test-rua` | `*.global.xero-test.com` |
| **UAT** | us-west-2 (Oregon) | `us-west-2-k8s-paas-uat-rua` | `*.global.xero-uat.com` |
| **Production** | us-east-1 (N. Virginia) | `us-east-1-k8s-paas-prod-rua` | `*.global.xero.com` |

---

## 3. Directory Layout

```
cicd-handson-lab-k8s/
├── .github/
│   ├── workflows/
│   │   └── ci-cd.yaml                  # THE pipeline (study this most)
│   ├── actions/
│   │   └── validate-open-api-spec/     # Reusable validation action
│   │       └── action.yml
│   └── scripts/
│       ├── version.sh                  # GitVersion → version strings
│       └── check-jira-references.sh    # PR title Jira enforcement
├── infra/
│   ├── terraform/
│   │   ├── main.tf                     # AWS infra: IAM exec roles + IRSA
│   │   ├── locals.tf                   # Region/env/secret-prefix mapping
│   │   ├── variables.tf                # Terraform variables
│   │   └── env/
│   │       ├── test.tfvars
│   │       ├── uat.tfvars
│   │       └── production.tfvars
│   ├── terraformBackend/
│   │   └── main.tf                     # S3 + KMS for TF state (one-time)
│   ├── deploymentRole/
│   │   └── main.tf                     # Pipeline IAM deployment role (OIDC)
│   └── k8s/
│       ├── shared.yaml                 # Base Helm values (applies everywhere)
│       ├── test.yaml                   # Test environment overrides
│       ├── uat.yaml                    # UAT environment overrides
│       └── production.yaml             # Production environment overrides
├── src/
│   ├── MySubscriptionService.sln
│   ├── MySubscriptionService.Api/      # ASP.NET Web API (port 5210)
│   └── MySubscriptionService.Core/     # Domain logic
├── tests/
│   ├── MySubscriptionService.UnitTests/    # xUnit + FluentAssertions
│   ├── MySubscriptionService.ComponentTests/ # WebApplicationFactory
│   └── MySubscriptionService.ContractTests/ # Pact consumer tests
├── e2e/
│   ├── playwright.config.ts            # Playwright E2E config
│   └── tests/
│       └── subscription.spec.ts        # Regression E2E tests
├── pact/                               # Generated Pact contract files
├── openapi/
│   └── openapi.yaml                    # OpenAPI 3.0.3 specification
├── Dockerfile                          # Multi-stage build, port 5210
├── GitVersion.yml                      # Semantic versioning rules
├── mega-linter.yml                     # MegaLinter configuration
├── deploytrack.yaml                    # Release governance (New Relic, Slack, CAB)
├── Build.ps1                           # Local build
├── Test.ps1                            # Local test + coverage
├── Start.ps1                           # Local Docker run
└── Stop.ps1                            # Local Docker stop
```

---

## 4. Deep Dive: Every Component

### 4.1 GitHub Actions (`ci-cd.yaml`)

**Two modes, one file.** The same YAML validates PRs and delivers to production. The `if:` conditions on each job decide what runs.

| Job | Mode | Purpose | Key detail |
|-----|------|---------|------------|
| `get-config` | Both | Shared config values | Reusable workflow pattern |
| `check-jira-references` | PR only | Enforce Jira ticket in title | Squash-merge means title is the only commit that matters |
| `validate-openapi-spec` | Both | Validate API spec | Runs local action |
| `static-analysis` | Both | MegaLinter | Multi-language, runs across whole repo |
| `run-tests-and-sonarscan` | Both | Unit + component tests + SonarCloud | `--filter "Category!=Contract"` excludes Pact tests |
| `run-pact-tests` | Both | Consumer contract tests | Generates Pact file |
| `pact-publish` | Both | Publish to PactFlow | Tagged `pull-request` or `main` |
| `docker-image-build` | PR only | Prove image builds | Version `0.0.0`, never pushed |
| `semver` | Main only | GitVersion SemVer | Tag format: `MAJOR.MINOR.PATCH.run_number.run_attempt` |
| `terraform-validate` | Main only | Terraform syntax check | Backend-disabled init |
| `deploy-deployment-roles-*` | Main only | Ensure IAM roles exist | Production depends on UAT |
| `docker-image-build-and-push` | Main only | Build + push to Artifactory | Waits for ALL quality gates |
| `deploy-test` | Main only | Deploy to TEST | Terraform + Helm |
| `regression-tests-stage` | Main only | Playwright E2E on TEST | Gates UAT deploy |
| `deploy-uat` | Main only | Deploy to UAT | Terraform + Helm |
| `regression-tests-uat` | Main only | Playwright E2E on UAT | Gates Production deploy |
| `deploy-production` | Main only | Deploy to PRODUCTION | Terraform + Helm |
| `create-release` | Main only | Tag + GitHub release | Audit trail |

### 4.2 GitVersion (`GitVersion.yml`)

- **Mode:** ContinuousDeployment — every commit gets a unique pre-release version
- **Branch rules:** `main` → patch bump, `feature/*` → minor bump + branch name tag
- **Output tag format:** `MAJOR.MINOR.PATCH.run_number.run_attempt` (guarantees uniqueness)

### 4.3 Terraform (`infra/terraform/`)

Three separate root modules under `infra/`:

| Root module | What it manages | Run by |
|-------------|----------------|--------|
| `infra/terraformBackend` | S3 bucket + KMS key for TF state | Manual bootstrap |
| `infra/deploymentRole` | AWS IAM deployment role (OIDC trust) | `deploy-deployment-roles-*` jobs |
| `infra/terraform` | Runtime infra — IAM exec roles, policies, IRSA trust | `deploy-*` jobs |

**What `infra/terraform` creates per environment:**
- `svc-exec-{env}-my-subscription-service` IAM role (bounded by permissions boundary)
- Inline IAM policies for Secrets Manager read access
- IRSA trust policy linking K8s ServiceAccount to the IAM role

**Security model:** Pipeline assumes `OIDC_ROLE_ARN` → then `DEPLOYMENT_ROLE_ARN` — no long-lived keys.

### 4.4 Kubernetes / Helm (`infra/k8s/`)

Uses Xero's **PaaS generic-service Helm chart**. The pipeline supplies values files only:

| File | What it sets |
|------|-------------|
| `shared.yaml` | Container port 5210, resource requests/limits, probes, ingress, Sumo annotations |
| `test.yaml` | 2-4 replicas, 75% autoscale, `DOTNET_ENVIRONMENT=Test` |
| `uat.yaml` | 2-6 replicas, 60% autoscale, `DOTNET_ENVIRONMENT=UAT` |
| `production.yaml` | 3-8 replicas, 40% autoscale, `DOTNET_ENVIRONMENT=Production` |

**Helm values layering:** `shared.yaml` + `{env}.yaml` = full deployment config.

**Health probes:** liveness at `/ping`, readiness at `/ready` (both return 200).

**Autoscaling:** Kubernetes HPA based on CPU/memory utilization.

**Secrets:** Injected at runtime from AWS Secrets Manager via `{aws-sm}...` value references — never stored in the repo.

### 4.5 Docker (`Dockerfile`)

Multi-stage build:
- **Stage 1 (build):** Full .NET SDK — compiles code
- **Stage 2 (runtime):** Minimal ASP.NET runtime image — only binaries
- Container listens on **port 5210** (`ASPNETCORE_URLS=http://+:5210`)

### 4.6 Quality Gates

| Gate | Tool | What it catches |
|------|------|-----------------|
| Jira reference | Custom script | PRs without a ticket reference |
| OpenAPI validation | Custom action | Broken API specs |
| Static analysis | MegaLinter | Code style, formatting, common mistakes |
| Unit tests | xUnit + FluentAssertions | Logic bugs |
| Component tests | WebApplicationFactory | API contract breaks |
| Code quality | SonarCloud | Bugs, smells, vulnerabilities, coverage drops |
| Contract tests | Pact | API incompatibilities between services |
| Regression E2E | Playwright | End-to-end functional regressions |

### 4.7 Deployment Tracking (`deploytrack.yaml`)

For every environment deploy:
1. Records a **New Relic change tracking marker** (correlate code changes with performance)
2. Posts a **Slack notification** to `#billing-releases` (separate channel for production)

**CAB rules:** Production deployments require Change Advisory Board approval unless the PR has the `no cab required` label.

---

## 5. Job Dependency Graph (Main Branch)

```
get-config ──► run-tests-and-sonarscan ──► run-pact-tests ──► pact-publish ──┐
                                                                              │
semver ──────────────────────────────────────────────────────────────────────┤
terraform-validate ─────────────────────────────────────────────────────────┤
validate-openapi-spec ──────────────────────────────────────────────────────┤
static-analysis ────────────────────────────────────────────────────────────┤
                                                                             ▼
                                                          docker-image-build-and-push
                                                                             │
                                              deploy-deployment-roles-test ──┤
                                                                             ▼
                                                                    deploy-test
                                                                         │
                                                              regression-tests-stage
                                                                         │
                                              deploy-deployment-roles-uat ─┤
                                                                             ▼
                                                                    deploy-uat
                                                                         │
                                                              regression-tests-uat
                                                                         │
                                        deploy-deployment-roles-production ─┤
                                                                             ▼
                                                                  deploy-production
                                                                         │
                                                                  create-release
```

---

## 6. How Each Environment Deploy Flows

```
┌─────────┐   ┌──────────────┐   ┌─────────────────┐   ┌─────────────────┐
│ Deploy  │──►│ Terraform    │──►│ Helm Upgrade     │──►│ K8s Rollout     │
│ Job     │   │ init + apply │   │ --install        │   │ (pods, HPA,     │
│         │   │ (IAM, IRSA)  │   │ shared+env.yaml  │   │  ingress, probes)│
└─────────┘   └──────────────┘   └─────────────────┘   └─────────────────┘
                                                              │
                                                         Regression
                                                         Tests (gate)
                                                              │
                                                     ┌────────┴────────┐
                                                     ▼                 ▼
                                               Next env         Pipeline stops
                                               deploys           (bug caught)
```

**Key rule:** TEST regression must pass before UAT deploys. UAT regression must pass before Production deploys. A regression failure **stops the line** — no parallel deployments.

---

## 7. How to Run This Lab

### Prerequisites
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Git](https://git-scm.com/)

### Local Commands

```powershell
# Initialize git (required for GitVersion)
cd cicd-handson-lab-k8s
git init
git add .
git commit -m "Initial commit"

# Build locally (simulates CI build job)
.\Build.ps1

# Run tests locally (simulates CI test jobs)
.\Test.ps1

# Run the service locally via Docker
.\Start.ps1

# Test the API
curl http://localhost:5210/api/subscriptions
curl http://localhost:5210/ping

# Stop the service
.\Stop.ps1
```

### Push to GitHub to See the FULL Pipeline

```powershell
# Create a GitHub repository, then:
git remote add origin https://github.com/YOUR_USER/cicd-handson-lab-k8s.git
git push -u origin main

# Open a PR to trigger PR-mode validation:
git checkout -b feature/add-email-validation
# ... make changes, commit, push
git push origin feature/add-email-validation
# Open PR on GitHub → pipeline runs validation only
```

**Every push to main triggers the ENTIRE pipeline automatically:**
1. ✅ Version (GitVersion)
2. ✅ OpenAPI validation
3. ✅ Static analysis (MegaLinter)
4. ✅ Unit + component tests + SonarCloud quality gate
5. ✅ Pact contract tests
6. ✅ Terraform validate
7. ✅ Deploy deployment roles (test → uat → production)
8. ✅ Build + push Docker image
9. ✅ Deploy to TEST → regression tests
10. ✅ Deploy to UAT → regression tests
11. ✅ Deploy to PRODUCTION
12. ✅ Create GitHub release

---

## 8. Interview Questions & Answers

### Q: "How does your CI/CD pipeline work end-to-end?"

**A:** "Our pipeline is a single GitHub Actions workflow with two modes controlled by conditional job execution. **PR mode** validates code through tests, static analysis, OpenAPI validation, Pact contract tests, and a throwaway Docker build — nothing gets deployed. **Main mode** runs the same validation on merged code, then versions it via GitVersion, builds and pushes a real Docker image to Artifactory, and progressively deploys through **TEST → UAT → Production** using **Terraform for AWS infra** and **Helm for Kubernetes**. Each environment is gated by Playwright regression tests — a failure stops the promotion. After production, we create a GitHub release. The whole thing is secured through OIDC role assumption — no long-lived credentials."

### Q: "How do you handle versioning?"

**A:** "GitVersion in ContinuousDeployment mode. Every commit gets a unique, deterministic version from git history — no manual bumps. The output tag format is `MAJOR.MINOR.PATCH.run_number.run_attempt`, guaranteeing every build is traceable. That same version flows into the Docker image tag, Helm deployment, and GitHub release."

### Q: "What's the difference between Terraform and Helm in your pipeline?"

**A:** "They're complementary. **Terraform** provisions cloud infrastructure — IAM execution roles, Secrets Manager policies, and IRSA trust policies that link Kubernetes ServiceAccounts to AWS IAM roles. **Helm** deploys the application itself onto Kubernetes using Xero's PaaS generic-service chart. Terraform runs first to ensure the infra exists, then Helm installs the app. The IAM role ARN that Terraform creates is passed as a Helm value for IRSA wiring."

### Q: "How do you prevent 'works on my machine'?"

**A:** "Our tests run in the same containers via MegaLinter and dotnet test whether locally or in CI. The component tests use `WebApplicationFactory` which boots the actual ASP.NET pipeline. Contract tests via Pact ensure API compatibility between services. And the Docker build is the same multi-stage file in both local dev and CI."

### Q: "How do you ensure code quality?"

**A:** "Multi-layered: Jira reference enforcement prevents undocumented changes, MegaLinter catches formatting issues, SonarCloud enforces a quality gate (coverage, bugs, vulnerabilities), Pact contract tests prevent API drift, and Playwright regression tests validate end-to-end functionality in each environment before promotion."

### Q: "What if a regression test fails in TEST?"

**A:** "The pipeline **stops the line**. TEST regression tests are a hard gate for UAT deployment, and UAT regression tests gate Production. A failure means the next environment never deploys. The team is notified via Slack, and the fix must go through the same pipeline again — PR → merge → deploy."

### Q: "How do you trace a deployment to a code change?"

**A:** "Three mechanisms: (1) **GitVersion** produces a unique tag per build that flows into the image and release, (2) **New Relic deployment markers** are recorded by DeployTrack so we can correlate performance changes with deployments, (3) **GitHub releases** are created after production, tagging the exact commit that shipped."

---

## 9. Quick Reference: File → Purpose Mapping

| File | Mirrors company's | Purpose |
|------|------------------|---------|
| `.github/workflows/ci-cd.yaml` | `ci-cd.yaml` | Main CI/CD workflow |
| `GitVersion.yml` | `GitVersion.yml` | Semantic versioning |
| `infra/terraform/main.tf` | `infra/terraform/main.tf` | AWS IAM + IRSA per env |
| `infra/terraform/locals.tf` | `infra/terraform/locals.tf` | Region/env mapping |
| `infra/k8s/shared.yaml` | `infra/k8s/shared.yaml` | Base Helm values |
| `infra/k8s/test.yaml` | `infra/k8s/test.yaml` | Test overrides |
| `infra/k8s/uat.yaml` | `infra/k8s/uat.yaml` | UAT overrides |
| `infra/k8s/production.yaml` | `infra/k8s/production.yaml` | Production overrides |
| `infra/deploymentRole/main.tf` | `infra/deploymentRole/main.tf` | Pipeline IAM role |
| `infra/terraformBackend/main.tf` | `infra/terraformBackend/main.tf` | TF state backend |
| `Dockerfile` | Service `Dockerfile` | Multi-stage build (port 5210) |
| `deploytrack.yaml` | `deploytrack.yaml` | Release governance |
| `openapi/openapi.yaml` | `openapi/openapi.yaml` | API specification |
| `mega-linter.yml` | `mega-linter.yml` | MegaLinter config |
| `.github/actions/validate-open-api-spec/` | `.github/actions/validate-open-api-spec/` | OpenAPI validation |
| `Build.ps1` | `Build.ps1` | Local build |
| `Test.ps1` | `Test.ps1` | Local test |
| `Start.ps1` | `Start.ps1` | Local run |
| `Stop.ps1` | `Stop.ps1` | Local stop |
