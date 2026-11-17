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
-- DOTNET_ROOT and VFOX_HOME both point into vfox's own tree: neither may be
-- offered to `vfox link --detect dotnet`.
local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {
        HOME = "/home/test",
        DOTNET_ROOT = "/home/test/.vfox/sdks/dotnet",
        VFOX_HOME = "/home/test/.vfox",
    },
})

local files, dirs = {}, {}
local function norm(path)
    return (path or ""):gsub("\\", "/")
end
io.open = function(path, mode)
    if (mode or "r") ~= "r" then
        return nil
    end
    local content = files[norm(path)]
    if content == nil then
        return nil
    end
    return {
        read = function(_, pattern)
            if pattern == "*a" then
                return content
            end
            return nil
        end,
        close = function()
            return true
        end,
    }
end
io.popen = function(cmd, mode)
    local dir = cmd:match("'([^']+)'") or cmd:match('"([^"]+)"')
    local children = (dir and dirs[norm(dir)]) or {}
    local index = 0
    return {
        lines = function()
            return function()
                index = index + 1
                return children[index]
            end
        end,
        close = function()
            return true
        end,
    }
end

local function add_sdk(home)
    home = norm(home):gsub("/+$", "")
    files[home .. "/dotnet"] = "binary"
    dirs[home .. "/sdk"] = { "8.0.428" }
    dirs[home .. "/shared/Microsoft.NETCore.App"] = { "8.0.34" }
end

add_sdk("/home/test/.vfox/sdks/dotnet")
assert(#plugin:Detect({}) == 0, "a vfox-managed SDK under DOTNET_ROOT and VFOX_HOME must not be detected")

print("PASS: vfox-managed SDKs are never detected")
