-- Copyright 2026 Han Li and contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local test = require("vfox.test")
local json = require("json")

local RELEASES = "https://builds.dotnet.microsoft.com/dotnet/release-metadata/8.0/releases.json"

-- A channel's releases.json as the plugin reads it on Linux x64. Only the
-- archive for the runner's RID is kept; installers and other RIDs are dropped.
local body = {
    ["release-type"] = "lts",
    releases = {
        {
            ["release-version"] = "8.0.34",
            security = true,
            sdk = {
                version = "8.0.428",
                files = {
                    {
                        rid = "linux-x64",
                        url = "https://example.invalid/dotnet-sdk-8.0.428-linux-x64.tar.gz",
                        hash = "sha512-a",
                    },
                    { rid = "linux-x64", url = "https://example.invalid/dotnet-installer.sh" },
                    {
                        rid = "win-x64",
                        url = "https://example.invalid/dotnet-sdk-8.0.428-win-x64.zip",
                        hash = "sha512-b",
                    },
                },
            },
        },
        {
            ["release-version"] = "8.0.33",
            security = false,
            sdk = {
                version = "8.0.419",
                files = {
                    {
                        rid = "linux-arm64",
                        url = "https://example.invalid/dotnet-sdk-8.0.419-linux-arm64.tar.gz",
                        hash = "sha512-c",
                    },
                },
            },
        },
        {
            ["release-version"] = "8.0.32",
            security = false,
            sdk = { version = "8.0.410", files = {} },
        },
    },
}

local requests = {}
local answer = function(request)
    requests[#requests + 1] = request.url
    return { status_code = 200, body = json.encode(body) }
end

local plugin = test.load({ os = "linux", arch = "amd64", http = answer })
local util = require("util")

local got = util:getAvailableByChannelReleaseUrl(RELEASES)
assert(requests[1] == RELEASES, "unexpected request: " .. tostring(requests[1]))
assert(#got == 1, "expected one build for linux/x64, got " .. #got)
local build = got[1]
assert(build.version == "8.0.34", "version: " .. tostring(build.version))
assert(build.url == "https://example.invalid/dotnet-sdk-8.0.428-linux-x64.tar.gz", "url: " .. tostring(build.url))
assert(build.sha512 == "sha512-a", "sha512: " .. tostring(build.sha512))
assert(build.note == "LTS - Security Patch", "note: " .. tostring(build.note))
assert(build.addition[1].name == "SDK", "addition name: " .. tostring(build.addition[1].name))
assert(build.addition[1].version == "8.0.428", "addition version: " .. tostring(build.addition[1].version))

print("PASS: channel releases are filtered to the runner's RID")
