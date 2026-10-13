#!/usr/bin/env bash
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_SHA:?GITHUB_SHA is required}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"

versions=(v0.1.0 v0.2.0 v0.3.0)
revisions=(
  ddf02495b6aee92134be8aac4b4ab056071afd1b
  420aac13918473c9680b3dc8f7fcbca2720711e0
  "$GITHUB_SHA"
)
titles=(
  "Verse v0.1.0 | Private Writing Foundation"
  "Verse v0.2.0 | Selected-Text Craft Workbench"
  "Verse v0.3.0 | Community-Ready Release"
)

[[ "$(gh api "repos/${GITHUB_REPOSITORY}/git/ref/heads/main" --jq '.object.sha')" == "$GITHUB_SHA" ]] || {
  echo "::error::main moved; refusing to publish stale tags"
  exit 1
}

# Strict preflight before creating anything: earlier milestones are ancestors,
# have passing push CI, and are not already tagged to different commits.
for i in "${!versions[@]}"; do
  tag="${versions[$i]}"
  sha="${revisions[$i]}"
  git merge-base --is-ancestor "$sha" "$GITHUB_SHA" || {
    echo "::error::${sha} is not an ancestor of the validated release commit"
    exit 1
  }

  if [[ "$i" -lt 2 ]]; then
    green="$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs?head_sha=${sha}&per_page=25" \
      --jq '[.workflow_runs[] | select(.name == "Validate" and .event == "push" and .status == "completed" and .conclusion == "success")] | length')"
    [[ "$green" -ge 1 ]] || { echo "::error::No successful push validation for ${tag}"; exit 1; }
  fi

  remote_sha="$(gh api "repos/${GITHUB_REPOSITORY}/git/ref/tags/${tag}" --jq '.object.sha' 2>/dev/null || true)"
  if [[ -n "$remote_sha" && "$remote_sha" != "$sha" ]]; then
    echo "::error::Existing ${tag} ref points to ${remote_sha}; expected ${sha}. No tag is modified."
    exit 1
  fi
  if gh release view "$tag" --json tagName >/dev/null 2>&1 && [[ -z "$remote_sha" ]]; then
    echo "::error::Release exists without matching tag reference: ${tag}"
    exit 1
  fi
done

# Rebuild self-contained static bundles at the exact commits, not at HEAD.
for i in "${!versions[@]}"; do
  tag="${versions[$i]}"
  sha="${revisions[$i]}"
  if gh release view "$tag" --json tagName >/dev/null 2>&1; then
    echo "Verified existing release: ${tag}"
    continue
  fi

  worktree="${RUNNER_TEMP}/verse-build-${tag}"
  archive="${RUNNER_TEMP}/verse-${tag}-github-pages.zip"
  git worktree add --detach "$worktree" "$sha"
  (
    cd "$worktree"
    npm ci --no-audit --no-fund
    GITHUB_PAGES=true npm run build
    GITHUB_PAGES=true npm run verify:dist
    cp dist/index.html dist/404.html
    touch dist/.nojekyll
  )
  # Earlier history predates the LICENSE file; the rights holder's current
  # MIT grant accompanies every downloadable binary bundle.
  cp LICENSE "$worktree/dist/LICENSE"
  printf '%s\n' \
    "Verse ${tag}: static GitHub Pages distribution" \
    "Host the contents under /verse/ or rebuild for a different Vite base path." \
    "The MIT LICENSE is included; review third-party dependency rights separately." \
    > "$worktree/dist/DEPLOYMENT.txt"
  (cd "$worktree/dist" && zip -q -r "$archive" .)
  git worktree remove --force "$worktree"

  refsha="$(gh api "repos/${GITHUB_REPOSITORY}/git/ref/tags/${tag}" --jq '.object.sha' 2>/dev/null || true)"
  if [[ -z "$refsha" ]]; then
    gh api --method POST "repos/${GITHUB_REPOSITORY}/git/refs" \
      -f "ref=refs/tags/${tag}" -f "sha=${sha}" >/dev/null
  fi

  args=(release create "$tag" "$archive"
    --verify-tag
    --title "${titles[$i]}"
    --notes-file "docs/releases/${tag}.md")
  if [[ "$tag" == "v0.3.0" ]]; then
    args+=(--latest)
  else
    args+=(--latest=false)
  fi
  gh "${args[@]}"
  echo "Published release ${tag} from verified source commit ${sha}"
done

{
  echo "### Three verified Verse releases"
  for tag in "${versions[@]}"; do
    echo "- [${tag}](https://github.com/${GITHUB_REPOSITORY}/releases/tag/${tag})"
  done
  echo "- All tags are immutable by this workflow. Mismatched existing refs cause failure."
} >> "$GITHUB_STEP_SUMMARY"
