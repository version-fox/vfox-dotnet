# 开发指南

[中文](development.md) | [English](../development.md)

## 仓库结构

| 路径 | 用途 |
| --- | --- |
| `metadata.lua` | 插件名称、版本、主页、许可证、描述和 manifest 地址 |
| `hooks/available.lua` | `Available`：返回 vfox 可以搜索的所有发布版本 |
| `hooks/pre_install.lua` | `PreInstall`：把用户版本号解析为一个可下载的发布版本 |
| `hooks/env_keys.lua` | `EnvKeys`：导出 `DOTNET_ROOT` 并把 SDK 目录加入 `PATH` |
| `hooks/post_install.lua`、`hooks/pre_use.lua` | 扩展点，目前为空 |
| `hooks/detect.lua` | `Detect`：查找机器上已有的 SDK，供 `vfox link --detect` 使用 |
| `lib/util.lua` | 版本解析、发布查询、操作系统/架构到 RID 的映射 |
| `lib/detect_dotnet.lua` | 通过 `sdk` 和运行时目录查找已安装的 SDK |
| `Injection.lua` | vfox 注入对象的类型提示，不要修改 |
| `tests/*_test.lua` | 由 `vfox plugin test` 运行的离线钩子测试 |
| `tests/fixtures/` | 离线测试读取的发布元数据 JSON |
| `tests/e2e/` | Ubuntu 和 Windows 端到端测试，参见 [e2e.md](e2e.md) |
| `.github/workflows/` | CI：检查、离线测试、E2E 测试和发布工作流 |
| `stylua.toml`、`.luarc.json`、`.licenserc.yaml` | Lua 格式化、LuaLS 设置和许可证头规则 |
| `opencode.jsonc` | OpenCode 权限：允许执行的 `git push` 和 `gh pr` 命令 |

## 插件原理

`Available` 读取[发布索引](https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json)，
再读取每个通道的 `releases.json`。对每个发布版本和每个发行版变体，它会选择与当前平台 RID 匹配、
文件名以变体的包名开头（`dotnet-sdk-`、`dotnet-runtime-` 或 `aspnetcore-runtime-`）、且 URL 以
`.tar.gz` 或 `.zip` 结尾的 *Binaries* 文件，并记录随发布提供的 SHA-512 作为 `sha512`。文件名决定选择
哪个文件：.NET 10 及更高版本的 `runtime` 组件还会在运行时之前列出 apphost 包。安装程序和 ASP.NET
composite 压缩包会被忽略。变体包括 SDK（无后缀）、`-runtime` 和
`-aspnetcore`，分别取自发布元数据中的 `sdk`、`runtime` 和 `aspnetcore-runtime` 组件。
vfox 随后搜索这份列表。

`PreInstall` 先去掉已知的变体后缀，再把剩余版本解析为通道（`8` → `8`、`8.0` → `8.0`、
`8.0.34` → `8.0`），只抓取该通道和该变体，并优先匹配精确版本，然后按组件边界匹配部分版本
（`8.0.3` 不会匹配 `8.0.34`），并在匹配项中选择最新的正式版。`addition` 字段携带组件的版本和名称。vfox 会在解压前校验校验和。

`resolveVersion` 还会把 `latest` 和空版本映射为 `Available` 返回的最新正式版；如果列表里全是预览版，则映射为最新的预览版。

没有匹配的发行版时，`PreInstall` 会抛出错误而不是返回空表，因为 vfox 会把空表记录为没有版本号的成功安装。

RID 映射位于 `lib/util.lua:getOsTypeAndArch`。增加平台时，请同时修改这里和
[versions.md](versions.md#平台) 中的平台表格。

在同一个 vfox 进程中，每个发布元数据文档只获取一次，操作系统和架构也只读取一次，因为两者在运行期间都不会变化。
获取或解析某个文档失败时，整个列表会报错并给出该 URL，不会悄悄漏掉某个通道。JSON 为 `null` 的组件会被跳过，
例如 1.0 到 2.0 通道的 ASP.NET Core Runtime。

## 检测已安装的 SDK

`hooks/detect.lua` 为 `vfox link --detect dotnet` 实现 `Detect`。
`lib/detect_dotnet.lua` 会扫描系统目录、`~/.dotnet`、Homebrew、Scoop、asdf、mise、CI 工具缓存以及
`DOTNET_ROOT`/`DOTNET_HOME`。如果一个目录包含 `dotnet` 可执行文件且 `sdk/` 下至少有一个版本，就视为 SDK 主目录；
它按 `shared/Microsoft.NETCore.App`（或 `host/fxr`）下的最新运行时命名，也就是 `vfox install` 使用的发布版本。
`.vfox` 或 `$VFOX_HOME` 下的路径、重复版本以及只有运行时的目录都会被排除。结果按版本从新到旧排序。

`tests/detect_test.lua`、`tests/detect_env_test.lua` 和 `tests/detect_windows_test.lua` 通过 `io.popen` 和
`io.open` 模拟目录列表与文件内容，不需要真实的 SDK。E2E 测试最后还会链接一个模拟的系统 SDK，以验证 vfox
确实能使用检测结果。

## 本地检查

所有检查都会在 CI 中运行。Docker 可以运行 Lua 检查和离线钩子测试；许可证、工作流和 Go 检查还需要本机安装 Go。在仓库根目录执行：

```bash
# Lua 格式化（stylua 2.5.2）
docker run --rm -v "$PWD:/work" -w /work ubuntu:24.04 bash -c \
  'apt-get update -qq && apt-get install -y -qq curl unzip >/dev/null 2>&1 && \
   curl -fsSL -o /tmp/s.zip https://github.com/JohnnyMorganz/StyLua/releases/download/v2.5.2/stylua-linux-x86_64.zip && \
   unzip -q /tmp/s.zip -d /usr/local/bin && stylua --check .'
# 去掉 --check 即可就地格式化。

# Lua 诊断（lua-language-server 3.19.1）
docker run --rm -v "$PWD:/work" -w /work ubuntu:24.04 bash -c \
  'apt-get update -qq && apt-get install -y -qq curl tar >/dev/null 2>&1 && \
   curl -fsSL -o /tmp/l.tgz https://github.com/LuaLS/lua-language-server/releases/download/3.19.1/lua-language-server-3.19.1-linux-x64.tar.gz && \
   mkdir -p /opt/luals && tar -xzf /tmp/l.tgz -C /opt/luals && \
   /opt/luals/bin/lua-language-server --check . --checklevel=Warning'

# 离线钩子测试（vfox 1.1.0）。先在仓库根目录构建一次镜像：
# docker build --file tests/e2e/linux/Dockerfile --tag vfox-dotnet-e2e:linux .
docker run --rm -v "$PWD:/work" -w /work vfox-dotnet-e2e:linux vfox plugin test .

# 许可证头检查（SkyWalking Eyes 0.9.0）
go install github.com/apache/skywalking-eyes/cmd/license-eye@v0.9.0
"$(go env GOPATH)/bin/license-eye" -c .licenserc.yaml header check

# 工作流检查（actionlint 1.7.12）
go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.12
"$(go env GOPATH)/bin/actionlint"

# Go 端到端测试（-short 模式不启动容器）
cd tests/e2e && go test -short ./... && cd ../..
# 完整的容器测试，参见 e2e.md
cd tests/e2e && go test -v -timeout 55m -run TestE2E ./linux
```

上述工具版本在工作流中也已固定。升级工具时，请同时更新工作流和本文档。

## 添加测试

离线测试是 `tests/*_test.lua`，由 `vfox plugin test` 运行，每个文件在独立的 VM 中执行。基本结构：

```lua
local test = require("vfox.test")
local json = require("json")

local answer = function(request)
    return { status_code = 200, body = json.encode({ ... }) }
end
local plugin = test.load({ os = "linux", arch = "amd64", http = answer })
local util = require("util")
```

`test.load` 会安装模拟的 `RUNTIME`、`http` 和包搜索路径，因此测试不会访问网络。使用普通的 Lua
`assert` 断言，并打印一行 `PASS:` 提示，说明该文件检查了什么。需要真正执行 shell 命令的测试不应放在 `*_test.lua` 中，
而应放入 E2E 测试。

## 发布

参见[发布插件](../../README_CN.md#发布插件)。拉取请求只运行检查；发布通过 `workflow_dispatch` 手动
指定稳定版本。发布时，请在中英文两份更新日志中添加带日期的章节：[changes.md](changes.md) 和 [英文版](../changes.md)。
