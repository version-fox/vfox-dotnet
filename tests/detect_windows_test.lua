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
local plugin = test.load({
    os = "windows",
    arch = "amd64",
    env = {
        USERPROFILE = "C:\\Users\\test",
        LOCALAPPDATA = "C:\\Users\\test\\AppData\\Local",
        ProgramFiles = "C:\\Program Files",
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
    local dir = cmd:match('"([^"]+)"') or cmd:match("'([^']+)'")
    local children = (dir and dirs[norm(dir)]) or {}
    return {
        read = function(_, pattern)
            if pattern == "*a" then
                return table.concat(children, "\n")
            end
            return nil
        end,
        close = function()
            return true
        end,
    }
end

local function add_child(path, name)
    dirs[norm(path)] = dirs[norm(path)] or {}
    dirs[norm(path)][#dirs[norm(path)] + 1] = name
end

local function add_sdk(home, runtime)
    home = norm(home):gsub("/+$", "")
    files[home .. "/dotnet.exe"] = "binary"
    dirs[home .. "/sdk"] = { "8.0.428" }
    dirs[home .. "/shared/Microsoft.NETCore.App"] = { runtime }
    local parent, base = home:match("^(.*)/([^/]+)$")
    if parent and parent ~= "" then
        add_child(parent, base)
    end
end

-- A system install, the dotnet-install.sh home, the dotnet-install.ps1 home
-- and a Scoop app are all found; Scoop keeps builds two levels down. Each
-- carries a different version so none is dropped as a duplicate.
add_sdk("C:\\Program Files\\dotnet", "8.0.34")
add_sdk("C:\\Users\\test\\.dotnet", "6.0.36")
add_sdk("C:\\Users\\test\\AppData\\Local\\Microsoft\\dotnet", "7.0.20")
add_sdk("C:\\Users\\test\\scoop\\apps\\dotnet-sdk\\current", "9.0.5")
add_child("C:/Users/test/scoop/apps", "dotnet-sdk")

local found = plugin:Detect({})
assert(#found == 4, "expected 4 SDKs, got " .. #found)
local by_note = {}
for _, item in ipairs(found) do
    by_note[item.note] = item
end
assert(by_note["system SDK"].path == "C:\\Program Files\\dotnet", "system SDK path")
assert(by_note["installed by dotnet-install.sh"].path == "C:\\Users\\test\\.dotnet", "dotnet-install.sh home")
assert(
    by_note["installed by dotnet-install.ps1"].path == "C:\\Users\\test\\AppData\\Local\\Microsoft\\dotnet",
    "dotnet-install.ps1 home"
)
assert(by_note["installed by Scoop"].path == "C:\\Users\\test\\scoop\\apps\\dotnet-sdk\\current", "Scoop app")
assert(found[1].version == "9.0.5", "newest SDK first")

print("PASS: 4 Windows detection cases")
