# ARD-0004: Use Semgrep for static application security testing
Date: 2026-09-30

Status: Accepted

## Context

As our backend codebase expands in complexity and team size, the probability of introducing application security defects, such as SQL injection, Cross-Site Scripting (XSS), path traversals, or insecure dependency configurations increases significantly.

Replying entirely on manual peer reviews or third-party penetration testing to catch these code-level flaws is highly unsustainable. Finding these bugs late in the software development lifecycle (SDLC) or post-production results in costly hotfixes, delayed product shipments, and elevated exposure to security incidents.

To maintain a high shipping velocity without compromising security compliance, we require a automated, developer-friendly **Static Application Security Testing (SAST)** solution. This solution must automatically analyze source code for patterns indicating security flaws, seamlessly interface with our CI/CD pipelines, and provide actionable remediation feedback directly within developer code review workflows (Pull Requests).

## Decision

We will adopt **Semgrep** as this project's standard static application security testing solution. To ensure full coverage, we will implement it at two critical guardrails:

+ **Local Testing (Shift-Left):** After writing implementation code, developers use make ```semgrep-sast-test``` and ```semgrep-sast-scan``` to test the custom rules and scan the diff and exits with code 1. The developer is presented with detected security vulnerabilties and their details. Developer can fix the code and retest to pass.
+ **Central Detection (CI Pipeline):** We will integreate semgrep with GitHub Actions CI job using docker image inside the ubuntu runner named ```semgrep/semgrep:latest```.
+ **Enforcement:** CI pipeline scans will be configured as **blocking checks.** Any pipeline that identifies code containing one of the CWE Top 25 rules will fail, preventing the code from being merged until the vulnerability is remediated.

## Alternative Decisions

### Option 1: SonarQube / SonarCloud

+ **Overview:** A widely-used platform for tracking static code analysis, code coverage, and general code quality metrics over time.

+ **Why it was rejected:** SonarQube is heavy-duty and relies on a central server architecture. This makes it incredibly difficult to run locally on a developer's machine without complex Docker setups or cloud connectivity. Because our engineering requirements mandate a frictionless local workflow (```make semgrep-sast-test```), we chose Semgrep's lightweight, decentralized CLI structure instead.

### Option 2: GitHub CodeQL

+ **Overview:** GitHub's native semantic code analysis engine that treats source code like a database to trace complex data flows (taint analysis).
+ **Why it was rejected:** While CodeQL offers incredibly deep analysis, it requires compiling the codebase during the scan. This results in significantly longer CI pipeline run times that would slow down our PR feedback loop. Semgrep evaluates rules via abstract syntax trees (AST) incredibly fast, fulfilling our need for a rapid, blocking CI check.

## Consequences

+ **Positive (Benefits):**
    ++ **Unified Developer Workflows:** Providing ```make semgrep-sast-test``` (for dry-runs) and ```make semgrep-sast-scan``` ensures developers can run identical security checks locally on their machines before ever pushing code.
    ++ **Enforced Guardrails:** Configuring the CI job to fail with the ```--error``` flag ensures that critical security vulnerabilities are blocked immediately at the Pull Request layer, preventing insecure code from ever reaching a production branch.
    ++ **Blazing Fast Execution:** Semgrep's scan speeds are minimal, meaning our blocking CI checks will not bottleneck development velocity or drastically increase pipeline compute costs.

+ **Negative (Trade-offs & Maintenance):**
    ++ **False Positive Triage:** Because the CI job explicitely blocks PR merges on errors, any false positive will completely halt a developer's deployment. The security and backend teams must actively maintain a ```.semgrepignore``` file or use inline code overrides (```# nosemgrep```) to mitigate workflow disruptions.
    ++ **Rule Tuning Overhead:** The team must invest initial operational effort into configuring the specific Semgrep rulesets (registry rules vs. custom internal rules) to ensure the blocking ```--error``` flag only triggers on high-confidence, actionable vulnerabilities.
