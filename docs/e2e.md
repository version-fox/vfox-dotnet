# E2E tests

[中文](zh-CN/e2e.md) | [English](e2e.md)

The end-to-end suites install a real .NET SDK through the plugin and run the
real `dotnet` binary. They are the counterpart to the offline hook tests in
`tests/*_test.lua`, which never touch the network or an actual SDK. Both suites
are Go tests driven by [testcontainers-go](https://golang.testcontainers.org/):
Go builds the image, starts a long-lived container and drives every phase
through exec calls, asserting in Go.

## Layout

```
tests/e2e/
├── go.mod, go.sum       the single module root
├── doc.go
├── common/              retry, version and output parsing shared by both suites
├── linux/
│   ├── Dockerfile       Ubuntu 24.04 with the .NET native libraries, pinned vfox and pinned mise
│   ├── exec.go          bash exec helpers
│   └── e2e_test.go      TestE2E
└── windows/
    ├── Dockerfile       Windows Server Core with PowerShell 7
    ├── bootstrap-tools.ps1
    ├── exec.go          pwsh exec helpers
    └── e2e_test.go      TestE2E
```

## What the suites do

Both suites follow the same steps (step 4 runs in the Linux suite only):

1. Install a pinned vfox (1.1.0, with its archive checksum checked). In the
   Linux image it is baked in at build time; the Windows test downloads it
   from the release archive and stages `vfox.exe` in the container.
2. Package `metadata.lua`, `hooks` and `lib` into a ZIP and add it as a local
   `dotnet` plugin, so the checked-out source is tested rather than a released
   version.
3. Run `vfox search dotnet <version>`.
4. Linux only: copy the same plugin into mise's plugin directory and run
   `mise ls-remote "vfox:version-fox/vfox-dotnet"`, which lists every release of
   every channel. The SDK, runtime and ASP.NET Core Runtime of the channel must
   all be listed. mise decodes a JSON null differently from vfox, so this is the
   step that catches issue #17. Only metadata is downloaded. The step sets
   `MISE_FETCH_REMOTE_VERSIONS_TIMEOUT=300`, because mise limits the whole listing
   to 20 seconds by default and a slow network can exceed that.
5. Run `vfox install dotnet@<version>`, which downloads and unpacks the SDK,
   and assert that vfox verified the download against the checksum in the
   release metadata.
6. Activate vfox, run `vfox use --global dotnet@<version>`, and apply the
   environment with `vfox env -s <shell>`.
7. Assert that `DOTNET_ROOT` is set and exists, that `vfox current dotnet`
   reports the release, that `dotnet --version` matches the requested major and
   minor, and that `dotnet --list-sdks` lists the SDK.
8. Create a synthetic SDK home where the `Detect` hook looks (`/opt/dotnet` on
   Linux, `~/.dotnet` on Windows) and run `vfox link --detect -y dotnet`, then
   verify the linked version appears in `vfox list dotnet` (and can be used on
   Linux). This exercises the `Detect` hook with a real vfox process; the SDK
   installed in step 5 lives under `.vfox` and is deliberately excluded from
   detection.

Every network-touching call goes through `common.Retry` (three attempts by
default, 10s/20s backoff), because downloads and daemon calls in throwaway
containers flake. Any failed assertion stops the suite with the command output
attached.

The Linux image deliberately has no .NET installed: the only SDK present
afterwards must be the one vfox installed. `libicu74`, `libssl3` and `zlib1g`
are the native libraries .NET needs on noble. The Windows image is Server Core
with PowerShell 7 installed from its release zip; the Go test stages vfox with
`Expand-Archive` to avoid the GNU tar that is also on the runner's `PATH`.

## Run locally

Docker is required. From the `tests/e2e` directory:

```bash
# Compile and run the tests that do not need containers.
go test -short ./...

# Ubuntu container (builds the image and runs TestE2E).
go test -v -timeout 55m -run TestE2E ./linux

# Windows container: run from a Windows host with Docker in Windows
# container mode.
go test -v -timeout 55m -run TestE2E ./windows
```

## Configuration

- `DOTNET_VERSION` overrides the channel under test (default `10.0`, the current LTS channel).
- `E2E_RETRY_ATTEMPTS` overrides the retry count (default `3`).

`dotnet --version` prints the SDK number (`10.0.404`), which can be higher than
the .NET release vfox selected (`10.0.15`), so the suites only compare the major
and minor with `DOTNET_VERSION`.

## CI

`.github/workflows/e2e.yml` runs two jobs on pull requests and pushes to `main`:

- **Ubuntu container** runs `go test -run TestE2E ./linux` on `ubuntu-latest`.
- **Windows container** runs `go test -run TestE2E ./windows` on `windows-latest`.

Both use Go 1.27.1. The CI job has a 60 minute timeout and runs the suites with
`go test -timeout 55m`; the Go tests themselves use a 40 minute context. The `concurrency` block
cancels an older pull-request run when a new commit arrives, while each commit
on `main` keeps its own run.

To upgrade vfox, change the pinned version and SHA-256 checksums in the Linux
Dockerfile, `tests/e2e/windows/e2e_test.go` and `.github/workflows/test.yml`
together, and recompute the checksums of the release archives before updating
them.

To upgrade mise, change `MISE_VERSION` and `MISE_SHA256` in the Linux Dockerfile,
and check the checksum against the digest GitHub reports for the release asset.
