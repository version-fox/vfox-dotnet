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

--- One archive of a release component, named the way the plugin looks for it on linux-x64.
local function file(archive, version)
    return {
        rid = "linux-x64",
        url = "https://example.invalid/" .. archive .. version .. "-linux-x64.tar.gz",
        hash = archive .. version,
    }
end

--- One release with the SDK, runtime and ASP.NET Core Runtime archives the plugin reads.
local function release(version)
    return {
        ["release-version"] = version,
        sdk = { version = version, files = { file("dotnet-sdk-", version) } },
        runtime = { version = version, files = { file("dotnet-runtime-", version) } },
        ["aspnetcore-runtime"] = { version = version, files = { file("aspnetcore-runtime-", version) } },
    }
end

--- The releases.json of one channel, releases listed newest first as Microsoft lists them.
local function channel(releases)
    return json.encode({ ["release-type"] = "sts", releases = releases })
end

-- The newest channel is 12.0, which has only previews so far.
local INDEX = [[
{
  "releases-index": [
    { "channel-version": "12.0", "release-type": "sts", "releases.json": "https://builds.dotnet.microsoft.com/dotnet/release-metadata/12.0/releases.json" },
    { "channel-version": "11.0", "release-type": "sts", "releases.json": "https://builds.dotnet.microsoft.com/dotnet/release-metadata/11.0/releases.json" }
  ]
}
]]

local bodies = {
    [BASE .. "releases-index.json"] = INDEX,
    [BASE .. "12.0/releases.json"] = channel({ release("12.0.0-preview.1") }),
    -- A preview listed above the stable release of its own channel.
    [BASE .. "11.0/releases.json"] = channel({ release("11.0.1-rc.1"), release("11.0.0") }),
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

-- A partial version takes the newest stable release, not a preview listed above it.
assert(resolve("11").version == "11.0.0", "11 must not pick the 11.0.1-rc.1 preview")
assert(resolve("11.0").version == "11.0.0", "11.0 must not pick the 11.0.1-rc.1 preview")
assert(resolve("11-runtime").version == "11.0.0-runtime", "the runtime variant follows the same rule")

-- An exact version still installs a preview.
assert(resolve("11.0.1-rc.1").version == "11.0.1-rc.1", "an exact preview must still resolve")

-- A channel with no stable release yet resolves to its newest preview.
assert(resolve("12").version == "12.0.0-preview.1", "12 has only previews")
assert(resolve("12.0").version == "12.0.0-preview.1", "12.0 has only previews")

-- latest skips every preview while a stable release is listed.
assert(resolve("latest").version == "11.0.0", "latest must skip the 12.0 and 11.0.1 previews")

print("PASS: partial versions and latest prefer the newest stable release")
