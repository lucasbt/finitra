# Contributing Guide

This document describes how branching, versioning, and releases work in this repository. The process is fully automated: **the branch name you choose determines the version bump and triggers a release when your pull request is merged into `main`.**

## Branch naming convention

Every pull request into `main` must come from a branch that starts with one of the following prefixes. The prefix tells the automation which part of the version number (`MAJOR.MINOR.PATCH`) to increase.

| Prefix | Bump | When to use it |
|---|---|---|
| `major/`, `release/` | **MAJOR** | Changes that break backward compatibility or official releases |
| `feature/`, `feat/`, `minor/` | **MINOR** | New functionality, non-breaking features |
| `bugfix/`, `fix/`, `hotfix/`, `chore/` | **PATCH** | Bug fixes, small adjustments, maintenance tasks |
| `docs/`, `documentation/` | **NONE** | Documentation updates only (skips version bump and release) |

**Examples:**

```
feature/checkout-with-pix
fix/incorrect-tax-calculation
chore/update-dependencies
major/remove-legacy-api
docs/update-readme
```

**Naming rules:**
- Use only lowercase letters, numbers, hyphens (`-`), underscores (`_`), and slashes (`/`).
- The prefix must be followed by a short, descriptive name (e.g. `feature/user-login`, not just `feature/`).

A pull request opened from a branch that doesn't follow this convention will fail the automated **`check-name`** status check and **cannot be merged** until the branch is renamed.

### How to rename an invalid branch

If your branch failed the validation check, you can rename it directly on GitHub or via your local terminal:

**Via Terminal:**
```bash
# Rename your branch locally
git branch -m correct/prefix-name

# Push the new branch and track it
git push origin -u correct/prefix-name

# Delete the old invalid branch from remote
git push origin --delete old-invalid-name
```
*Note: GitHub will automatically update your existing Pull Request with the new branch name.*

**Via GitHub Web Interface:**
Navigate to the **Branches** tab in the repository, locate your branch, click the **Pencil icon (Rename)** on the right side, update the name, and save.

## How releases are created

1. You create a branch using one of the valid prefixes above and open a pull request into `main`.
2. GitHub Actions validates the branch name as soon as the PR is opened (via `Validate Branch Name` workflow).
3. When the PR is merged:
   - If the branch starts with `docs/` or `documentation/`, the workflow safely terminates without any versioning or release changes.
   - For all other valid prefixes, the `version` file is bumped automatically.
   - The updated `version` file is committed directly to `main` with a `[skip ci]` tag to avoid loops.
   - A new tag (e.g. `v1.4.0`) is created on that commit.
   - A rich GitHub Release is published containing details about the PR author, original title, and an automated changelog of commits and contributors.

Because the version bump happens **as part of the merge**, the `version` file, the tag, and the release always point to the exact same commit.

## Summary checklist before opening a PR

- [ ] Branch name starts with a valid prefix (`major/`, `release/`, `feature/`, `feat/`, `minor/`, `bugfix/`, `fix/`, `hotfix/`, `chore/`, `docs/`, `documentation/`)
- [ ] Branch name uses only lowercase letters, numbers, `-`, `_`, and `/`
- [ ] Target branch is `main`