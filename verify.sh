#!/bin/bash
# Enable strict mode: Exit on errors, unset variables, or pipe failues
# set -euo pipefail

IMAGE_REF=""
CERTIFICATE_IDENTITY="https://github.com/mananqayas/paved-road-devsecops/.github/workflows/ci.yml@refs/heads/main"
IDENTITY="$CERTIFICATE_IDENTITY"


while [[ $# -gt 0 ]]; do
	case "$1" in
		--image-ref) 
			if [[ $# -lt 2 ]]; then echo "Error: --image-ref needs a value"; exit 1; fi
			IMAGE_REF="$2"; shift 2 ;;
		--identity)
			if [[ $# -lt 2 ]]; then echo "Error: --identity needs a value"; exit 1; fi
			IDENTITY="$2"; shift 2 ;;
		*) echo "Unknown argument: $1"; exit 1 ;;
	esac

done


COSIGN_VERSION="v3.1.4"
if ! command -v cosign &>/dev/null; then
	OS=$(uname -s | tr '[:upper:]' '[:lower:]')
	ARCH=$(uname -m)
	case "$ARCH" in
		x86_64) ARCH=amd64 ;;
		aarch64|arm64) ARCH=arm64 ;;
		*) echo "unsupported arch: $ARCH"; exit 1 ;;
	esac
	echo "Installing cosign ${COSIGN_VERSION} (${OS}/${ARCH}...)"
	curl -sSL -o /tmp/cosign \
		"https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-${OS}-${ARCH}"
	chmod +x /tmp/cosign
	sudo mv /tmp/cosign "$HOME/.local/bin/cosign"
fi
if ! SIG_OUT=$(cosign verify --certificate-identity "${IDENTITY}" --certificate-oidc-issuer "https://token.actions.githubusercontent.com" "$IMAGE_REF"); then
	echo "Error: signature verification failed for $IMAGE_REF";
	exit 1
fi
if ! ATTEST_OUT=$(cosign verify-attestation --type cyclonedx --certificate-identity "${IDENTITY}" --certificate-oidc-issuer "https://token.actions.githubusercontent.com" "$IMAGE_REF"); then
	echo "Error: SBOM attestation verification failed";
	exit 1
fi
VERIFIED_REF=$(jq -r '.[0].critical.identity["docker-reference"]' <<< "$SIG_OUT")
if [[ "$VERIFIED_REF" != "$IMAGE_REF" ]]; then
	echo "Error: verified reference ($VERIFIED_REF) != requested ($IMAGE_REF)"
	exit 1
fi
