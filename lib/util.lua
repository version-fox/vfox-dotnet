local http = require("http")
local json = require("json")
local strings = require("vfox.strings")

local util = {}

util.BARE_URL = "https://dotnet.microsoft.com"

-- 路由基础
-- @example https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json
-- @example https://builds.dotnet.microsoft.com/dotnet/release-metadata/9.0/releases.json
util.RELEASE_META_BASE_URL = "https://builds.dotnet.microsoft.com/dotnet/release-metadata"
util.RELEASE_META_INDEX_URL = util.RELEASE_META_BASE_URL.."/releases-index.json"

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
        osType = osType, archType = archType
    }
    return cachedSysInfo
end

--- parse semver
--- @param versionStr string dotNet version, maybe 3 or 3.1 or 3.1.1
--- @return table an table with major, minor, patch
function util:parseVersion(versionStr)
    -- 默认值
    local major, minor, patch = 0, 0, 0

    if (versionStr) then
        -- 解析版本号
        local parts = {}
        for part in string.gmatch(versionStr, "%d+") do
            table.insert(parts, tonumber(part))
        end

        -- 根据解析结果赋值
        if parts[1] then major = parts[1] end
        if parts[2] then minor = parts[2] end
        if parts[3] then patch = parts[3] end
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
        releaseVersion = releaseVersion
    }
end

--- get channel version
--- @param userVersion string something like "9" or "9.0" or "9.0.12", or nil
--- @return table channel-info by dotnet
function util:getAvailableByUserVersion(userVersion)
    --- get all release info
    local resp, err = http.get({
        url = util.RELEASE_META_INDEX_URL
    })

    if err ~= nil or resp.status_code ~= 200 then
        return {}
    end

    local body = json.decode(resp.body)
    local releases_index = body["releases-index"]
    local result = {}
    local has_prefix = strings.has_prefix

    --- if user provide version, filter by it
    if userVersion then
        local userVersionInfo = util:parseVersion(userVersion)

        local targetChannel = userVersionInfo.channelVersion
        --- if user provide "9", make sure targetChannel is "9" but not "9.0"
        --- so we can get "9.1" if there is one
        if (userVersionInfo.majorVersion == userVersion) then
            targetChannel = userVersionInfo.majorVersion
        end

        for _, channel in ipairs(releases_index) do
            if has_prefix(channel["channel-version"], targetChannel) then
                local releaseInChannel = util:getAvailableByChannelReleaseUrl(channel["releases.json"])
                -- Preallocate space in result table
                for i=1, #releaseInChannel do
                    result[#result + 1] = releaseInChannel[i]
                end
                break
            end
        end
    else
        for _, channel in ipairs(releases_index) do
            local releaseInChannel = util:getAvailableByChannelReleaseUrl(channel["releases.json"])
            -- Preallocate space in result table
            for i=1, #releaseInChannel do
                result[#result + 1] = releaseInChannel[i]
            end
        end
    end

    return result
end

--- get release version info
--- @param url string something like "ms.dev/3.0/release-info.json"
--- @return table Descriptions of available versions and accompanying tool descriptions
function util:getAvailableByChannelReleaseUrl(url)
    local sysInfo = util:getOsTypeAndArch()
    local osType = sysInfo.osType
    local archType = sysInfo.archType
    local rid = osType .. "-" .. archType
    local has_suffix = strings.has_suffix

    local resp, err = http.get({
        url = url
    })
    if err ~= nil or resp.status_code ~= 200 then
        return {}
    end
    local body = json.decode(resp.body)

    local isLts = body["release-type"] == "lts"
    local releases = body["releases"]
    local result = {}

    result = {}

    for _, release in ipairs(releases) do
        local versionInfo = {
            --- 版本号
            --- 9.0.0-rc.1 / 9.0.2
            version = release["release-version"],
            --- 文件地址, 可以是远程地址或者本地文件路径 [可选]
            url = "",
            --- 备注信息 [可选]
            note = "",
            --- sha512 checksum [optional]
            sha512 = "",
        }

        -- Build note
        local noteTable = {}
        if isLts then
            table.insert(noteTable, "LTS")
        end

        -- if security is true then this release contains fixes for security issues
        if release["security"] then
            if #noteTable > 0 then
                table.insert(noteTable, " - ")
            end
            table.insert(noteTable, "Security Patch")
        end

        versionInfo.note = table.concat(noteTable)

        --- sdk mean contain latest sdk version
        local latestSdk = release["sdk"]
        local files = latestSdk["files"]
        for _, file in ipairs(files) do
            -- only need Binaries, not installer
            if file.rid == rid and (has_suffix(file.url, ".tar.gz") or has_suffix(file.url, ".zip")) then
                versionInfo.url = file.url
                versionInfo.sha512 = file.hash
                versionInfo.addition = {
                    { name = "SDK", version = latestSdk["version"] }
                }
                break
            end
        end

        if versionInfo.url ~= "" then
            result[#result + 1] = versionInfo
        end
    end

    return result
end

return util