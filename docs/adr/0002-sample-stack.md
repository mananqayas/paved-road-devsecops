# ADR-0002: Sample stack – Python FastAPI on slim, null Terraform

Date: 2026-09-30

Status: Accepted

## Context
The pipeline needs a realistic-but-boring sample app (API + Dockerfile + Terraform) that scanners can chew on in Phase 2.0-4.0. It must stay cheap, fast in CI, and familiar enough that custom Semgrep rules feel natural.

## Decision
- **FastAPI** (not Flask): typed endpoints make better Semgrep custom-rule targets; matches my Python background.
- `python:3.12-slim` (not alpine/distroless yet): glibc compatibility avoids weird build failures in Phase 1.0; image-hardening is a Phase 3.0 decision made with Trivy evidence, not upfront.
- **Non-root** `appuser` **from day one:** one-line, never regretted, no downside.
- **Terraform null provider:** zero cost, zero credentials, CI stays green without AWS. Real resources + Checkov arrive in Phase 3.0.

## Consequences

- Slightly larger image than distroless – accepted until Phase 3.0 measures it.
- Null Terraform looks trivially small – intentional; it's a placeholder the Checkov phase will grow into real (still cheap) resources.