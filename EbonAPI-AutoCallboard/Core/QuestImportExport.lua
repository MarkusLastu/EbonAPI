local Core = AutoCallboardCore or {}
AutoCallboardCore = Core

local type, tonumber, tostring, pairs = type, tonumber, tostring, pairs
local string, table, math = string, table, math

local RT = AutoCallboardRuntime

local trim = Core.trim

local byTitle = Core.byTitle

local function encodeField(value)
  value = tostring(value or "")
  value = value:gsub("%%", "%%%%")
  value = value:gsub("|", "%%p")
  value = value:gsub("%^", "%%h")
  value = value:gsub("\t", "%%t")
  value = value:gsub("\r", "%%r")
  value = value:gsub("\n", "%%n")

  return value
end

local function decodeField(value)
  value = tostring(value or "")

  return (value:gsub("%%([nrt%%ph])", {
    n = "\n",
    r = "\r",
    t = "\t",
    ["%"] = "%",
    p = "|",
    h = "^",
  }))
end

local function importMarker(line)
  return trim(tostring(line or ""):gsub("^\239\187\191", ""))
end

local function splitPlain(value, separator)
  local fields = {}
  local startIndex = 1

  while true do
    local separatorStart, separatorEnd = string.find(value, separator, startIndex, true)
    if not separatorStart then
      table.insert(fields, string.sub(value, startIndex))
      break
    end

    table.insert(fields, string.sub(value, startIndex, separatorStart - 1))
    startIndex = separatorEnd + 1
  end

  return fields
end

local function countPlain(value, needle)
  local count = 0
  local startIndex = 1

  while true do
    local matchStart, matchEnd = string.find(value, needle, startIndex, true)
    if not matchStart then
      break
    end

    count = count + 1
    startIndex = matchEnd + 1
  end

  return count
end

local QUEST_EXPORT_FIELDS = {
  "key",
  "questId",
  "title",
  "objectiveText",
  "zoneOrSort",
  "questType",
}

for i = 1, #(Core.questRewardFields) do
  QUEST_EXPORT_FIELDS[#(QUEST_EXPORT_FIELDS) + 1] = Core.questRewardFields[i]
end

QUEST_EXPORT_FIELDS[#(QUEST_EXPORT_FIELDS) + 1] = "seen"
QUEST_EXPORT_FIELDS[#(QUEST_EXPORT_FIELDS) + 1] = "lastSeenRoll"

Core.questExportFields = QUEST_EXPORT_FIELDS

function Core.exportKnownQuestText(quests)
  local lines = { "ACBQUESTS3" }
  local cleanQuests = Core.copyQuestList(quests)

  for i = 1, #(cleanQuests) do
    local quest = cleanQuests[i]
    local fields = {}

    for fieldIndex = 1, #(QUEST_EXPORT_FIELDS) do
      table.insert(fields, encodeField(quest[QUEST_EXPORT_FIELDS[fieldIndex]]))
    end

    table.insert(lines, table.concat(fields, " ^ "))
  end

  return table.concat(lines, "\n")
end

local function decodeFields(fields)
  for i = 1, #(fields) do
    fields[i] = decodeField(fields[i])
  end

  return fields
end

local function splitQuestImportFields(line, marker)
  local fields

  if marker == "ACBQUESTS1" then
    return decodeFields(splitPlain(line, "\t")), "ACBQUESTS1"
  end

  if marker == "ACBQUESTS3" then
    return decodeFields(splitPlain(line, " ^ ")), "ACBQUESTS3"
  end

  fields = splitPlain(line, " | ")
  if marker == "ACBQUESTS2" or #(fields) >= #(QUEST_EXPORT_FIELDS) then
    if #(fields) < #(QUEST_EXPORT_FIELDS) then
      fields = splitPlain(line, " // ")
    end

    return decodeFields(fields), "ACBQUESTS2"
  end

  fields = splitPlain(line, " ^ ")
  if #(fields) >= #(QUEST_EXPORT_FIELDS) then
    return decodeFields(fields), "ACBQUESTS3"
  end

  fields = splitPlain(line, " // ")
  if #(fields) >= #(QUEST_EXPORT_FIELDS) then
    return decodeFields(fields), "ACBQUESTS2"
  end

  fields = splitPlain(line, "\t")
  if #(fields) < #(QUEST_EXPORT_FIELDS) then
    return fields, nil
  end

  return decodeFields(fields), "ACBQUESTS1"
end

function Core.analyzeQuestImportText(text)
  local info = {
    textLength = type(text) == "string" and string.len(text) or 0,
    fieldCount = #(QUEST_EXPORT_FIELDS),
    lineCount = 0,
    nonEmptyLineCount = 0,
    marker = nil,
    markerLine = 0,
    dataLineCount = 0,
    importableLineCount = 0,
    invalidLineCount = 0,
    firstLine = "",
    samples = {},
  }

  if type(text) ~= "string" or trim(text) == "" then
    return info
  end

  local marker = nil
  local stopped = false

  for line in string.gmatch(text .. "\n", "([^\r\n]*)\r?\n") do
    info.lineCount = info.lineCount + 1

    local cleanLine = importMarker(line)
    local trimmedLine = trim(line)
    if info.firstLine == "" and trimmedLine ~= "" then
      info.firstLine = cleanLine
    end

    if cleanLine == "```" and (marker or info.dataLineCount > 0) then
      stopped = true
      break
    elseif cleanLine == "ACBQUESTS1" or cleanLine == "ACBQUESTS2" or cleanLine == "ACBQUESTS3" then
      marker = cleanLine
      info.marker = cleanLine
      info.markerLine = info.lineCount
      info.nonEmptyLineCount = info.nonEmptyLineCount + 1
    elseif trimmedLine ~= "" and string.sub(cleanLine, 1, 3) ~= "```" then
      info.nonEmptyLineCount = info.nonEmptyLineCount + 1
      info.dataLineCount = info.dataLineCount + 1

      local v3Fields = #(splitPlain(line, " ^ "))
      local v2Fields = #(splitPlain(line, " | "))
      local slashFields = #(splitPlain(line, " // "))
      local v1Fields = #(splitPlain(line, "\t"))
      local rawFields, inferredMarker = splitQuestImportFields(line, marker)
      local activeFields = #(rawFields)
      local importable = activeFields >= info.fieldCount

      if importable then
        info.importableLineCount = info.importableLineCount + 1
      else
        info.invalidLineCount = info.invalidLineCount + 1
      end

      if #(info.samples) < 5 then
        table.insert(info.samples, {
          line = info.lineCount,
          length = string.len(line),
          marker = marker or inferredMarker or "none",
          v3Separators = countPlain(line, " ^ "),
          v2Separators = countPlain(line, " | "),
          slashSeparators = countPlain(line, " // "),
          tabSeparators = countPlain(line, "\t"),
          v3Fields = v3Fields,
          v2Fields = v2Fields,
          slashFields = slashFields,
          v1Fields = v1Fields,
          activeFields = activeFields,
          importable = importable,
          preview = cleanLine,
        })
      end
    end
  end

  info.stoppedAtFence = stopped

  return info
end

function Core.importKnownQuestText(text)
  local quests = {}
  local imported = 0
  local skipped = 0

  if type(text) ~= "string" or trim(text) == "" then
    return quests, imported, skipped + 1, RT.api:Problem("QUESTCODE.EMPTY", { length = type(text) == "string" and #text or 0 })
  end

  local marker = nil
  local lineCount = 0
  local firstLine = nil
  local firstSkipped = nil
  local fieldSkips = 0
  local invalidSkips = 0

  for line in string.gmatch(text .. "\n", "([^\r\n]*)\r?\n") do
    lineCount = lineCount + 1
    firstLine = firstLine or string.sub(line, 1, 60)
    local cleanLine = importMarker(line)

    if cleanLine == "```" and (marker or imported > 0) then
      break
    elseif cleanLine == "ACBQUESTS1" or cleanLine == "ACBQUESTS2" or cleanLine == "ACBQUESTS3" then
      marker = cleanLine
    elseif trim(line) ~= "" and string.sub(cleanLine, 1, 3) ~= "```" then
      local rawFields, inferredMarker = splitQuestImportFields(line, marker)

      if #(rawFields) >= #(QUEST_EXPORT_FIELDS) then
        marker = marker or inferredMarker
        local quest = {}

        for fieldIndex = 1, #(QUEST_EXPORT_FIELDS) do
          quest[QUEST_EXPORT_FIELDS[fieldIndex]] = rawFields[fieldIndex]
        end

        local cleanQuest = Core.copyQuest(quest)
        if cleanQuest and Core.questKey(cleanQuest) then
          table.insert(quests, cleanQuest)
          imported = imported + 1
        else
          skipped = skipped + 1
          invalidSkips = invalidSkips + 1
          firstSkipped = firstSkipped or lineCount
        end
      elseif marker or imported > 0 then
        skipped = skipped + 1
        fieldSkips = fieldSkips + 1
        firstSkipped = firstSkipped or lineCount
      end
    end
  end

  if not marker and imported == 0 then
    return quests, imported, skipped + 1, RT.api:Problem("QUESTCODE.NO_MARKER", { lines = lineCount, first = firstLine or "" })
  end

  if skipped > 0 then
    return quests, imported, skipped, RT.api:Problem("QUESTCODE.LINES_SKIPPED", {
      skipped = skipped,
      fields = fieldSkips,
      invalid = invalidSkips,
      line = firstSkipped or 0,
    })
  end

  return quests, imported, skipped
end

function Core.mergeKnownQuestLists(existing, incoming)
  local merged = Core.copyQuestList(existing)
  local indexByKey = {}

  for i = 1, #(merged) do
    if type(merged[i].key) == "string" then
      indexByKey[merged[i].key] = i
    end
  end

  local cleanIncoming = Core.copyQuestList(incoming)

  for i = 1, #(cleanIncoming) do
    local quest = cleanIncoming[i]
    local key = type(quest.key) == "string" and quest.key ~= "" and quest.key or Core.questKey(quest)
    local existingIndex = key and indexByKey[key]

    if existingIndex then
      quest.seen = math.max(tonumber(merged[existingIndex].seen) or 0, tonumber(quest.seen) or 0)
      quest.lastSeenRoll = math.max(tonumber(merged[existingIndex].lastSeenRoll) or 0, tonumber(quest.lastSeenRoll) or 0)
      merged[existingIndex] = quest
    elseif key then
      table.insert(merged, quest)
      indexByKey[key] = #(merged)
    else
      RT.api:Reject("QUESTCODE.KEY_MISSING", { title = string.sub(tostring(quest.title or ""), 1, 60) })
    end
  end

  table.sort(merged, byTitle)

  return merged
end

function Core.questStateBackup(currentState)
  local state = Core.mergeState(currentState)

  return {
    schemaVersion = 1,
    knownQuests = state.knownQuests,
    desiredQuests = state.desiredQuests,
    characterProfiles = state.characterProfiles,
  }
end

function Core.restoreQuestState(savedState, questBackup)
  local state = Core.mergeState(savedState)

  if type(questBackup) ~= "table" then
    return state
  end

  local backup = Core.questStateBackup(questBackup)
  state.knownQuests = Core.mergeKnownQuestLists(backup.knownQuests, state.knownQuests)

  if not Core.hasDesiredQuests(state.desiredQuests) then
    state.desiredQuests = Core.copyDesiredMap(backup.desiredQuests)
  end

  local currentProfiles = Core.copyCharacterProfiles(state.characterProfiles)
  state.characterProfiles = Core.copyCharacterProfiles(backup.characterProfiles)
  for profileKey, profile in pairs(currentProfiles) do
    state.characterProfiles[profileKey] = Core.copyCharacterProfile(profile)
  end

  return state
end
