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
keyring=""

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
		--keyring)
			keyring="$2"
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

download_debian_archive_keyring() {
	local cache_root="${SBUILD_KEYRING_CACHE_DIR:-${TMPDIR:-/tmp}/sbuild-keyrings}"
	local cache_dir="$cache_root"
	local index_url="${SBUILD_DEBIAN_KEYRING_INDEX_URL:-https://deb.debian.org/debian/pool/main/d/debian-archive-keyring/}"
	local package_name=""
	local package_path=""
	local extracted_dir=""
	local keyring_path=""

	install -d -m 0755 "$cache_dir"
	package_name=$(
		curl -fsSL "$index_url" |
			grep -oE 'debian-archive-keyring_[^"]+_all\.deb' |
			sort -uV |
			tail -n 1
	)
	[[ -n "$package_name" ]] || die "unable to determine latest debian-archive-keyring package from $index_url"

	package_path="${cache_dir}/${package_name}"
	keyring_path="${cache_dir}/${package_name%.deb}.gpg"

	if [[ ! -f "$keyring_path" ]]; then
		curl -fsSL -o "$package_path" "${index_url}${package_name}"
		extracted_dir=$(mktemp -d)
		dpkg-deb -x "$package_path" "$extracted_dir"
		install -m 0644 \
			"$extracted_dir/usr/share/keyrings/debian-archive-keyring.gpg" \
			"$keyring_path"
		rm -rf "$extracted_dir"
	fi

	printf '%s\n' "$keyring_path"
}

cd "$workspace"

user_name=$(id -un)
getsubids "$user_name" >/dev/null 2>&1 || die "missing subuid allocation for ${user_name}; configure /etc/subuid before using sbuild unshare mode"
getsubids -g "$user_name" >/dev/null 2>&1 || die "missing subgid allocation for ${user_name}; configure /etc/subgid before using sbuild unshare mode"

source_pkg=$(package_source_name)
full_version=$(package_full_version)
upstream_version=$(package_upstream_version)
dist_from_changelog=$(package_distribution)
suite=$(normalized_sbuild_suite "${suite:-${SBUILD_SUITE:-$dist_from_changelog}}")
arch=${arch:-${SBUILD_ARCH:-$(dpkg --print-architecture)}}
build_dir=${build_dir:-"$(dirname -- "$workspace")/sbuild-out"}
artifact_dir=${artifact_dir:-"$(dirname -- "$workspace")/artifacts"}
chroot_tarball="${HOME}/.cache/sbuild/${suite}-${arch}.tar"
keyring=${keyring:-${SBUILD_KEYRING:-}}

mkdir -p "$build_dir" "$artifact_dir" "$(dirname -- "$chroot_tarball")"

if [[ -z "$keyring" ]]; then
	if [[ "$mirror" == *deb.debian.org/debian* || "$mirror" == *ftp.debian.org/debian* ]]; then
		keyring=$(download_debian_archive_keyring)
	elif [[ -f /usr/share/keyrings/debian-archive-keyring.gpg ]]; then
		keyring=/usr/share/keyrings/debian-archive-keyring.gpg
	fi
fi

if [[ -n "$keyring" ]]; then
	[[ -r "$keyring" ]] || die "keyring is not readable: $keyring"
fi

if [[ ! -f "$chroot_tarball" ]]; then
	mmdebstrap_args=(--variant=buildd)
	if [[ -n "$keyring" ]]; then
		mmdebstrap_args+=(--keyring "$keyring")
	fi
	mmdebstrap "${mmdebstrap_args[@]}" "$suite" "$chroot_tarball" "$mirror"
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
	"${build_dir}/${source_pkg}_${full_version}"*.deb \
	"${build_dir}/${source_pkg}_${full_version}"*.udeb \
	"${build_dir}/${source_pkg}_${full_version}"*.changes \
	"${build_dir}/${source_pkg}_${full_version}"*.buildinfo \
	"${build_dir}"/**/"${source_pkg}_${full_version}"*.build; do
	if [[ -f "$file" ]]; then
		copy_artifact_file "$artifact_dir" "$file"
	fi
done

write_output "$output_file" artifact_dir "$artifact_dir"
write_output "$output_file" suite "$suite"
write_output "$output_file" arch "$arch"
write_output "$output_file" chroot_tarball "$chroot_tarball"
write_output "$output_file" keyring "${keyring:-}"
