# vfox-dotnet

[中文](README_CN.md) | [English](README.md)

A [vfox](https://vfox.dev/) plugin for the .NET SDK. It installs SDKs from
Microsoft's official [release metadata](https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json)
and verifies every download with the SHA-512 checksum published next to it.

## Install

After installing [vfox](https://github.com/version-fox/vfox), add the plugin and
install an SDK:

```
vfox add dotnet
vfox install dotnet@8.0
vfox use --global dotnet@8.0
dotnet --version
```

For `dotnet` to be on your `PATH`, hook vfox into your shell; see the
[vfox quick start](https://vfox.dev/guides/quick-start.html).

## Versions and names

A version is a .NET channel or a full release version:

```
vfox install dotnet@8        # newest release in the 8.x line
vfox install dotnet@8.0      # newest release in the 8.0 channel
vfox install dotnet@8.0.34   # a specific runtime release
```

`vfox search dotnet 8.0` lists the releases the plugin knows about. See
[versions and names](docs/versions.md) for how a version is resolved, preview
builds and the environment the plugin sets.

## Platforms

vfox's OS and architecture are mapped to a .NET runtime identifier (RID) such
as `linux-x64`, `osx-arm64` or `win-x64`, and the matching binaries archive is
installed — `.tar.gz` on Linux and macOS, `.zip` on Windows. See
[versions and names](docs/versions.md#platforms).

## Documentation

**Using the plugin**

- [Versions and names](docs/versions.md): version syntax, installing, using, searching, platforms and checksums
- [Using SDKs already on the machine](docs/detect.md): `vfox link --detect dotnet`
- [Changes](docs/changes.md): what changed in each release

**Working on the plugin**

- [Development](docs/development.md): how the plugin works, the local checks and how to release
- [E2E tests](docs/e2e.md): the Ubuntu and Windows end-to-end tests

## Releasing this plugin

Maintainers can publish from **Actions → Plugin → Run workflow** on the default
branch by entering a stable plugin version without the `v` prefix. The shared
workflow updates `metadata.lua`, creates the version commit and tag, and publishes
the ZIP and manifest in this repository. No local tag or extra release token is
needed. Pull requests run checks only; PR titles no longer trigger publication.

Existing version-tag pushes are supported when `PLUGIN.version` already matches
the tag. If publication fails, re-run the original failed job to resume it.

The workflow follows the shared `@v1` release-tool version. Updating the tool does
not release this plugin. See the [shared workflow documentation](https://github.com/version-fox/plugin-manifest-action)
for the package contract and first-rollout requirements.

## License

Apache-2.0. See [LICENSE](LICENSE).
