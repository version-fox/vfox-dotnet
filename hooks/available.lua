local util = require("util")
local http = require("http")
local html = require("html")
--- Return all available versions provided by this plugin
--- @param ctx table Empty table used as context, for future extension
--- @return table Descriptions of available versions and accompanying tool descriptions
function PLUGIN:Available(ctx)
    local result = {}
    local versions = {}
    local resp, err = http.get({
        url = util.VERSIONS_URL
    })
    if err ~= nil or resp.status_code ~= 200 then
        error("Getting releases failed: " .. err)
    end
    local type = util:getOsTypeAndArch()
    local doc = html.parse(resp.body)
    local tableDoc = doc:find("table")
    -- first find available sdk versions
    tableDoc:find("tbody"):first():find("tr"):each(function(ti, ts)
        local td = ts:find("td")
        local downloadLink = td:eq(0):find("a"):attr("href")
        local support = td:eq(1):text()
        local installableVersion = td:eq(3):text()
        local endOfLife = td:eq(5):text():gsub("\n", ""):gsub("%s+$", "")
        table.insert(versions, {
            version = installableVersion,
            url = util.BARE_URL .. downloadLink,
            note = "End of Support: " .. endOfLife,
            -- sha256 = nil,
        })
    end)
    -- then find os and arch specific version
    for _, version in ipairs(versions) do
        local resp, err = http.get({
            url = version.url
        })
        if err ~= nil or resp.status_code ~= 200 then
            error("Getting specific versions failed: " .. err)
        end
        local downloadDoc = html.parse(resp.body)
        local tableDoc = downloadDoc:find("table"):first():find("tbody"):first()
        local osSpecifics = tableDoc:find("tr")

        local downloadUrl = ""

        if type.osType == "Linux" then
            local archVersions = osSpecifics:eq(0):find("td"):eq(1):find("a")
            if type.archType == "x64" then
                downloadUrl = archVersions:eq(4):attr("href")
            elseif type.archType == "Arm64" then
                downloadUrl = archVersions:eq(2):attr("href")
            elseif type.archType == "x86" then
                error("Can't provide dotnet for x86 architecture linux")
            end
        elseif type.osType == "macOS" then
            local archVersions = osSpecifics:eq(1):find("td"):eq(1):find("a")
            if type.archType == "x64" then
                downloadUrl = archVersions:eq(1):attr("href")
            elseif type.archType == "Arm64" then
                downloadUrl = archVersions:eq(0):attr("href")
            end
        elseif type.osType == "Windows" then
            local archVersions = osSpecifics:eq(2):find("td"):eq(1):find("a")
            if type.archType == "x64" then
                downloadUrl = archVersions:eq(1):attr("href")
            elseif type.archType == "Arm64" then
                downloadUrl = archVersions:eq(0):attr("href")
            elseif type.archType == "x86" then
                downloadUrl = archVersions:eq(2):attr("href")
            end
        end

        -- after getting download url parse direct download link and checksum
        local resp, err = http.get({
            url = util.BARE_URL .. downloadUrl
        })
        if err ~= nil or resp.status_code ~= 200 then
            error("Getting specific versions failed: " .. err)
        end

        local directLinkDoc = html.parse(resp.body)
        local directLink = directLinkDoc:find("a#directLink"):attr("href")
        local checksum = directLinkDoc:find("input#checksum"):attr("value")

        table.insert(result, {
            version = version.version,
            url = directLink,
            note = version.note,
            sha512 = checksum
        })
    end
    return result
end