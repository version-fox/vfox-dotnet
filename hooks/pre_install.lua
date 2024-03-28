--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- @param ctx table
--- @field ctx.version string User-input version
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local releases = self:Available(ctx)
    for _, release in ipairs(releases) do
        if release.version == ctx.version then
            return release
        end
    end
    return {}
end