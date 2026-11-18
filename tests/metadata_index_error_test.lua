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

-- The responses change between cases. A failed request is never cached, so each
-- case reaches the mocked endpoint again.
local responses = {}
local plugin = test.load({
    os = "linux",
    arch = "amd64",
    http = function(request)
        local response = responses[request.url]
        if response then
            return response
        end
        return { status_code = 404, body = "", headers = {} }
    end,
})

-- A failed index request must be reported with its URL, not read as an empty list.
responses[INDEX_URL] = { status_code = 503, body = "unavailable", headers = {} }
local ok, err = pcall(plugin.Available, plugin, {})
assert(not ok and tostring(err):find(INDEX_URL, 1, true), "index failure not reported: " .. tostring(err))

-- A body that is not JSON is reported with its URL, not treated as an empty list.
responses[INDEX_URL] = { status_code = 200, body = "<html>maintenance</html>", headers = {} }
ok, err = pcall(plugin.Available, plugin, {})
assert(not ok and tostring(err):find(INDEX_URL, 1, true), "undecodable index not reported: " .. tostring(err))

print("PASS: a failed or undecodable release index stops the listing")
