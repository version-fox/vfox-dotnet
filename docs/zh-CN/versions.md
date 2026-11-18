# 版本与名称

[中文](versions.md) | [English](../versions.md)

插件从微软的[发布元数据](https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json)
获取版本列表。仓库里没有内置的 SDK 清单：微软当前发布什么，就可以安装什么。

## 版本语法

版本号由一到三段数字组成，每一段都会缩小查找范围：

| 你输入 | 插件查找的内容 |
| --- | --- |
| `8` | 第一个以 `8` 开头的通道（通常是 `8.0`） |
| `8.0` | `8.0` 通道，以及其中最新的发布版本 |
| `8.0.34` | 发布版本 `8.0.34` 及其附带的 SDK |

```bash
vfox install dotnet@8
vfox install dotnet@8.0
vfox install dotnet@8.0.34
```

单独的主版本号会保留在主版本号级别，而不是补成 `8.0`，这样像 `9.1` 这样的通道也仍然可以被找到。

`vfox search dotnet` 会列出所有通道中每个可安装的变体，方括号内是发行版及其组件的版本。插件返回完整列表，
搜索条件由 vfox 应用：

```
vfox search dotnet
vfox search dotnet runtime
vfox search dotnet 8.0
```

## 发行版变体

版本号可以带后缀，以安装比完整 SDK 更小的发行版：

| 你输入 | 安装的内容 |
| --- | --- |
| `8.0.34` | .NET SDK（默认） |
| `8.0.34-runtime` | 仅 .NET Runtime |
| `8.0.34-aspnetcore` | ASP.NET Core Runtime（包含 .NET Runtime） |

```bash
vfox install dotnet@8.0.34-runtime
vfox install dotnet@8-runtime
vfox install dotnet@8.0.34-aspnetcore
```

SDK 压缩包大约 600 MB，而仅运行时的压缩包约为 70–100 MB。只需要运行应用程序时可以使用运行时变体。
不带后缀会保持原有行为，因此既有安装不受影响。

后缀适用于任何接受版本号的地方，包括 `vfox use` 和 `.tool-versions`，也可以与部分版本号组合
（`8-runtime`、`8.0-runtime`）。由于 `11.0.0-rc.3` 这样的预览版本本身已包含连字符，插件只把上述两个
已知后缀解释为发行版；未知后缀不会匹配任何版本。

## 安装与使用

```bash
vfox install dotnet@8.0
vfox use --global dotnet@8.0
dotnet --version
```

`dotnet --version` 输出的是 SDK 版本（例如 `8.0.428`），`vfox current dotnet` 输出的是 vfox 选中的
.NET 发布版本（例如 `8.0.34`）——同一个 SDK 发布版本可能带有更高的 SDK 编号。
`dotnet --list-sdks` 会列出选中版本附带的所有 SDK。

`vfox use --global` 为之后所有新 shell 选中 SDK；`--project` 只作用于当前目录，`--session` 只作用于
当前 shell。作用域规则参见 [vfox 文档](https://vfox.dev/zh-hans/guides/quick-start.html)。

## 预览版和抢先体验版

微软会在同一份元数据中列出预览版和候选发布版，版本号形如 `11.0.0-rc.3` 和
`11.0.0-preview.7`。它们和其他发布版本一样可以搜索和安装：

```bash
vfox search dotnet 11.0
vfox install dotnet@11.0.0-rc.3
```

安装预览版请使用精确版本号。`11.0` 这样的通道会选中微软在该通道中列出的第一个发布版本，也就是最新的那个；在该通道发布正式版之前，它可能是预览版。

## 环境变量

插件通过 vfox 导出两个变量：

| 变量 | 值 |
| --- | --- |
| `DOTNET_ROOT` | 选中 SDK 或运行时的目录 |
| `PATH` | 该目录被加入最前面 |

它们来自 `EnvKeys` 钩子，在 vfox 接入 shell 后生效。在脚本中使用时，需要先激活 vfox：

```bash
eval "$(vfox activate bash)"
vfox use --global dotnet@8.0
eval "$(vfox env -s bash)"
dotnet --version
```

## 平台

vfox 报告操作系统（`linux`、`darwin`、`windows`）和架构（`amd64`、`arm64`、`386`），
插件会把它们映射为 .NET 运行时标识符（RID）：

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

只会安装匹配 RID 的 *Binaries* 压缩包，安装程序和其他组件会被忽略。Linux 和 macOS 上是
`.tar.gz`，Windows 上是 `.zip`。如果微软在某个通道中没有针对你平台的二进制文件，该通道对你来说
就没有可安装的版本。

.NET SDK 本身在 Linux 上还需要原生库，尤其是用于全球化的 ICU。首次运行 `dotnet` 之前，请在
Ubuntu 上安装 `libicu74`（或对应发行版的 ICU 运行时），以及 `libssl3` 和 `zlib1g`。

## 校验和

发布元数据为每个二进制文件提供 SHA-512 `hash`。插件把它交给 vfox，vfox 会在解压前验证下载内容。
校验和不匹配的下载会被拒绝，也不会安装任何东西。
