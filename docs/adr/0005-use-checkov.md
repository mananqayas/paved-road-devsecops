# ADR-0005: Use Checkov to prevent cloud misconfigurations in IaC files
Date: 2026-10-14

Status: Accepted

## Context
As part of building our **paved road devsecops** initiative, we must establish automated guardrails for Infrastructure as Code (IaC) terraform templates.

Currently, infrastructure security reviews are manual, inconsistent across squads, and occur too late in the development lifecyle. To realize a true "paved road," developers need automated, rapid feedback on security misconfigurations (such as public S3 buckets or overly permissive IAM policies) directly inside their pull requests and local workflows without requiring manual SecOps approval for standard changes.

## Decision
We will adopt **Checkov** as our standard static analysis tool for IaC security scanning across all engineering repositories utilizing the paved road.

We will implement this by:
1. Publishing a future centralized, version-controlled configuration file defining our organizational security baselines (aligned with CIS Benchmarks).
2. Embedding this scanner directly into our global, reusable GitHub Actions CI/CD pipeline templates.
3. Configured in **Soft Fail** mode and sending SARIF results to GitHub Advanced Security for PR merge enforcement.

## Alternative considerations

### Option 1: Checkov by Bridgecrew (Selected)
+ **Pros:** Includes over 1,000 built-in policies mapped to frameworks like CIS annd SOC2. Supports smart graph-based analysis (understanding how resources connect, not just single files). Uses straightforward Python or YAML for writing custom organization-specific security rules.
+ **Cons:** Can be slower and consume more memory in massively sized repositories compared to Go-based binaries.

### Option 2: Aqua Security Trivy
+ **Pros:** Incredibly fast execution binary written in Go. Excellent for scanning container images and software vulnerabilities (SBOs) alongside IaC.
+ **Cons:** Custom policy engine relies strictly on Rego (Open Policy Agent), which has a steep learning curve for our general development teams compared to Checkov's simple YAML/Python rules.

### Option 3: tfsec / TFLint
+ **Pros:** Highly optimized specifically for Terraform. Executes lightning fast and has deep integration with Terraform syntax.
+ **Cons:** Very narrow scope. Since tfsec was largely merged into Trivy, it lacks the broader multi-IaC support (like Kubernetes or Dockerfiles) that we need to build a comprehensive, multi-language DevSecOps paved road.

## Consequences
+ **Positive:** Developers receive instant feedback on IaC security risks directly in Git. SecOps is freed from manual configuration reviews.
+ **Negative/Trade-offs:** We must dedicate engineering time to tune out false positives to prevent developer fatigue. Teams with existing legacy infrastructure will face initial build failure that require remediation or documented exceptions.
