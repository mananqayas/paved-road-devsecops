# ADR-0003: Use Gitleaks (secrets scanning) for the paved-road-pipeline
Date: 2026-10-10

Status: Accepted

## Context

Engineering teams develop application code that require sensitive credentials, including API keys, database passwords, and authentication tokens.

Currently, there is a risk of developers accidentally hardcoding these credentials into source files and pushing them to remote repositories. This exposure introduces severe security vulnerabilities and increases the risk of data breaches.

To mitigate this, we require a mechanism that detects and prevents secrets from being exposed both at the local dev level (before the code is commited) and at the central level (during Continuous Integration pipelines).

## Decision
We will adopt **Gitleaks** as this project's standard secret scanning solution. To ensure full coverage, we will implement it at two critical guardrails:

+ **Local Prevention (Shift-Left)**: We will mandate the user for **pre-commit** hooks using the framework/pre-commit ecosystem to run Gitleaks locally on every developer's machine before code can be committed.
+ **Central Detection (CI Pipeline)**: We will integrate the **Gitleaks GitHub Action** (or GitLab CI template) into our base Continuous Integration pipeline to scan all incoming Pull Requests / Merge Requests.
+ **Enforcement:** CI pipeline scans will be configured as **blocking checks.** Any pipeline that detects a secret will fail, preventing the code from being merged until the secret is remediated.

## Alternative considerations

### Option 1: TruffleHog (Open Source)
- **Overview:** A highly capable open-source secrets scanner that focuses heavily on **active validation** (verifying if a flagged key is actually live by making an outbound API call).

- **Why it was rejected:** TruffleHog is exceptionally powerful for scheduled historical repo audits and security incident response. However, because its signature feature requires making live networking calls to verify secrets, it can introduce significant latency or provider rate-limiting. For an **immediate pre-commit hook**, we require a lightning-fast, lightweight, and fully offline tool so developer workflows are not disrupted.

- **Future Consideration:**  We may layer TruffleHog into our security stack in the future for scheduled weekly full-history sweeps.

### Option 2: GitGuardian (Enterprise Platform)
- **Overview:** A leading commercial SaaS platform that offers deep, enterprise-wide governance, real-time alert dashboards, and public repo monitoring.
- **Why it was rejected:** GitGuardian is highly accurate, but it operates as a full SaaS platform. This introduces budget considerations, complex procurement cycles, and integration overhead for an enterprise security dashboard. Our immediate priority is to solve a specific, localized threat at CI level using a zero-cost, open-source solution that can be managed entirely as code via a configuration file (gitleaks.toml).

### Option 3: Yelp/detect-secrets

- **Overview:** A popular Python-based pattern and entropy scanner that maps existing technical debt using a dedicated baseline file.
- **Why it was rejected:** Written in Python, it requires installing a specific runtime ecosystem across all developer machines to execute local pre-commit hooks. Gitleaks, being written in Go, compiles to a single native binary, which offers **superior execution speed** and zero local environment dependency overhead.j:

## Consequences
- **Positive:** It is open-source, highly performant (written in Go), and easily runs offline in local hooks.
- **Negative:** Your team will need to managed a shared ``gitleaks.toml`` configuration file to handle false positives and baseline existing technical debt (historical secrets already in the git history).
