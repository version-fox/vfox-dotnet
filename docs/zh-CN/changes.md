# 更新日志

[中文](changes.md) | [English](../changes.md)

记录每个版本中用户可感知的变化。拉取请求列表见 GitHub 的发布页面。

## 0.3.2 (2026-11-17)

- 将最低支持的 vfox 版本提升至 1.1.0,与 SDK 检测钩子、CI 和 E2E 测试已使用的版本一致。
  使用旧版 vfox 的安装现在会收到升级提示。
- 刷新文档:修正发布工作流的历史与 E2E 超时说明、修复失效链接,并补全检测 SDK 的路径列表。

## 0.3.1 (2026-11-17)

- 通过版本后缀安装更小的发行版：`-runtime` 对应 .NET Runtime，`-aspnetcore` 对应
  ASP.NET Core Runtime；不带后缀时仍然安装完整 SDK。部分版本号（`8`、`8.0`）和 `latest`
  现在会解析为最新发布版本，并按版本组件边界匹配，因此 `8.0.3` 不会再选中 `8.0.34`。
- 中英文双语文档：两种语言的 README，以及版本、开发、E2E 测试和本更新日志的指南。
- 拉取请求和推送到 `main` 时自动运行检查：Lua 格式化（stylua）与诊断（lua-language-server）、
  工作流检查（actionlint）、许可证头检查（SkyWalking Eyes）、离线钩子测试（`vfox plugin test`），
  以及 Ubuntu 容器和 Windows 运行器上的端到端测试。
- 所有源码、构建和工作流文件都加上 Apache-2.0 许可证头，并通过 `.gitattributes` 统一使用 LF 换行。
- 新增 `opencode.jsonc`，显式放行推送以及创建、评论拉取请求。
- `vfox link --detect dotnet` 可以直接纳入机器上已有的 .NET SDK，无需再下载一份：包括系统目录、
  `~/.dotnet`、Homebrew、Scoop、asdf、mise、CI 运行器工具缓存以及 `DOTNET_ROOT`/`DOTNET_HOME`。
  找到的 SDK 以它携带的最新运行时命名。参见 [detect.md](detect.md)。
- 发布切换到共享的 `@v1` 可复用工作流：维护者通过 **Actions → Plugin → Run workflow** 发起发布，
  拉取请求只运行检查。

## 0.3.0 (2025-09-29)

- 版本信息改为从微软官方发布元数据读取，不再依赖其他来源；重写了版本检测与输出格式。
- 发布改用共享的 `plugin-manifest-action`，取代原先自写的 Lua manifest 任务；当时仍由版本标签和
  以 `Release v` 开头的拉取请求标题触发。

## 0.2.0 (2025-03-06)

- SDK 信息改用官方 .NET 发布接口，并增加了可用的版本通道。

## 0.1.1 (2024-04-01)

- CI 更新。

## 0.1.0 (2024-03-28)

- 插件首个版本，同时发布了 manifest。
