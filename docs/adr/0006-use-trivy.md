# ADR-0006: Use Trivy for Dockerfile and Docker image security scanning
Date: 2026-10-11

Status: Accepted

## Context

A part of the **Paved-road DevSecOps** initiative, our engineering teams are rapidly adopting containerization using Docker. However, containers introduce a unique and complex attack surface that spans both static configuration files and compiled runtime layers.

Currently, we face several unmitigated security risks in our container lifecycle.

1. **Misconfigured Dockerfiles:** Images are frequently built with insecure configurations, such as running applications as ```root``` user or failing to pin base image tags.

2. **Vulnerable Base Images and Packages:** Application images are regularly compiled on top of outdated base operating systems containing Critical and High Common Vulnerabilities and Exposures (CVEs).

3. **Delayed Security Feedback:** Vulnerability detection currently occurs reactively, either during production penetration testing or via passive cloud registry scanning long after the code has been merged. 

## Decision

We will standardize on **Aqua Security Trivy** as our primary tool for Dockerfile and container image security scanning across the entire DevSecOps paved road.

We chose Trivy due to its multi-functional capability to sweep both text-based configurations and binary image layers in a single, high-speed execution block. This allows us to keep developer feedback loops tight without adding operational overhead or database management dependencies to our CI/CD platform.

We will enforce this tool by:

1. Embedding Trivy into our global, reusable CI pipeline templates.
2. Breaking builds on **Critical** and **High** vulnerabilities for all newly created container images.
3. Automatically generating a Software Bill of Materials (SBOM) in CycloneDX format during every image build to track third-party dependencies.

## Alternative considerations

### Option 1: Aqua Security Trivy (Selected)
+ **Pros:** Blazing fast execution speeds (written in Go) with a highly accurate, frequently updated vulnerability database. It is a comprehensive tool that handles both static configuration scanning (Dockerfile linter) *and* dynamic layer analysis (OS/application package vulnerabilities). It operates as a stateless single binary, requiring zero backend database infrastructure to run in a CI pipeline.
+ **Cons:** Native custom policy writing requires learning Rego (Open Policy Agent), though its out-of-box policies are comprehensive enough to satisfy our immediate compliance baselines.

### Option 2: Snyk Container

+ **Pros:** Exceptionally polished developer experience with automated pull requests that suggest upgrades to more secure base images.

+ **Cons:** Commercial tool with restrictive open-source/free-tier API limits. Scaling this platfom across our growing engineering team would introduce substantial, unpreditable licensing costs.

### Option 3: Clair / Anchore Engine

+ **Pros:** Highly mature, industry-standard open-source container vulnerability engines historically integrated into major registries.

+ **Cons:** Primarily designed for server-side asynchronous registry scanning rather than developer-centric workflow automation. They require setting up and maintaining external database instances (e.g., PostgreSQL) to sync vulnerability data, making them too heavy and slow for rapid CI/CD feedback loops.


## Consequences

### Positive (Benefits)
+ **Shift-Left Security:** Developers are alerted to dangerous base images and package vulnerabilities immediately upon submitting a Pull Request, avoiding downstream deployment blockers.

+ **Minimal Infrastructure Overhead:** Because Trivy doesn't require a dedicated database cluster to run locally or in CI, it scales horizontally across runners at near-zero cost.

+ **Unified Container Compliance:** Provides standard audit logs and SBOMs out of the box, fulfilling key compliance criteria for upcoming security audits.

### Negative (Trade-offs & Mitigations)
+ **Vulnerability Database Sync Time:** Trivy must fetch the latest vulnerability database differential at the start of pipeline runs.
*Mitigation:* We will implement a centralized cache on our CI runners to store the Trivy database, ensuring pipelines do not slow down to external network requests.

+ **Legacy Image Noise:** Existing applications running on older base images will initially trigger a wave of build failures.
*Mitigation:* We will allow a 30-day grace period where teams can use Trivy .trivyignore files for existing legacy CVEs, provided a ticket is logged for base image remediation.

