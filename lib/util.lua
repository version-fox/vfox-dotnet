
local util = {}

util.BARE_URL = "https://dotnet.microsoft.com"
util.VERSIONS_URL = "https://dotnet.microsoft.com/en-us/download/dotnet"


function util:getOsTypeAndArch()
    local osType = RUNTIME.osType
    local archType = RUNTIME.archType
    if RUNTIME.osType == "darwin" then
        osType = "macOS"
    elseif RUNTIME.osType == "linux" then
        osType = "Linux"
    elseif RUNTIME.osType == "windows" then
        osType = "Windows"
    end
    if RUNTIME.archType == "amd64" then
        archType = "x64"
    elseif RUNTIME.archType == "arm64" then
        archType = "Arm64"
    elseif RUNTIME.archType == "386" then
        archType = "x86"
    end
    return {
        osType = osType, archType = archType
    }
end

return util