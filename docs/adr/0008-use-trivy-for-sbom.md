# ADR-0008: Selecting Trivy and CycloneDX for SBOM generation
Date: 2026-10-20

Status: Accepted

## Context

Following our decision to adopt software supply chain signing (ADR 0007), we must define a standardized tool and schema for generating our **Software Bills of Materials (SBOMs)** during the CI build process.

An effective SBOM strategy requires:

1. A **generation tool** that integrates seamlessly into our container compilation pipelines without introducing performance bottlenecks.
2. A **standardized data schema** capable of accurately representing both OS-level system libraries and complex, application-level open-source language dependencies (transitive dependencies).
3. Wide interoperability with downstream policy enforcement tools (e.g., Kyverno) and continuous vulnerability management scanners.

## Decision

We will standardize on **Aqua Security's Trivy** as our core tool for automated SBOM generation, and we will output these files natively in the **OWASP CycloneDX (JSON)** format.

### Implementation Specifics

+ **Execution Window:** Trivy will run inside the CI pipeline immediately after a container image is successfully built, but prior to the `cosign sign` step.

+ **Output Configuration:** The generation command will be standardized as:

```
trivy image --format cyclonedx --output sbom.json IMAGE_NAME:SHA_DIGEST

```
+ **Storage:** The resulting sbom.json will be attached directly to the image in the OCI registry as an attestation using Cosign (`cosign attest --type cyclonedx --predicate sbom.json ...`) so that it travels alongside the container image inherently.

## Alternative considerations

### Alternative 1: Syft (by Anchore)
+ **Description:** A highly popular, dedicated CLI tool explicitly designed for generating SBOMs for container images and filesystems.
+ **Why Rejected:** While Syft is an exceptional tool for SBOM generation, choosing it would require us to maintain two distinct security binaries in our CI runners (Syft for generating the SBOM, and Trivy for local vulnerability scanning.) Standardizing on Trivy allows us to consolidate our DevSecOps tooling, using one engine for generation, scanning, and local pipeline gating.

### Alternative 2: SPDX (Software Package Data Exchange) format
+ **Description:** An ISO-standard open format for SBOMs, heavily championed by the Linux Foundation.
+ **Why Rejected:** SPDX excels at tracking deep legal licensing, copyright data, and intellectual property constraints. However, our primary threat model evolves around **cybersecurity, rapid vulnerability mapping (CVEs), and cloud-native application components.** CycloneDX is much more lightweight, natively optimized for fast JSON parsing, and maintains superior out-of-the-box integration with application security posture management (ASPM) tools.

## Consequences

### Positive (Benefits)
+ **Tooling Consolidation:** Reduces maintenance overhead by using Trivy for both SBOM production and static container analysis.
+ **Downstream Compatibility:** CycloneDX JSON format is natively swallowed by major vulnerability platforms (Dependency-Track, DefectDojo, Snyk, Wiz).
+ **Precision Inventorying:** Trivy accurately parses deep application lockfiles, giving security teams visibility into obscured transitive vulnerabilities.

### Negative / Risks (Trade-offs)
+ **Format Lock-in:** While conversion tools exist, migrating downstream security integrations from CycloneDX to SPDX in the future would require updating all pipeline definitions and ingestion schemas.
