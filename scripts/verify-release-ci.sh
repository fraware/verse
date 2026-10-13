#!/usr/bin/env bash
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_SHA:?GITHUB_SHA is required}"

# The release bootstrap runs once on a specific main push. It does not
# trust an earlier successful run or tag an unvalidated commit.
for attempt in $(seq 1 100); do
  current="$(gh api "repos/${GITHUB_REPOSITORY}/git/ref/heads/main" --jq '.object.sha')"
  if [[ "$current" != "$GITHUB_SHA" ]]; then
    echo "::error::main advanced during release verification; refusing to tag ${GITHUB_SHA}"
    exit 1
  fi

  outcome="$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs?head_sha=${GITHUB_SHA}&event=push&per_page=50" \
    --jq '.workflow_runs | map(select(.name == "Validate")) | first | if . == null then "pending" else (.status + "|" + (.conclusion // "")) end')"

  case "$outcome" in
    completed\|success)
      echo "Validated main commit: ${GITHUB_SHA}"
      exit 0
      ;;
    completed\|*)
      echo "::error::Validate did not pass for ${GITHUB_SHA}: ${outcome}"
      exit 1
      ;;
    *)
      if (( attempt % 8 == 1 )); then
        echo "Waiting for Validate on exact main SHA ${GITHUB_SHA} (${outcome})"
      fi
      sleep 15
      ;;
  esac
done

echo "::error::Timed out waiting for Validate on exact main SHA"
exit 1
