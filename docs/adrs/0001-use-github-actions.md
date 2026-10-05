# ADR-0001: Use GitHub Actions for the paved-road pipeline
Date: 2026-09-30

Status: Accepted

## Context
Need a CI system for the paved-road pipeline that service teams can adopt with zero infrastructure, supports OIDC (required for Cosign keyless signing in Phase 4.0), and is free for a public portfolio repo.

## Decision
Use GitHub Actions. Code lives on GitHub anyway; Actions give us OIDC-to-Sigstore federation. SARIF upload to code scanning (Phase 3.0), reusable workflows/callable actions for the "paved road" distribution model, and 2000 free minutes/month.

## Alternative considerations
- **Jenkins:** self-hosted, real-world enterprise relevance, but needs a controller + agents ($, maintenance) – overkill for Phase 1.0, weakens the "adopt in one PR" story.
- **CircleCI:** clean UX, but OIDC story is thinner and free tier is smaller; no SARIF-native code scanning intergration.

## Consequences
- Pipeline is GitHub-coupled. Mitigation: keep scanner invocations in composable shell steps / composite actions so a Jenkins.ADO port is mechanical.
- Minutes cap is fine for a smaller app; documented in Cost section.