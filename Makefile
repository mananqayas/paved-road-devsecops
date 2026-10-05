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
all: install test lint
	@echo "Phase 1.0 local checks passed."