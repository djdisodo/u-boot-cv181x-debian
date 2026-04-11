#!/usr/bin/env bash
set -euo pipefail

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

repo_root() {
	git rev-parse --show-toplevel
}

package_source_name() {
	dpkg-parsechangelog --show-field Source
}

package_full_version() {
	dpkg-parsechangelog --show-field Version
}

package_upstream_version() {
	package_full_version | sed 's/-[^-]*$//'
}

package_distribution() {
	dpkg-parsechangelog --show-field Distribution
}

normalized_sbuild_suite() {
	local suite="$1"
	if [[ -z "$suite" || "$suite" == "UNRELEASED" || "$suite" == "unreleased" ]]; then
		printf 'unstable\n'
	else
		printf '%s\n' "$suite"
	fi
}

gbp_upstream_tag() {
	local version="$1"
	printf 'upstream/%s\n' "${version//\~/_}"
}

write_output() {
	local output_file="$1"
	local key="$2"
	local value="$3"

	if [[ -z "$output_file" ]]; then
		return 0
	fi

	printf '%s=%s\n' "$key" "$value" >>"$output_file"
}

ensure_local_branch_from_remote() {
	local remote="$1"
	local branch="$2"
	local ref="refs/remotes/${remote}/${branch}"

	if git show-ref --verify --quiet "$ref"; then
		git branch -f "$branch" "$ref" >/dev/null
		return 0
	fi

	return 1
}

ensure_empty_branch() {
	local branch="$1"
	local empty_tree="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
	local commit

	commit=$(printf 'Initial %s branch\n' "$branch" | git commit-tree "$empty_tree")
	git update-ref "refs/heads/${branch}" "$commit"
}

copy_if_exists() {
	local output_dir="$1"
	shift

	for file in "$@"; do
		if [[ -f "$file" ]]; then
			cp -a "$file" "$output_dir"/
		fi
	done
}
