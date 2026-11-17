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

--- Finds .NET SDKs that are already on the machine, for `vfox link --detect dotnet`.
--- An SDK home is named after the newest runtime it carries, which is the
--- release version `vfox install` uses, such as `8.0.34`.
local detect = {}

local function lower(value)
    return (value or ""):lower()
end

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Returns the separator for the current platform: `\` on Windows, `/` elsewhere.
local function sep()
    if RUNTIME and RUNTIME.osType == "windows" then
        return "\\"
    end
    return "/"
end

--- Joins path segments with the platform separator. Forward slashes in the
--- right-hand side are converted too, so nested relative paths work.
function detect.join(left, right)
    local s = sep()
    right = right:gsub("/", s)
    if left:sub(-1) == "/" or left:sub(-1) == "\\" then
        return left .. right
    end
    return left .. s .. right
end

local function shell_quote(value)
    if RUNTIME and RUNTIME.osType == "windows" then
        return '"' .. value:gsub('"', '""') .. '"'
    end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

--- Lists the immediate children of dir as full paths, or {}.
function detect.list_children(dir)
    if dir == "" then
        return {}
    end
    local cmd
    if RUNTIME and RUNTIME.osType == "windows" then
        cmd = "dir /b /ad " .. shell_quote(dir) .. " 2>nul"
    else
        cmd = "ls -1 " .. shell_quote(dir) .. " 2>/dev/null"
    end
    local handle = io.popen(cmd, "r")
    if not handle then
        return {}
    end
    -- read("*a") rather than lines(): vfox's Windows io.popen override in
    -- 1.1.0 does not provide the lines() method that gopher-lua has on Unix.
    local output = handle:read("*a")
    handle:close()
    local result = {}
    if type(output) ~= "string" then
        return result
    end
    for line in output:gmatch("[^\r\n]+") do
        line = trim(line)
        if line ~= "" and line ~= "." and line ~= ".." then
            table.insert(result, detect.join(dir, line))
        end
    end
    return result
end

local function file_exists(path)
    local file = io.open(path, "r")
    if not file then
        return false
    end
    file:close()
    return true
end

--- Splits a version directory name into numeric parts for comparison.
local function parts(value)
    local result = {}
    for part in value:gmatch("[^.]+") do
        local number = part:match("^(%d+)")
        table.insert(result, { number = number and tonumber(number) or 0, rest = part })
    end
    return result
end

--- Whether version a sorts after version b. A stable part is newer than a
--- prerelease such as `9.0.0-rc.1` at the same numeric position.
local function newer(a, b)
    local left, right = parts(a), parts(b)
    for i = 1, math.max(#left, #right) do
        local x, y = left[i], right[i]
        local xn, yn = x and x.number or 0, y and y.number or 0
        if xn ~= yn then
            return xn > yn
        end
        local xr, yr = x and x.rest or "", y and y.rest or ""
        local xs, ys = xr:match("^%d+$") ~= nil, yr:match("^%d+$") ~= nil
        if xs ~= ys then
            return xs
        end
        if xr ~= yr then
            return xr > yr
        end
    end
    return false
end

--- Returns the version-named subdirectories of path, newest first.
function detect.version_dirs(path)
    local result = {}
    for _, child in ipairs(detect.list_children(path)) do
        local name = child:match("[/\\]([^/\\]+)$")
        if name and name:match("^%d") then
            table.insert(result, name)
        end
    end
    table.sort(result, newer)
    return result
end

--- Whether dir is a .NET SDK home: it has the dotnet executable and at least
--- one SDK under sdk/. Runtime-only installations are not linkable as SDKs.
function detect.is_sdk_home(dir)
    if not (file_exists(detect.join(dir, "dotnet")) or file_exists(detect.join(dir, "dotnet.exe"))) then
        return false
    end
    return #detect.version_dirs(detect.join(dir, "sdk")) > 0
end

--- Names an SDK home after the newest runtime it carries. Every SDK ships a
--- runtime, so shared/Microsoft.NETCore.App is the primary source; host/fxr
--- covers unusual layouts that keep only the host.
function detect.version_for(dir)
    local runtimes = detect.version_dirs(detect.join(dir, "shared/Microsoft.NETCore.App"))
    if #runtimes > 0 then
        return runtimes[1]
    end
    local hosts = detect.version_dirs(detect.join(dir, "host/fxr"))
    if #hosts > 0 then
        return hosts[1]
    end
    return nil
end

--- Candidate roots whose children (levels 1) or grandchildren (levels 2) may
--- be SDK homes, or which are SDK homes themselves (levels 0). Each carries a
--- note shown by `vfox link --detect`.
function detect.candidate_roots()
    local roots = {}
    local function add(path, note, levels)
        if type(path) == "string" and path ~= "" then
            table.insert(roots, { path = path, note = note, levels = levels or 0 })
        end
    end
    local function child(base, ...)
        if base == "" then
            return ""
        end
        local result = base
        for _, part in ipairs({ ... }) do
            result = detect.join(result, part)
        end
        return result
    end

    local home = os.getenv("HOME") or os.getenv("USERPROFILE") or ""
    local dotnet_root = os.getenv("DOTNET_ROOT") or os.getenv("DOTNET_HOME") or ""

    if RUNTIME and RUNTIME.osType == "windows" then
        local userprofile = os.getenv("USERPROFILE") or home
        local programfiles = os.getenv("ProgramFiles") or "C:\\Program Files"
        local programfiles_x86 = os.getenv("ProgramFiles(x86)")
        add(child(programfiles, "dotnet"), "system SDK")
        if programfiles_x86 and programfiles_x86 ~= "" then
            add(child(programfiles_x86, "dotnet"), "system SDK")
        end
        -- dotnet-install.ps1 defaults to ~/.dotnet; Scoop, asdf and mise
        -- keep one directory per version beneath their roots.
        add(child(userprofile, ".dotnet"), "installed by dotnet-install.ps1")
        add(child(userprofile, "scoop", "apps"), "installed by Scoop", 2)
        add(child(userprofile, ".asdf", "installs", "dotnet"), "installed by asdf", 1)
        add(child(userprofile, ".local", "share", "mise", "installs", "dotnet"), "installed by mise", 1)
        add(dotnet_root, "pointed to by DOTNET_ROOT or DOTNET_HOME")
        return roots
    end

    add("/usr/share/dotnet", "system SDK")
    add("/usr/lib/dotnet", "system SDK")
    add("/usr/local/share/dotnet", "system SDK")
    add("/usr/local/dotnet", "system SDK")
    add("/opt/dotnet", "system SDK")
    add("/opt/microsoft/dotnet", "system SDK")
    -- dotnet-install.sh defaults to ~/.dotnet; the Homebrew cask installs
    -- under the Homebrew share directory.
    add(child(home, ".dotnet"), "installed by dotnet-install.sh")
    add("/opt/homebrew/share/dotnet", "installed by Homebrew")
    add("/usr/local/share/dotnet", "installed by Homebrew")
    add("/home/linuxbrew/.linuxbrew/share/dotnet", "installed by Homebrew")
    add(child(home, ".asdf", "installs", "dotnet"), "installed by asdf", 1)
    add(child(home, ".local", "share", "mise", "installs", "dotnet"), "installed by mise", 1)
    add(child(home, ".mise", "installs", "dotnet"), "installed by mise", 1)
    add("/opt/hostedtoolcache/dotnet", "CI runner tool cache", 2)
    add(child(home, ".local", "share", "dotnet"), "installed by dotnet-install.sh")
    add(dotnet_root, "pointed to by DOTNET_ROOT or DOTNET_HOME")
    return roots
end

--- True for paths vfox itself manages, which must never be detected.
local function is_vfox_managed(path)
    local p = lower(path or ""):gsub("\\", "/")
    if p:find("/.vfox/", 1, true) or p:sub(-7) == "/.vfox" then
        return true
    end
    local vfox_home = lower(os.getenv("VFOX_HOME") or ""):gsub("\\", "/")
    if vfox_home ~= "" and (p == vfox_home or p:find(vfox_home .. "/", 1, true)) then
        return true
    end
    return false
end

local function normalized(path)
    return (path:gsub("[/\\]+$", ""))
end

--- Records an SDK home once, under the release version it carries.
local function try_add(path, note, seen_paths, out)
    path = normalized(path)
    if seen_paths[path] or is_vfox_managed(path) then
        return
    end
    seen_paths[path] = true
    if not detect.is_sdk_home(path) then
        return
    end
    local version = detect.version_for(path)
    -- vfox refuses `latest` as an installed name.
    if not version or version == "latest" then
        return
    end
    table.insert(out, { version = version, path = path, note = note })
end

local function scan(path, levels, note, seen_paths, out)
    if levels <= 0 then
        try_add(path, note, seen_paths, out)
        return
    end
    for _, child in ipairs(detect.list_children(path)) do
        scan(child, levels - 1, note, seen_paths, out)
    end
end

--- Returns every .NET SDK on the machine, sorted by version then path so
--- `vfox link --detect dotnet` offers them deterministically. One entry per
--- version: vfox links the first it sees and skips the rest as installed.
function detect.find_all()
    local out, seen_paths = {}, {}
    for _, root in ipairs(detect.candidate_roots()) do
        scan(root.path, root.levels, root.note, seen_paths, out)
    end
    table.sort(out, function(a, b)
        if a.version ~= b.version then
            return newer(a.version, b.version)
        end
        return a.path < b.path
    end)
    local result, seen_versions = {}, {}
    for _, item in ipairs(out) do
        if not seen_versions[item.version] then
            seen_versions[item.version] = true
            table.insert(result, item)
        end
    end
    return result
end

return detect
