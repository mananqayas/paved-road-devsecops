# Paved-Road DevSecOps Pipeline
A reusable, opinionated CI/CD pipeline ("paved road") that any service team can adopt.

Security is built into the road, not bolted on: every PR gets secrets, SAST, IaC security misconfigurations, Dockerfile, container image scanning. Critical/High vulnerabilities block developer's PR requests. Each failure exits with actionable directions for developers to fix before PR is merged. Each PR merge on main branch builds and pushes the container image to GHCR. Each build artifact (container image digest + CycloneDX SBOMs) is cryptographically signed using cosign's keyless public infrastructure for artifact integrity.

## Problem

Service teams ship fast and security reviews don't scale. Without a paved road, every team reinvents scanning, gates are advisory-only, and "we'll fix it later" becomes the vulnerability backlog. The result: secrets in git history, known-CVE base image in prod, unsigned artifacts nobody can verify.

## Architecture
```
                 ┌──────────────────────────────────────────────────┐
                 │                   GitHub PR                      │
                 └───────────────┬──────────────────────────────────┘
                                 ▼
              ┌──────────────────────────────────────┐
              │            GitHub Actions            │
              │  ┌─────────┐ ┌────────┐ ┌──────────┐ │
   Phase 2.0  │  │Gitleaks │ │Semgrep │ │  Checkov │ │  Phase 3.0
              │  │(secrets)│ │(SAST)  │ │  (IaC)   │ │
              │  └─────────┘ └────────┘ └──────────┘ │
              │  ┌─────────┐ ┌───────────────────┐   │
              │  │ Trivy   │ │ Cosign + SBOM     │   │  Phase 4.0
              │  │(fs+image│ │ (keyless sign,    │   │
              │  │ +SARIF) │ │  attest)          │   │
              │  └─────────┘ └───────────────────┘   │
              └───────────────┬──────────────────────┘
                              ▼  fail on HIGH/CRITICAL or secret hit
                 ┌────────────────────────┐
                 │  Signed image + SBOM   │  verify.sh proves it
                 └────────────────────────┘
```

+ *On every PR / push:* pytest, docker build, terraform validate, Gitleaks secrets, Semgrep SAST (25 custom CWE rules), Checkov IaC, Trivy Dockerfile + image scans - any failure blocks merge; SARIF to code scanning.
+ *On merge to main:* push to GHCR, Cosign keyless sign, Trivy SBOM + attestation, `verify.sh` + negative tests re-prove verification.

## Threat model
| Threat | Phase 4.0 posture | Paved-road mitigation (later phases) |
| --- | --- | --- |
| Secret committed to git | Blocked at PR | Gitleaks CI, blocks PR |
| Vulnerable app code merged | SAST fails on any ```ERROR``` finding at PR | Semgrep SAST + 25 custom rules, blocks PR |
| Insecure infra merged | `fmt`/`validate` + Blocked at PR for any failed Checkov policy | Checkov IaC scan, blocks on any failed Checkov policy|
| CVE in base image / deps | Dockerfile and image are scanned for security vulnerabilities | Trivy |
| Tampered image deployed | Signed | Cosign keyless (OIDC) signing, `verify.sh` |
| Unknown what's inside image | OS system libraries + runtime application packages | SBOM per OS + image, attached as attestation |


## What was built (Phase 1.0)

- `app/` – FastAPI sample API (`/healthz`, `/hello`), pytest suite (3 tests)
- `Dockerfile` – `python:3.12-slim`, non-root `appuser` (uid 10001), healthcheck
- `terraform/` – null provider, zero-cost placeholder; `fmt`/`validate` in CI
- `.github/workflows/ci.yml` – three jobs: `python` (Checkout code/Install uv and Python/Install dependencies/Lint/Run tests), `docker` (Checkout code/Build docker image), `terraform` (Checkout code/Terraform format/Terraform init and validate)
- Branch protection: `main` requires PR + passing `ci` (setup script below)

## What was built (Phase 2.0)

- gitleaks ci job
- SAST ci job + CWE Top 25 Application Security Vulnerabilities Custom Rules using Semgrep
- Semgrep rules cover OWASP Top 10 security vulnerabilities like XSS, SQLi, CSRF, Missing Authorization etc

## What was built (Phase 3.0)

- checkov ci job (IaC scanning)
- trivy ci job for Dockerfile misconfigurations (Dockerfile scan)
- trivy ci job for docker image scan for `CRITICAL` and `HIGH` severity vulnerabilities
- SARIF (Static Analysis Results Interchange Format) reports are sent to GitHub code scanning

## What was built (Phase 4.0)

- Multi-platform (amd64 + arm64) docker images builds in ci (main branch)
- Artifacts are pushed to GHCR
- CI trivy SBOM step produces CycloneDX SBOMs for OS + runtime packages
- Cosign signs the image artifacts and SBOMs using OIDC + keyless signatures
- `verify.sh` bash script created for image signature and sbom attestation verification
- Negative tests for image signature and SBOM attestation verifications are added in ci pipeline

## Reproduce in one command

```bash
gitleaks git    # locally runs gitleaks in the repo for secrets scanning
```
```bash
semgrep --test semgrep/rules    # locally unit tests the semgrep rules
```
```bash
semgrep scan \
    --config semgrep/rules/cwe-top25-rules.yml \
    --metrics=off \
    --json \
    --output semgrep-results.json
```
```
checkov -d terraform/
```
```
trivy config --severity 'HIGH,CRITICAL' Dockerfile
```
```
trivy image paved-road-sample-api:dev --severity 'CRITICAL,HIGH'
```
```bash
make all    # install + pytest + compile check (no docker/terraform needed) + gitleaks + semgrep-sast-test + semgrep-sast-scan
```

Full local parity (needs docker + terraform)

``` bash
make install && make test && make docker-build && make tf-validate
```

CI runs the same on every push/PR to `main`

## Verification

**Done-gate for Phase 1.0:** green pipeline on clean code.

- [x] `make all` passes locally (output pasted below)
- [X] `gh` push to new repo shows all three CI jobs green on `main`
- [x] Branch protection on `main`: require PR, require `ci` status checks, dismiss stale approvals (commands below)
- [x] Negative test (reserved for Phase 2.0): seeded secret must FAIL the pipeline – not applicable yet, no scanners wired

Local verification output (Phase 1.0) – run 2026-10-03:

```
uv run ruff check
All checks passed!
Phase 1.0 local checks passed.
```

Docker build + Terraform fmt/validate need docker/terraform binaries – they run in CI (ubuntu-latest) on every push/PR.

**Done-gate for Phase 2.0:** green pipeline on clean, secrets free and secure code.

- [x] `gitleaks git` passes locally and PR is blocked when code contains a secret (output below)
- [x] `semgrep --test semgrep/rules` runs tests for CWE top 25 custom rules successfully (output below)
- [x] `semgrep scan --config semgrep/rules/cwe-top25-rules.yml app` tests code locally against the custom rules defined for critical vulnerabilities (output below)

**gitleaks result**

```
    ○
    │╲
    │ ○
    ○ ░
    ░    gitleaks

11:00PM INF 20 commits scanned.
11:00PM INF scanned ~304218 bytes (304.22 KB) in 186ms
11:00PM WRN leaks found: 1

```
**Semgrep tests result**
```
25/25: ✓ All tests passed
No tests for fixes found.
```

**Semgrep scan result (FAILED)**
```
┌──── ○○○ ────┐
│ Semgrep CLI │
└─────────────┘

Scanning 1 file (only git-tracked) with 25 Code rules:

  CODE RULES
  Scanning 1 file with 25 python rules.

  SUPPLY CHAIN RULES

  No rules to run.


  PROGRESS

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 100% 0:00:00


┌────────────────┐
│ 1 Code Finding │
└────────────────┘

    app/main.py
   ❯❯❱ semgrep.rules.python.cwe94.dynamic-code-execution
          ❰❰ Blocking ❱❱
          CWE-94: Dynamic code execution is forbidden in the API runtime. Replace eval/exec/compile of dynamic
          content with explicit parsing/dispatch.

            4┆ eval("hello")



┌──────────────┐
│ Scan Summary │
└──────────────┘
✅ Scan completed successfully.
 • Findings: 1 (1 blocking)
 • Rules run: 25
 • Targets scanned: 1
 • Parsed lines: ~100.0%
 • Scan was limited to files tracked by git
 • For a detailed list of skipped files and lines, run semgrep with the --verbose flag
Ran 25 rules on 1 file: 1 finding.
```

**Semgrep scan result (PASSED)**
```
┌──── ○○○ ────┐
│ Semgrep CLI │
└─────────────┘

Scanning 1 file (only git-tracked) with 25 Code rules:

  CODE RULES
  Scanning 1 file with 25 python rules.

  SUPPLY CHAIN RULES

  No rules to run.


  PROGRESS

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 100% 0:00:00


┌──────────────┐
│ Scan Summary │
└──────────────┘
✅ Scan completed successfully.
 • Findings: 0 (0 blocking)
 • Rules run: 25
 • Targets scanned: 1
 • Parsed lines: ~100.0%
 • Scan was limited to files tracked by git
 • For a detailed list of skipped files and lines, run semgrep with the --verbose flag
Ran 25 rules on 1 file: 0 finding
```
**PR blocked on gitleaks**

![Gitleaks PR block](./docs/images/pr_blocked_on_aws_secret_detection.png)

**PR blocked for insecure and critically vulnerable code**

![SAST PR block](./docs/images/pr_blocked_on_insecure_code_sast.png)

**Done-gate for Phase 3.0:** green pipeline on clean code, secure IaC configuration, secrets free, secure Dockerfile and docker container image.

- [x] `checkov -d terraform/` runs locally with zero errors (see below)
- [x] `trivy config --severity 'HIGH,CRITICAL' Dockerfile`
- [x] `trivy image --ignore-unfixed --severity 'HIGH,CRITICAL' paved-road-sample-api:dev`

```

[ terraform framework ]: 100%|████████████████████|[3/3], Current File Scanned=terraform/variables.tf
[ secrets framework ]: 100%|████████████████████|[3/3], Current File Scanned=terraform/terraform.tf

       _               _
   ___| |__   ___  ___| | _______   __
  / __| '_ \ / _ \/ __| |/ / _ \ \ / /
 | (__| | | |  __/ (__|   < (_) \ V /
  \___|_| |_|\___|\___|_|\_\___/ \_/

By Prisma Cloud | version: 3.3.29

```
```
Report Summary

┌────────────┬────────────┬───────────────────┐
│   Target   │    Type    │ Misconfigurations │
├────────────┼────────────┼───────────────────┤
│ Dockerfile │ dockerfile │         0         │
└────────────┴────────────┴───────────────────┘

```
```

oTotal: 6 (UNKNOWN: 0, LOW: 1, MEDIUM: 5, HIGH: 0, CRITICAL: 0)
```

**PR blocked on insecure Dockerfile and container image**

![Insecure Docker PR block](./docs/images/pr_blocked_on_insecure_dockerfile_and_image.png)

**PR blocked on insecure infrastructure provisioning**

![Misconfigured IaC PR block](./docs/images/pr_blocked_on_insecure_infrastructure_provisioning_code.png)

**Done-gate for phase 4.0:** On clean code passing mandatory CI checks, container images are built with immutable digest and signed once PR is merged with the main branch, negative tests are added in CI pipeline rejecting the unsigned and altered images.

- [x] `cosign verify` with certificate identity and certificate OIDC issuer verifies image digest (see below)

```
./verify.sh --image-ref ghcr.io/mananqayas/paved-road-devsecops@sha256:84596e6ae63c01116fb051908bd2151ce48e57e00222e08be47fcfe9cdcdcb70 --identity "https://github.com/mananqayas/paved-road-devsecops/.github/workflows/ci.yml@refs/heads/main"

Verification for ghcr.io/mananqayas/paved-road-devsecops@sha256:84596e6ae63c01116fb051908bd2151ce48e57e00222e08be47fcfe9cdcdcb70 --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The code-signing certificate was verified using trusted certificate authority certificates

Verification for ghcr.io/mananqayas/paved-road-devsecops@sha256:84596e6ae63c01116fb051908bd2151ce48e57e00222e08be47fcfe9cdcdcb70 --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The code-signing certificate was verified using trusted certificate authority certificates

```

## Trade-offs

- **FastAPI over Flask:** better for my Python background and for writing meaningful Semgrep custom rules later (typed endpoints).
- **Terraform null provider in Phase 1.0:** keeps cost at $0 and CI green without cloud credentials; real AWS resources arrive in Checkov in Phase 3.0.
- **Slim image, not distroless/aline (yet):** debuggability first; Trivy + hardening decisions land with evidence in Phase 3.0 (see ADR 0002).
- **GitHub Actions over Jenkins/CircleCI:** zero infra, OIDC-native (needed for Cosign keyless in Phase 4.0), free for public repos, See `docs/adr/0001`
- ***No real AWS resources*: this project is for developer experience and security, testing locally and on GitHub Actions CI for free.

## Framework mapping
| Control | NIST CSF 2.0| SOC 2 CC |
| --- | --- | --- |
| CI runs tests on every change (1.0) | PR.PS-1 (baseline config) | CC7.2 (monitoring) |
| Branch protection, required reviews (1.0) | PR.AC-4 (access permissions) | CC6.1 (logical access) |
| Secret scanning (2.0) | PR.DS-1 (data-at-rest protection) | CC6.7 (encryption/keys) |
| SAST (2.0) built, IaC/image (3.0) | DE.CM-8 (vuln scanning)  | CC7.1 (vuln mgmt) |
| Image signing + SBOM (4.0) | PR.DS-6 (integrity checking) |  CC7.2   |

## Cost

Phase 1.0 + Phase 2.0 + Phase 3.0 + Phase 4.0: **\$0** – GitHub Actions free tier (public repo), no cloud resources (null Terraform provider), no third-party SaaS. Later phases stay $0: all scanners are OSS, Cosign keyless uses free Sigstore infrastructure.


## Teardown

Phase 1.0 creates nothing outside the repo. To remove all traces:

```bash
# delete the GitHub repo (also removed Actions history)
gh repo delete <owner>/paved-road-devsecops --yes
#local
rm -rf paved-road-devsecops
```

No cloud resources, no credentials, no cost to unwind.

## Roadmap

- [X] **1.0 Foundations** – sample app, baseline CI, branch protection (this phase)
- [X] **2.0 Secrets && SAST** – Gitleaks CI job, Semgrep + CWE Top 25 custom rules
- [x] **3.0 IaC & image scanning** – Checkov, Trivy fs+image, SARIF, severity gates
- [x] **4.0 Signing & SBOM** – Cosign keyless, SBOM attestation, `verify.sh`
- [ ] **5.0 Docs & case study** – diagram, demo GIF, mananqayas.com write-up
