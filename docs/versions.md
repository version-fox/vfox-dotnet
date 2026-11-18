# Versions and names

[中文](zh-CN/versions.md) | [English](versions.md)

The plugin gets its version list from Microsoft's
[release metadata](https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json).
There is no bundled list of SDKs: whatever Microsoft currently publishes is what
you can install.

## Version syntax

A version is one to three numeric parts. Each part narrows the lookup:

| You write | What the plugin looks for |
| --- | --- |
| `8` | the first channel whose version starts with `8` (usually `8.0`) |
| `8.0` | channel `8.0`; its newest stable release, or its newest preview when it has none |
| `8.0.34` | release `8.0.34`; the SDK that ships with it |

```bash
vfox install dotnet@8
vfox install dotnet@8.0
vfox install dotnet@8.0.34
```

A bare major is deliberately kept at the major, not turned into `8.0`, so a
channel such as `9.1` can still be found.

`vfox search dotnet` lists every installable variant of every release, with the
distribution and the version of its component in brackets. The plugin returns the
whole list; vfox applies the search query:

```
vfox search dotnet
vfox search dotnet runtime
vfox search dotnet 8.0
```

## Distribution variants

A version can carry a suffix that selects a smaller installation instead of the
full SDK:

| You write | What gets installed |
| --- | --- |
| `8.0.34` | .NET SDK (default) |
| `8.0.34-runtime` | .NET Runtime only |
| `8.0.34-aspnetcore` | ASP.NET Core Runtime, which includes the .NET Runtime |

```bash
vfox install dotnet@8.0.34-runtime
vfox install dotnet@8-runtime
vfox install dotnet@8.0.34-aspnetcore
```

The SDK archive is roughly 600 MB while the runtime-only archives are around
70–100 MB. Use the runtime variants when you only need to run applications. No
suffix keeps the historical behavior, so existing installations are unchanged.

The suffix works everywhere a version is accepted, including `vfox use` and
`.tool-versions`, and can be combined with a partial version (`8-runtime`,
`8.0-runtime`). Since preview versions such as `11.0.0-rc.3` already contain
hyphens, only the two known suffixes are interpreted as a distribution; an
unknown suffix does not match any release.

## Install and use

```bash
vfox install dotnet@8.0
vfox use --global dotnet@8.0
dotnet --version
```

`dotnet --version` prints the SDK version (for example `8.0.428`), while
`vfox current dotnet` prints the .NET release vfox selected (for example
`8.0.34`) — one SDK release can carry a newer SDK number. `dotnet --list-sdks`
lists every SDK installed by the selected release.

`vfox use --global` selects the SDK for every new shell. `--project` selects it
for the current directory and `--session` for the current shell only; see the
[vfox documentation](https://vfox.dev/guides/quick-start.html) for the scope rules.

## Preview and early-access builds

Microsoft lists preview and release-candidate builds in the same metadata with
versions such as `11.0.0-rc.3` and `11.0.0-preview.7`. They are searchable and
installable like any other release:

```bash
vfox search dotnet 11.0
vfox install dotnet@11.0.0-rc.3
```

Use an exact version for a preview: a channel such as `11.0` selects the newest
stable release, not a preview that happens to be listed first. A channel with no
stable release yet selects its newest preview.

## Environment

The plugin exports two variables through vfox:

| Variable | Value |
| --- | --- |
| `DOTNET_ROOT` | directory of the selected SDK or runtime |
| `PATH` | the same directory is added at the front |

These come from the `EnvKeys` hook and are applied when vfox is hooked into the
shell. In a script, activate vfox first:

```bash
eval "$(vfox activate bash)"
vfox use --global dotnet@8.0
eval "$(vfox env -s bash)"
dotnet --version
```

## Platforms

vfox reports an OS (`linux`, `darwin`, `windows`) and an architecture
(`amd64`, `arm64`, `386`). The plugin maps them to a .NET runtime identifier:

| vfox | RID |
| --- | --- |
| `linux` + `amd64` | `linux-x64` |
| `linux` + `arm64` | `linux-arm64` |
| `linux` + `386` | `linux-x86` |
| `darwin` + `amd64` | `osx-x64` |
| `darwin` + `arm64` | `osx-arm64` |
| `windows` + `amd64` | `win-x64` |
| `windows` + `arm64` | `win-arm64` |
| `windows` + `386` | `win-x86` |

Only the *Binaries* archive of a matching RID is installed; installers and
other components are ignored. It is a `.tar.gz` on Linux and macOS and a `.zip`
on Windows. If Microsoft has no binaries for your RID in a channel, that
channel has no installable version for you.

The .NET SDK itself also needs native libraries on Linux, notably ICU for
globalization. On Ubuntu install `libicu74` (or the ICU runtime of your release)
plus `libssl3` and `zlib1g` before running `dotnet` for the first time.

## Checksums

The release metadata publishes a SHA-512 `hash` for each binaries file. The
plugin passes it to vfox, which verifies the download before unpacking it. A
download that does not match is rejected and nothing is installed.
