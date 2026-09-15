# Release design and operations

ScopedAnimation is a source-only Swift package published from
`9uiLe/swift-scoped-animation`. The owner, `9uiLe`, chooses the version and
publishes a commit validated by GitHub Actions. Release credentials stay in the
owner's local GitHub CLI authentication.

## Release contract

A release consists of an annotated `vX.Y.Z` Git tag and a GitHub Release. The tag
points directly to the source commit consumed by SwiftPM. The Release uses
`X.Y.Z` as its title and the versioned CHANGELOG section as its body. No binary
assets are attached.

**Creating the remote tag makes the version available to SwiftPM.** All
publication prerequisites are checked before tag creation. The GitHub Release
is created as a draft, checked against the tag, and then published.

| Responsibility | Owner |
| --- | --- |
| Choose a stable version, review and merge the release PR, initiate publication | Repository owner `9uiLe` |
| Prepare versioned documents and verify publication conditions | Local `scripts/release.py` |
| Run package and release-tooling checks | Read-only GitHub Actions |
| Restrict writes and lock published artifacts | GitHub repository protection and Immutable releases |

The package continues to use `v`-prefixed tags. Command arguments and the README
dependency use the numeric `X.Y.Z` version. Prerelease suffixes, build metadata,
leading zeroes, and a `v` prefix in command arguments are rejected. Version
selection is manual and should reflect API compatibility.

## Commands

Run from a clean checkout with Python 3.10+, Git, and a current GitHub CLI.

```sh
gh auth login --hostname github.com
gh auth switch --hostname github.com --user 9uiLe
```

The script checks the actual authenticated user through the API. Environment
tokens such as `GH_TOKEN` take precedence over saved CLI authentication.
The `origin` URL must identify the upstream repository using HTTPS or its
`git@github.com:9uiLe/swift-scoped-animation.git` SSH URL.

Remote fetch and push operations use HTTPS with the same GitHub CLI credential
helper. SSH keys are not required even when `origin` uses SSH. Commands reject
execution inside GitHub Actions.

Replace `X.Y.Z` below with the selected stable version:

| Command | Effect |
| --- | --- |
| `./scripts/release.py prepare X.Y.Z --dry-run` | Fetch source and tags, validate preparation, and print the selected source SHA and release notes. |
| `./scripts/release.py prepare X.Y.Z` | Create and push `release/X.Y.Z` with versioned documents, then open a PR targeting `master`. |
| `./scripts/release.py check X.Y.Z` | Validate publication and print the source SHA, qualifying CI URL, and release notes. |
| `./scripts/release.py publish X.Y.Z` | Repeat validation, create or resume the tag and draft, publish, and verify the result. |

`prepare --dry-run` and `check` update local fetched refs but do not edit working
files, create working branches, or write remote state. `scripts/release.sh`
forwards these subcommands to Python. The command without a subcommand is
rejected; there is no command that versions documents and publishes in one step.

## 1. Prepare a release PR

Maintain user-facing entries under `## Unreleased` in `CHANGELOG.md`. Describe
breaking changes and required migration steps explicitly. Release notes are
copied to GitHub, so use absolute URLs for links in those entries.

Preparation reads the fetched `origin/master` snapshot, regardless of the
current working branch. It requires:

- a version newer than all recognized stable tags and the latest CHANGELOG release;
- exactly one leading Unreleased section with release entries;
- valid dated release headings in descending, unique version order;
- exactly one ScopedAnimation dependency in README matching the latest released
  CHANGELOG version; and
- no existing tag, Release, or local/remote `release/X.Y.Z` branch.

It leaves an empty Unreleased section, inserts `## X.Y.Z - YYYY-MM-DD`, updates
the README dependency, commits those two documents on the selected source SHA,
pushes the release branch, and creates the PR.

Preparation does not modify Swift sources, package requirements, or old release
sections. It neither chooses the version automatically nor publishes it.

## 2. Merge and wait for commit CI

Review the release notes and installation version, then merge the release PR.
The workflow runs for every `master` push, including documentation-only changes.

Publication requires both `build-test-docs` and `Release tooling checks` to
succeed in the latest run attempt for the exact source commit. PR checks,
manual workflow dispatches, older successful attempts, and another commit's
successful run cannot substitute for that push run.

If the latest attempt fails or is cancelled, fix the cause and rerun the same CI
run or merge a corrected release PR. A successful retry can qualify.

## 3. Check and publish

Run `check` to inspect the intended source and notes, then `publish`.
Publication repeats the checks rather than reusing a saved plan.

| Check | Requirement |
| --- | --- |
| Account and repository | Actual user is `9uiLe`; upstream is public, uses `master`, and grants that user admin access. |
| Working tree | No tracked or untracked changes. |
| Artifact protection | Repository Immutable releases is enabled. |
| Source | Full commit SHA contained in the fetched `master` history. |
| Documents | Latest CHANGELOG release and README dependency match the requested version, notes contain entries, dates are valid, and Unreleased is empty. |
| CI run | Active `ci.yml`, upstream repository, `push` event, `master` branch, exact SHA, and latest run/attempt all match. |
| CI jobs | Each required job appears once, succeeded, and has the same source SHA. |
| Existing tag | Annotated `vX.Y.Z` tag pointing directly to a commit; nested or lightweight tags are rejected. |
| Existing Release | Tag, source SHA, title, owner, and notes match; no prerelease flag or attached assets. Published releases must be immutable. |

For a new tag, the source is the fetched `origin/master` tip. The script rechecks
that remote `master` has not changed before creating the tag. For an existing
tag, its commit is the source, even if `master` has advanced.

An unpublished version must be newer than other stable tags. Both prefixed and
unprefixed stable tags participate in this check so an alias such as `0.3.0`
cannot silently coexist with a new `v0.3.0`.

The tag is checked after creation and before and after publication. A draft must
match the plan before it is published. The final Release must be published and
immutable. On success the command prints its URL.

## Recovery

### Publication

Rerun `publish` with the same version after resolving the reported error.

| Remote state | Behavior |
| --- | --- |
| No tag or Release | Validate the current master snapshot and start publication. |
| Matching annotated tag | Validate that tag's commit and CI, then create a draft. |
| Matching draft | Validate tag, source, metadata, and CI, then publish. |
| Matching published immutable Release | Verify its source and metadata, print its URL, and perform no writes. |
| Conflicting tag or Release | Stop for manual inspection. |

A created tag is never deleted, overwritten, or moved by the script. If the tag
changes or disappears during validation, publication stops. An orphaned
annotated-tag object without a ref does not expose a package version; retrying
can create the required ref through a new validated attempt.

A published Release does not need its old CI logs to remain available for
idempotent inspection. Its tag, committed documents, author, title, notes, and
immutable state are still checked.

### Preparation

If preparation stops after creating its branch, inspect
`git log release/X.Y.Z`, the document diff, and
`gh pr list --head release/X.Y.Z`. Complete any missing push or PR creation
from that branch. Rerunning `prepare` refuses to replace existing branches.

If `master` gains new Unreleased entries after release preparation, publish
stops. Include those changes in the release documents through a reviewed PR or
complete a release at an already-created, validated tag.

## Repository settings

The owner configures these settings separately from the release commands:

- **Immutable releases:** enable it before publishing. It applies to newly
  published releases; it does not retroactively make older releases immutable.
- **Master protection:** require PRs and both `build-test-docs` and
  `Release tooling checks`. Keep the existing deletion and force-push protection.
  The publication script independently enforces successful commit CI even when
  an admin bypasses merge rules.
- **Tag protection:** restrict creation, updates, and deletion of `v*` tags to
  the repository admin. Never move a published version to a different commit.
- **Actions:** use read-only default token permissions and disable PR approvals.
  The workflow declares `contents: read`, pins checkout by full SHA, and sets
  `persist-credentials: false`.
- **Credentials:** no release token or signing credential is stored in Actions.

These permissions belong to GitHub settings; a local script is not a substitute
for access control. The script does not edit repository rules or permission
settings. Existing releases made with lightweight tags or mutable publication
are historical artifacts and are not adopted or rewritten by these commands.

## Development and verification

```sh
python3 -m unittest discover -s scripts/tests -v
bash -n scripts/release.sh
```

Tests use temporary Git repositories and simulated GitHub responses. They cover
document preparation, exact CI matching, rejected publication, tag integrity,
interrupted operations, idempotent publication, pagination, and PR creation.
They require neither network access nor credentials.

The `release-tooling` CI job runs these tests on Ubuntu 24.04. The existing
macOS job retains Swift builds/tests, iOS Simulator tests, formatting, RELEASE
diagnostic auditing, DocC, and example validation. See
[CONTRIBUTING.md](../CONTRIBUTING.md) for the complete check commands.

## References

- [Owner-authenticated release design in swift-app-macros PR #8](https://github.com/9uiLe/swift-app-macros/pull/8)
- [GitHub immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases)
- [GitHub release API](https://docs.github.com/en/rest/releases/releases)
- [GitHub CLI release creation](https://cli.github.com/manual/gh_release_create)
- [GitHub CLI environment variables](https://cli.github.com/manual/gh_help_environment)
- [GitHub runner image: Ubuntu 24.04](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md)
