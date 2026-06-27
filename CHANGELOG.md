# Changelog

All notable changes to this module are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/). Releases
are git tags `vX.Y.Z`; see [docs/VERSIONING.md](docs/VERSIONING.md).

## [Unreleased]

## [0.2.0] - 2026-06-27

### Added

- `VERSION` file as the in-repo source for the module's SemVer, read at plan
  time into a `module_version` local.
- `module_version` output so consumers can trace which version of the module
  they are running.
- `docs/VERSIONING.md` documenting the git-tag release convention
  (patch=fix / minor=feature / major=breaking), how to cut a release, and the
  `VERSION`-file/tag lockstep.
- This `CHANGELOG.md` (Keep a Changelog format).

## [0.1.2] - 2026-06-25

- Bring-your-own-secrets toggle and related variable wiring.

## [0.1.1] - 2026-06-09

- Follow-up fixes after the initial release.

## [0.1.0] - 2026-06-09

- Initial release: registers Anchor service agents, stores API keys in AWS
  Secrets Manager, syncs them into Kubernetes via External Secrets, and creates
  `AnchorAgent` custom resources reconciled by the operator.

[Unreleased]: https://github.com/OrSason/terraform-anchor-agents/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/OrSason/terraform-anchor-agents/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/OrSason/terraform-anchor-agents/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/OrSason/terraform-anchor-agents/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/OrSason/terraform-anchor-agents/releases/tag/v0.1.0
