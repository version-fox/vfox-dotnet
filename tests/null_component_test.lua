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
local RELEASES_URL = "https://builds.dotnet.microsoft.com/dotnet/release-metadata/1.0/releases.json"

local INDEX = [[
{
  "releases-index": [
    {
      "channel-version": "1.0",
      "release-type": "sts",
      "releases.json": "https://builds.dotnet.microsoft.com/dotnet/release-metadata/1.0/releases.json"
    }
  ]
}
]]

-- A channel as the official metadata writes it. Every release lists the
-- ASP.NET Core Runtime as null, and 1.0.12 also lists its runtime as null.
local RELEASES = [[
{
  "release-type": "sts",
  "releases": [
    {
      "release-version": "1.0.13",
      "security": false,
      "sdk": {
        "version": "1.1.14",
        "files": [
          { "rid": "linux-x64", "url": "https://example.invalid/dotnet-sdk-1.0.13-linux-x64.tar.gz", "hash": "sdk-hash" }
        ]
      },
      "runtime": {
        "version": "1.0.13",
        "files": [
          { "rid": "linux-x64", "url": "https://example.invalid/dotnet-runtime-1.0.13-linux-x64.tar.gz", "hash": "runtime-hash" }
        ]
      },
      "aspnetcore-runtime": null
    },
    {
      "release-version": "1.0.12",
      "security": false,
      "sdk": {
        "version": "1.1.13",
        "files": [
          { "rid": "linux-x64", "url": "https://example.invalid/dotnet-sdk-1.0.12-linux-x64.tar.gz", "hash": "sdk-hash-12" }
        ]
      },
      "runtime": null,
      "aspnetcore-runtime": null
    }
  ]
}
]]

-- vfox decodes a JSON null to nil, which would hide the crash here. mise decodes
-- it to a userdata, which is not nil, so the plugin reached `component.files`
-- and failed (issue #17). Hand the plugin a non-table value for each component
-- the fixture leaves out, as mise delivers a null.
local decode = json.decode
json.decode = function(text)
    local body = decode(text)
    for _, release in ipairs(body.releases or {}) do
        for _, field in ipairs({ "runtime", "aspnetcore-runtime" }) do
            if release[field] == nil then
                release[field] = true
            end
        end
    end
    return body
end

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    http = function(request)
        if request.url == INDEX_URL then
            return { status_code = 200, body = INDEX, headers = {} }
        elseif request.url == RELEASES_URL then
            return { status_code = 200, body = RELEASES, headers = {} }
        end
        return { status_code = 404, body = "", headers = {} }
    end,
})

-- Listing skips the null components instead of failing the whole list.
local versions = plugin:Available({})
local listed = {}
for _, version in ipairs(versions) do
    listed[version.version] = true
end
assert(#versions == 3, "expected the SDK and runtime of 1.0.13 and the SDK of 1.0.12, got " .. #versions)
assert(listed["1.0.13"], "SDK of 1.0.13 missing")
assert(listed["1.0.13-runtime"], "runtime of 1.0.13 missing")
assert(listed["1.0.12"], "SDK of 1.0.12 missing")
assert(not listed["1.0.13-aspnetcore"], "null ASP.NET Core Runtime was listed")
assert(not listed["1.0.12-runtime"], "null runtime of 1.0.12 was listed")

-- Variants that exist in the same channel still install.
assert(plugin:PreInstall({ version = "1.0.13-runtime" }).sha512 == "runtime-hash")
assert(plugin:PreInstall({ version = "1.0.13" }).sha512 == "sdk-hash")

print("PASS: null release components are skipped")
