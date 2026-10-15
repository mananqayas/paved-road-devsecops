.PHONY: install test lint docker-build tf-fmt tf-validate all
install:
	uv sync
test:
	uv run pytest
lint:
	uv run ruff check
docker-build:
	docker build -t paved-road-sample-api:dev .
tf-fmt:
	terraform -chdir=terraform fmt
tf-validate:
	terraform -chdir=terraform init -backend=false -input=false
	terraform -chdir=terraform validate
gitleaks:
	gitleaks git
semgrep-sast-test:
	semgrep --test semgrep/rules
semgrep-sast-scan:
	semgrep scan --config semgrep/rules/cwe-top25-rules.yml app
checkov-iac-scan:
	checkov -d terraform/
trivy-dockerfile-scan:
	trivy config --severity 'HIGH,CRITICAL' Dockerfile
trivy-image-scan:
	trivy image paved-road-sample-api:dev --severity 'CRITICAL,HIGH'
all: install test lint gitleaks semgrep-sast-test semgrep-sast-scan checkov-iac-scan trivy-dockerfile-scan trivy-image-scan
	@echo "Phase 3.0 local checks passed."
