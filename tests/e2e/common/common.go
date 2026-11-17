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

// Package common holds logic shared by the Linux and Windows container
// suites: the version under test, retrying flaky container calls and
// parsing vfox output. Container interaction stays in the platform packages.
package common

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"regexp"
	"strings"
	"testing"
	"time"
)

// DefaultVersion is the .NET channel installed when DOTNET_VERSION is unset.
const DefaultVersion = "8.0"

// Version returns the channel under test, honouring $DOTNET_VERSION.
func Version() string {
	if v := strings.TrimSpace(os.Getenv("DOTNET_VERSION")); v != "" {
		return v
	}
	return DefaultVersion
}

// MajorMinor returns the leading "major.minor" of a version. The .NET release
// vfox selects (8.0.34) may carry a newer SDK number (8.0.428), so checks
// compare only these two components.
func MajorMinor(version string) string {
	parts := strings.SplitN(version, ".", 3)
	if len(parts) < 2 {
		return version
	}
	return parts[0] + "." + parts[1]
}

// RetryAttempts caps retries; honours $E2E_RETRY_ATTEMPTS (default 3).
func RetryAttempts() int {
	if v := strings.TrimSpace(os.Getenv("E2E_RETRY_ATTEMPTS")); v != "" {
		var n int
		if _, err := fmt.Sscanf(v, "%d", &n); err == nil && n >= 1 {
			return n
		}
	}
	return 3
}

// Retry runs run until it reports exit code 0, waiting 10s, 20s, ... between
// attempts. Downloads and daemon calls in throwaway containers flake, so all
// network-touching calls go through it. It returns the last output on success
// and fatals, with that output attached, when the budget is exhausted.
func Retry(ctx context.Context, t *testing.T, label string, run func() (int, string)) string {
	t.Helper()
	max := RetryAttempts()
	var out string
	var code int
	for attempt := 1; attempt <= max; attempt++ {
		if err := ctx.Err(); err != nil {
			t.Fatalf("%s: %v", label, err)
		}
		code, out = run()
		if code == 0 {
			return out
		}
		if attempt < max {
			t.Logf("retrying %s: attempt %d exited %d; output:\n%s", label, attempt, code, out)
			select {
			case <-ctx.Done():
				t.Fatalf("%s: %v", label, ctx.Err())
			case <-time.After(time.Duration(10*attempt) * time.Second):
			}
		}
	}
	t.Fatalf("%s failed after %d attempt(s) (exit %d)\n--- output ---\n%s", label, max, code, out)
	return out
}

var ansiEscape = regexp.MustCompile(`\x1b\[[0-9;]*m`)

// StripANSI removes the SGR colour sequences vfox writes even to a pipe.
func StripANSI(s string) string {
	return ansiEscape.ReplaceAllString(s, "")
}

// InstalledVersion extracts the version vfox recorded from `vfox install`
// output, e.g. 8.0.34 for `Install dotnet@8.0.34 success!`.
func InstalledVersion(output string) string {
	re := regexp.MustCompile(`Install dotnet@(\S+) success!`)
	if m := re.FindStringSubmatch(StripANSI(output)); m != nil {
		return m[1]
	}
	return ""
}

// ListedVersions extracts installed versions from `vfox list dotnet` output.
func ListedVersions(output string) []string {
	re := regexp.MustCompile(`^-> (\S+)`)
	var versions []string
	for _, line := range strings.Split(StripANSI(output), "\n") {
		if m := re.FindStringSubmatch(strings.TrimRight(line, "\r")); m != nil {
			versions = append(versions, m[1])
		}
	}
	return versions
}

// ContainerName returns a unique container name: greppable prefix, random
// suffix so leftovers from killed runs cannot clash.
func ContainerName(slug string) string {
	var b [4]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "vfox-dotnet-e2e-" + slug + "-" + fmt.Sprint(time.Now().UnixNano())
	}
	return "vfox-dotnet-e2e-" + slug + "-" + hex.EncodeToString(b[:])
}
