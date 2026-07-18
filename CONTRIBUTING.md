# Contributing Guide

This document describes how branching, versioning, and releases work in this repository. The process is fully automated: **the branch name you choose determines the version bump and triggers a release when your pull request is merged into `main`.**

## Branch naming convention

Every pull request into `main` must come from a branch that starts with one of the following prefixes. The prefix tells the automation which part of the version number (`MAJOR.MINOR.PATCH`) to increase.

| Prefix | Bump | When to use it |
|---|---|---|
| `major/` or `breaking/` | **MAJOR** | Changes that break backward compatibility |
| `feature/` or `feat/` | **MINOR** | New functionality, non-breaking |
| `fix/`, `bugfix/`, `hotfix/`, `chore/` | **PATCH** | Bug fixes, small adjustments, maintenance tasks |

**Examples:**

```
feature/checkout-with-pix
fix/incorrect-tax-calculation
chore/update-dependencies
breaking/remove-legacy-api
```

**Naming rules:**
- Use only lowercase letters, numbers, hyphens (`-`), underscores (`_`), and slashes (`/`).
- The prefix must be followed by a short, descriptive name (e.g. `feature/user-login`, not just `feature/`).
- Reserved names (`main`, `master`, `develop`, and anything starting with `release/`) can never be used as a PR source branch — they are blocked automatically.

A pull request opened from a branch that doesn't follow this convention will fail an automated check and **cannot be merged** until the branch is renamed or recreated with a valid prefix.

## How releases are created

1. You create a branch using one of the prefixes above and open a pull request into `main`.
2. GitHub Actions validates the branch name as soon as the PR is opened (and on every update).
3. When the PR is merged:
   - The `version` file is bumped automatically based on the branch prefix.
   - The updated `version` file is committed directly to `main`.
   - A new tag (e.g. `v1.4.0`) is created on that commit.
   - A GitHub Release is created from that tag, with auto-generated release notes.

Because the version bump happens **as part of the merge**, the `version` file, the tag, and the release always point to the exact same commit — there's no gap between "code is merged" and "version reflects that code."

## Skipping a release

Some merges shouldn't trigger a release at all (e.g. documentation-only changes, internal tooling, or a batch of related PRs where you only want the release built once, on the last one).

To skip the release for a specific PR, add the **`skip-release`** label to it before merging. When this label is present:
- The `version` file is **not** bumped.
- No tag is created.
- No GitHub Release is created.

The branch naming validation still applies even when `skip-release` is used — the label only affects the release step, not the naming rules.

## Summary checklist before opening a PR

- [ ] Branch name starts with a valid prefix (`major/`, `breaking/`, `feature/`, `feat/`, `fix/`, `bugfix/`, `hotfix/`, `chore/`)
- [ ] Branch name uses only lowercase letters, numbers, `-`, `_`, and `/`
- [ ] If this merge should **not** produce a release, add the `skip-release` label
- [ ] Target branch is `main`
