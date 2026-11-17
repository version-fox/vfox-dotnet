// Copyright 2026 Han Li and contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Package windows is the Windows container E2E suite, driven from Go through
// testcontainers-go. TestE2E builds the image once, starts one long-lived
// container and drives setup -> search -> install -> use -> verify -> detect
// through pwsh exec calls, asserting in Go.
package windows

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	tc "github.com/testcontainers/testcontainers-go"

	"github.com/version-fox/vfox-dotnet/tests/e2e/common"
)

// TestE2E installs a real .NET SDK through the plugin, uses it and links a
// synthetic system SDK. Scope the version locally with DOTNET_VERSION=9.0.
func TestE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("skip container E2E in short mode")
	}
	// Ryuk has no Windows image, so the reaper can never start here. The
	// container is terminated explicitly via t.Cleanup instead.
	t.Setenv("TESTCONTAINERS_RYUK_DISABLED", "true")
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Minute)
	defer cancel()

	here, err := filepath.Abs(".")
	if err != nil {
		t.Fatal(err)
	}
	repoRoot := filepath.Join(here, "..", "..", "..")
	image := buildImage(t, ctx, repoRoot)
	ctr := startContainer(t, ctx, image)
	t.Cleanup(func() { _ = ctr.Terminate(context.Background()) })

	version := common.Version()
	setupVfox(t, ctx, ctr)
	checkSearch(t, ctx, ctr, version)
	installed := installDotnet(t, ctx, ctr, version)
	useDotnet(t, ctx, ctr, installed)
	verifyToolchain(t, ctx, ctr, version, installed)
	verifyDetect(t, ctx, ctr)
}

// buildImage replicates `docker build --file tests/e2e/windows/Dockerfile
// --tag vfox-dotnet-e2e:windows <repoRoot>`.
func buildImage(t *testing.T, ctx context.Context, repoRoot string) string {
	t.Helper()
	provider, err := tc.NewDockerProvider()
	if err != nil {
		t.Fatalf("new docker provider: %v", err)
	}
	t.Cleanup(func() { _ = provider.Close() })
	base := "mcr.microsoft.com/windows/servercore:ltsc2025-KB5122871-amd64"
	if strings.EqualFold(os.Getenv("PROCESSOR_ARCHITECTURE"), "ARM64") {
		base = "mcr.microsoft.com/windows/servercore:ltsc2025-KB5122871-arm64"
	}
	tag, err := provider.BuildImage(ctx, &tc.ContainerRequest{
		FromDockerfile: tc.FromDockerfile{
			Context:        repoRoot,
			Dockerfile:     "tests/e2e/windows/Dockerfile",
			Repo:           "vfox-dotnet-e2e",
			Tag:            "windows",
			KeepImage:      true,
			BuildArgs:      map[string]*string{"BASE_IMAGE": &base},
			BuildLogWriter: os.Stdout,
		},
	})
	if err != nil {
		t.Fatalf("build image: %v", err)
	}
	return tag
}

func startContainer(t *testing.T, ctx context.Context, image string) tc.Container {
	t.Helper()
	ctr, err := tc.GenericContainer(ctx, tc.GenericContainerRequest{
		ContainerRequest: tc.ContainerRequest{
			Image: image,
			Name:  common.ContainerName("windows"),
		},
		Started: true,
	})
	if err != nil {
		t.Fatalf("start container: %v", err)
	}
	return ctr
}

// setupScript installs the pinned vfox from its release archive and adds the
// plugin packaged from the checked-out source. Keep the checksums in step
// with VFOX_VERSION.
const setupScript = `
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'aarch64' } else { 'x86_64' }
$sum = if ($arch -eq 'aarch64') { '67bf5c8b3bde5c1b3fc06dcaa460db9bb1dc9fc587b467d1dc96205377767465' } else { '1bbec8fffddbb62de0d93030c3f6203c69680662bc65257ca4a5e611cb607d0a' }
$version = '1.1.0'
$zip = Join-Path $env:TEMP 'vfox.zip'
$url = "https://github.com/version-fox/vfox/releases/download/v$version/vfox_${version}_windows_${arch}.zip"
curl.exe --retry 3 --retry-delay 5 --retry-all-errors --fail --silent --show-error --location --output $zip $url
if ($LASTEXITCODE -ne 0) { throw 'vfox download failed' }
if ((Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant() -ne $sum) { throw 'vfox checksum mismatch' }
$extract = Join-Path $env:TEMP 'vfox-extract'
New-Item -ItemType Directory -Force -Path $extract | Out-Null
Expand-Archive -Path $zip -DestinationPath $extract -Force
$found = Get-ChildItem -Path $extract -Recurse -Filter 'vfox.exe' | Select-Object -First 1
if ($null -eq $found) { throw 'vfox.exe not found in the release archive' }
Copy-Item -Path $found.FullName -Destination 'C:\e2e\vfox.exe'

$plugin = Join-Path $env:TEMP 'dotnet-plugin.zip'
Compress-Archive -Path 'C:\e2e\metadata.lua', 'C:\e2e\hooks', 'C:\e2e\lib' -DestinationPath $plugin -Force
vfox add dotnet --source $plugin
if ($LASTEXITCODE -ne 0) { throw 'vfox add dotnet failed' }
`

func setupVfox(t *testing.T, ctx context.Context, ctr tc.Container) {
	t.Helper()
	out := execOK(ctx, t, ctr, setupScript+`vfox --version`)
	t.Logf("PASS %s with the local dotnet plugin", strings.TrimSpace(common.StripANSI(out)))
}

func checkSearch(t *testing.T, ctx context.Context, ctr tc.Container, version string) {
	t.Helper()
	out := execRetry(ctx, t, ctr, "vfox search dotnet "+version, "vfox search dotnet "+pwshQuote(version))
	if !strings.Contains(common.StripANSI(out), " - ") {
		t.Fatalf("vfox search dotnet %s listed no versions\n--- output ---\n%s", version, out)
	}
	t.Logf("PASS vfox search dotnet %s lists versions", version)
}

func installDotnet(t *testing.T, ctx context.Context, ctr tc.Container, version string) string {
	t.Helper()
	out := execRetry(ctx, t, ctr, "vfox install dotnet@"+version, "vfox install dotnet@"+pwshQuote(version))
	installed := common.InstalledVersion(out)
	if !strings.HasPrefix(installed, common.MajorMinor(version)+".") {
		t.Fatalf("vfox install dotnet@%s installed %q\n--- output ---\n%s", version, installed, out)
	}
	if !strings.Contains(common.StripANSI(out), "Verifying checksum") {
		t.Fatalf("the download of dotnet@%s was not verified\n--- output ---\n%s", version, out)
	}
	t.Logf("PASS dotnet@%s installed as %s with a verified checksum", version, installed)
	return installed
}

func useDotnet(t *testing.T, ctx context.Context, ctr tc.Container, installed string) {
	t.Helper()
	execOK(ctx, t, ctr, activated("vfox use --global "+pwshQuote("dotnet@"+installed)))
}

func verifyToolchain(t *testing.T, ctx context.Context, ctr tc.Container, version, installed string) {
	t.Helper()
	root := execOK(ctx, t, ctr, dotnetScript(`$env:DOTNET_ROOT`))
	if strings.TrimSpace(common.StripANSI(root)) == "" {
		t.Fatal("DOTNET_ROOT is empty after vfox use")
	}
	out := execOK(ctx, t, ctr, dotnetScript("vfox current dotnet"))
	if !strings.Contains(common.StripANSI(out), installed) {
		t.Fatalf("vfox current dotnet does not report %s\n--- output ---\n%s", installed, out)
	}
	out = execRetry(ctx, t, ctr, "dotnet --version", dotnetScript("dotnet --version"))
	actual := strings.TrimSpace(common.StripANSI(out))
	if !strings.HasPrefix(actual, common.MajorMinor(version)+".") {
		t.Fatalf("dotnet --version = %q, want %s.*", actual, common.MajorMinor(version))
	}
	out = execOK(ctx, t, ctr, dotnetScript("dotnet --list-sdks"))
	if len(strings.TrimSpace(common.StripANSI(out))) == 0 {
		t.Fatal("dotnet --list-sdks listed no SDK")
	}
	t.Logf("PASS dotnet --version = %s; DOTNET_ROOT = %s", actual, strings.TrimSpace(root))
}

// verifyDetect links a synthetic SDK under ~/.dotnet and checks that vfox
// lists it. The SDK installed earlier lives under .vfox and is excluded.
func verifyDetect(t *testing.T, ctx context.Context, ctr tc.Container) {
	t.Helper()
	const script = `
$fake = Join-Path $env:USERPROFILE '.dotnet'
New-Item -ItemType Directory -Force -Path (Join-Path $fake 'sdk\6.0.428') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $fake 'shared\Microsoft.NETCore.App\6.0.36') | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $fake 'dotnet.exe') | Out-Null
`
	execOK(ctx, t, ctr, script)
	out := execOK(ctx, t, ctr, activated("vfox link --detect -y dotnet"))
	if !strings.Contains(out, "dotnet@6.0.36") || !strings.Contains(out, ".dotnet") {
		t.Fatalf("vfox link --detect did not report the synthetic SDK\n--- output ---\n%s", out)
	}
	out = execOK(ctx, t, ctr, "vfox list dotnet")
	if !strings.Contains(out, "linked") || !strings.Contains(out, ".dotnet") {
		t.Fatalf("the linked SDK is not listed\n--- output ---\n%s", out)
	}
	t.Log("PASS vfox link --detect found and linked a system SDK")
}
