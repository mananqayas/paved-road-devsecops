# Changelog

All notable decisions and changes, newest first. Conventional commits in git; this file is the human-readable decision log.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)


## [4.0.0] - 2026-10-22

### Added
- **Docker build and push:** Added CI steps for docker build and push to GHCR
- **SBOM production:** Generating CycloneDX SBOMs for OS libraries and runtime packages
- **Cosign image sign and SBOM attestation:** Signed image artifact and SBOMs using cosign keyless public infra
- **Verification:** Image signature and SBOM attestation are verified with our own certificate identity and image digest claims

## [3.0.0] - 2026-10-16

### Added
- **IaC scanning:** Added CI scans for terraform security misconfigurations
- **Container scanner:** Added CI scans for Dockerfile misconfigurations, and docker image CRITICAL and HIGH CVEs.
- SARIF/code scanning, required checks, digest pinning, CVE triage, negative tests PR #11/#13
- ADRs (0005/0006)

## [2.0.0] – 2026-10-10

### Added
- **Gitleaks CI Integration:** Added CI scans for secrets using gitleaks
- **Custom Semgrep SAST Framework:** Integrated Semgrep engine targeting the CWE Top 25 matrix.
- **Deployed CWE Top 25 Rules:** Deployed 25 custom cwe top 25 rules alongside matching test suites.
- **ADRs 0003/0004 for Gitleaks and Semgrep.**

## [1.0.0] – 2026-10-04

### Added

- FastAPI sample (/healthz, /hello) with pytest suite
- Dockerfile: python:3.12-slim, non-root user, healthcheck
- Terraform scaffold on null provider ($0, no credentials)
- Baseline CI: python, docker (needs python), terraform jobs
- README, ADRs 0001/0002, Makefile, CHANGELOG
