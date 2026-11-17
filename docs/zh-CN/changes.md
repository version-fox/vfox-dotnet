# 更新日志

[中文](changes.md) | [English](../changes.md)

记录每个版本中用户可感知的变化。拉取请求列表见 GitHub 的发布页面。

## 未发布

- 中英文双语文档：两种语言的 README，以及版本、开发、E2E 测试和本更新日志的指南。
- 拉取请求和推送到 `main` 时自动运行检查：Lua 格式化（stylua）与诊断（lua-language-server）、
  工作流检查（actionlint）、许可证头检查（SkyWalking Eyes）、离线钩子测试（`vfox plugin test`），
  以及 Ubuntu 容器和 Windows 运行器上的端到端测试。
- 所有源码、构建和工作流文件都加上 Apache-2.0 许可证头，并通过 `.gitattributes` 统一使用 LF 换行。
- 新增 `opencode.jsonc`，显式放行推送以及创建、评论拉取请求。
- `vfox link --detect dotnet` 可以直接纳入机器上已有的 .NET SDK，无需再下载一份：包括系统目录、
  `~/.dotnet`、Homebrew、Scoop、asdf、mise、CI 运行器工具缓存以及 `DOTNET_ROOT`/`DOTNET_HOME`。
  找到的 SDK 以它携带的最新运行时命名。参见 [detect.md](detect.md)。

## 0.3.0 (2025-09-29)

- 版本信息改为从微软官方发布元数据读取，不再依赖其他来源；重写了版本检测与输出格式。
- 发布切换到共享的 `plugin-manifest-action` 工作流：通过 **Actions → Plugin → Run workflow** 发起发布，
  拉取请求只运行检查。

## 0.2.0 (2025-03-06)

- SDK 信息改用官方 .NET 发布接口，并增加了可用的版本通道。

## 0.1.1 (2024-04-01)

- CI 更新。

## 0.1.0 (2024-03-28)

- 插件首个版本，同时发布了 manifest。
