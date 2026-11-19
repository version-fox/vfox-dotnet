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

local BASE = "https://builds.dotnet.microsoft.com/dotnet/release-metadata/"

--- One archive of a release component on linux-x64, named the way Microsoft names it.
local function archive(name, hash)
    return { rid = "linux-x64", url = "https://example.invalid/" .. name, hash = hash }
end

-- The 2.0 channel as Microsoft lists the linux-x64 files, trimmed. The ASP.NET Core
-- Runtime of 2.0.3 and 2.0.5 to 2.0.9 is a dotnet-hosting archive, and the
-- aspnetcore-store archive beside it is not the runtime. The hosting archive of
-- the hosting archives of 2.0.3 and 2.0.8 have an empty hash, and 2.0.4 has no
-- ASP.NET Core Runtime (null).
local releases = {
    {
        ["release-version"] = "2.0.9",
        security = true,
        sdk = { version = "2.0.9", files = { archive("dotnet-sdk-2.0.9-linux-x64.tar.gz", "sdk-9") } },
        -- The store archive comes first, so only its name keeps it from being taken.
        ["aspnetcore-runtime"] = {
            version = "2.0.9",
            files = {
                archive("aspnetcore-store-2.0.9-linux-x64.tar.gz", "store-9"),
                archive("dotnet-hosting-2.0.9-linux-x64.tar.gz", "hosting-9"),
            },
        },
    },
    {
        ["release-version"] = "2.0.8",
        sdk = { version = "2.0.8", files = { archive("dotnet-sdk-2.0.8-linux-x64.tar.gz", "sdk-8") } },
        ["aspnetcore-runtime"] = {
            version = "2.0.8",
            files = {
                archive("aspnetcore-store-2.0.8-linux-x64.tar.gz", "store-8"),
                archive("dotnet-hosting-2.0.8-linux-x64.tar.gz", ""),
            },
        },
    },
    {
        -- No ASP.NET Core Runtime component: the metadata has null here.
        ["release-version"] = "2.0.4",
        sdk = { version = "2.0.4", files = { archive("dotnet-sdk-2.0.4-linux-x64.tar.gz", "sdk-4") } },
    },
    {
        ["release-version"] = "2.0.3",
        sdk = { version = "2.0.3", files = { archive("dotnet-sdk-2.0.3-linux-x64.tar.gz", "sdk-3") } },
        ["aspnetcore-runtime"] = {
            version = "2.0.3",
            files = { archive("dotnet-hosting-2.0.3-linux-x64.tar.gz", "") },
        },
    },
}

local INDEX = json.encode({
    ["releases-index"] = {
        { ["channel-version"] = "2.0", ["release-type"] = "sts", ["releases.json"] = BASE .. "2.0/releases.json" },
    },
})

local bodies = {
    [BASE .. "releases-index.json"] = INDEX,
    [BASE .. "2.0/releases.json"] = json.encode({ ["release-type"] = "sts", releases = releases }),
}

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    http = function(request)
        local body = bodies[request.url]
        if body == nil then
            return { status_code = 404, body = "", headers = {} }
        end
        return { status_code = 200, body = body, headers = {} }
    end,
})

local function resolve(version)
    return plugin:PreInstall({ version = version })
end

-- A version that matches no release must raise an error that names it.
local function expectUnavailable(version)
    local ok, err = pcall(resolve, version)
    assert(not ok, version .. " must not resolve to a release")
    local expected = "dotnet version " .. version .. " is not available for linux-x64"
    assert(string.find(tostring(err), expected, 1, true), "unexpected error: " .. tostring(err))
end

-- The ASP.NET Core Runtime of 2.0.9 is its dotnet-hosting archive, although the
-- aspnetcore-store archive is listed before it.
local runtime = resolve("2.0.9-aspnetcore")
assert(runtime.version == "2.0.9-aspnetcore", "version: " .. tostring(runtime.version))
assert(runtime.url == "https://example.invalid/dotnet-hosting-2.0.9-linux-x64.tar.gz", "url: " .. tostring(runtime.url))
assert(runtime.sha512 == "hosting-9", "sha512: " .. tostring(runtime.sha512))

-- A partial version selects the same archive.
assert(resolve("2.0-aspnetcore").sha512 == "hosting-9", "2.0-aspnetcore must select 2.0.9")

-- 2.0.8 and 2.0.3 have only archives without a SHA-512, which vfox would install
-- unchecked, and 2.0.4 has no ASP.NET Core Runtime. None of them is offered.
expectUnavailable("2.0.8-aspnetcore")
expectUnavailable("2.0.4-aspnetcore")
expectUnavailable("2.0.3-aspnetcore")

-- The SDK of every release is listed, and only the ASP.NET Core Runtime of 2.0.9.
local listed = {}
local versions = plugin:Available({})
for _, version in ipairs(versions) do
    listed[version.version] = true
end
assert(#versions == 5, "expected 5 variants, got " .. #versions)
for _, version in ipairs({ "2.0.9", "2.0.8", "2.0.4", "2.0.3", "2.0.9-aspnetcore" }) do
    assert(listed[version], version .. " is not listed")
end
assert(not listed["2.0.8-aspnetcore"], "2.0.8-aspnetcore is listed without a SHA-512")
assert(not listed["2.0.3-aspnetcore"], "2.0.3-aspnetcore is listed without a SHA-512")
assert(not listed["2.0.4-aspnetcore"], "2.0.4-aspnetcore is listed without a runtime")

print("PASS: the 2.0 ASP.NET Core Runtime is its dotnet-hosting archive, listed only with a SHA-512")
