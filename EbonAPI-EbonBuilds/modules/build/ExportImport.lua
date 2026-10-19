EbonBuilds.ExportImport = {}

local L = EbonBuilds.L

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local BASE64_CHUNK = 2000
local function Base64Encode(data)
	local out = {}
	local len = #data
	for i = 1, len, 3 do
		local a, b, c = data:byte(i, i + 2)
		a, b, c = a or 0, b or 0, c or 0
		local n = a * 65536 + b * 256 + c
		out[#out + 1] = B64:byte(math.floor(n / 262144) + 1)
		out[#out + 1] = B64:byte(math.floor((n % 262144) / 4096) + 1)
		out[#out + 1] = i + 1 <= len and B64:byte(math.floor((n % 4096) / 64) + 1) or 61
		out[#out + 1] = i + 2 <= len and B64:byte(math.floor(n % 64) + 1) or 61
	end
	local chunks = {}
	for i = 1, #out, BASE64_CHUNK do
		chunks[#chunks + 1] = string.char(unpack(out, i, math.min(i + BASE64_CHUNK - 1, #out)))
	end
	return table.concat(chunks)
end

local function Base64Decode(s)
	local rev = {}
	for i = 1, #B64 do rev[B64:byte(i)] = i - 1 end
	rev[61] = 0
	local out = {}
	local len = #s
	for i = 1, len, 4 do
		local a = rev[s:byte(i)] or 0
		local b = rev[s:byte(i + 1)] or 0
		local c = rev[s:byte(i + 2)] or 0
		local d = rev[s:byte(i + 3)] or 0
		local n = a * 262144 + b * 4096 + c * 64 + d
		out[#out + 1] = string.char(math.floor(n / 65536))
		if s:byte(i + 2) ~= 61 then
			out[#out + 1] = string.char(math.floor((n % 65536) / 256))
		end
		if s:byte(i + 3) ~= 61 then
			out[#out + 1] = string.char(math.floor(n % 256))
		end
	end
	return table.concat(out)
end

local function IsArray(tbl)
	if type(tbl) ~= "table" then return false end
	local count, maxIdx = 0, 0
	for k in pairs(tbl) do
		if type(k) ~= "number" or k < 1 then return false end
		count = count + 1
		if k > maxIdx then maxIdx = k end
	end
	return count == maxIdx
end

local function JSONEncode(value)
	local t = type(value)
	if t == "nil" then return "null"
	elseif t == "boolean" then return value and "true" or "false"
	elseif t == "number" then
		if value ~= value then return "null" end
		if value == math.huge or value == -math.huge then return "null" end
		return tostring(value)
	elseif t == "string" then
		local escaped = value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
		escaped = escaped:gsub("[%z\1-\31]", function(c)
			return string.format("\\u%04x", string.byte(c))
		end)
		return '"' .. escaped .. '"'
	elseif t == "table" then
		local parts = {}
		if IsArray(value) then
			for i = 1, #value do parts[#parts + 1] = JSONEncode(value[i]) end
			return "[" .. table.concat(parts, ",") .. "]"
		else
			for k, v in pairs(value) do
				if v ~= nil then
					parts[#parts + 1] = JSONEncode(tostring(k)) .. ":" .. JSONEncode(v)
				end
			end
			return "{" .. table.concat(parts, ",") .. "}"
		end
	end
	return "null"
end

EbonBuilds.ExportImport.JSONEncode = JSONEncode

local function SkipWhitespace(s, pos)
	while pos <= #s do
		local c = s:byte(pos)
		if c ~= 32 and c ~= 9 and c ~= 10 and c ~= 13 then break end
		pos = pos + 1
	end
	return pos
end

local function NormalizeKey(key)
	if type(key) ~= "string" then return key end
	local num = tonumber(key)
	if num and tostring(num) == key then return num end
	return key
end

local function ParseValue(s, pos)
	pos = SkipWhitespace(s, pos)
	if pos > #s then return nil, pos end
	local c = s:byte(pos)
	if c == 110 then
		return nil, pos + 4
	elseif c == 116 then
		return true, pos + 4
	elseif c == 102 then
		return false, pos + 5
	elseif c == 34 then
		local out = {}
		pos = pos + 1
		while pos <= #s do
			local cc = s:byte(pos)
			if cc == 34 then
				return table.concat(out), pos + 1
			elseif cc == 92 then
				pos = pos + 1
				local ec = s:byte(pos)
				if ec == 110 then out[#out + 1] = "\n"
				elseif ec == 114 then out[#out + 1] = "\r"
				elseif ec == 116 then out[#out + 1] = "\t"
				elseif ec == 92 then out[#out + 1] = "\\"
				elseif ec == 34 then out[#out + 1] = '"'
				elseif ec == 117 then
					local code = tonumber(s:sub(pos + 1, pos + 4), 16)
					if code and code < 256 then out[#out + 1] = string.char(code) end
					pos = pos + 4
				else out[#out + 1] = s:sub(pos, pos) end
			else
				out[#out + 1] = s:sub(pos, pos)
			end
			pos = pos + 1
		end
		return table.concat(out), pos
	elseif c == 91 then
		local arr = {}
		pos = pos + 1
		pos = SkipWhitespace(s, pos)
		if s:byte(pos) == 93 then return arr, pos + 1 end
		while true do
			if pos > #s then return arr, pos end
			local val
			val, pos = ParseValue(s, pos)
			arr[#arr + 1] = val
			pos = SkipWhitespace(s, pos)
			if s:byte(pos) == 93 then return arr, pos + 1 end
			pos = pos + 1
		end
	elseif c == 123 then
		local obj = {}
		pos = pos + 1
		pos = SkipWhitespace(s, pos)
		if s:byte(pos) == 125 then return obj, pos + 1 end
		while true do
			if pos > #s then return obj, pos end
			local key
			key, pos = ParseValue(s, pos)
			pos = SkipWhitespace(s, pos)
			pos = pos + 1
			local val
			val, pos = ParseValue(s, pos)
			if key ~= nil then obj[NormalizeKey(key)] = val end
			pos = SkipWhitespace(s, pos)
			if s:byte(pos) == 125 then return obj, pos + 1 end
			pos = pos + 1
		end
	else
		local startPos = pos
		if c == 45 then pos = pos + 1 end
		while pos <= #s do
			local nc = s:byte(pos)
			if nc >= 48 and nc <= 57 or nc == 46 or nc == 101 or nc == 69 or nc == 43 then
				pos = pos + 1
			else
				break
			end
		end
		return tonumber(s:sub(startPos, pos - 1)), pos
	end
end

EbonBuilds.ExportImport.JSONDecode = function(s)
	if not s or s == "" then return nil end
	local val = ParseValue(s, 1)
	return val
end

local EXPORT_VERSION = 1

local function BuildExportData(build)
	local filteredWeights = {}
	if build.echoWeights then
		for name, weight in pairs(build.echoWeights) do
			if type(weight) == "number" and weight > 0 then
				filteredWeights[name] = weight
			end
		end
	end

	return {
		v = EXPORT_VERSION,
		title = build.title,
		class = build.class,
		spec = build.spec,
		comments = build.comments,
		lockedEchoes = build.lockedEchoes or { nil, nil, nil, nil, nil },
		echoWeights = filteredWeights,
		settings = build.settings,
		automationEnabled = build.automationEnabled,
		author = build.author,
		lastModified = build.lastModified,
		copiedFrom = build.copiedFrom or nil,
	}
end

function EbonBuilds.ExportImport.ExportBuild(build)
	if not build then return nil end
	local data = BuildExportData(build)
	local json = EbonBuilds.ExportImport.JSONEncode(data)
	return Base64Encode(json)
end

function EbonBuilds.ExportImport.DecodeBuild(b64String)
	if not b64String or b64String == "" then
		return nil, EbonBuilds.api:Problem("IMPORT.EMPTY", {})
	end
	local length = #b64String
	local json = Base64Decode(b64String)
	if not json or json == "" then
		return nil, EbonBuilds.api:Problem("IMPORT.NOT_A_BUILD", { reason = "base64 gave no text", length = length })
	end
	local data = EbonBuilds.ExportImport.JSONDecode(json)
	if not data or type(data) ~= "table" then
		return nil, EbonBuilds.api:Problem("IMPORT.NOT_A_BUILD", { reason = "decoded text is not a JSON object", length = length })
	end

	local locked = EbonBuilds.Build.CopyLocked(data.lockedEchoes)

	local echoWeights = nil
	if data.echoWeights and next(data.echoWeights) then
		echoWeights = {}
		for name, weight in pairs(data.echoWeights) do
			echoWeights[name] = weight
		end
		EbonBuilds.Build.NormalizeWeights(echoWeights)
	end

	local build = EbonBuilds.Build.NewObject({
		title       = data.title    or "Imported Build",
		class       = data.class    or EbonBuilds.Build.PlayerClassToken(),
		spec        = data.spec     or 1,
		comments    = data.comments or "",
		lockedEchoes = locked,
		echoWeights = echoWeights,
		settings    = data.settings or EbonBuilds.Build.DefaultSettings(),
		automationEnabled = data.automationEnabled,
		author      = data.author,
		lastModified = data.lastModified,
		copiedFrom  = data.copiedFrom or nil,
	})
	EbonBuilds.Build.EnsureSettings(build)
	return build
end

local CLASS_TOKENS = {
    WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true,
    DEATHKNIGHT = true, SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true,
}

function EbonBuilds.ExportImport.ParseEBH1(text)
    if type(text) ~= "string" then return nil end
    text = strtrim(text)
    if text:sub(1, 5) ~= "EBH1:" then return nil end
    local body, class, name = text:match("^EBH1:(.-):([A-Z]+):?(.*)$")
    if not body or not CLASS_TOKENS[class] then
        return nil, EbonBuilds.api:Problem("IMPORT.EBH1_BAD_CLASS", { class = class or "none" })
    end

    local echoes = {}
    local tokens = 0
    for token in body:gmatch("[^,]+") do
        tokens = tokens + 1
        local id, quality, stacks = token:match("^(%d+)%.(%d+)%.(%d+)$")
        if id then
            echoes[#echoes + 1] = {
                spellId = tonumber(id),
                quality = tonumber(quality),
                stacks  = tonumber(stacks),
            }
        end
    end
    if #echoes == 0 then
        return nil, EbonBuilds.api:Problem("IMPORT.EBH1_NO_ECHOES", { tokens = tokens })
    end
    return { class = class, name = (name ~= "" and name or nil), echoes = echoes }
end

function EbonBuilds.ExportImport.LearnFromEBH1(text)
    local parsed, problem = EbonBuilds.ExportImport.ParseEBH1(text)
    if not parsed then return nil, problem end
    if not (EbonBuilds.Matrix and EbonBuilds.Matrix.AddImportedComposition) then
        return nil, EbonBuilds.api:Problem("IMPORT.EBH1_MATRIX_MISSING", {})
    end

    local ids = {}
    for i = 1, #parsed.echoes do ids[i] = parsed.echoes[i].spellId end
    if not EbonBuilds.Matrix.AddImportedComposition(parsed.class, ids) then
        return 0, parsed
    end
    return #ids, parsed
end

function EbonBuilds.ExportImport.ImportBuild(b64String)
	local build, problem = EbonBuilds.ExportImport.DecodeBuild(b64String)
	if not build then return nil, problem end
	EbonBuilds.Build.Add(build)
	EbonBuilds.Build.SetActive(build.id)
	return build
end

function EbonBuilds.ExportImport.ShowExportDialog(build)
	local b64 = EbonBuilds.ExportImport.ExportBuild(build)
	if not b64 then return end
	EbonBuilds.api:CopyBox(b64, L.EXPORT_BUILD_TITLE)
end

local IMPORT_WIDTH   = 700
local IMPORT_HEIGHT  = 420
local IMPORT_PADDING = 14
local IMPORT_LINES   = 20
local BUTTON_WIDTH   = 80
local ERROR_COLOR    = "|cffff4c4c"

local importDialog

local function RunImport(f)
	local text = f._field.edit:GetText() or ""

	local learned, parsed = EbonBuilds.ExportImport.LearnFromEBH1(text)
	if learned then
		f:Close()
		local who = parsed.name and ("\"" .. parsed.name .. "\" ") or ""
		if learned > 0 then
			EbonBuilds.api:Notify(string.format(
				L.EBH1_LEARNED,
				who, parsed.class, learned))
		else
			EbonBuilds.api:Notify(string.format(L.EBH1_KNOWN, who))
		end
		return
	end

	local build, problem = nil, parsed
	if not problem then
		build, problem = EbonBuilds.ExportImport.ImportBuild(text)
	end
	if build then
		f:Close()
		if EbonBuilds.BuildList and EbonBuilds.BuildList.Refresh then
			EbonBuilds.BuildList.Refresh()
		end
		EbonBuilds.ViewRouter.Show("buildOverview", { build = build })
	else
		EbonBuilds.api:Report(problem)
		f._problem = problem
		f._failed = true
		f:Refresh()
	end
end

local function CreateImportDialog()
	local W = EbonBuilds.Widgets
	local inner = IMPORT_WIDTH - IMPORT_PADDING * 2
	local f = EbonBuilds.api:Window("import", {
		key = "IMPORT_BUILD", width = IMPORT_WIDTH, height = IMPORT_HEIGHT, layout = "VERTICAL", spacing = 8,
		padding = IMPORT_PADDING,
	})
	f:SetFrameStrata("FULLSCREEN_DIALOG")

	local field = W.Field(f, { width = inner, lines = IMPORT_LINES }, { placeholder = "IMPORT_HINT" })
	field.edit:SetScript("OnEscapePressed", function() f:Close() end)
	f._field = field

	local error = W.Kit("text", f, {
		width = inner,
		text = function() return ERROR_COLOR .. (f._problem and EbonBuilds.api:ProblemText(f._problem) or "") .. "|r" end,
		hidden = function() return not f._failed end,
	})
	error.text:SetJustifyH("CENTER")
	f._error = error

	local buttons = W.Centered(f, inner, BUTTON_WIDTH * 2 + 20)
	W.Kit("button", buttons, {
		key = "IMPORT", width = BUTTON_WIDTH,
		onClick = function() RunImport(f) end,
	})
	W.Gap(buttons, 20, 1)
	W.Kit("button", buttons, {
		key = "CANCEL", width = BUTTON_WIDTH,
		onClick = function() f:Close() end,
	})

	importDialog = f
end

function EbonBuilds.ExportImport.ShowImportDialog()
	if not importDialog then CreateImportDialog() end
	importDialog._field:SetValue("")
	importDialog._failed = false
	importDialog._problem = nil
	importDialog:Refresh()
	importDialog:Show()
	importDialog._field.edit:SetFocus()
end
