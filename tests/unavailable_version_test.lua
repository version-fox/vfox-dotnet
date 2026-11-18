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

-- The release index lists no channel, so no release exists for this platform.
-- Every request must fail with an error that names what was asked for.
local plugin = test.load({
    os = "linux",
    arch = "amd64",
    http = function(request)
        if request.url:find("releases-index.json", 1, true) then
            return { status_code = 200, body = '{"releases-index":[]}', headers = {} }
        end
        return { status_code = 404, body = "", headers = {} }
    end,
})

local function expectFailure(version, expected)
    local ok, err = pcall(plugin.PreInstall, plugin, { version = version })
    assert(not ok, version .. " must fail instead of returning an empty version")
    assert(string.find(tostring(err), expected, 1, true), "unexpected error: " .. tostring(err))
end

expectFailure("8.0.999", "dotnet version 8.0.999 is not available for linux-x64")
expectFailure("8.0.999-runtime", "dotnet version 8.0.999-runtime is not available for linux-x64")
expectFailure("latest", "no dotnet release is available for linux-x64")

print("PASS: unavailable versions fail with an error that names them")
