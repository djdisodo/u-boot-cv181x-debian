#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib.sh"

source_branch=""
generated_branch=""
workspace=""
download_dir=""
remote="origin"
upstream_branch="upstream/latest"
output_file=""

while (($#)); do
	case "$1" in
		--source-branch)
			source_branch="$2"
			shift 2
			;;
		--generated-branch)
			generated_branch="$2"
			shift 2
			;;
		--workspace)
			workspace="$2"
			shift 2
			;;
		--download-dir)
			download_dir="$2"
			shift 2
			;;
		--remote)
			remote="$2"
			shift 2
			;;
		--upstream-branch)
			upstream_branch="$2"
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

[[ -n "$source_branch" ]] || die "--source-branch is required"
[[ -n "$generated_branch" ]] || die "--generated-branch is required"
[[ -n "$workspace" ]] || die "--workspace is required"

repo=$(repo_root)
download_dir=${download_dir:-"$(dirname -- "$workspace")"}

git fetch --prune "$remote" '+refs/heads/*:refs/remotes/'"$remote"'/*' '+refs/tags/*:refs/tags/*'

git worktree remove --force "$workspace" 2>/dev/null || true
rm -rf "$workspace"
mkdir -p "$download_dir"

git worktree add --force -B "$generated_branch" "$workspace" "refs/remotes/${remote}/${source_branch}" >/dev/null

if ! ensure_local_branch_from_remote "$remote" "$upstream_branch"; then
	ensure_empty_branch "$upstream_branch"
fi

ensure_local_branch_from_remote "$remote" pristine-tar || true

cd "$workspace"

source_pkg=$(package_source_name)
upstream_version=$(package_upstream_version)
full_version=$(package_full_version)
distribution=$(package_distribution)
upstream_tag=$(gbp_upstream_tag "$upstream_version")

uscan --check-dirname-level 0 --download-current-version --rename --destdir "$download_dir"

main_orig="${download_dir}/${source_pkg}_${upstream_version}.orig.tar.xz"
opensbi_orig="${download_dir}/${source_pkg}_${upstream_version}.orig-opensbi.tar.xz"
[[ -f "$main_orig" ]] || die "missing main orig tarball: $main_orig"
[[ -f "$opensbi_orig" ]] || die "missing component orig tarball: $opensbi_orig"

import_log=$(mktemp)
import_mode="gbp-import"

if ! gbp import-orig \
	--no-interactive \
	--debian-branch="$generated_branch" \
	--upstream-branch="$upstream_branch" \
	--upstream-version "$upstream_version" \
	"$main_orig" >"$import_log" 2>&1; then
	cat "$import_log" >&2
	if grep -q "Upstream tag '.*' already exists" "$import_log"; then
		import_mode="reuse-existing-upstream"
		recipe_ref="refs/remotes/${remote}/${source_branch}"
		upstream_ref="refs/heads/${upstream_branch}"
		find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
		git checkout "$upstream_ref" -- .
		git checkout "$recipe_ref" -- .
		git add -A
		tree_id=$(git write-tree)
		parent_recipe=$(git rev-parse "$recipe_ref")
		parent_upstream=$(git rev-parse "$upstream_ref")
		commit_id=$(
			printf 'Regenerate %s from %s for upstream %s\n' \
				"$generated_branch" "$source_branch" "$upstream_version" |
				git commit-tree "$tree_id" -p "$parent_recipe" -p "$parent_upstream"
		)
		git reset --hard "$commit_id" >/dev/null
	else
		exit 1
	fi
else
	cat "$import_log"
fi

rm -f "$import_log"

write_output "$output_file" workspace "$workspace"
write_output "$output_file" download_dir "$download_dir"
write_output "$output_file" source_pkg "$source_pkg"
write_output "$output_file" upstream_version "$upstream_version"
write_output "$output_file" full_version "$full_version"
write_output "$output_file" distribution "$distribution"
write_output "$output_file" upstream_tag "$upstream_tag"
write_output "$output_file" main_orig "$main_orig"
write_output "$output_file" opensbi_orig "$opensbi_orig"
write_output "$output_file" generated_branch "$generated_branch"
write_output "$output_file" source_branch "$source_branch"
write_output "$output_file" upstream_branch "$upstream_branch"
write_output "$output_file" import_mode "$import_mode"
