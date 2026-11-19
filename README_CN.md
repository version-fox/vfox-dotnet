# vfox-dotnet

[中文](README_CN.md) | [English](README.md)

[vfox](https://vfox.dev/) 的 .NET 插件。它从微软官方的
[发布元数据](https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json)
获取 SDK、.NET Runtime 或 ASP.NET Core Runtime，并使用随发布提供的 SHA-512 校验和验证每一次下载。

## 安装

安装好 [vfox](https://github.com/version-fox/vfox) 之后，添加插件并安装 SDK：

```
vfox add dotnet
vfox install dotnet@10.0
vfox use --global dotnet@10.0
dotnet --version
```

要让 `dotnet` 出现在 `PATH` 中，需要把 vfox 接入 shell，参见
[vfox 快速开始](https://vfox.dev/zh-hans/guides/quick-start.html)。

## 版本与名称

版本号可以是 .NET 通道，也可以是完整的发布版本：

```
vfox install dotnet@10       # 10.x 系列中最新的正式版
vfox install dotnet@10.0     # 10.0 通道中最新的正式版
vfox install dotnet@10.0.15  # 指定的 .NET 发布版本，安装 SDK
```

`vfox search dotnet 10.0` 会列出插件已知的版本。版本如何解析、预览版本以及插件设置的环境变量，
参见[版本与名称](docs/zh-CN/versions.md)。

## 发行版变体

版本号可以带后缀，以安装比完整 SDK 更小的发行版：

```
vfox install dotnet@10.0.15-runtime     # 仅 .NET Runtime
vfox install dotnet@10.0.15-aspnetcore  # ASP.NET Core Runtime（包含 .NET Runtime）
```

| 后缀 | 发行版 | 大致磁盘占用 |
| --- | --- | --- |
| *（无）* | .NET SDK（默认） | 约 600 MB |
| `-runtime` | 仅 .NET Runtime | 约 70 MB |
| `-aspnetcore` | ASP.NET Core Runtime | 约 100 MB |

后缀适用于任何接受版本号的地方，包括 `vfox use` 和 `.tool-versions`。不带后缀的既有安装仍使用
SDK。细节参见[版本与名称](docs/zh-CN/versions.md#发行版变体)。

## 平台

vfox 的操作系统和架构会映射为 .NET 运行时标识符（RID），例如 `linux-x64`、`osx-arm64` 或
`win-x64`，并安装对应的二进制压缩包：Linux 和 macOS 上是 `.tar.gz`，Windows 上是 `.zip`。
参见[版本与名称](docs/zh-CN/versions.md#平台)。

## 文档

**使用插件**

- [版本与名称](docs/zh-CN/versions.md)：版本语法、发行版变体、安装、使用、搜索、平台与校验和
- [使用机器上已有的 SDK](docs/zh-CN/detect.md)：`vfox link --detect dotnet`
- [更新日志](docs/zh-CN/changes.md)：每个版本的变化

**参与开发**

- [开发指南](docs/zh-CN/development.md)：插件原理、本地检查和发布方式
- [E2E 测试](docs/zh-CN/e2e.md)：Ubuntu 与 Windows 的端到端测试

## 发布插件

维护者可以在默认分支上通过 **Actions → Plugin → Run workflow** 发布，输入不带 `v` 前缀的稳定插件版本。
共享工作流会更新 `metadata.lua`、创建版本提交与标签，并在本仓库发布 ZIP 和 manifest。
无需本地打标签，也无需额外的发布令牌。拉取请求只运行检查；发布通过手动 `workflow_dispatch` 完成。

当 `PLUGIN.version` 已与标签一致时，仍然支持推送版本标签。如果发布失败，重新运行原来失败的作业即可继续。

该工作流使用共享的 `@v1` 发布工具版本。更新工具本身不会发布本插件。包结构和首次启用要求参见
[共享工作流文档](https://github.com/version-fox/plugin-manifest-action)。

## 许可证

Apache-2.0，参见 [LICENSE](LICENSE)。
