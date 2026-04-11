#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib.sh"

workspace=""
dsc=""
suite=""
arch=""
mirror="${SBUILD_MIRROR:-http://deb.debian.org/debian}"
build_dir=""
artifact_dir=""
output_file=""

while (($#)); do
	case "$1" in
		--workspace)
			workspace="$2"
			shift 2
			;;
		--dsc)
			dsc="$2"
			shift 2
			;;
		--suite)
			suite="$2"
			shift 2
			;;
		--arch)
			arch="$2"
			shift 2
			;;
		--mirror)
			mirror="$2"
			shift 2
			;;
		--build-dir)
			build_dir="$2"
			shift 2
			;;
		--artifact-dir)
			artifact_dir="$2"
			shift 2
			;;
		--output-file)
			output_file="$2"
			shift 2
			;;
		*)
			die "unknown argument: $1"
			;;
	esac
done

[[ -n "$workspace" ]] || die "--workspace is required"
[[ -n "$dsc" ]] || die "--dsc is required"

cd "$workspace"

source_pkg=$(package_source_name)
full_version=$(package_full_version)
upstream_version=$(package_upstream_version)
dist_from_changelog=$(package_distribution)
suite=$(normalized_sbuild_suite "${suite:-${SBUILD_SUITE:-$dist_from_changelog}}")
arch=${arch:-${SBUILD_ARCH:-$(dpkg --print-architecture)}}
build_dir=${build_dir:-"$(dirname -- "$workspace")/sbuild-out"}
artifact_dir=${artifact_dir:-"$(dirname -- "$workspace")/artifacts"}
chroot_tarball="${HOME}/.cache/sbuild/${suite}-${arch}.tar"

mkdir -p "$build_dir" "$artifact_dir" "$(dirname -- "$chroot_tarball")"

if [[ ! -f "$chroot_tarball" ]]; then
	mmdebstrap --variant=buildd "$suite" "$chroot_tarball" "$mirror"
fi

sbuild \
	--chroot-mode=unshare \
	--chroot "$chroot_tarball" \
	--dist "$suite" \
	--arch "$arch" \
	--build-dir "$build_dir" \
	--no-run-lintian \
	--no-run-autopkgtest \
	--no-run-piuparts \
	"$dsc"

parent_dir=$(dirname -- "$dsc")
shopt -s nullglob globstar
copy_if_exists "$artifact_dir" \
	"${parent_dir}/${source_pkg}_${full_version}.dsc" \
	"${parent_dir}/${source_pkg}_${full_version}.debian.tar.xz" \
	"${parent_dir}/${source_pkg}_${upstream_version}.orig.tar.xz" \
	"${parent_dir}/${source_pkg}_${upstream_version}.orig-opensbi.tar.xz"

for file in \
	"${parent_dir}/${source_pkg}_${full_version}"*.deb \
	"${parent_dir}/${source_pkg}_${full_version}"*.udeb \
	"${parent_dir}/${source_pkg}_${full_version}"*.changes \
	"${parent_dir}/${source_pkg}_${full_version}"*.buildinfo \
	"${build_dir}"/**/"${source_pkg}_${full_version}"*.build; do
	if [[ -f "$file" ]]; then
		cp -a "$file" "$artifact_dir"/
	fi
done

write_output "$output_file" artifact_dir "$artifact_dir"
write_output "$output_file" suite "$suite"
write_output "$output_file" arch "$arch"
write_output "$output_file" chroot_tarball "$chroot_tarball"
