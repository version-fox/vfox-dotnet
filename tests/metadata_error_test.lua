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

local INDEX_URL = "https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json"
local CHANNEL_10 = "https://builds.dotnet.microsoft.com/dotnet/release-metadata/10.0/releases.json"
local CHANNEL_11 = "https://builds.dotnet.microsoft.com/dotnet/release-metadata/11.0/releases.json"

local INDEX = [[
{
  "releases-index": [
    { "channel-version": "11.0", "release-type": "sts", "releases.json": "https://builds.dotnet.microsoft.com/dotnet/release-metadata/11.0/releases.json" },
    { "channel-version": "10.0", "release-type": "lts", "releases.json": "https://builds.dotnet.microsoft.com/dotnet/release-metadata/10.0/releases.json" }
  ]
}
]]

local TEN = [[
{
  "release-type": "lts",
  "releases": [
    {
      "release-version": "10.0.15",
      "security": true,
      "sdk": { "version": "10.0.404", "files": [ { "rid": "linux-x64", "url": "https://example.invalid/dotnet-sdk-10.0.404-linux-x64.tar.gz", "hash": "sdk-hash" } ] },
      "runtime": { "version": "10.0.15", "files": [ { "rid": "linux-x64", "url": "https://example.invalid/dotnet-runtime-10.0.15-linux-x64.tar.gz", "hash": "runtime-hash" } ] },
      "aspnetcore-runtime": { "version": "10.0.15", "files": [ { "rid": "linux-x64", "url": "https://example.invalid/aspnetcore-runtime-10.0.15-linux-x64.tar.gz", "hash": "aspnet-hash" } ] }
    }
  ]
}
]]

-- One load per file: the 11.0 channel fails for every case below.
local plugin = test.load({
    os = "linux",
    arch = "amd64",
    http = function(request)
        if request.url == INDEX_URL then
            return { status_code = 200, body = INDEX, headers = {} }
        elseif request.url == CHANNEL_10 then
            return { status_code = 200, body = TEN, headers = {} }
        elseif request.url == CHANNEL_11 then
            return { status_code = 500, body = "internal error", headers = {} }
        end
        return { status_code = 404, body = "", headers = {} }
    end,
})

-- A channel whose metadata request fails must stop the listing, not disappear
-- from it: the error names the channel and the status.
local ok, err = pcall(plugin.Available, plugin, {})
assert(not ok, "listing succeeded although the 11.0 channel failed")
assert(tostring(err):find(CHANNEL_11, 1, true), "error does not name the channel: " .. tostring(err))
assert(tostring(err):find("500", 1, true), "error does not give the status: " .. tostring(err))

-- latest must not quietly resolve to the 10.0 channel while 11.0 is unknown.
ok, err = pcall(plugin.PreInstall, plugin, { version = "latest" })
assert(not ok, "latest resolved while the 11.0 channel failed")
assert(tostring(err):find(CHANNEL_11, 1, true), "latest error does not name the channel: " .. tostring(err))

-- Installing a version needs only its own channel, so the unrelated failure does not block it.
assert(plugin:PreInstall({ version = "10.0.15" }).sha512 == "sdk-hash")
assert(plugin:PreInstall({ version = "10.0.15-runtime" }).sha512 == "runtime-hash")

print("PASS: a failed channel stops the listing and latest instead of dropping the channel")
