#!/bin/bash
# Enable strict mode: Exit on errors, unset variables, or pipe failues
# set -euo pipefail

IMAGE_REF=""
IDENTITY=""
EXPECTED_COMMIT=""
SOURCE_REPO="git+https://github.com/mananqayas/paved-road-devsecops"
REPO="https://github.com/mananqayas/paved-road-devsecops"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--image-ref) 
			if [[ $# -lt 2 || -z "$2" ]]; then
				echo "Error: --image-ref needs a value" >&2
				exit 1
			fi
			IMAGE_REF="$2";
			shift 2
			;;
		--identity)
			if [[ $# -lt 2 || -z "$2" ]]; then
				echo "Error: --identity needs a value" >&2
				exit 1;
			fi
			IDENTITY="$2";
			shift 2
			;;
		--commit-sha)
			if [[ $# -lt 2 || -z "$2" ]]; then
				echo "Error: --commit-sha needs a value" >&2
				exit 1;
			fi
			EXPECTED_COMMIT="$2";
			shift 2
			;;
		*) echo "Unknown argument: $1"; exit 1 ;;
	esac

done

# Validate all required arguments
: "${IMAGE_REF:?Error: --image-ref is required}"
: "${IDENTITY:?Error: --identity is required}"
: "${EXPECTED_COMMIT:?Error: --commit-sha is required}"



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

echo "Image signature verified successfully";


if ! ATTEST_OUT=$(cosign verify-attestation --type cyclonedx --certificate-identity "${IDENTITY}" --certificate-oidc-issuer "https://token.actions.githubusercontent.com" "$IMAGE_REF"); then
	echo "Error: SBOM attestation verification failed";
	exit 1
fi

echo "Image's SBOMs are verified successfully";


VERIFIED_REF=$(jq -r '.[0].critical.identity["docker-reference"]' <<< "$SIG_OUT")
if [[ "$VERIFIED_REF" != "$IMAGE_REF" ]]; then
	echo "Error: verified reference ($VERIFIED_REF) != requested ($IMAGE_REF)"
	exit 1
fi
echo "$EXPECTED_COMMIT"

VERIFIED_FILE="$(mktemp)"
trap 'rm -f "$VERIFIED_FILE"' EXIT

echo "Checking SLSA provenance policy"

if ! SLSAPROVENANCE_OUT=$(cosign verify-attestation \
	--type slsaprovenance02 \
	--certificate-identity "$IDENTITY" \
	--certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
	"$IMAGE_REF" > "$VERIFIED_FILE"); then
	echo "Error: SLSAPROVENANCE verification failed"
	exit 1
fi
die() {

	echo "[ERROR] $*" >&2
	exit 1
}
EXPECTED_DIGEST="${IMAGE_REF##*@sha256:}"
jq -s -e \
	--arg repo "$SOURCE_REPO" \
	--arg commit "$EXPECTED_COMMIT" \
	--arg digest "$EXPECTED_DIGECT" \
	--arg entry "CI" \
	--arg builder_prefix "https://github.com/mananqayas/devsecops/actions/runs/" '
	[
	.[]
	| (.dsseEnvelope.payload // .payload)
	| @base64d
	| fromjson
	]
	| any (.[];
		.predicateType == "https://slsa.dev/provenance/v0.2"
		and any (.subject[]?;
		.digest.sha256 == $digest
		)
		and .predicate.invocation.configSource.uri == $repo

		and .predicate.invocation.configSource.entryPoint == $entry

		and (.predicate.builder.id | type == "string" and startswith($builder_prefix))
		)
		' "$VERIFIED_FILE" > /dev/null || 
			die "SLSA provenance policy FAILED"
