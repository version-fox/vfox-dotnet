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
    os = "linux",
    arch = "amd64",
    env = { HOME = "/home/test", DOTNET_ROOT = "/custom/dotnet" },
})
local detect = require("detect_dotnet")

-- Fake filesystem: files maps a normalized path to its contents, dirs maps a
-- normalized directory to its immediate child names. No real disk is touched.
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

local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

local function add_child(path, name)
    dirs[norm(path)] = dirs[norm(path)] or {}
    if not contains(dirs[norm(path)], name) then
        table.insert(dirs[norm(path)], name)
    end
end

-- Registers a complete SDK home with its SDK versions and runtime versions.
local function add_sdk(home, sdks, runtimes)
    home = norm(home):gsub("/+$", "")
    files[home .. "/dotnet"] = "binary"
    dirs[home .. "/sdk"] = sdks
    dirs[home .. "/shared/Microsoft.NETCore.App"] = runtimes
    local parent, base = home:match("^(.*)/([^/]+)$")
    if parent and parent ~= "" then
        add_child(parent, base)
    end
end

local function reset()
    files, dirs = {}, {}
end

local cases = 0
local function check(got, want, message)
    assert(got == want, (message or "") .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
    cases = cases + 1
end

-- Version naming: the newest runtime of the SDK is the release version that
-- `vfox install` names, and a prerelease sorts below the stable of its line.
reset()
add_sdk("/usr/share/dotnet", { "8.0.428" }, { "8.0.30", "8.0.34" })
check(detect.version_for("/usr/share/dotnet"), "8.0.34", "newest runtime")
dirs["/usr/share/dotnet/shared/Microsoft.NETCore.App"] = { "9.0.0-rc.1", "9.0.0" }
check(detect.version_for("/usr/share/dotnet"), "9.0.0", "stable over prerelease")
dirs["/usr/share/dotnet/shared/Microsoft.NETCore.App"] = {}
dirs["/usr/share/dotnet/host/fxr"] = { "8.0.34" }
check(detect.version_for("/usr/share/dotnet"), "8.0.34", "host/fxr fallback")
dirs["/usr/share/dotnet/host/fxr"] = {}
check(detect.version_for("/usr/share/dotnet"), nil, "no runtime or host")

-- A home needs both the dotnet executable and at least one SDK.
reset()
add_sdk("/usr/share/dotnet", { "8.0.428" }, { "8.0.34" })
check(detect.is_sdk_home("/usr/share/dotnet"), true, "complete SDK home")
files["/usr/share/dotnet/dotnet"] = nil
check(detect.is_sdk_home("/usr/share/dotnet"), false, "no dotnet executable")
files["/usr/share/dotnet/dotnet"] = "binary"
dirs["/usr/share/dotnet/sdk"] = {}
check(detect.is_sdk_home("/usr/share/dotnet"), false, "runtime-only home")

-- Detected entries carry the source note and a path that can be linked.
reset()
add_sdk("/usr/share/dotnet", { "8.0.428" }, { "8.0.34" })
local found = plugin:Detect({})
check(#found, 1, "one system SDK")
check(found[1].version, "8.0.34", "system SDK version")
check(found[1].path, "/usr/share/dotnet", "system SDK path")
check(found[1].note, "system SDK", "system SDK note")

-- dotnet-install.sh's default home and DOTNET_ROOT are both scanned; the
-- duplicate of 8.0.34 is dropped, keeping the first path in version-then-path
-- order, and results are sorted newest first.
reset()
add_sdk("/usr/share/dotnet", { "8.0.428" }, { "8.0.34" })
add_sdk("/home/test/.dotnet", { "6.0.428" }, { "6.0.36" })
add_sdk("/custom/dotnet", { "8.0.428" }, { "8.0.34" })
found = plugin:Detect({})
check(#found, 2, "duplicate version dropped")
check(found[1].version, "8.0.34", "newest first")
check(found[1].path, "/custom/dotnet", "first path after sorting wins")
check(found[2].version, "6.0.36", "second version")
check(found[2].note, "installed by dotnet-install.sh", "dotnet-install.sh note")

-- asdf and mise keep one directory per version beneath their roots.
reset()
add_sdk("/home/test/.asdf/installs/dotnet/9.0.100", { "9.0.100" }, { "9.0.5" })
add_sdk("/home/test/.local/share/mise/installs/dotnet/8.0.411", { "8.0.411" }, { "8.0.35" })
found = plugin:Detect({})
check(#found, 2, "asdf and mise SDKs")
check(found[1].version, "9.0.5", "asdf version")
check(found[1].note, "installed by asdf", "asdf note")
check(found[2].note, "installed by mise", "mise note")

-- ~/.local/share/dotnet is scanned, but dotnet-install.sh does not default to
-- it, so its note names only the directory.
reset()
add_sdk("/home/test/.local/share/dotnet", { "7.0.410" }, { "7.0.20" })
found = plugin:Detect({})
check(#found, 1, "user data directory SDK")
check(found[1].version, "7.0.20", "user data directory version")
check(found[1].note, "user data directory", "user data directory note")

-- Nothing is found on a machine with no SDKs outside vfox.
reset()
check(#plugin:Detect({}), 0, "no SDKs")

print("PASS: " .. cases .. " Linux detection cases")
