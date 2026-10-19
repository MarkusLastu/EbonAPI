EbonAPI = EbonAPI or {}

EbonAPI.SS = {
  SEND_LOADOUTS                 = 3,
  SKILL_TREE_UPDATE_SPELL_CAST_RESULT = 6,
  INSTANCE_ENTERED              = 9,
  INSTANCE_ENCOUNTERS_COMPLETED = 10,
  JUNK_SOLD                     = 12,
  PLAYER_RUN_DATA               = 13,
  SOUL_POINTS_MULTIPLIER        = 14,
  COMMITTED_SOUL_POINTS         = 15,
  PLAYER_PERK_CHOICE            = 16,
  PLAYER_PERK_GRANTED           = 18,
  PLAYER_INTENSITY_POINTS       = 30,
  PLAYER_SPEC_INDEX             = 32,
  OBJECTIVES_PROPOSALS          = 101,
  CURRENT_OBJECTIVE             = 102,
  FREEZE_PERK_RESULT            = 104,
  HARDMODE_DATA                 = 500,
  BUILD_LIST                    = 540,
  BUILD_ACK                     = 541,
  BUILD_ACTIVE                  = 542,
  INSTANCE_RESET_RESULT         = 701,
  CHECKPOINTS_DATA              = 800,
  PLAYER_PERK_SELECTION_RESULT  = 1000,
  PRESTIGE_RESULT               = 1201,
  ORBS                          = 1220,
}

EbonAPI.CS = {
  PERK_SELECT    = 17,
  REFRESH_PERKS  = 330,
  REFRESH_BUILDS = 340,
  BUILD_SAVE     = 341,
  BUILD_SELECT   = 344,
  ORBS           = 1220,
  ORB_FORGET     = 1221,
}

local SS = EbonAPI.SS
local CS = EbonAPI.CS

local ssNames = {}
local csNames = {}

for name, opcode in pairs(SS) do
  ssNames[opcode] = name
end

for name, opcode in pairs(CS) do
  csNames[opcode] = name
end

EbonAPI.Opcodes = {}

local Opcodes = EbonAPI.Opcodes

function Opcodes.describe(opcode)
  local name = ssNames[opcode] or csNames[opcode]

  if name then
    return name .. " (" .. tostring(opcode) .. ")"
  end

  return "opcode " .. tostring(opcode)
end

function Opcodes.list()
  local lines = {}
  local codes = {}

  for opcode in pairs(ssNames) do
    codes[#codes + 1] = opcode
  end

  table.sort(codes)

  for index = 1, #codes do
    lines[#lines + 1] = "  S>C  " .. codes[index] .. "  " .. ssNames[codes[index]]
  end

  codes = {}

  for opcode in pairs(csNames) do
    codes[#codes + 1] = opcode
  end

  table.sort(codes)

  for index = 1, #codes do
    lines[#lines + 1] = "  C>S  " .. codes[index] .. "  " .. csNames[codes[index]]
  end

  return table.concat(lines, "\n")
end
