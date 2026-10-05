#!/usr/bin/env bash
# Phase 1.0 – push repo to GitHub and local down main.
# Prerequisites: gh auth login (run once)
set -euo pipefail

REPO_NAME="${1:-paved-road-devsecops}"

VISIBILITY="${2:-public}" # public keeps Actions free + portfolio-visible

cd "$(dirname "$0")"

if ! gh auth status > /dev/null 2>&1; then
    echo "Not logged into GitHub. Run: gh auth login"
    exit 1
fi

# Create repo + push (skios if remote already set)
if ! git remote get-url origin >/dev/null 2>&1 ; then
    gh repo create "$REPO_NAME" --"$VISIBILITY" --source=. --push \
    --description "Paved-road DevSecOps pipeline: Gitleaks, Semgrep, Checkov, Trivy, Cosign, SBOM – reusable GitHub Actions with policy gates."
    git branch -M main
else
    git push -u origin main
fi

OWNER="$(gh repo view --json owner -q '.owner.id')"
gh api --method POST "/repos/${OWNER}/${REPO_NAME}/rulesets" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2026-03-10" --input - <<< '
{
  "name": "Protect Main Branch",
  "target": "branch",
  "enforcement": "active",
	"conditions": {"ref_name": {"include":["refs/heads/main"], "exclude": []}},
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          {
            "context": "python"
          },
          {
            "context": "docker"
          },
          {
            "context": "terraform"
          },
          {
            "context": "secrets_scan"
          },
        ]
      }
    }
  ]
}'


