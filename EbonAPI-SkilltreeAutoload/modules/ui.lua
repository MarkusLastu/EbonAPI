local NS = SkillTreeAutoLoad
local FormatCost = EbonAPI.Format.number
local L = NS.L

local UI = {}
NS.UI = UI

local NO_NODES = {}
local INFINITE_NEED = 1e12

local panel, saves

local function Status(text, kind)
    if saves then saves:SetStatus(text, kind) end
end

local savePlans = {}

local function GetSavePlan(saveId, save, snapshot)
    local stamp = NS.Core.GetSnapshotStamp()
    local plan = savePlans[saveId]
    if plan and plan.stamp == stamp then return plan end

    plan = plan or {}
    plan.totalCost, plan.pendingNodes = NS.Core.ComputeActivationPlan(save.nodeRanks, snapshot)
    plan.ownedCost, plan.saveCost, plan.ownedNodes, plan.totalNodes =
        NS.Plan.ComputeProgress(save.nodeRanks, snapshot)

    plan.stamp = plan.totalCost and stamp or nil
    plan.progStamp = nil
    savePlans[saveId] = plan
    return plan
end

local function GetProgressivePlan(plan, save, snapshot, available)
    if plan.stamp and plan.progStamp == plan.stamp and plan.progBudget == available then
        return plan.chosen, plan.spent, plan.count, plan.blocked
    end

    local chosen, spent, count, blocked =
        NS.Plan.ComputeProgressive(save.nodeRanks, snapshot, available)
    if chosen then
        plan.chosen, plan.spent, plan.count, plan.blocked = chosen, spent, count, blocked
        plan.progStamp, plan.progBudget = plan.stamp, available
    end
    return chosen, spent, count, blocked
end

local function ActivationFailed(save, detail)
    NS.api:Report(NS.api:Problem("ACTIVATION.FAILED", { save = save.name, detail = tostring(detail) }))
end

local function ActivateSave(saveId)
    local save = NS.Data.GetSave(saveId)
    if not save then return end

    NS.Core.InvalidateSnapshot()
    local snapshot = NS.Core.GetTreeSnapshot()
    local _, pendingNodes = NS.Core.ComputeActivationPlan(save.nodeRanks, snapshot)
    if not pendingNodes then
        NS.api:Report(NS.api:Problem("TREE.NOT_READY", { detail = L.ERR_READ_TREE }))
        Status(L.ROW_READ_FAILED, "bad")
        return
    end
    if pendingNodes == 0 then
        local message = string.format(L.MSG_ALREADY_ACTIVE, save.name)
        NS.api:Notify(message)
        Status(message, "ok")
        return
    end

    local targets, touched, partial = save.nodeRanks, pendingNodes, false

    if save.progressive then
        local available = NS.Core.GetAvailableSoulAshes()
        if not available then
            local points = skillTreeFrame and skillTreeFrame.pointsText
            NS.api:Degrade(NS.api:Problem("ASHES.UNREADABLE",
                { text = EbonAPI.Lib.stripColor(points and points:GetText() or "") }))
            Status(L.ROW_READ_FAILED, "bad")
            return
        end
        local chosen, _, count, blocked =
            NS.Plan.ComputeProgressive(save.nodeRanks, snapshot, available)

        if not chosen then
            ActivationFailed(save, L.ERR_NO_GRAPH)
            Status(L.ERR_NO_GRAPH, "bad")
            return
        end
        if count == 0 then
            NS.api:Report(NS.api:Problem("PROGRESSIVE.NOTHING_AFFORDABLE",
                { save = save.name, balance = FormatCost(available), cost = blocked and FormatCost(blocked) or "?" }))
            Status(blocked and string.format(L.ROW_BLOCKED, FormatCost(blocked - available)) or L.ROW_READ_FAILED, "bad")
            return
        end

        targets, touched, partial = chosen, count, count < pendingNodes
    end

    local cost, err = NS.Core.ApplyBuild(targets)
    if not cost then
        ActivationFailed(save, err)
        Status(tostring(err), "bad")
        UI.RefreshList()
        return
    end

    local message
    if partial then
        message = string.format(L.MSG_APPLIED_PARTIAL, save.name, touched, FormatCost(cost), pendingNodes - touched)
    else
        message = string.format(L.MSG_APPLIED, save.name, touched, FormatCost(cost))
    end
    NS.api:Notify(message)
    Status(message, "ok")
    UI.RefreshList()
end

local function GetTreeWindow()
    local window, parent = skillTreeFrame, skillTreeFrame:GetParent()
    while parent and parent ~= UIParent do
        window, parent = parent, parent:GetParent()
    end
    return window
end

local xOffsetBase

local function SetWindowShift(window, shift)
    if not window:GetAttribute("UIPanelLayout-defined") then return end

    local current = window:GetAttribute("UIPanelLayout-xoffset") or 0
    xOffsetBase = xOffsetBase or current

    local wanted = xOffsetBase + shift
    if shift == 0 then xOffsetBase = nil end
    if current == wanted then return end

    window:SetAttribute("UIPanelLayout-xoffset", wanted)
    if window:IsShown() then UpdateUIPanelPositions(window) end
end


local ApplyLayout
local panelShown = false
local refreshDriver, refreshQueued = nil, false
local affordables, seenSaves = {}, {}

local function Purge(cache, seen)
    for key in pairs(cache) do
        if not seen[key] then cache[key] = nil end
    end
end

local function MarkedSaves()
    local marked = {}
    for _, entry in ipairs(NS.api:ActiveProblems()) do
        local save = entry.facts and entry.facts.save
        if save then
            local ok, text = pcall(NS.api.ProblemText, NS.api, entry)
            marked[save] = (ok and type(text) == "string" and text ~= "") and text or entry.code or "?"
        end
    end
    return marked
end

local function RowTip(save, plan, affordable)
    local lines = {}
    local totalCost, pendingNodes = plan.totalCost, plan.pendingNodes
    if not totalCost then
        lines[1] = L.TOOLTIP_READ_FAILED
    elseif pendingNodes == 0 then
        lines[1] = L.ROW_ACTIVE
    else
        if plan.ownedCost then
            lines[#lines + 1] = string.format(L.TOOLTIP_PROGRESS, plan.ownedNodes, plan.totalNodes,
                FormatCost(plan.ownedCost), FormatCost(plan.saveCost))
        end
        lines[#lines + 1] = string.format(L.TOOLTIP_COST, FormatCost(totalCost))
        local available = NS.Core.GetAvailableSoulAshes()
        if available and available < totalCost then
            lines[#lines + 1] = string.format(L.TOOLTIP_MISSING, FormatCost(totalCost - available))
        end
        if affordable then
            lines[#lines + 1] = L.TOOLTIP_LEGEND_NOW
            lines[#lines + 1] = L.TOOLTIP_LEGEND_LATER
        end
    end
    lines[#lines + 1] = save.progressive and L.TOOLTIP_MODE_PROGRESSIVE or L.TOOLTIP_MODE_STRICT
    return table.concat(lines, "\n")
end

local function Clamp(value)
    if type(value) ~= "number" or value ~= value then return 0 end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function FillSaveItem(saveId, snapshot, available, marked)
    local save = NS.Data.GetSave(saveId)
    if not save then return end

    seenSaves[saveId] = true
    local progressive = save.progressive == true
    local plan = snapshot and GetSavePlan(saveId, save, snapshot)
    local totalCost, pendingNodes = plan and plan.totalCost, plan and plan.pendingNodes
    local item = {
        id = saveId, name = save.name, progressive = progressive, owned = 0, now = 0,
        marked = marked[save.name], canActivate = false,
    }
    local affordable

    if not totalCost then
        item.state, item.text, item.need = "error", L.ROW_READ_FAILED, INFINITE_NEED
        item.why = L.TOOLTIP_READ_FAILED
    else
        local ownedCost, saveCost = plan.ownedCost, plan.saveCost
        item.owned = (ownedCost and saveCost and saveCost > 0) and Clamp(ownedCost / saveCost) or 0
        item.nodes = { owned = plan.ownedNodes or 0, total = plan.totalNodes or 0 }
        local total = plan.totalNodes and plan.totalNodes > 0 and plan.totalNodes or nil

        if pendingNodes == 0 then
            item.state, item.owned, item.need, item.text = "active", 1, 0, L.ROW_ACTIVE
            item.why = L.ROW_ACTIVE
        else
            item.remaining = totalCost
            item.text = string.format(L.ROW_COST, pendingNodes, FormatCost(totalCost))

            if progressive then
                local chosen, spent, count, blocked = GetProgressivePlan(plan, save, snapshot, available or 0)
                if chosen and count > 0 then
                    affordable, item.canActivate, item.state = chosen, true, "step"
                    item.count, item.need = count, spent
                    item.now = total and Clamp(count / total) or 0
                    item.text = string.format(L.ROW_NEXT_STEP, count, FormatCost(spent))
                else
                    affordable = chosen or NO_NODES
                    item.state, item.need = "blocked", blocked or totalCost
                    local short = blocked and (blocked - (available or 0))
                    if short and short > 0 then
                        item.text = string.format(L.ROW_BLOCKED, FormatCost(short))
                    end
                    item.why = item.text
                end
            elseif available ~= nil and available >= totalCost then
                item.state, item.canActivate, item.need = "ready", true, totalCost
                item.now = total and Clamp(pendingNodes / total) or 0
            else
                item.state, item.need = "short", totalCost
                item.why = available and string.format(L.TOOLTIP_MISSING, FormatCost(totalCost - available))
                    or L.TOOLTIP_READ_FAILED
            end
        end
    end

    affordables[saveId] = affordable
    item.tip = plan and RowTip(save, plan, affordable) or L.TOOLTIP_READ_FAILED
    return item
end

local function PanelPad()
    return EbonAPI.Skins.value("kit.padding") or 0
end

-- The width of the panel: the player's choice, else the skin's.
local function PanelWidth()
    return NS.Data.GetPanelWidth() or EbonAPI.Skins.value("widgets.saves.width")
end

function UI.GetPanelWidth()
    return PanelWidth()
end

function UI.GetDetail()
    return NS.Data.GetDetail() or EbonAPI.Skins.value("widgets.saves.detail")
end

function UI.GetWidget()
    return saves
end

local function SizeTree()
    if not (saves and panel) then return end

    local top, bottom = saves:GetTop(), panel:GetBottom()
    if top and bottom and top > bottom + 8 then saves:SetHeight(top - bottom - 8) end
end

local function FitWidth()
    if not (saves and panel) then return end

    local width = PanelWidth()
    panel.spec.width = width
    saves.spec.width = width - 2 * PanelPad()
    saves:SetWidth(width - 2 * PanelPad())
end

function UI.RefreshList()
    if not saves then return end

    local snapshot = NS.Core.GetTreeSnapshot()
    local available = NS.Core.GetAvailableSoulAshes()
    local marked = MarkedSaves()
    local groups = {}
    seenSaves = {}

    local function AddGroup(groupId, name, saveIds)
        local items = {}
        for i = 1, #saveIds do items[#items + 1] = FillSaveItem(saveIds[i], snapshot, available, marked) end
        groups[#groups + 1] = { id = groupId, name = name, items = items }
    end

    local groupIds = NS.Data.GetSortedGroupIds()
    for i = 1, #groupIds do
        local groupId = groupIds[i]
        AddGroup(groupId, NS.Data.GetGroup(groupId).name, NS.Data.GetSortedSaveIdsInGroup(groupId))
    end

    local ungrouped = NS.Data.GetSortedSaveIdsInGroup(nil)
    if #ungrouped > 0 then AddGroup("", L.UNGROUPED, ungrouped) end

    saves:SetModel({ balance = available, groups = groups })
    Purge(affordables, seenSaves)
    Purge(savePlans, seenSaves)
    SizeTree()
end

function UI.SetDetail(detail)
    if not NS.Data.SetDetail(detail) then return end
    if saves then saves:SetDetail(detail or EbonAPI.Skins.value("widgets.saves.detail")) end
end

function UI.SetPanelWidth(width)
    if not NS.Data.SetPanelWidth(width) then return end
    FitWidth()
    if panel then
        panel:Refresh()
        ApplyLayout()
    end
    SizeTree()
end

ApplyLayout = function()
    if not (panel and _G.skillTreeFrame) then return end

    local compact = NS.Data.IsCompact()
    local collapsed = NS.Data.IsPanelCollapsed()
    local side = NS.Data.GetPanelSide()
    local window = GetTreeWindow()

    local at
    if compact then
        local frame, left, top, right, bottom = NS.View.GetViewInsets()
        at = {
            frame = skillTreeFrame, side = side, inside = true, gap = 0, anchor = frame or skillTreeFrame,
            insets = frame and { left = left, top = -top, right = -right, bottom = bottom } or {},
        }
    else
        at = { frame = window, side = side, inside = false, anchor = window, insets = {} }
    end

    -- The reduced display is one line: the window takes the size of its content and keeps the same side of the tree.
    if saves then saves:SetReduced(collapsed) end
    panel.kitFit = collapsed
    panel:Attach(at)
    if collapsed then
        local point, relative, relativePoint, x, y = panel:GetPoint(1)
        panel:ClearAllPoints()
        panel:SetPoint(point, relative, relativePoint, x, y)
    end
    panel:Refresh()

    local width = panel:GetWidth() or 0
    SetWindowShift(window, (not compact and side == "LEFT") and width or 0)
    NS.View.SetCovered(side, (compact and not collapsed) and width or 0)
end

function UI.SetCompact(enabled)
    NS.Data.SetCompact(enabled)
    ApplyLayout()
    UI.RefreshList()
end

function UI.RefreshUpdateNotice()
    if panel then panel:Refresh() end
end

local function BuildPanel()
    if panel or not _G.skillTreeFrame then return end

    panel = NS.api:Window("panel", {
        text = L.PANEL_TITLE, tip = "SkillTreeAutoLoad", escape = false, width = PanelWidth(),
        attach = { frame = GetTreeWindow(), side = NS.Data.GetPanelSide() },
        buttons = {
            { key = "BTN_PANEL_MENU", onClick = function(element) NS.Menus.ShowPanelMenu(element) end },
            {
                key = "BTN_UPDATE",
                hidden = function() return not NS.Update.GetAvailable() or NS.Data.IsPanelCollapsed() end,
                tip = function() return string.format(L.TOOLTIP_UPDATE, NS.Update.GetAvailable() or "") end,
                onClick = function() NS.Menus.ShowUpdateLink() end,
            },
            {
                text = function() return NS.Data.IsPanelCollapsed() and L.BTN_EXPAND or L.BTN_COLLAPSE end,
                onClick = function()
                    NS.Data.SetPanelCollapsed(not NS.Data.IsPanelCollapsed())
                    ApplyLayout()
                    UI.RefreshList()
                end,
            },
            {
                key = "BTN_SIDE",
                onClick = function()
                    NS.Data.SetPanelSide((NS.Data.GetPanelSide() == "RIGHT") and "LEFT" or "RIGHT")
                    ApplyLayout()
                end,
            },
        },
    })
    _G.STAL_Panel = panel
    NS.View.Attach(panel)

    saves = panel:Add("saves", {
        width = PanelWidth() - 2 * PanelPad(), empty = L.EMPTY_LIST,
        view = NS.Data.GetView(), detail = NS.Data.GetDetail(),
        sort = NS.Data.GetSort(), grouped = NS.Data.IsGrouped(),
        onActivate = ActivateSave,
        onMode = function(saveId)
            local save = NS.Data.GetSave(saveId)
            if save and NS.Data.SetSaveProgressive(saveId, not save.progressive) then UI.RefreshList() end
        end,
        onMenu = function(saveId, anchor) NS.Menus.ShowSaveMenu(saveId, anchor or panel) end,
        onGroupMenu = function(groupId, anchor) NS.Menus.ShowGroupMenu(groupId, anchor or panel) end,
        onHover = function(saveId)
            local save = NS.Data.GetSave(saveId)
            if not save then return end
            local snapshot = NS.Core.GetTreeSnapshot()
            NS.View.Preview(saveId, snapshot and NS.Plan.ComputeMissing(save.nodeRanks, snapshot), affordables[saveId])
        end,
        onLeave = function()
            NS.Overlay.Hide()
            NS.View.Release()
        end,
        onNew = function() NS.Menus.NewSave() end,
        onView = function(view) NS.Data.SetView(view) end,
        onSort = function(sort, grouped)
            NS.Data.SetSort(sort)
            NS.Data.SetGrouped(grouped)
        end,
    })
    panel:HookScript("OnSizeChanged", SizeTree)
end

local PREWARM_DELAY = 1

local prewarming, prewarmDone, prewarmDriver

local function FirePrewarm()
    prewarmDone = true

    local onShow = skillTreeFrame:GetScript("OnShow")
    if not onShow then return end

    prewarming = true
    local ok, err = pcall(onShow, skillTreeFrame)
    prewarming = false

    if not ok then NS.api:Report(NS.api:Problem("INIT.STEP_FAILED", { part = "Prewarm", detail = tostring(err) })) end
end

local function TickPrewarm(self, elapsed)
    if elapsed > 0.1 then elapsed = 0.1 end
    self.timer = self.timer + elapsed
    if self.timer < PREWARM_DELAY then return end

    self:Hide()

    if CollectionsJournal and CollectionsJournal:IsVisible() then
        prewarmDone = true
        return
    end

    FirePrewarm()
end

function UI.IsPrewarming()
    return prewarming == true
end

function UI.Prewarm()
    if prewarmDone or prewarming then return end
    if not _G.skillTreeFrame then return end

    if _G.skillTreeNode1 then
        prewarmDone = true
        return
    end

    if not prewarmDriver then
        prewarmDriver = CreateFrame("Frame")
        prewarmDriver:SetScript("OnUpdate", TickPrewarm)
    end

    prewarmDriver.timer = 0
    prewarmDriver:Show()
end


local function ShowPanel()
    if prewarming then return end

    BuildPanel()
    if not panel then return end

    panelShown = true
    NS.Core.InvalidateSnapshot()
    panel:Open()
    ApplyLayout()
    UI.RefreshList()
end

local function HidePanel()
    if prewarming then return end

    NS.Overlay.Hide()
    panelShown = false
    if panel then panel:Close() end

    NS.View.Cancel()

    SetWindowShift(GetTreeWindow(), 0)
end

local function FlushRefresh(self)
    self:Hide()
    refreshQueued = false
    NS.Core.InvalidateSnapshot()
    if panelShown then UI.RefreshList() end
end

local function QueueRefresh()
    if refreshQueued or not panelShown then return end
    refreshQueued = true
    refreshDriver:Show()
end

local function OnProblemChanged()
    if panelShown then UI.RefreshList() end
end

local function OnLanguageChanged()
    NS.Menus.Localize()
    NS.View.Localize()

    if not panel then return end

    ApplyLayout()
    UI.RefreshList()
end

local function InstallWatch()
    if type(_G.refreshAccessibility) ~= "function" then return end

    refreshDriver = CreateFrame("Frame")
    refreshDriver:Hide()
    refreshDriver:SetScript("OnUpdate", FlushRefresh)
    hooksecurefunc("refreshAccessibility", QueueRefresh)
end

function UI.Init()
    if not _G.skillTreeFrame then return end

    InstallWatch()
    NS.api:On("LANGUAGE_CHANGED", OnLanguageChanged)
    NS.api:On("PROBLEM", OnProblemChanged)
    NS.api:On("PROBLEM_CLOSED", OnProblemChanged)
    skillTreeFrame:HookScript("OnShow", ShowPanel)
    skillTreeFrame:HookScript("OnHide", HidePanel)
    NS.View.Init()

    if skillTreeFrame:IsVisible() then ShowPanel() end
end
