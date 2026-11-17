# 使用机器上已有的 SDK

[中文](detect.md) | [English](../detect.md)

如果机器上已经有 .NET SDK —— 来自系统包管理器、`dotnet-install.sh`、Homebrew、Scoop、其他版本管理器或
厂商安装程序 —— `vfox link --detect dotnet` 会直接纳入它，而不是再下载一份。需要 vfox 1.1.0 或更高版本
（`vfox --version`）。

```
vfox link --detect dotnet
```

vfox 会列出插件找到的 SDK，并让你选择要纳入哪一个。`vfox link --detect -y dotnet` 会不经询问全部纳入。
之后 `vfox use dotnet@...` 照常工作：`vfox list dotnet` 会把纳入的版本标记为
`(linked → <path>)`，`vfox uninstall` 只移除链接，SDK 文件仍留在原处。

## 能找到哪些

- 系统目录：Linux 和 macOS 上的 `/usr/share/dotnet`、`/usr/lib/dotnet`、`/usr/local/share/dotnet`、`/usr/local/dotnet`、`/opt/dotnet`、`/opt/microsoft/dotnet`；Windows 上的 `%ProgramFiles%\dotnet`，winget、Chocolatey 和厂商安装程序也装在这里。
- `~/.dotnet`（以及 `~/.local/share/dotnet`），即 `dotnet-install.sh` 和 `dotnet-install.ps1` 的默认目录。
- Homebrew（`/opt/homebrew/share/dotnet`、`/usr/local/share/dotnet`、Linuxbrew）和 Scoop（`~/scoop/apps` 下任意应用的版本目录）。
- asdf 和 mise（`~/.asdf/installs/dotnet/<版本>`、`~/.local/share/mise/installs/dotnet/<版本>`、`~/.mise/installs/dotnet/<版本>`）。
- CI 运行器的工具缓存（`/opt/hostedtoolcache/dotnet`）。
- `DOTNET_ROOT` 和 `DOTNET_HOME`。

一个 SDK 目录必须包含 `dotnet` 可执行文件，且 `sdk/` 下至少有一个版本。只有运行时、不能编译的目录不会被提供。
vfox 自己管理的路径（`.vfox` 或 `$VFOX_HOME` 下）永远不会被提供，因此 vfox 安装的 SDK 不会被误认为另一份。

## 版本名称

找到的 SDK 会以它携带的最新运行时命名，取自 `shared/Microsoft.NETCore.App` 目录 —— 也就是 `vfox install`
使用的 .NET 发布版本，例如 `8.0.34`。如果两个目录携带相同的运行时，只提供第一个，这样
`vfox use dotnet@8.0.34` 只有一个目标。已经安装或已经纳入的条目会被跳过。

## 手动链接

如果 `--detect` 没有扫描到，可以手动指定 SDK 主目录，即包含 `dotnet` 可执行文件、`sdk` 和 `shared` 的目录：

```
vfox link dotnet@8.0.34 /opt/dotnet
vfox use dotnet@8.0.34
```

只有当该版本已经链接到其他目录时才需要 `vfox link --force`。
