#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib.sh"

workspace=""
output_file=""

while (($#)); do
	case "$1" in
		--workspace)
			workspace="$2"
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

cd "$workspace"
debian/rules clean || true
dpkg-source -b .

source_pkg=$(package_source_name)
full_version=$(package_full_version)
upstream_version=$(package_upstream_version)
parent_dir=$(dirname -- "$workspace")
dsc="${parent_dir}/${source_pkg}_${full_version}.dsc"
debian_tar="${parent_dir}/${source_pkg}_${full_version}.debian.tar.xz"
main_orig="${parent_dir}/${source_pkg}_${upstream_version}.orig.tar.xz"
opensbi_orig="${parent_dir}/${source_pkg}_${upstream_version}.orig-opensbi.tar.xz"

[[ -f "$dsc" ]] || die "missing generated dsc: $dsc"

write_output "$output_file" dsc "$dsc"
write_output "$output_file" debian_tar "$debian_tar"
write_output "$output_file" main_orig "$main_orig"
write_output "$output_file" opensbi_orig "$opensbi_orig"
