# Security Policy

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues,
discussions, or pull requests.**

Instead, report them privately through GitHub's built-in
[private vulnerability reporting](https://github.com/9uiLe/swift-scoped-animation/security/advisories/new).
This creates a confidential advisory that only the maintainer can see.

Please include, where possible:

- A description of the vulnerability and its impact
- Steps to reproduce, or a proof of concept
- The affected version(s), Swift/Xcode version, and platform
- Any suggested remediation

You can expect an initial acknowledgement within **5 business days**. If the
issue is confirmed, we will work on a fix and coordinate a disclosure timeline
with you before any public release.

## Supported Versions

Security fixes are provided for the latest minor release line.

| Version | Supported          |
| ------- | ------------------ |
| 0.2.x   | :white_check_mark: |
| < 0.2   | :x:                |

## Scope

ScopedAnimation is a dependency-free SwiftUI library. Its `DEBUG`-only
diagnostics are compiled out of release builds. Reports that concern the
runtime behavior of the library itself are in scope; reports about GitHub
Actions workflow configuration or the example app are welcome too.
