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

common_args=(
	--bucket "$DEB_S3_BUCKET"
	--codename "${DEB_S3_CODENAME:-stable}"
	--component "${DEB_S3_COMPONENT:-main}"
	--s3-region "${DEB_S3_REGION:-us-east-1}"
)

if [[ -n "${DEB_S3_ENDPOINT:-}" ]]; then
	common_args+=(--endpoint "$DEB_S3_ENDPOINT")
fi

if [[ "${DEB_S3_FORCE_PATH_STYLE:-0}" == "1" ]]; then
	common_args+=(--force-path-style)
fi

if [[ -n "${DEB_S3_PREFIX:-}" ]]; then
	common_args+=(--prefix "$DEB_S3_PREFIX")
fi

if [[ -n "${DEB_S3_ORIGIN:-}" ]]; then
	common_args+=(--origin "$DEB_S3_ORIGIN")
fi

if [[ -n "${DEB_S3_SUITE:-}" ]]; then
	common_args+=(--suite "$DEB_S3_SUITE")
fi

if [[ "${DEB_S3_PRESERVE_VERSIONS:-0}" == "1" ]]; then
	common_args+=(--preserve-versions)
fi

if [[ "${DEB_S3_LOCK:-1}" == "1" ]]; then
	common_args+=(--lock)
fi

if [[ "${DEB_S3_FAIL_IF_EXISTS:-0}" == "1" ]]; then
	common_args+=(--fail-if-exists)
fi

if [[ -n "${DEB_S3_VISIBILITY:-}" ]]; then
	common_args+=(--visibility "$DEB_S3_VISIBILITY")
fi

upload_args=(upload "${common_args[@]}")
deb-s3 "${upload_args[@]}" "${debs[@]}"

if [[ "${DEB_S3_CLEAN:-1}" == "1" && "${DEB_S3_PRESERVE_VERSIONS:-0}" != "1" ]]; then
	clean_args=(clean "${common_args[@]}")
	deb-s3 "${clean_args[@]}"
fi
