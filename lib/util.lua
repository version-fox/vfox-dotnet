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

local http = require("http")
local json = require("json")
local strings = require("vfox.strings")

local util = {}

util.BARE_URL = "https://dotnet.microsoft.com"

-- @example https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json
-- @example https://builds.dotnet.microsoft.com/dotnet/release-metadata/9.0/releases.json
util.RELEASE_META_BASE_URL = "https://builds.dotnet.microsoft.com/dotnet/release-metadata"
util.RELEASE_META_INDEX_URL = util.RELEASE_META_BASE_URL .. "/releases-index.json"

--[[
    Installation variants. The suffix is appended to the .NET release version
    to form the version string vfox manages, for example:

        8.0.8             -> full SDK (default, keeps existing installations working)
        8.0.8-runtime     -> .NET Runtime only
        8.0.8-aspnetcore  -> ASP.NET Core Runtime (includes the .NET Runtime)

    `field` is the key holding the component inside a release entry of the
    official releases.json metadata. `archive` is the start of the file name of
    the variant's archive inside that component. A component can list other
    packages too (the runtime component of .NET 10 and later lists the apphost
    pack first), so the name decides which archive is taken, not the position.
]]
local VARIANTS = {
    { key = "sdk", suffix = "", label = "SDK", field = "sdk", archive = "dotnet-sdk-" },
    { key = "runtime", suffix = "-runtime", label = "Runtime", field = "runtime", archive = "dotnet-runtime-" },
    {
        key = "aspnetcore",
        suffix = "-aspnetcore",
        label = "ASP.NET Core Runtime",
        field = "aspnetcore-runtime",
        archive = "aspnetcore-runtime-",
    },
}
local DEFAULT_VARIANT = VARIANTS[1]

-- Metadata is immutable during a single vfox invocation; avoid refetching it
-- while building the list of variants for a release.
local metaCache = {}

--- Fetch and decode one release metadata document. A failed request, a status
--- other than 200 or a body that is not a JSON object raises an error that names
--- the URL. A listing must never leave a channel out without saying so.
--- @param url string
--- @return table the decoded document
local function fetchJson(url)
    if metaCache[url] ~= nil then
        return metaCache[url]
    end
    local resp, err = http.get({ url = url })
    if err ~= nil or resp == nil then
        error("cannot fetch " .. url .. ": " .. tostring(err or "no response"), 0)
    end
    if resp.status_code ~= 200 then
        error("cannot fetch " .. url .. ": HTTP " .. tostring(resp.status_code), 0)
    end
    local ok, body = pcall(json.decode, resp.body)
    if not ok then
        error("cannot decode " .. url .. ": " .. tostring(body), 0)
    end
    if type(body) ~= "table" then
        error("cannot decode " .. url .. ": not a JSON object", 0)
    end
    metaCache[url] = body
    return body
end

-- Cache system info since it won't change during execution
local cachedSysInfo = nil
function util:getOsTypeAndArch()
    if cachedSysInfo then
        return cachedSysInfo
    end

    local osType = RUNTIME.osType
    local archType = RUNTIME.archType
    if RUNTIME.osType == "darwin" then
        osType = "osx"
    elseif RUNTIME.osType == "linux" then
        osType = "linux"
    elseif RUNTIME.osType == "windows" then
        osType = "win"
    end
    if RUNTIME.archType == "amd64" then
        archType = "x64"
    elseif RUNTIME.archType == "arm64" then
        archType = "arm64"
    elseif RUNTIME.archType == "386" then
        archType = "x86"
    end

    cachedSysInfo = {
        osType = osType,
        archType = archType,
        rid = osType .. "-" .. archType,
    }
    return cachedSysInfo
end

--- parse semver
--- @param versionStr string|nil dotNet version, maybe 3 or 3.1 or 3.1.1 or 3.1.1-rc.1
--- @return table an table with major, minor, patch
function util:parseVersion(versionStr)
    -- 默认值
    local major, minor, patch = 0, 0, 0

    if versionStr then
        -- 解析版本号
        local parts = {}
        for part in string.gmatch(versionStr, "%d+") do
            table.insert(parts, tonumber(part))
        end

        -- 根据解析结果赋值
        if parts[1] then
            major = parts[1]
        end
        if parts[2] then
            minor = parts[2]
        end
        if parts[3] then
            patch = parts[3]
        end
    end

    -- 构建 channelVersion 和 releaseVersion
    local majorVersion = tostring(major)
    local channelVersion = major .. "." .. minor
    local releaseVersion = major .. "." .. minor .. "." .. patch

    return {
        major = major,
        minor = minor,
        patch = patch,
        majorVersion = majorVersion,
        channelVersion = channelVersion,
        releaseVersion = releaseVersion,
    }
end

--- Split a version string into its .NET version and distribution variant.
--- Unknown suffixes are left alone and resolve to the default SDK variant.
--- @param versionStr string|nil something like "8", "8.0.8" or "8.0.8-runtime"
--- @return string baseVersion, table variant
function util:splitVariant(versionStr)
    versionStr = versionStr or ""
    for _, variant in ipairs(VARIANTS) do
        if variant.suffix ~= "" and strings.has_suffix(versionStr, variant.suffix) then
            return string.sub(versionStr, 1, -(#variant.suffix + 1)), variant
        end
    end
    return versionStr, DEFAULT_VARIANT
end

--- A version is a prefix of another only on a component boundary, so "8.0.3"
--- must not accidentally resolve to "8.0.34".
--- @param candidate string a complete version from the metadata
--- @param requested string the (possibly partial) version supplied by the user
--- @return boolean
function util:isVersionPrefix(candidate, requested)
    if candidate == requested then
        return true
    end
    if not strings.has_prefix(candidate, requested) then
        return false
    end
    local nextChar = string.sub(candidate, #requested + 1, #requested + 1)
    return nextChar == "." or nextChar == "-"
end

--- The file name at the end of a download URL.
--- @param url string
--- @return string
local function fileName(url)
    return string.match(url, "([^/]+)$") or url
end

--- Pick the binary archive of a variant for the current platform out of a
--- component's files. The archive's name must start with the variant's prefix,
--- so a package listed before it (such as the apphost pack) is never taken.
--- Installers (.pkg/.exe) and the composite ASP.NET archives are skipped.
--- @param files table|nil list of file descriptors from releases.json
--- @param rid string target runtime identifier, e.g. "linux-x64"
--- @param archive string file name prefix of the variant, e.g. "dotnet-runtime-"
--- @return table|nil
local function findAsset(files, rid, archive)
    if type(files) ~= "table" then
        return nil
    end
    for _, file in ipairs(files) do
        if
            file.rid == rid
            and strings.has_prefix(fileName(file.url), archive)
            and (strings.has_suffix(file.url, ".tar.gz") or strings.has_suffix(file.url, ".zip"))
            and not string.find(file.url, "-composite-", 1, true)
        then
            return file
        end
    end
    return nil
end

local function buildVersionInfo(release, variant, sysInfo, isLts)
    local component = release[variant.field]
    -- mise hands a JSON null over as a userdata, which is not nil, so test the type.
    if type(component) ~= "table" then
        return nil
    end
    local asset = findAsset(component.files, sysInfo.rid, variant.archive)
    if not asset then
        return nil
    end

    local releaseVersion = release["release-version"]
    local noteTable = {}
    if variant.key ~= DEFAULT_VARIANT.key then
        table.insert(noteTable, variant.label)
    end
    if isLts then
        table.insert(noteTable, "LTS")
    end
    if release["security"] then
        table.insert(noteTable, "Security Patch")
    end

    return {
        version = releaseVersion .. variant.suffix,
        url = asset.url,
        note = table.concat(noteTable, " - "),
        sha512 = asset.hash,
        addition = {
            { name = variant.label, version = component["version"] or releaseVersion },
        },
    }
end

--- Build the installable variants of every release in one channel.
--- @param url string releases.json URL
--- @param variant table|nil when set, only build this variant
--- @return table list of version descriptors
function util:getAvailableByChannelReleaseUrl(url, variant)
    local sysInfo = util:getOsTypeAndArch()
    local body = fetchJson(url)

    local isLts = body["release-type"] == "lts"
    local result = {}
    for _, release in ipairs(body["releases"] or {}) do
        if variant then
            local info = buildVersionInfo(release, variant, sysInfo, isLts)
            if info then
                result[#result + 1] = info
            end
        else
            for _, candidate in ipairs(VARIANTS) do
                local info = buildVersionInfo(release, candidate, sysInfo, isLts)
                if info then
                    result[#result + 1] = info
                end
            end
        end
    end
    return result
end

--- get channel version
--- @param userVersion string|nil something like "9" or "9.0.12-runtime", or nil
--- @return table channel-info by dotnet
function util:getAvailableByUserVersion(userVersion)
    local body = fetchJson(util.RELEASE_META_INDEX_URL)
    local releasesIndex = body["releases-index"] or {}
    local result = {}

    if userVersion then
        local baseVersion, variant = util:splitVariant(userVersion)
        local userVersionInfo = util:parseVersion(baseVersion)

        local targetChannel = userVersionInfo.channelVersion
        --- If the user provide "9", make sure targetChannel is "9" but not "9.0"
        --- so we can get "9.1" if there is one
        if userVersionInfo.majorVersion == baseVersion then
            targetChannel = userVersionInfo.majorVersion
        end

        for _, channel in ipairs(releasesIndex) do
            if util:isVersionPrefix(channel["channel-version"], targetChannel) then
                local inChannel = util:getAvailableByChannelReleaseUrl(channel["releases.json"], variant)
                -- Preallocate space in result table
                for i = 1, #inChannel do
                    result[#result + 1] = inChannel[i]
                end
                break
            end
        end
    else
        for _, channel in ipairs(releasesIndex) do
            local inChannel = util:getAvailableByChannelReleaseUrl(channel["releases.json"])
            -- Preallocate space in result table
            for i = 1, #inChannel do
                result[#result + 1] = inChannel[i]
            end
        end
    end

    return result
end

--- Whether a version, without its variant suffix, is a preview such as 9.0.0-rc.2.
--- @param baseVersion string
--- @return boolean
local function isPreview(baseVersion)
    return string.find(baseVersion, "-", 1, true) ~= nil
end

--- Pick the newest stable release from a list ordered newest first. When the list
--- holds only previews, its first entry is returned, so a channel that has no
--- stable release yet still resolves to its newest preview.
--- @param releases table version descriptors, newest first
--- @return table|nil
local function newestStable(releases)
    for _, info in ipairs(releases) do
        local infoBase = util:splitVariant(info.version)
        if not isPreview(infoBase) then
            return info
        end
    end
    return releases[1]
end

--- Resolve a user-provided version (partial, full, or variant-suffixed) into
--- the single best matching installable release.
--- @param userVersion string|nil the version requested by the user
--- @return table|nil version descriptor, or nil when nothing matches
function util:resolveVersion(userVersion)
    if not userVersion or userVersion == "" or userVersion == "latest" then
        return newestStable(util:getAvailableByUserVersion(nil))
    end

    local baseVersion = util:splitVariant(userVersion)
    local releases = util:getAvailableByUserVersion(userVersion)

    -- Exact matches win over partial matches.
    for _, info in ipairs(releases) do
        if info.version == userVersion then
            return info
        end
    end

    -- A partial version takes the newest stable release it matches, even when a
    -- preview of the same channel is listed above it.
    local matches = {}
    for _, info in ipairs(releases) do
        local infoBase = util:splitVariant(info.version)
        if util:isVersionPrefix(infoBase, baseVersion) then
            matches[#matches + 1] = info
        end
    end
    return newestStable(matches)
end

return util
