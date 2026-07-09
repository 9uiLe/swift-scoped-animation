## Summary

<!-- What does this change do, and why? -->

## Related issues

<!-- e.g. Closes #123 -->

## Checklist

- [ ] Ran the local checks in [CONTRIBUTING.md](../CONTRIBUTING.md) (`swift format lint`, `swift build`, `swift test`, iOS Simulator tests, release build, DocC build, example app build)
- [ ] Updated `CHANGELOG.md` under `## Unreleased` if this is user-facing
- [ ] Updated `HANDOFF.md` if this changes public API, semantics, or roadmap phase order
- [ ] Public API additions have DocC comments; user-facing docs are in English and describe the model as **blocking + detection**
- [ ] Diagnostics code paths remain guarded with `#if DEBUG`
