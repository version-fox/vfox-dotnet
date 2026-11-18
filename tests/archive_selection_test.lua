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

local INDEX_URL = "https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json"
local RELEASES_URL = "https://builds.dotnet.microsoft.com/dotnet/release-metadata/10.0/releases.json"

local function archive(name, rid, hash)
    return { rid = rid, url = "https://example.invalid/" .. name, hash = hash }
end

-- The 10.0.15 entry as releases.json lists it, trimmed to linux-x64. The runtime
-- component names the apphost pack before the runtime; that order made "-runtime"
-- install the apphost pack (issue #18). The one deliberate difference from the
-- metadata: the ASP.NET Core Runtime component lists its targeting pack first,
-- where releases.json lists it last, so the archive must be chosen by its name
-- rather than by its position.
local index = {
    ["releases-index"] = {
        { ["channel-version"] = "10.0", ["release-type"] = "lts", ["releases.json"] = RELEASES_URL },
    },
}

local channel = {
    ["release-type"] = "lts",
    releases = {
        {
            ["release-version"] = "10.0.15",
            security = true,
            sdk = {
                version = "10.0.404",
                files = {
                    archive("dotnet-sdk-10.0.404-linux-x64.tar.gz", "linux-x64", "sdk-hash"),
                },
            },
            runtime = {
                version = "10.0.15",
                files = {
                    archive("dotnet-apphost-pack-10.0.15-linux-x64.tar.gz", "linux-x64", "apphost-hash"),
                    archive("dotnet-runtime-10.0.15-linux-x64.tar.gz", "linux-x64", "runtime-hash"),
                },
            },
            ["aspnetcore-runtime"] = {
                version = "10.0.15",
                files = {
                    archive("aspnetcore-targeting-pack-10.0.15-linux-x64.tar.gz", "linux-x64", "targeting-hash"),
                    archive("aspnetcore-runtime-composite-10.0.15-linux-x64.tar.gz", "linux-x64", "composite-hash"),
                    archive("aspnetcore-runtime-10.0.15-linux-x64.tar.gz", "linux-x64", "aspnet-hash"),
                },
            },
        },
    },
}

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    http = function(request)
        if request.url == INDEX_URL then
            return { status_code = 200, body = json.encode(index), headers = {} }
        elseif request.url == RELEASES_URL then
            return { status_code = 200, body = json.encode(channel), headers = {} }
        end
        return { status_code = 404, body = "", headers = {} }
    end,
})

-- "-runtime" installs the runtime archive, not the apphost pack listed before it.
local runtime = plugin:PreInstall({ version = "10.0.15-runtime" })
assert(runtime.version == "10.0.15-runtime", "version: " .. tostring(runtime.version))
assert(
    runtime.url == "https://example.invalid/dotnet-runtime-10.0.15-linux-x64.tar.gz",
    "url: " .. tostring(runtime.url)
)
assert(runtime.sha512 == "runtime-hash", "sha512: " .. tostring(runtime.sha512))

-- A partial version selects the same archive.
assert(plugin:PreInstall({ version = "10-runtime" }).sha512 == "runtime-hash")

-- The other variants are chosen by name as well.
assert(plugin:PreInstall({ version = "10.0.15-aspnetcore" }).sha512 == "aspnet-hash")
assert(plugin:PreInstall({ version = "10.0.15" }).sha512 == "sdk-hash")

-- Each variant is listed once, and installing any listed version never fetches an apphost pack.
local versions = plugin:Available({})
assert(#versions == 3, "expected one entry per variant, got " .. #versions)
for _, listed in ipairs(versions) do
    local installed = plugin:PreInstall({ version = listed.version })
    assert(not installed.url:find("apphost", 1, true), "apphost pack installed for " .. listed.version)
end

print("PASS: variant archives are selected by name, not by position")
