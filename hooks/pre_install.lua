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

local util = require("util")

--- @class PreInstallContext
--- @field version string User-input version, optionally with a variant suffix
---                       (-runtime or -aspnetcore). Partial versions such as
---                       "10" and "10.0" resolve to the newest stable release.

--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- @param ctx PreInstallContext
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local release = util:resolveVersion(ctx.version)
    if not release then
        -- Never return an empty table: vfox records it as a successful install
        -- with no version. Name the requested version and the platform instead.
        local rid = util:getOsTypeAndArch().rid
        local requested = ctx.version
        if not requested or requested == "" or requested == "latest" then
            error("no dotnet release is available for " .. rid, 0)
        end
        error("dotnet version " .. requested .. " is not available for " .. rid, 0)
    end
    return release
end
