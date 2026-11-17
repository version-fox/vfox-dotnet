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
| `lib/util.lua` | 版本解析、发布查询、操作系统/架构到 RID 的映射 |
| `Injection.lua` | vfox 注入对象的类型提示，不要修改 |
| `tests/*_test.lua` | 由 `vfox plugin test` 运行的离线钩子测试 |
| `tests/e2e/` | Ubuntu 和 Windows 端到端测试，参见 [e2e.md](e2e.md) |

## 插件原理

`Available` 读取[发布索引](https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json)，
再读取每个通道的 `releases.json`。对每个发布版本，它会选择与当前平台 RID 匹配、且 URL 以 `.tar.gz`
或 `.zip` 结尾的 *Binaries* 文件，并记录随发布提供的 SHA-512 作为 `sha512`。vfox 随后搜索这份列表。

`PreInstall` 把请求的版本解析为通道（`8` → `8`、`8.0` → `8.0`、`8.0.34` → `8.0`），只抓取该通道，
并返回第一个以用户输入开头的发布版本。`addition` 字段携带 SDK 版本，因此 vfox 也会下载并解压
该发布版本附带的 SDK。vfox 会在解压前校验校验和。

RID 映射位于 `lib/util.lua:getOsTypeAndArch`。增加平台时，请同时修改这里和
[versions.md](versions.md#平台) 中的平台表格。

结果会在一个 vfox 进程的生命周期内缓存，因为运行时操作系统和架构在此其间不会变化。

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

所有检查都会在 CI 中运行；本地只需要 Docker。在仓库根目录执行：

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

# 离线钩子测试（vfox 1.1.0）
docker run --rm -v "$PWD:/work" -w /work vfox-dotnet-e2e:linux vfox plugin test .

# 许可证头检查（SkyWalking Eyes 0.9.0）
GOBIN=/tmp/opencode/bin go install github.com/apache/skywalking-eyes/cmd/license-eye@v0.9.0
/tmp/opencode/bin/license-eye -c .licenserc.yaml header check

# 工作流检查（actionlint 1.7.12）
go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.12
"$(go env GOPATH)/bin/actionlint"

# Go 端到端测试（-short 模式不启动容器）
cd tests/e2e && go test -short ./... && cd ../..
# 完整的容器测试，参见 e2e.md
cd tests/e2e && go test -v -timeout 45m -run TestE2E ./linux
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
`assert` 断言，并打印带用例数的 `PASS:` 行。需要真正执行 shell 命令的测试不应放在 `*_test.lua` 中，
而应放入 E2E 测试。

## 发布

参见[发布插件](../README_CN.md#发布插件)。拉取请求只运行检查；发布通过 `workflow_dispatch` 手动
指定稳定版本。发布时，请在 [changes.md](changes.md) 及其中文副本中添加带日期的章节。
