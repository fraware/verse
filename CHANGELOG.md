# Verse release history

Verse versions are retrospective, tested milestones of the same browser-local writing product. The three inaugural releases have distinct source commits and reproducible GitHub Pages distribution bundles.

| Release | Milestone | Source commit | Verified production checks |
| --- | --- | --- | --- |
| [v0.1.0](https://github.com/fraware/verse/releases/tag/v0.1.0) | Browser-local writing, transactional collections, literary catalogue | `ddf0249` | [Run 38451887232](https://github.com/fraware/verse/actions/runs/38451887232) |
| [v0.2.0](https://github.com/fraware/verse/releases/tag/v0.2.0) | Selected-text craft preview and undo | `420aac1` | [Run 38455445346](https://github.com/fraware/verse/actions/runs/38455445346) |
| [v0.3.0](https://github.com/fraware/verse/releases/tag/v0.3.0) | Voluntary usability pilot, MIT licensing, public-project documentation and release hygiene | Exact green main release commit | [Current workflow](https://github.com/fraware/verse/actions) |

Release descriptions: [v0.1.0](docs/releases/v0.1.0.md), [v0.2.0](docs/releases/v0.2.0.md), [v0.3.0](docs/releases/v0.3.0.md).

## Release contract

- The GitHub Pages site remains the live installation: https://fraware.github.io/verse/.
- Each release tag refers to a distinct, exact commit. Tags cannot be moved by the release bootstrap.
- The release workflow waits for the full main-branch validation (quality, Chromium/Firefox/WebKit, accessibility) before publishing v0.3.0 and verifies historical successful push runs for v0.1.0 and v0.2.0.
- Attached `verse-vX.Y.Z-github-pages.zip` archives are rebuilt at their respective commits with `npm ci`, `GITHUB_PAGES=true npm run build`, and `GITHUB_PAGES=true npm run verify:dist`. They target GitHub Pages' `/verse/` base path.
- Historical v0.1.0 and v0.2.0 source commits precede the later root MIT `LICENSE`. The rights holder's MIT grant is supplied in each compiled bundle. The project's current source release is MIT licensed; third-party materials retain separate terms.
- Tags and release downloads do not add cloud backups, accounts, remote inference, or collection sharing. Writers still need external poem backups.

## Branch hygiene

The inaugural cleanup audit is recorded at [the branch audit](.github/maintenance/branch-audit-2026-10-13.json). It records exact branch SHAs and their PR disposition. The bootstrap deletes an audited branch only if its SHA has not moved, it is unprotected, no open PR references it, and its merged PR is in main. Two closed, unmerged branches from superseded experiments are explicitly approved for deletion by PR number. Any failure of these conditions preserves the branch and reports the reason.

The workflow is deliberately path-scoped and idempotent. It is not a policy to delete active or unreviewed contributor work. New releases should use fresh tags with reviewed release notes, verified build artifacts, and complete passing CI.
