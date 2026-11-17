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
    os = "darwin",
    arch = "arm64",
    http = function(request)
        local url = request.url
        if url:find("releases-index.json", 1, true) then
            return { status_code = 200, body = fixture("releases-index.json"), headers = {} }
        elseif url:find("/8.0/releases.json", 1, true) then
            return { status_code = 200, body = fixture("8.0-releases.json"), headers = {} }
        end
        return { status_code = 404, body = "", headers = {} }
    end,
})

-- darwin/arm64 maps to the osx-arm64 runtime identifier.
assert(plugin:PreInstall({ version = "8.0.34-runtime" }).sha512 == "runtime-osx-hash-34")
assert(plugin:PreInstall({ version = "8.0.34-aspnetcore" }).sha512 == "aspnet-osx-hash-34")
assert(plugin:PreInstall({ version = "8.0.34" }).sha512 == "sdk-osx-hash-34")

-- Releases without an asset for this platform are skipped.
assert(plugin:PreInstall({ version = "8.0.8-runtime" }).version == "")
assert(plugin:PreInstall({ version = "8-runtime" }).version == "8.0.34-runtime")

print("PASS: osx-arm64 variant selection for every distribution")
