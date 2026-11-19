# Changes

[中文](zh-CN/changes.md) | [English](changes.md)

What changed in each release, as a user notices it. GitHub's release pages list
the pull requests.

## Unreleased

- A bare major such as `dotnet@2` now installs the newest stable release across all of its channels. Before, only the first channel of that major in Microsoft's release index was searched, so `dotnet@2` installed 2.1.30 although 2.2.8 is newer. A full channel such as `dotnet@2.1` still selects only that channel.
- The ASP.NET Core Runtime of .NET Core 2.0 is now listed and installable on Linux, for example `dotnet@2.0.9-aspnetcore`. It failed with `not available for linux-x64` before, because Microsoft publishes it as a `dotnet-hosting` archive. It is listed for 2.0.6, 2.0.7 and 2.0.9. The archives of 2.0.3, 2.0.5 and 2.0.8 have no checksum in Microsoft's release metadata, so they are not listed, and the other 2.0 releases have no ASP.NET Core Runtime for Linux.

## 0.3.5 (2026-11-18)

- An unknown version, such as `dotnet@8.0.999`, no longer reports a successful install. vfox recorded an install with no version, and `vfox list dotnet` showed `no available version`. The install now fails with an error that names the version and the platform, for example `dotnet version 8.0.999 is not available for linux-x64`. A `latest` request with no release for the platform fails with `no dotnet release is available for linux-x64`.

## 0.3.4 (2026-11-18)

- A partial version such as `dotnet@11.0` or `dotnet@11`, and `latest`, now pick the newest stable release. A preview listed above the stable release used to be installed instead, and `latest` picked the preview of a newer channel that had no stable release yet. A channel with no stable release still installs its newest preview, and exact versions are unchanged.

## 0.3.3 (2026-11-18)

- Fixed `-runtime` for .NET 10 and later. Their runtime component lists the
  apphost pack before the runtime, so `vfox install dotnet@<version>-runtime`
  installed the apphost pack and left no `dotnet` executable. The archive is now
  chosen by its name, so every release that has a runtime installs it.
- Fixed the `attempt to index local 'component'` error when listing versions or
  installing a variant. The release metadata lists some components as `null`,
  such as the ASP.NET Core Runtime of the 1.0, 1.1 and 2.0 channels. mise reads
  that `null` as a value that cannot be indexed, which failed the whole list.
  Components that are `null` are now skipped.
- A failed request for release metadata now stops the listing and names the URL
  and the HTTP status, instead of quietly leaving that channel out. Before, `latest`
  could resolve to an older .NET while the newest channel could not be fetched, and
  `vfox search` could show an incomplete list without an error.

## 0.3.2 (2026-11-17)

- Raised the minimum required vfox version to 1.1.0, matching the version the
  SDK detection hook, CI and E2E tests already use. Installations on older
  vfox releases are now prompted to upgrade.
- Refreshed the documentation: corrected the release-workflow history and E2E
  timeout details, fixed dead links, and completed the detected SDK path lists.

## 0.3.1 (2026-11-17)

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
- Publication moved to the shared `@v1` reusable workflows: maintainers start a
  release from **Actions → Plugin → Run workflow**, and pull requests only run
  checks.

## 0.3.0 (2025-09-29)

- Versions are read from Microsoft's official release metadata instead of a
  separate source, and version detection and output formatting were reworked.
- Release publishing switched to the shared `plugin-manifest-action` from the
  bespoke Lua manifest job; it was still driven by version tags and `Release v`
  pull-request titles.

## 0.2.0 (2025-03-06)

- SDK information comes from the official .NET release endpoint, and more
  version channels are available.

## 0.1.1 (2024-04-01)

- CI updates.

## 0.1.0 (2024-03-28)

- First release of the plugin, with a published manifest.
