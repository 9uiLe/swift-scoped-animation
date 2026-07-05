#!/usr/bin/env bash
#
# release.sh — automate the release flow for swift-scoped-animation.
#
# Usage: scripts/release.sh <version> [--dry-run] [--yes]
#
# Runs pre-flight checks, local verification (format lint, build, test,
# release build), rolls the CHANGELOG "Unreleased" section over to the new
# version, updates the SPM example in README.md, commits, tags, pushes, and
# creates a GitHub release with the extracted release notes.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

VERSION=""
DRY_RUN=0
ASSUME_YES=0
RELEASE_NOTES=""

usage() {
  cat <<'EOF'
Usage: scripts/release.sh <version> [options]

Automate the release flow: pre-flight checks, local verification,
CHANGELOG rollover, README version bump, commit, tag, push, and
GitHub release creation.

Arguments:
  <version>    Version to release, without the "v" prefix (e.g. 0.2.0).

Options:
  --dry-run    Run all checks and verification, show what would happen,
               but make no changes (no file edits, commit, push, tag,
               or release).
  --yes        Skip the confirmation prompt.
  --help       Show this help and exit.
EOF
}

die() {
  echo "Error: $1" >&2
  echo "Hint: $2" >&2
  exit 1
}

step() {
  echo "==> $1"
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --help)
        usage
        exit 0
        ;;
      --dry-run)
        DRY_RUN=1
        ;;
      --yes)
        ASSUME_YES=1
        ;;
      -*)
        die "unknown option: $1" "run 'scripts/release.sh --help' for usage."
        ;;
      *)
        if [ -n "$VERSION" ]; then
          die "unexpected argument: $1" "only one version argument is allowed."
        fi
        VERSION="$1"
        ;;
    esac
    shift
  done

  if [ -z "$VERSION" ]; then
    usage >&2
    die "missing required <version> argument" "pass a version like 0.2.0."
  fi
}

preflight_checks() {
  step "Phase 1: Pre-flight checks"

  if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    die "invalid version '$VERSION'" "use the X.Y.Z format without the 'v' prefix (e.g. 0.2.0)."
  fi

  if ! gh auth status >/dev/null 2>&1; then
    die "GitHub CLI is not authenticated" "run 'gh auth login' and retry."
  fi

  if [ -n "$(git status --porcelain)" ]; then
    die "working tree is not clean" "commit or stash your changes before releasing."
  fi

  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  if [ "$branch" != "master" ]; then
    die "current branch is '$branch', not 'master'" "switch to master before releasing."
  fi

  git fetch origin master
  local local_sha remote_sha
  local_sha="$(git rev-parse HEAD)"
  remote_sha="$(git rev-parse origin/master)"
  if [ "$local_sha" != "$remote_sha" ]; then
    die "HEAD ($local_sha) does not match origin/master ($remote_sha)" \
      "push or pull so that master is in sync with origin/master."
  fi

  local tag="v$VERSION"
  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    die "tag '$tag' already exists locally" "pick a new version or delete the stale tag."
  fi
  if [ -n "$(git ls-remote --tags origin "refs/tags/$tag")" ]; then
    die "tag '$tag' already exists on origin" "pick a new version."
  fi

  if ! grep -q '^## Unreleased$' CHANGELOG.md; then
    die "CHANGELOG.md has no '## Unreleased' section" \
      "add an '## Unreleased' section with the release notes."
  fi
  local unreleased_body
  unreleased_body="$(awk '/^## Unreleased$/{found=1; next} found && /^## /{exit} found{print}' CHANGELOG.md)"
  if [ -z "$(echo "$unreleased_body" | grep -v '^[[:space:]]*$' || true)" ]; then
    die "the '## Unreleased' section in CHANGELOG.md is empty" \
      "add at least one release note entry before releasing."
  fi

  step "Checking CI status for HEAD"
  local total incomplete failed
  read -r total incomplete failed <<<"$(gh run list --commit "$local_sha" --json status,conclusion \
    --jq '[length,
           ([.[] | select(.status != "completed")] | length),
           ([.[] | select(.status == "completed" and .conclusion != "success")] | length)] | @tsv')"
  if [ "$total" -eq 0 ]; then
    echo "No CI runs found for HEAD (documentation-only changes skip CI)."
    echo "Falling back to the latest CI run on master."
    local latest_status latest_conclusion latest_sha
    read -r latest_status latest_conclusion latest_sha <<<"$(gh run list --branch master --limit 1 \
      --json status,conclusion,headSha \
      --jq '.[0] | [.status, .conclusion, .headSha] | @tsv')"
    if [ -z "$latest_status" ]; then
      die "no CI runs found on master at all" \
        "push a build-affecting change and let CI complete, or check the Actions tab."
    fi
    if [ "$latest_status" != "completed" ]; then
      die "the latest CI run on master is still in progress" \
        "wait for it to complete and rerun this script."
    fi
    if [ "$latest_conclusion" != "success" ]; then
      die "the latest CI run on master did not succeed (conclusion: $latest_conclusion)" \
        "fix CI on master before releasing."
    fi
    echo "Latest master CI run (commit ${latest_sha:0:7}) completed successfully."
  else
    if [ "$incomplete" -gt 0 ] || [ "$failed" -gt 0 ]; then
      die "CI for HEAD is not fully green ($incomplete incomplete, $failed failed of $total runs)" \
        "wait for CI to complete successfully after pushing, then rerun this script."
    fi
    echo "All $total CI runs for HEAD completed successfully."
  fi
}

local_verification() {
  step "Phase 2: Local verification"

  step "swift format lint"
  swift format lint --configuration .swift-format \
    Package.swift \
    Sources/ScopedAnimation/*.swift \
    Sources/ScopedAnimation/Diagnostics/*.swift \
    Tests/ScopedAnimationTests/*.swift \
    Tests/ScopedAnimationTests/Support/*.swift \
    Examples/ScopedAnimationExample/ScopedAnimationExample/*.swift

  step "swift build"
  swift build

  step "swift test"
  swift test

  step "swift build -c release"
  swift build -c release
}

extract_release_notes() {
  step "Phase 3: Extracting release notes from CHANGELOG.md"

  # Leading blank lines are dropped by the second awk; trailing newlines are
  # stripped by the command substitution itself.
  RELEASE_NOTES="$(awk '/^## Unreleased$/{found=1; next} found && /^## /{exit} found{print}' CHANGELOG.md \
    | awk 'NF {p=1} p')"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Release notes preview:"
    echo "$RELEASE_NOTES"
  fi
}

confirm() {
  step "Phase 4: Confirmation"

  local tag="v$VERSION"
  echo "About to release:"
  echo "  Version:  $VERSION"
  echo "  Tag:      $tag"
  echo "  Files:    CHANGELOG.md, README.md"
  echo "  Release notes:"
  printf '%s\n' "$RELEASE_NOTES" | awk '{print "    " $0}'

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run complete. No changes made."
    exit 0
  fi

  if [ "$ASSUME_YES" -eq 0 ]; then
    printf "Proceed? [y/N] "
    local answer
    read -r answer
    if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
      echo "Aborted. No changes made."
      exit 0
    fi
  fi
}

perform_release() {
  step "Phase 5: Performing release"

  local tag="v$VERSION"
  local today
  today="$(date +%Y-%m-%d)"

  step "Updating CHANGELOG.md"
  perl -pi -e "s/^## Unreleased\$/## $VERSION - $today/" CHANGELOG.md

  step "Updating README.md"
  perl -pi -e "s/from: \"[0-9]+\\.[0-9]+\\.[0-9]+\"/from: \"$VERSION\"/ if /\\.package\\(url: .*swift-scoped-animation/" README.md

  step "Committing and pushing"
  git add CHANGELOG.md README.md
  git commit -m "Release $VERSION"
  git push origin master

  step "Tagging"
  git tag "$tag"
  git push origin "$tag"

  step "Creating GitHub release"
  local release_url
  release_url="$(gh release create "$tag" --title "$VERSION" --notes "$RELEASE_NOTES")"

  echo "Release $VERSION published: $release_url"
}

main() {
  parse_args "$@"
  preflight_checks
  local_verification
  extract_release_notes
  confirm
  perform_release
}

main "$@"
