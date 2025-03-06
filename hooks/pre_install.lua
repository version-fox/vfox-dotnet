local util = require("util")
local strings = require("vfox.strings")

--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- @param ctx table
--- @field ctx.version string User-input version
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local releases = util:getAvailableByUserVersion(ctx.version)

    for _, release in ipairs(releases) do
        if strings.has_prefix(release.version, ctx.version) then
            return release
        end
    end

    return {}
end