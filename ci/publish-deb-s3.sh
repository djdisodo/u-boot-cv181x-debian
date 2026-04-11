#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib.sh"

artifact_dir=""

while (($#)); do
	case "$1" in
		--artifact-dir)
			artifact_dir="$2"
			shift 2
			;;
		*)
			die "unknown argument: $1"
			;;
	esac
done

[[ -n "$artifact_dir" ]] || die "--artifact-dir is required"
[[ -n "${DEB_S3_BUCKET:-}" ]] || die "DEB_S3_BUCKET is required"

mapfile -t debs < <(find "$artifact_dir" -maxdepth 1 -type f -name '*.deb' | sort)
[[ ${#debs[@]} -gt 0 ]] || die "no .deb files found in $artifact_dir"

args=(
	upload
	--bucket "$DEB_S3_BUCKET"
	--codename "${DEB_S3_CODENAME:-stable}"
	--component "${DEB_S3_COMPONENT:-main}"
	--s3-region "${DEB_S3_REGION:-us-east-1}"
)

if [[ -n "${DEB_S3_ENDPOINT:-}" ]]; then
	args+=(--endpoint "$DEB_S3_ENDPOINT")
fi

if [[ "${DEB_S3_FORCE_PATH_STYLE:-0}" == "1" ]]; then
	args+=(--force-path-style)
fi

if [[ -n "${DEB_S3_PREFIX:-}" ]]; then
	args+=(--prefix "$DEB_S3_PREFIX")
fi

if [[ -n "${DEB_S3_ORIGIN:-}" ]]; then
	args+=(--origin "$DEB_S3_ORIGIN")
fi

if [[ -n "${DEB_S3_SUITE:-}" ]]; then
	args+=(--suite "$DEB_S3_SUITE")
fi

if [[ "${DEB_S3_PRESERVE_VERSIONS:-0}" == "1" ]]; then
	args+=(--preserve-versions)
fi

if [[ "${DEB_S3_LOCK:-1}" == "1" ]]; then
	args+=(--lock)
fi

if [[ "${DEB_S3_FAIL_IF_EXISTS:-0}" == "1" ]]; then
	args+=(--fail-if-exists)
fi

if [[ -n "${DEB_S3_VISIBILITY:-}" ]]; then
	args+=(--visibility "$DEB_S3_VISIBILITY")
fi

deb-s3 "${args[@]}" "${debs[@]}"
