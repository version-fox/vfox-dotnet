# Development

[中文](zh-CN/development.md) | [English](development.md)

## Repository layout

| Path | Purpose |
| --- | --- |
| `metadata.lua` | plugin name, version, homepage, license, description, manifest URL |
| `hooks/available.lua` | `Available`: returns every release vfox can search |
| `hooks/pre_install.lua` | `PreInstall`: resolves a user version to one downloadable release |
| `hooks/env_keys.lua` | `EnvKeys`: exports `DOTNET_ROOT` and prepends the SDK to `PATH` |
| `hooks/post_install.lua`, `hooks/pre_use.lua` | extension points, intentionally empty |
| `hooks/detect.lua` | `Detect`: find SDKs already on the machine for `vfox link --detect` |
| `lib/util.lua` | version parsing, release lookup, OS/architecture to RID mapping |
| `lib/detect_dotnet.lua` | finding installed SDKs by their `sdk` and runtime directories |
| `Injection.lua` | type hints for the objects vfox injects; never changed |
| `tests/*_test.lua` | offline hook tests run by `vfox plugin test` |
| `tests/e2e/` | Ubuntu and Windows end-to-end suites, see [e2e.md](e2e.md) |

## How the plugin works

`Available` reads the
[releases index](https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json),
then every channel's `releases.json`. For each release and each distribution
variant it picks the *Binaries* file whose RID matches the current platform,
whose name starts with the variant's package name (`dotnet-sdk-`,
`dotnet-runtime-` or `aspnetcore-runtime-`) and whose URL ends in `.tar.gz` or
`.zip`, and records the published SHA-512 as `sha512`. The name is what selects
the file: the `runtime` component of .NET 10 and later also lists the apphost
pack, before the runtime. Installers and composite ASP.NET archives are ignored.
The variants are the SDK (no suffix), `-runtime` and `-aspnetcore`, built from
the `sdk`, `runtime` and `aspnetcore-runtime` components of the release metadata.
vfox searches that list.

`PreInstall` strips a known variant suffix, parses the remaining version into a
channel (`8` → `8`, `8.0` → `8.0`, `8.0.34` → `8.0`), fetches only that channel and
that variant, and resolves an exact version first, then a partial version on
component boundaries (`8.0.3` does not match `8.0.34`), taking the newest stable
release among the matches. The `addition` field carries the component version and
label. vfox verifies the checksum before unpacking.

`resolveVersion` also maps `latest` and an empty version to the newest stable
release returned by `Available`, or to the newest preview when none is stable.

When no release matches, `PreInstall` raises an error instead of returning an empty table, because vfox would record an empty table as a successful install with no version.

The RID mapping lives in `lib/util.lua:getOsTypeAndArch`. When adding a platform,
change it there and in the platform table in [versions.md](versions.md#platforms).

Within one vfox process each release metadata document is fetched once, and the
OS and architecture are read once, because neither changes while it runs. If a
document cannot be fetched or decoded, the whole listing fails with an error that
names its URL, so no channel is left out silently. A component that is JSON
`null`, such as the ASP.NET Core Runtime of the 1.0 to 2.0 channels, is skipped.

## Detecting installed SDKs

`hooks/detect.lua` implements `Detect` for `vfox link --detect dotnet`.
`lib/detect_dotnet.lua` scans the system directories, `~/.dotnet`, Homebrew,
Scoop, asdf, mise, the CI tool cache and `DOTNET_ROOT`/`DOTNET_HOME`. A directory
is an SDK home when it has the `dotnet` executable and at least one version under
`sdk/`; it is named after the newest runtime under
`shared/Microsoft.NETCore.App` (or `host/fxr`), which is the release version
`vfox install` uses. Paths under `.vfox` or `$VFOX_HOME`, duplicate versions and
runtime-only directories are left out. Results are sorted newest first.

`tests/detect_test.lua`, `tests/detect_env_test.lua` and
`tests/detect_windows_test.lua` fake the directory listings and file contents
through `io.popen` and `io.open`; no real SDK is needed. The E2E suites link a
synthetic system SDK as a final check that vfox can use the result.

## Local checks

Every check runs in CI. Docker runs the Lua checks and the offline hook tests;
the license, workflow and Go checks also need Go on the host. From the
repository root:

```bash
# Lua formatting (stylua 2.5.2)
docker run --rm -v "$PWD:/work" -w /work ubuntu:24.04 bash -c \
  'apt-get update -qq && apt-get install -y -qq curl unzip >/dev/null 2>&1 && \
   curl -fsSL -o /tmp/s.zip https://github.com/JohnnyMorganz/StyLua/releases/download/v2.5.2/stylua-linux-x86_64.zip && \
   unzip -q /tmp/s.zip -d /usr/local/bin && stylua --check .'
# Drop --check to format in place.

# Lua diagnostics (lua-language-server 3.19.1)
docker run --rm -v "$PWD:/work" -w /work ubuntu:24.04 bash -c \
  'apt-get update -qq && apt-get install -y -qq curl tar >/dev/null 2>&1 && \
   curl -fsSL -o /tmp/l.tgz https://github.com/LuaLS/lua-language-server/releases/download/3.19.1/lua-language-server-3.19.1-linux-x64.tar.gz && \
   mkdir -p /opt/luals && tar -xzf /tmp/l.tgz -C /opt/luals && \
   /opt/luals/bin/lua-language-server --check . --checklevel=Warning'

# Offline hook tests (vfox 1.1.0). Build the image once from the repository root:
# docker build --file tests/e2e/linux/Dockerfile --tag vfox-dotnet-e2e:linux .
docker run --rm -v "$PWD:/work" -w /work vfox-dotnet-e2e:linux vfox plugin test .

# License headers (SkyWalking Eyes 0.9.0)
go install github.com/apache/skywalking-eyes/cmd/license-eye@v0.9.0
"$(go env GOPATH)/bin/license-eye" -c .licenserc.yaml header check

# Workflow lint (actionlint 1.7.12)
go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.12
"$(go env GOPATH)/bin/actionlint"

# Go E2E suites (no containers in -short mode)
cd tests/e2e && go test -short ./... && cd ../..
# Full container suites, see e2e.md
cd tests/e2e && go test -v -timeout 55m -run TestE2E ./linux
```

The versions above are pinned in the workflows too. When upgrading a tool,
change the workflow and this document together.

## Adding a test

Offline tests are `tests/*_test.lua` and run under `vfox plugin test`, which
executes each file in its own VM. Boilerplate:

```lua
local test = require("vfox.test")
local json = require("json")

local answer = function(request)
    return { status_code = 200, body = json.encode({ ... }) }
end
local plugin = test.load({ os = "linux", arch = "amd64", http = answer })
local util = require("util")
```

`test.load` installs a mock `RUNTIME`, `http` and package path, so tests never
touch the network. Assert with plain Lua `assert` and print a `PASS:` line that says
what the file checked. Anything that must run real shell commands does not belong in
a `*_test.lua` file; use an E2E suite instead.

## Releasing

See [Releasing this plugin](../README.md#releasing-this-plugin). Pull requests
only run checks; publication is a manual `workflow_dispatch` with a stable
version. Add a dated section to [changes.md](changes.md) and its Chinese copy
when publishing.
