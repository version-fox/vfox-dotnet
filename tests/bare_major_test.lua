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

--- A release with one archive per variant on linux-x64.
local function release(version)
    local function archive(prefix)
        return {
            rid = "linux-x64",
            url = "https://example.invalid/" .. prefix .. version .. "-linux-x64.tar.gz",
            hash = prefix .. version,
        }
    end
    return {
        ["release-version"] = version,
        sdk = { version = version, files = { archive("dotnet-sdk-") } },
        runtime = { version = version, files = { archive("dotnet-runtime-") } },
        ["aspnetcore-runtime"] = { version = version, files = { archive("aspnetcore-runtime-") } },
    }
end

--- The releases.json of one channel, releases listed newest first as Microsoft lists them.
local function channel(releases)
    return json.encode({ ["release-type"] = "sts", releases = releases })
end

--- One entry of releases-index.json.
local function indexEntry(channelVersion)
    return {
        ["channel-version"] = channelVersion,
        ["release-type"] = "sts",
        ["releases.json"] = BASE .. channelVersion .. "/releases.json",
    }
end

-- The index lists 2.1 before 2.2, as Microsoft does. The 10.0 channel is listed
-- too, so a bare "1" is also checked against a major that starts with the same digit.
local INDEX = json.encode({
    ["releases-index"] = {
        indexEntry("10.0"),
        indexEntry("2.1"),
        indexEntry("2.2"),
        indexEntry("2.0"),
        indexEntry("1.1"),
    },
})

local bodies = {
    [BASE .. "releases-index.json"] = INDEX,
    [BASE .. "10.0/releases.json"] = channel({ release("10.0.2") }),
    [BASE .. "2.1/releases.json"] = channel({ release("2.1.30"), release("2.1.29") }),
    [BASE .. "2.2/releases.json"] = channel({ release("2.2.8"), release("2.2.7") }),
    [BASE .. "2.0/releases.json"] = channel({ release("2.0.9") }),
    [BASE .. "1.1/releases.json"] = channel({ release("1.1.13") }),
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

-- A bare major covers every channel of that major. 2.1 is listed first in the
-- index, but 2.2 is the newer channel, so its newest stable release wins.
local sdk = resolve("2")
assert(sdk.version == "2.2.8", "2 must resolve to 2.2.8, got " .. tostring(sdk.version))
assert(sdk.url == "https://example.invalid/dotnet-sdk-2.2.8-linux-x64.tar.gz", "url: " .. tostring(sdk.url))
assert(resolve("2-runtime").version == "2.2.8-runtime", "2-runtime must resolve to 2.2.8-runtime")
assert(resolve("2-aspnetcore").version == "2.2.8-aspnetcore", "2-aspnetcore must resolve to 2.2.8-aspnetcore")

-- A full channel covers only itself.
assert(resolve("2.1").version == "2.1.30", "2.1 must resolve to 2.1.30")
assert(resolve("2.0").version == "2.0.9", "2.0 must resolve to 2.0.9")

-- A bare "1" covers 1.1 but not 10.0, which only starts with the same digit.
assert(resolve("1").version == "1.1.13", "1 must not cover the 10.0 channel")

print("PASS: a bare major resolves to the newest stable release of its channels")
