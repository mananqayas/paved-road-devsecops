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
all: install test lint gitleaks semgrep-sast-test semgrep-sast-scan
	@echo "Phase 1.0 local checks passed."