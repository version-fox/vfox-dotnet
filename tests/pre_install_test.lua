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

local function fixture(name)
    local file = assert(io.open(RUNTIME.pluginDirPath .. "/tests/fixtures/" .. name, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    http = function(request)
        local url = request.url
        if url:find("releases-index.json", 1, true) then
            return { status_code = 200, body = fixture("releases-index.json"), headers = {} }
        elseif url:find("/9.0/releases.json", 1, true) then
            return { status_code = 200, body = fixture("9.0-releases.json"), headers = {} }
        elseif url:find("/8.0/releases.json", 1, true) then
            return { status_code = 200, body = fixture("8.0-releases.json"), headers = {} }
        elseif url:find("/80.0/releases.json", 1, true) then
            -- The index fixture also lists a 80.0 channel. It has no releases, and
            -- it must not be mistaken for 8.0.
            return { status_code = 200, body = '{"release-type":"sts","releases":[]}', headers = {} }
        end
        return { status_code = 404, body = "", headers = {} }
    end,
})

local function resolve(version)
    return plugin:PreInstall({ version = version })
end

-- A version that matches no release must raise an error that names it. An empty
-- table would be recorded by vfox as a successful install with no version.
local function expectUnavailable(version)
    local ok, err = pcall(resolve, version)
    assert(not ok, version .. " must not resolve to a release")
    local expected = "dotnet version " .. version .. " is not available for linux-x64"
    assert(string.find(tostring(err), expected, 1, true), "unexpected error: " .. tostring(err))
end

-- Exact SDK versions keep the historical (unsuffixed) behaviour.
local sdk = resolve("8.0.8")
assert(sdk.version == "8.0.8")
assert(sdk.sha512 == "sdk-hash-8")

-- Partial versions resolve to the newest release in the channel.
assert(resolve("8").version == "8.0.34")
assert(resolve("8.0").version == "8.0.34")
assert(resolve("9").version == "9.0.0")
assert(resolve("latest").version == "9.0.0")

-- A numeric prefix must not match an unrelated, longer patch number.
expectUnavailable("8.0.3")

-- A channel prefix must not match an unrelated channel ("8" vs "80.0").
assert(resolve("8").url:find("Sdk/8.0.428/", 1, true))

-- Runtime and ASP.NET Core Runtime variants select their own archives.
local runtime = resolve("8.0.8-runtime")
assert(runtime.version == "8.0.8-runtime")
assert(runtime.sha512 == "runtime-hash-8")
assert(resolve("8-runtime").version == "8.0.34-runtime")
assert(resolve("8.0-runtime").sha512 == "runtime-hash-34")

local aspnet = resolve("8.0.8-aspnetcore")
assert(aspnet.version == "8.0.8-aspnetcore")
assert(aspnet.sha512 == "aspnet-hash-8")
assert(resolve("8-aspnetcore").version == "8.0.34-aspnetcore")

-- Prerelease versions may themselves contain hyphens.
assert(resolve("9.0.0-rc.2-runtime").sha512 == "runtime-hash-rc2")
assert(resolve("9.0.0-rc.2-aspnetcore").sha512 == "aspnet-hash-rc2")

-- An unknown variant or an unknown channel fails, rather than installing an SDK or an empty version.
expectUnavailable("8.0.8-jre")
expectUnavailable("99")

print("PASS: version resolution across variants and partial versions")
