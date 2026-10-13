#!/usr/bin/env bash
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_SHA:?GITHUB_SHA is required}"

manifest=".github/maintenance/branch-audit-2026-10-13.json"
open_count="$(gh api "repos/${GITHUB_REPOSITORY}/pulls?state=open&per_page=100" --jq 'length')"
if [[ "$open_count" != "0" ]]; then
  echo "::warning::Open PRs exist. Branch cleanup is postponed to protect active work."
  exit 0
fi

current_main="$(gh api "repos/${GITHUB_REPOSITORY}/git/ref/heads/main" --jq '.object.sha')"
[[ "$current_main" == "$GITHUB_SHA" ]] || {
  echo "::error::main changed during cleanup, refusing to delete branches"
  exit 1
}

removed=0
skipped=0

prune_one() {
  local name="$1" expected_sha="$2" number="$3" disposition="$4"
  local current_json current_sha protected pr actual_head state merged_at merge_commit
  if [[ "$name" == "main" || "$name" == *..* || -z "$name" ]]; then
    echo "::warning::Invalid or protected-by-policy branch name: ${name}"
    skipped=$((skipped + 1))
    return
  fi

  current_json="$(gh api "repos/${GITHUB_REPOSITORY}/branches?per_page=100" | jq -c --arg name "$name" '.[] | select(.name == $name)')"
  if [[ -z "$current_json" ]]; then
    echo "Already removed: ${name}"
    return
  fi
  current_sha="$(jq -r '.commit.sha' <<< "$current_json")"
  protected="$(jq -r '.protected' <<< "$current_json")"
  if [[ "$protected" != "false" || "$current_sha" != "$expected_sha" ]]; then
    echo "::warning::Retaining protected or changed branch ${name}"
    skipped=$((skipped + 1))
    return
  fi

  pr="$(gh api "repos/${GITHUB_REPOSITORY}/pulls/${number}")"
  actual_head="$(jq -r '.head.sha' <<< "$pr")"
  state="$(jq -r '.state' <<< "$pr")"
  merged_at="$(jq -r '.merged_at // ""' <<< "$pr")"
  merge_commit="$(jq -r '.merge_commit_sha // ""' <<< "$pr")"

  if [[ "$actual_head" != "$expected_sha" || "$state" != "closed" ]]; then
    echo "::warning::PR status or head changed for ${name}; leaving branch untouched"
    skipped=$((skipped + 1))
    return
  fi

  if [[ "$disposition" == "merged" ]]; then
    if [[ -z "$merged_at" || -z "$merge_commit" ]] ||
      ! git merge-base --is-ancestor "$merge_commit" "$GITHUB_SHA"; then
      echo "::warning::PR merge not present in main for ${name}; branch retained"
      skipped=$((skipped + 1))
      return
    fi
  elif [[ "$disposition" == "abandoned" ]]; then
    # The two abandoned approaches were explicitly closed as unsafe/obsolete;
    # never apply this exception to another unmerged PR.
    if [[ -n "$merged_at" || ( "$number" != "21" && "$number" != "22" ) ]]; then
      echo "::warning::Not an approved abandoned PR: ${name}"
      skipped=$((skipped + 1))
      return
    fi
  else
    echo "::warning::Unknown disposition for ${name}"
    skipped=$((skipped + 1))
    return
  fi

  # A final exact-SHA read guards against a branch advancing during validation.
  latest_sha="$(gh api "repos/${GITHUB_REPOSITORY}/branches?per_page=100" | jq -r --arg name "$name" '.[] | select(.name == $name) | .commit.sha')"
  if [[ "$latest_sha" != "$expected_sha" ]]; then
    echo "::warning::Branch advanced before delete; retaining ${name}"
    skipped=$((skipped + 1))
    return
  fi

  open_branch_prs="$(gh api "repos/${GITHUB_REPOSITORY}/pulls?state=open&head=fraware:${name}&per_page=100" --jq 'length')"
  if [[ "$open_branch_prs" != "0" ]]; then
    echo "::warning::An open PR now references ${name}; retaining branch"
    skipped=$((skipped + 1))
    return
  fi

  gh api --method DELETE "repos/${GITHUB_REPOSITORY}/git/refs/heads/${name}" >/dev/null
  echo "Removed ${disposition} PR #${number} branch ${name}"
  removed=$((removed + 1))
}

while IFS= read -r item; do
  name="$(jq -r '.branch' <<< "$item")"
  sha="$(jq -r '.sha' <<< "$item")"
  prnum="$(jq -r '.pull_request' <<< "$item")"
  disposition="$(jq -r '.disposition' <<< "$item")"
  prune_one "$name" "$sha" "$prnum" "$disposition"
done < <(jq -c '.branches[]' "$manifest")

# The branch that opened the bootstrap PR is now also a merged and stale branch.
# Its SHA cannot be statically pinned in its own commit, so independently
# validate its final head against its completed, just-merged PR.
self_branch="release/bootstrap-versioned-releases-and-cleanup"
self_json="$(gh api "repos/${GITHUB_REPOSITORY}/branches?per_page=100" | jq -c --arg name "$self_branch" '.[] | select(.name == $name)')"
if [[ -n "$self_json" ]]; then
  self_sha="$(jq -r '.commit.sha' <<< "$self_json")"
  self_protected="$(jq -r '.protected' <<< "$self_json")"
  self_prs="$(gh api "repos/${GITHUB_REPOSITORY}/pulls?state=closed&head=fraware:${self_branch}&per_page=100")"
  self_num="$(jq -r --arg sha "$self_sha" --arg release "$GITHUB_SHA" \
    '[.[] | select(.merged_at != null and .merge_commit_sha == $release and .head.sha == $sha)] | first | .number // ""' \
    <<< "$self_prs")"
  if [[ "$self_protected" == "false" && -n "$self_num" ]]; then
    prune_one "$self_branch" "$self_sha" "$self_num" "merged"
  else
    echo "::warning::Bootstrap PR branch not proven merged and unchanged; preserving it"
    skipped=$((skipped + 1))
  fi
fi

remaining="$(gh api --paginate "repos/${GITHUB_REPOSITORY}/branches?per_page=100" --jq '.[].name')"
{
  echo "### Audited branch hygiene"
  echo "- Deleted: ${removed}"
  echo "- Skipped for safety: ${skipped}"
  echo "- Branches remaining:"
  while IFS= read -r branch_name; do echo "  - \`${branch_name}\`"; done <<< "$remaining"
} >> "$GITHUB_STEP_SUMMARY"

if [[ "$skipped" != "0" ]]; then
  echo "::warning::Some branches were preserved due to safety checks; review the summary."
fi
