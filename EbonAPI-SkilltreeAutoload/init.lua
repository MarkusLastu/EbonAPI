SkillTreeAutoLoad = SkillTreeAutoLoad or {}
local NS = SkillTreeAutoLoad

NS.api = EbonAPI and EbonAPI:NewAddon("SkillTreeAutoLoad", 0, 5) or nil

NS.SNAPSHOT_TTL = 0.2
NS.ASHES_POLL_INTERVAL = 0.5

NS.COLOR = {
    PREFIX = "|cff33ccff",
    ERROR = "|cffff4444",
    WARN = "|cffff9900",
    SUCCESS = "|cff40ff40",
    HIGHLIGHT = "|cffffd200",
    DIM = "|cff808080",
    RESET = "|r",
}

local COLOR = NS.COLOR

function NS.Colorize(color, text)
    return color .. tostring(text) .. COLOR.RESET
end

