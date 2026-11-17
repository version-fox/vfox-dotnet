# Changes

[中文](zh-CN/changes.md) | [English](changes.md)

What changed in each release, as a user notices it. GitHub's release pages list
the pull requests.

## Unreleased

- Install a smaller distribution with a version suffix: `-runtime` for the .NET
  Runtime and `-aspnetcore` for ASP.NET Core Runtime. Without a suffix the full
  SDK is still installed. Partial versions (`8`, `8.0`) and `latest` now resolve
  to the newest release, and matching is done on version-component boundaries so
  `8.0.3` no longer selects `8.0.34`.
- Bilingual documentation in English and Simplified Chinese: a README for each
  language and guides for versions, development, E2E tests and this changelog.
- Automated checks on pull requests and pushes to `main`: Lua formatting
  (stylua) and diagnostics (lua-language-server), workflow linting (actionlint),
  license headers (SkyWalking Eyes), offline hook tests (`vfox plugin test`),
  and end-to-end tests on an Ubuntu container and a Windows runner.
- Apache-2.0 license headers on all source, build and workflow files, plus
  `.gitattributes` to keep LF line endings everywhere.
- `opencode.jsonc` with an explicit allowlist for pushing and creating or
  commenting on pull requests.
- `vfox link --detect dotnet` adopts .NET SDKs that are already on the machine
  instead of downloading another copy: system directories, `~/.dotnet`, Homebrew,
  Scoop, asdf, mise, the CI runner tool cache and `DOTNET_ROOT`/`DOTNET_HOME`.
  A found SDK is named after the newest runtime it carries. See [detect.md](detect.md).

## 0.3.0 (2025-09-29)

- Versions are read from Microsoft's official release metadata instead of a
  separate source, and version detection and output formatting were reworked.
- Releases moved to the shared `plugin-manifest-action` workflows: publishing
  is started from **Actions → Plugin → Run workflow**, pull requests only run
  checks.

## 0.2.0 (2025-03-06)

- SDK information comes from the official .NET release endpoint, and more
  version channels are available.

## 0.1.1 (2024-04-01)

- CI updates.

## 0.1.0 (2024-03-28)

- First release of the plugin, with a published manifest.
