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

// Package e2e is the single Go module root of the container E2E suites.
//
// This directory holds no test logic, only the module definition
// (go.mod/go.sum) and the shared helpers in common. The suites live in:
//
//   - linux: the Ubuntu container suite, run on ubuntu-latest in CI;
//   - windows: the Windows container suite, run on windows-latest in CI.
//
// Both build their Dockerfile, start one long-lived container and drive
// setup -> install -> use -> verify -> detect through exec calls, asserting
// in Go. Pure unit tests (no containers) run with `go test -short ./...`.
package e2e
