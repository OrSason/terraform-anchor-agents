# Versioning

`terraform-anchor-agents` follows [Semantic Versioning](https://semver.org/)
(`MAJOR.MINOR.PATCH`). For a Terraform module the **source of truth for a release
is a git tag** of the form `vX.Y.Z`. That is what consumers pin against:

```hcl
module "anchor_agents" {
  source = "github.com/OrSason/terraform-anchor-agents?ref=v0.2.0"
  # ...
}
```

## What each part means

| Bump      | When                                                                                       | Example                                                        |
| --------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------- |
| **PATCH** | Backwards-compatible **fix** — no input/output change consumers must react to.              | Correct a default, fix a label, tighten an RBAC rule.         |
| **MINOR** | Backwards-compatible **feature** — new optional variable/output, new opt-in behaviour.      | Add an output, add a variable with a safe default.            |
| **MAJOR** | **Breaking** change — anything that forces consumers to change their configuration.         | Rename/remove a variable or output, change a default's effect, drop provider support. |

Rule of thumb: **patch = fix, minor = feature, major = breaking.**

## The `VERSION` file

The repository carries a [`VERSION`](../VERSION) file holding the current SemVer
(no `v` prefix, e.g. `0.2.0`). It is read at plan time into a local and exposed
as the `module_version` output, so a consumer can always trace which version of
the module they are actually running:

```hcl
output "anchor_agents_version" {
  value = module.anchor_agents.module_version
}
```

The `VERSION` file is bumped **in lockstep with the git tag** — the commit that
sets `VERSION` to `X.Y.Z` is the commit you tag `vX.Y.Z`. They must never drift.

## Cutting a release

1. Make sure `main` is green and holds everything for the release.
2. Decide the bump (patch/minor/major) from the rule above.
3. Set the `VERSION` file to the new number (no `v` prefix) and roll the
   `[Unreleased]` section of [`CHANGELOG.md`](../CHANGELOG.md) into a new
   `[X.Y.Z]` section dated today.
4. Commit those two changes on `main` (via PR).
5. Tag that commit and push the tag:

   ```bash
   git tag vX.Y.Z
   git push --tags
   ```

The tag — not a branch — is the immutable, consumable release.
