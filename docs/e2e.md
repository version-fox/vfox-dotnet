# E2E tests

[中文](zh-CN/e2e.md) | [English](e2e.md)

The end-to-end suites install a real .NET SDK through the plugin and run the
real `dotnet` binary. They are the counterpart to the offline hook tests in
`tests/*_test.lua`, which never touch the network or an actual SDK.

## Layout

```
tests/e2e/
├── linux/
│   ├── Dockerfile      Ubuntu 24.04 with the .NET native libraries and pinned vfox
│   └── e2e.sh          the Ubuntu scenario
└── windows/
    └── e2e.ps1         the Windows scenario
```

## What the suites do

Both suites follow the same steps:

1. Install a pinned vfox (1.1.0, with its archive checksum checked).
2. Package `metadata.lua`, `hooks` and `lib` into a ZIP and add it as a local
   `dotnet` plugin, so the checked-out source is tested rather than a released
   version.
3. Run `vfox search dotnet <version>`.
4. Run `vfox install dotnet@<version>`, which downloads and unpacks the SDK.
5. Activate vfox, run `vfox use --global dotnet@<version>`, and apply the
   environment with `vfox env -s <shell>`.
6. Assert that `DOTNET_ROOT` is set and exists, that `vfox current dotnet`
   reports the release, that `dotnet --version` matches the requested major and
   minor, and that `dotnet --list-sdks` lists the SDK.
7. Create a synthetic SDK home in a system location and run
   `vfox link --detect -y dotnet`, then verify the linked version appears in
   `vfox list dotnet` and can be used. This exercises the `Detect` hook with a
   real vfox process; the SDK installed in step 4 lives under `.vfox` and is
   deliberately excluded from detection.

The steps run in one pass; any failure stops the suite and prints the output of
the failed command.

The Ubuntu suite runs inside a container built from
`tests/e2e/linux/Dockerfile`. The image deliberately has no .NET installed: the
only SDK present afterwards must be the one vfox installed. `libicu74`,
`libssl3` and `zlib1g` are the native libraries .NET needs on noble.

The Windows suite runs natively on a GitHub-hosted `windows-latest` runner with
PowerShell 7. It downloads the pinned vfox Windows ZIP, verifies its checksum,
and uses `Expand-Archive` to avoid the GNU tar that is also on the runner's
`PATH`.

## Run locally

Ubuntu, with Docker:

```bash
docker build --file tests/e2e/linux/Dockerfile --tag vfox-dotnet-e2e:linux .
docker run --rm vfox-dotnet-e2e:linux bash /e2e/e2e.sh
```

Windows, from PowerShell 7 in the repository root:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
./tests/e2e/windows/e2e.ps1
```

The same image is used for the offline hook tests; see [development.md](development.md).

## Configuration

`DOTNET_VERSION` overrides the version under test (default `8.0`), for example:

```bash
docker run --rm --env DOTNET_VERSION=9.0 vfox-dotnet-e2e:linux bash /e2e/e2e.sh
```

`dotnet --version` prints the SDK number (`8.0.428`), which can be higher than
the .NET release vfox selected (`8.0.34`), so the suites only compare the major
and minor with `DOTNET_VERSION`.

## CI

`.github/workflows/e2e.yml` runs two jobs on pull requests and pushes to `main`:

- **Ubuntu container** builds the image and runs `e2e.sh` with the runner's
  Docker.
- **Windows** runs `e2e.ps1` on `windows-latest`.

Both jobs have a 60 minute timeout. The `concurrency` block cancels an older
pull-request run when a new commit arrives, while each commit on `main` keeps
its own run.

To upgrade vfox, change `VFOX_VERSION` and `VFOX_SHA256` in the Linux Dockerfile,
`tests/e2e/windows/e2e.ps1` and `.github/workflows/test.yml` together, and
recompute the SHA-256 of both release archives before updating the checksums.
