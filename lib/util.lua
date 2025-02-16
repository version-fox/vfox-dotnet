
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

function util:getOsTypeAndArch()
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
    return {
        osType = osType, archType = archType
    }
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
    local majorVersion = string.format("%d", major)
    local channelVersion = string.format("%d.%d", major, minor)
    local releaseVersion = string.format("%d.%d.%d", major, minor, patch)

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

    local result = {}

    --- if user provide version, filter by it
    if userVersion then
        local userVersionInfo = util:parseVersion(userVersion)

        local targetChannel = userVersionInfo.channelVersion
        --- if user provide "9", make sure targetChannel is "9" but not "9.0"
        --- so we can get "9.1" if there is one
        if (userVersionInfo.majorVersion == userVersion) then
            targetChannel = userVersionInfo.majorVersion
        end

        for _, channel in ipairs(body["releases-index"]) do
            if strings.has_prefix(channel["channel-version"], targetChannel) then
                local releaseInChannel = util:getAvailableByChannelReleaseUrl(channel["releases.json"])
                for _, info in ipairs(releaseInChannel) do
                    table.insert(result, info)
                end
                do break end
            end
        end
    else
        for _, channel in ipairs(body["releases-index"]) do
            local releaseInChannel = util:getAvailableByChannelReleaseUrl(channel["releases.json"])
            for _, info in ipairs(releaseInChannel) do
                table.insert(result, info)
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

    local resp, err = http.get({
        url = url
    })
    if err ~= nil or resp.status_code ~= 200 then
        return {}
    end
    local body = json.decode(resp.body)

    local result = {}
    for _, release in ipairs(body["releases"]) do
        local rid = sysInfo.osType .. "-" .. sysInfo.archType
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

        -- security mean has CVE
        if (release["security"]) then
            versionInfo["note"] = versionInfo["note"] .. "not-secure"
        else
            versionInfo["note"] = versionInfo["note"] .. "secure"
        end

        --- "sdk": {
        ---     "version": "2.1.300-preview1-008174",
        ---     "version-display": "2.1.300-preview1",
        ---     "runtime-version": "2.1.0-preview1-26216-03",
        ---     "files": []
        --- }

        versionInfo["note"] = versionInfo["note"] .. ", " .. release["release-date"] --- .. ", C# " .. release["sdk"]["csharp-version"]

        --- sdk mean contain latest sdk version
        local latestSdk = release["sdk"]
        local files = latestSdk["files"]
        for _, file in ipairs(files) do
            -- only need Binaries, not installer
            if file.rid == rid and (strings.has_suffix(file.url, ".tar.gz") or strings.has_suffix(file.url, ".zip")) then
                versionInfo.url = file.url
                versionInfo.sha512 = file.hash
                versionInfo.addition = {
                    { name = file.name, version = latestSdk["version"] }
                }
                --do break end
            end
        end

        if (string.len(versionInfo.url) > 0) then
            table.insert(result, versionInfo)
        end
    end

    return result
end

return util