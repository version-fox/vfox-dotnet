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

// Package linux is the Ubuntu container E2E suite, driven from Go through
// testcontainers-go. TestE2E builds the image once, starts one long-lived
// container and drives setup -> search -> install -> use -> verify -> detect
// through exec calls, asserting in Go.
package linux

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

// buildImage replicates `docker build --file tests/e2e/linux/Dockerfile
// --tag vfox-dotnet-e2e:linux <repoRoot>`.
func buildImage(t *testing.T, ctx context.Context, repoRoot string) string {
	t.Helper()
	provider, err := tc.NewDockerProvider()
	if err != nil {
		t.Fatalf("new docker provider: %v", err)
	}
	t.Cleanup(func() { _ = provider.Close() })
	tag, err := provider.BuildImage(ctx, &tc.ContainerRequest{
		FromDockerfile: tc.FromDockerfile{
			Context:        repoRoot,
			Dockerfile:     "tests/e2e/linux/Dockerfile",
			Repo:           "vfox-dotnet-e2e",
			Tag:            "linux",
			KeepImage:      true,
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
			Name:  common.ContainerName("linux"),
		},
		Started: true,
	})
	if err != nil {
		t.Fatalf("start container: %v", err)
	}
	return ctr
}

// setupVfox packages the checked-out plugin and registers it as a local
// dotnet plugin, so the source under test is what gets installed.
func setupVfox(t *testing.T, ctx context.Context, ctr tc.Container) {
	t.Helper()
	out := execOK(ctx, t, ctr, "vfox --version")
	execOK(ctx, t, ctr, "cd /e2e && zip -q -r /tmp/dotnet-plugin.zip metadata.lua hooks lib && vfox add dotnet --source /tmp/dotnet-plugin.zip")
	t.Logf("PASS %s with the local dotnet plugin", strings.TrimSpace(common.StripANSI(out)))
}

func checkSearch(t *testing.T, ctx context.Context, ctr tc.Container, version string) {
	t.Helper()
	out := execRetry(ctx, t, ctr, "vfox search dotnet "+version, "vfox search dotnet "+version)
	if !strings.Contains(common.StripANSI(out), " - ") {
		t.Fatalf("vfox search dotnet %s listed no versions\n--- output ---\n%s", version, out)
	}
	t.Logf("PASS vfox search dotnet %s lists versions", version)
}

// installDotnet installs the channel and returns the release vfox recorded,
// asserting the download was verified against the checksum in the metadata.
func installDotnet(t *testing.T, ctx context.Context, ctr tc.Container, version string) string {
	t.Helper()
	out := execRetry(ctx, t, ctr, "vfox install dotnet@"+version, "vfox install dotnet@"+version)
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
	execOK(ctx, t, ctr, activated("vfox use --global dotnet@"+installed))
}

// dotnetScript applies the vfox environment inside a fresh shell, which has
// no interactive prompt to run the hook for us.
func dotnetScript(command string) string {
	return activated(`eval "$(vfox env -s bash)"; ` + command)
}

func verifyToolchain(t *testing.T, ctx context.Context, ctr tc.Container, version, installed string) {
	t.Helper()
	root := execOK(ctx, t, ctr, dotnetScript(`printf '%s' "$DOTNET_ROOT"`))
	if strings.TrimSpace(common.StripANSI(root)) == "" {
		t.Fatal("DOTNET_ROOT is empty after vfox use")
	}
	execOK(ctx, t, ctr, dotnetScript(`test -d "$DOTNET_ROOT"`))
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
	t.Logf("PASS dotnet --version = %s; DOTNET_ROOT = %s", actual, root)
}

// verifyDetect places a synthetic SDK home in a system location, asks vfox to
// detect it, and selects the linked version. The SDK installed earlier lives
// under .vfox and is deliberately excluded from detection.
func verifyDetect(t *testing.T, ctx context.Context, ctr tc.Container) {
	t.Helper()
	execOK(ctx, t, ctr, `mkdir -p /opt/dotnet/sdk/6.0.428 /opt/dotnet/shared/Microsoft.NETCore.App/6.0.36 `+
		`&& printf '#!/bin/sh\nif [ "$1" = "--version" ]; then echo 6.0.428; else echo fake; fi\n' > /opt/dotnet/dotnet `+
		`&& chmod +x /opt/dotnet/dotnet`)
	out := execOK(ctx, t, ctr, activated("vfox link --detect -y dotnet"))
	if !strings.Contains(out, "dotnet@6.0.36") || !strings.Contains(out, "/opt/dotnet") {
		t.Fatalf("vfox link --detect did not report the synthetic SDK\n--- output ---\n%s", out)
	}
	out = execOK(ctx, t, ctr, "vfox list dotnet")
	if !strings.Contains(out, "linked") || !strings.Contains(out, "/opt/dotnet") {
		t.Fatalf("the linked SDK is not listed\n--- output ---\n%s", out)
	}
	execOK(ctx, t, ctr, activated("vfox use --global dotnet@6.0.36"))
	out = execOK(ctx, t, ctr, dotnetScript("dotnet --version"))
	if got := strings.TrimSpace(common.StripANSI(out)); got != "6.0.428" {
		t.Fatalf("linked dotnet --version = %q, want 6.0.428", got)
	}
	t.Log("PASS vfox link --detect found, linked and used a system SDK")
}
