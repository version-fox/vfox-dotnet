# E2E 测试

[中文](e2e.md) | [English](../e2e.md)

端到端测试会通过插件安装真实的 .NET SDK 并运行真正的 `dotnet` 命令。它们与
`tests/*_test.lua` 中的离线钩子测试互为补充——后者既不访问网络，也不使用真正的 SDK。
两个套件都是 [testcontainers-go](https://golang.testcontainers.org/) 驱动的 Go 测试：
Go 构建镜像、启动一个长期运行的容器，并通过 exec 调用驱动每个阶段，在 Go 中断言。

## 目录结构

```
tests/e2e/
├── go.mod, go.sum       唯一的模块根目录
├── doc.go
├── common/              两个套件共用的重试、版本和输出解析
├── linux/
│   ├── Dockerfile       Ubuntu 24.04，包含 .NET 原生依赖以及固定版本的 vfox 和 mise
│   ├── exec.go          bash exec 辅助函数
│   └── e2e_test.go      TestE2E
└── windows/
    ├── Dockerfile       带 PowerShell 7 的 Windows Server Core
    ├── bootstrap-tools.ps1
    ├── exec.go          pwsh exec 辅助函数
    └── e2e_test.go      TestE2E
```

## 测试内容

两个套件执行相同的步骤（第 4 步仅 Linux 套件运行）：

1. 安装固定版本的 vfox（1.1.0，并校验归档的 SHA-256）。Linux 镜像在构建时把它装入镜像；
   Windows 测试从发布归档下载并暂存 `vfox.exe`。
2. 把 `metadata.lua`、`hooks` 和 `lib` 打包成 ZIP，作为本地 `dotnet` 插件添加，
   从而测试当前检出的源码，而非已发布的版本。
3. 运行 `vfox search dotnet <版本>`。
4. 仅 Linux：把同一个插件复制到 mise 的插件目录，运行 `mise ls-remote "vfox:version-fox/vfox-dotnet"`，
   列出所有通道的每个发布版本。该通道的 SDK、runtime 和 ASP.NET Core Runtime 都必须被列出。
   mise 对 JSON `null` 的解析与 vfox 不同，因此由这一步发现 #17 问题；只下载元数据。
   这一步设置了 `MISE_FETCH_REMOTE_VERSIONS_TIMEOUT=300`：mise 默认把整个列表限制在 20 秒内，
   慢网络下可能超过这个时限。
5. 运行 `vfox install dotnet@<版本>`，下载并解压 SDK，并断言 vfox 用发布元数据中的校验和
   验证了下载内容。
6. 激活 vfox，运行 `vfox use --global dotnet@<版本>`，并用 `vfox env -s <shell>` 应用环境。
7. 断言 `DOTNET_ROOT` 已设置且目录存在、`vfox current dotnet` 报告选中的发布版本、
   `dotnet --version` 与请求的主次版本号一致，且 `dotnet --list-sdks` 列出了该 SDK。
8. 在 `Detect` 钩子会扫描的位置创建一个模拟的 SDK 主目录（Linux 为 `/opt/dotnet`，Windows 为 `~/.dotnet`），
   运行 `vfox link --detect -y dotnet`，然后验证链接的版本出现在 `vfox list dotnet` 中（Linux 上还可正常使用）。
   这会在真实 vfox 进程中验证 `Detect` 钩子；第 5 步安装的 SDK 位于 `.vfox` 下，会被刻意排除在检测之外。

所有涉及网络调用都经过 `common.Retry`（默认三次，10s/20s 退避），因为临时容器中的下载和进程调用
偶尔会失败。任何断言失败都会停止测试，并打印相关命令的输出。

Linux 镜像中故意不安装 .NET：结束后存在的 SDK 必须只是 vfox 安装的那个。`libicu74`、`libssl3`
和 `zlib1g` 是 noble 上 .NET 所需的原生库。Windows 镜像是安装了 PowerShell 7 发布版 zip 的
Server Core；Go 测试用 `Expand-Archive` 暂存 vfox，以避免使用运行器 `PATH` 上的 GNU tar。

## 本地运行

需要 Docker。在 `tests/e2e` 目录下执行：

```bash
# 编译并运行不需要容器的测试。
go test -short ./...

# Ubuntu 容器（构建镜像并运行 TestE2E）。
go test -v -timeout 55m -run TestE2E ./linux

# Windows 容器：在 Windows 主机上以 Windows 容器模式运行 Docker。
go test -v -timeout 55m -run TestE2E ./windows
```

## 配置

- `DOTNET_VERSION` 覆盖被测试的通道（默认 `10.0`，即当前的 LTS 通道）。
- `E2E_RETRY_ATTEMPTS` 覆盖重试次数（默认 `3`）。

`dotnet --version` 输出的是 SDK 编号（`10.0.404`），它可能高于 vfox 选中的 .NET 发布版本
（`10.0.15`），因此套件只比较主版本号和次版本号与 `DOTNET_VERSION` 是否一致。

## CI

`.github/workflows/e2e.yml` 在拉取请求和推送到 `main` 时运行两个作业：

- **Ubuntu container** 在 `ubuntu-latest` 上运行 `go test -run TestE2E ./linux`。
- **Windows container** 在 `windows-latest` 上运行 `go test -run TestE2E ./windows`。

两者都使用 Go 1.27.1。CI 作业超时为 60 分钟，并用 `go test -timeout 55m` 运行测试，而 Go 测试
自身使用 40 分钟的上下文。`concurrency` 配置会在拉取请求有新提交时取消较旧的
推送运行，而 `main` 上的每个提交都保留自己的运行。

升级 vfox 时，请同时修改 Linux Dockerfile、`tests/e2e/windows/e2e_test.go` 和
`.github/workflows/test.yml` 中的固定版本与 SHA-256 校验和，并在更新校验和之前重新计算发布归档的
SHA-256。

升级 mise 时，请修改 Linux Dockerfile 中的 `MISE_VERSION` 和 `MISE_SHA256`，并对照 GitHub 为该发布资产给出的 digest 核对校验和。
