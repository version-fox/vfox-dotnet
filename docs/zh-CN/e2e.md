# E2E 测试

[中文](e2e.md) | [English](../e2e.md)

端到端测试会通过插件安装真实的 .NET SDK 并运行真正的 `dotnet` 命令。它们与
`tests/*_test.lua` 中的离线钩子测试互为补充——后者既不访问网络，也不使用真正的 SDK。

## 目录结构

```
tests/e2e/
├── linux/
│   ├── Dockerfile      Ubuntu 24.04，包含 .NET 原生依赖和固定版本的 vfox
│   └── e2e.sh          Ubuntu 场景
└── windows/
    └── e2e.ps1         Windows 场景
```

## 测试内容

两个套件执行相同的步骤：

1. 安装固定版本的 vfox（1.1.0，并校验归档的 SHA-256）。
2. 把 `metadata.lua`、`hooks` 和 `lib` 打包成 ZIP，作为本地 `dotnet` 插件添加，
   从而测试当前检出的源码，而非已发布的版本。
3. 运行 `vfox search dotnet <版本>`。
4. 运行 `vfox install dotnet@<版本>`，下载并解压 SDK。
5. 激活 vfox，运行 `vfox use --global dotnet@<版本>`，并用 `vfox env -s <shell>` 应用环境。
6. 断言 `DOTNET_ROOT` 已设置且目录存在、`vfox current dotnet` 报告选中的发布版本、
   `dotnet --version` 与请求的主次版本号一致，且 `dotnet --list-sdks` 列出了该 SDK。

这些步骤一次执行完成；任何失败都会停止测试，并打印失败命令的输出。

Ubuntu 套件在由 `tests/e2e/linux/Dockerfile` 构建的容器中运行。镜像中故意不安装 .NET：
结束后存在的 SDK 必须只是 vfox 安装的那个。`libicu74`、`libssl3` 和 `zlib1g` 是 noble 上
.NET 所需的原生库。

Windows 套件在 GitHub 托管的 `windows-latest` 运行器上以 PowerShell 7 原生运行。它下载固定版本的
vfox Windows ZIP、校验其校验和，并使用 `Expand-Archive` 解压，以避免使用运行器 `PATH` 上同时存在的
GNU tar。

## 本地运行

Ubuntu（使用 Docker）：

```bash
docker build --file tests/e2e/linux/Dockerfile --tag vfox-dotnet-e2e:linux .
docker run --rm vfox-dotnet-e2e:linux bash /e2e/e2e.sh
```

Windows，在仓库根目录用 PowerShell 7 执行：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
./tests/e2e/windows/e2e.ps1
```

同一个镜像也用于离线钩子测试，参见 [development.md](development.md)。

## 配置

`DOTNET_VERSION` 可以覆盖被测试的版本（默认 `8.0`），例如：

```bash
docker run --rm --env DOTNET_VERSION=9.0 vfox-dotnet-e2e:linux bash /e2e/e2e.sh
```

`dotnet --version` 输出的是 SDK 编号（`8.0.428`），它可能高于 vfox 选中的 .NET 发布版本
（`8.0.34`），因此套件只比较主版本号和次版本号与 `DOTNET_VERSION` 是否一致。

## CI

`.github/workflows/e2e.yml` 在拉取请求和推送到 `main` 时运行两个作业：

- **Ubuntu container** 构建镜像，并使用运行器的 Docker 运行 `e2e.sh`。
- **Windows** 在 `windows-latest` 上运行 `e2e.ps1`。

两个作业的超时时间都是 60 分钟。`concurrency` 配置会在拉取请求有新提交时取消较旧的推送运行，
而 `main` 上的每个提交都保留自己的运行。

升级 vfox 时，请同时修改 Linux Dockerfile、`tests/e2e/windows/e2e.ps1` 和
`.github/workflows/test.yml` 中的 `VFOX_VERSION` 与 `VFOX_SHA256`，并在更新校验和之前重新计算两个
发布归档的 SHA-256。
