#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/lib.sh"

workspace=""
generated_branch=""
remote="origin"
upstream_branch="upstream/latest"

while (($#)); do
	case "$1" in
		--workspace)
			workspace="$2"
			shift 2
			;;
		--generated-branch)
			generated_branch="$2"
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
		*)
			die "unknown argument: $1"
			;;
	esac
done

[[ -n "$workspace" ]] || die "--workspace is required"
[[ -n "$generated_branch" ]] || die "--generated-branch is required"

cd "$workspace"

git push --force-with-lease "$remote" \
	"refs/heads/${generated_branch}:refs/heads/${generated_branch}"

if git show-ref --verify --quiet "refs/heads/${upstream_branch}"; then
	git push "$remote" "refs/heads/${upstream_branch}:refs/heads/${upstream_branch}"
fi

if git show-ref --verify --quiet "refs/heads/pristine-tar"; then
	git push "$remote" "refs/heads/pristine-tar:refs/heads/pristine-tar"
fi

git push "$remote" --tags
