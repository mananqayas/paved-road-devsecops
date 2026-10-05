# Changelog

All notable decisions and changes, newest first. Conventional commits in git; this file is the human-readable decision log.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)

## [1.0.0] 2026-10-04

### Added

- FastAPI sample (/healthz, /hello) with pytest suite
- Dockerfile: python:3.12-slim, non-root user, healthcheck
- Terraform scaffold on null provider ($0, no credentials)
- Baseline CI: python, docker (needs python), terraform jobs
- README, ADRs 0001/0002, Makefile, CHANGELOG