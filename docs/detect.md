# Using SDKs that are already on the machine

[中文](zh-CN/detect.md) | [English](detect.md)

If a .NET SDK is already on the machine — from the system package manager,
`dotnet-install.sh`, Homebrew, Scoop, another version manager or a vendor
installer — `vfox link --detect dotnet` adopts it instead of downloading another
copy. It needs vfox 1.1.0 or later (`vfox --version`).

```
vfox link --detect dotnet
```

vfox lists what the plugin found and links what you pick.
`vfox link --detect -y dotnet` links everything without asking. Afterwards
`vfox use dotnet@...` works as usual: `vfox list dotnet` marks linked versions
`(linked → <path>)`, and `vfox uninstall` removes only the link, leaving the SDK
where it is.

## What it finds

- System locations: `/usr/share/dotnet`, `/usr/lib/dotnet`, `/usr/local/share/dotnet`, `/usr/local/dotnet`, `/opt/dotnet`, `/opt/microsoft/dotnet` on Linux and macOS; `%ProgramFiles%\dotnet` on Windows, where winget, Chocolatey and the vendor installers land too.
- `~/.dotnet` (and `~/.local/share/dotnet`), the defaults of `dotnet-install.sh` and `dotnet-install.ps1`.
- Homebrew (`/opt/homebrew/share/dotnet`, `/usr/local/share/dotnet`, Linuxbrew) and Scoop (`~/scoop/apps`, any app's version directories).
- asdf and mise (`~/.asdf/installs/dotnet/<version>`, `~/.local/share/mise/installs/dotnet/<version>`, `~/.mise/installs/dotnet/<version>`).
- The CI runner tool cache (`/opt/hostedtoolcache/dotnet`).
- `DOTNET_ROOT` and `DOTNET_HOME`.

An SDK home must have the `dotnet` executable and at least one version under
`sdk/`. Runtime-only installations are not offered, because they cannot build
anything. Paths vfox manages itself (under `.vfox` or `$VFOX_HOME`) are never
offered, so an SDK vfox installed is not detected as a second copy.

## Version names

A found SDK is named after the newest runtime it carries, in the
`shared/Microsoft.NETCore.App` directory — the .NET release version that
`vfox install` also uses, such as `8.0.34`. When two homes carry the same
runtime, only the first is offered, so `vfox use dotnet@8.0.34` has one target.
Entries that are already installed or linked are skipped.

## Linking by hand

Where `--detect` does not look, point at the SDK home by hand. It is the
directory that holds the `dotnet` executable, `sdk` and `shared`:

```
vfox link dotnet@8.0.34 /opt/dotnet
vfox use dotnet@8.0.34
```

`vfox use --force dotnet@8.0.34` is not needed unless the version is already
linked to a different directory; use `vfox link --force` for that.
