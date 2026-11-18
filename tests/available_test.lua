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

local versions = plugin:Available({})
assert(#versions == 12, "expected three variants for each of four releases, got " .. #versions)

local byVersion = {}
for _, version in ipairs(versions) do
    byVersion[version.version] = version
end

local sdk = byVersion["8.0.34"]
assert(sdk, "SDK variant missing")
assert(sdk.note == "LTS - Security Patch")
assert(sdk.addition[1].name == "SDK")
assert(sdk.addition[1].version == "8.0.428")

local runtime = byVersion["8.0.34-runtime"]
assert(runtime, "Runtime variant missing")
assert(runtime.note == "Runtime - LTS - Security Patch")
assert(runtime.addition[1].name == "Runtime")
assert(runtime.addition[1].version == "8.0.34")

local aspnet = byVersion["8.0.34-aspnetcore"]
assert(aspnet, "ASP.NET Core Runtime variant missing")
assert(aspnet.note == "ASP.NET Core Runtime - LTS - Security Patch")
assert(aspnet.addition[1].name == "ASP.NET Core Runtime")

local prerelease = byVersion["9.0.0-rc.2-runtime"]
assert(prerelease, "prerelease Runtime variant missing")
assert(prerelease.note == "Runtime")

-- The ASP.NET variant must use the plain archive, not the composite archive
-- or the Windows hosting installer that appear earlier in the metadata.
assert(plugin:PreInstall({ version = "8.0.34-aspnetcore" }).sha512 == "aspnet-hash-34")

print("PASS: " .. #versions .. " available variants across all channels")
