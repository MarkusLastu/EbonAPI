local NS = SkillTreeAutoLoad
local FormatCost = EbonAPI.Format.number
local L = NS.L

local UI = {}
NS.UI = UI

local NO_NODES = {}

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
        return
    end
    if pendingNodes == 0 then
        NS.api:Notify(string.format(L.MSG_ALREADY_ACTIVE, save.name))
        return
    end

    local targets, touched, partial = save.nodeRanks, pendingNodes, false

    if save.progressive then
        local available = NS.Core.GetAvailableSoulAshes()
        if not available then
            local points = skillTreeFrame and skillTreeFrame.pointsText
            NS.api:Degrade(NS.api:Problem("ASHES.UNREADABLE",
                { text = EbonAPI.Lib.stripColor(points and points:GetText() or "") }))
            return
        end
        local chosen, _, count, blocked =
            NS.Plan.ComputeProgressive(save.nodeRanks, snapshot, available)

        if not chosen then
            ActivationFailed(save, L.ERR_NO_GRAPH)
            return
        end
        if count == 0 then
            NS.api:Report(NS.api:Problem("PROGRESSIVE.NOTHING_AFFORDABLE",
                { save = save.name, balance = FormatCost(available), cost = blocked and FormatCost(blocked) or "?" }))
            return
        end

        targets, touched, partial = chosen, count, count < pendingNodes
    end

    local cost, err = NS.Core.ApplyBuild(targets)
    if not cost then
        ActivationFailed(save, err)
        UI.RefreshList()
        return
    end

    if partial then
        NS.api:Notify(string.format(L.MSG_APPLIED_PARTIAL,
            save.name, touched, FormatCost(cost), pendingNodes - touched))
    else
        NS.api:Notify(string.format(L.MSG_APPLIED, save.name, touched, FormatCost(cost)))
    end
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


local panel, tree
local panelShown = false
local refreshDriver, refreshQueued = nil, false
local groupNodes, saveItems = {}, {}
local seenSaves, seenGroups = {}, {}

local function Purge(cache, seen)
    for key in pairs(cache) do
        if not seen[key] then cache[key] = nil end
    end
end

local function MarkedSaves()
    local marked = {}
    for _, entry in ipairs(NS.api:ActiveProblems()) do
        local save = entry.facts and entry.facts.save
        if save then marked[save] = true end
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

local COST_ACTIVE = { 0.25, 1, 0.25 }
local COST_FAILED = { 1, 0.267, 0.267 }
local COST_BLOCKED = { 1, 0.6, 0 }

local function SaveItem(saveId)
    local item = saveItems[saveId]
    if item then return item end

    local activate = { onClick = function() ActivateSave(saveId) end }
    local toggle = {
        onClick = function()
            local save = NS.Data.GetSave(saveId)
            if save and NS.Data.SetSaveProgressive(saveId, not save.progressive) then UI.RefreshList() end
        end,
    }
    local menu = { text = L.BTN_MENU, onClick = function(_, _, button) NS.Menus.ShowSaveMenu(saveId, button or panel) end }
    item = { actions = { activate, toggle, menu } }
    item.onEnter = function(self)
        local save = NS.Data.GetSave(saveId)
        local snapshot = save and NS.Core.GetTreeSnapshot()
        if not save then return end
        NS.View.Preview(saveId, snapshot and NS.Plan.ComputeMissing(save.nodeRanks, snapshot), self.affordable)
    end
    item.onLeave = function()
        NS.Overlay.Hide()
        NS.View.Release()
    end
    saveItems[saveId] = item
    return item
end

local function FillSaveItem(saveId, snapshot, available, marked)
    local save = NS.Data.GetSave(saveId)
    if not save then return end

    seenSaves[saveId] = true
    local item = SaveItem(saveId)
    local activate, toggle, menu = item.actions[1], item.actions[2], item.actions[3]
    local progressive = save.progressive == true
    local plan = snapshot and GetSavePlan(saveId, save, snapshot)
    local totalCost, pendingNodes = plan and plan.totalCost, plan and plan.pendingNodes
    local canActivate, affordable, suffix, fill, color = false, nil, L.ROW_READ_FAILED, 0, COST_FAILED

    if totalCost and pendingNodes == 0 then
        suffix, fill, color = L.ROW_ACTIVE, 1, COST_ACTIVE
    elseif totalCost then
        local ownedCost, saveCost = plan.ownedCost, plan.saveCost
        fill = (ownedCost and saveCost and saveCost > 0) and (ownedCost / saveCost) or 0
        suffix, color = string.format(L.ROW_COST, pendingNodes, FormatCost(totalCost)), nil

        if progressive then
            local chosen, spent, count, blocked = GetProgressivePlan(plan, save, snapshot, available or 0)
            if chosen and count > 0 then
                affordable, canActivate = chosen, true
                suffix = string.format(L.ROW_NEXT_STEP, count, FormatCost(spent))
            else
                affordable = chosen or NO_NODES
                local short = blocked and (blocked - (available or 0))
                if short and short > 0 then
                    suffix, color = string.format(L.ROW_BLOCKED, FormatCost(short)), COST_BLOCKED
                end
            end
        else
            canActivate = available ~= nil and available >= totalCost
        end
    end

    item.text, item.suffix, item.suffixColor, item.fill = save.name, suffix, color, fill
    item.affordable = affordable
    item.marked = marked[save.name] == true
    item.tip = plan and RowTip(save, plan, affordable) or L.TOOLTIP_READ_FAILED
    activate.text, activate.disabled = L.BTN_ACTIVATE, not canActivate
    toggle.text, toggle.pressed = progressive and L.BTN_ON or L.BTN_OFF, progressive
    menu.text = L.BTN_MENU
    return item
end

local function GroupNode(groupId, name, saveIds, snapshot, available, marked)
    local key = groupId or "none"
    seenGroups[key] = true
    local node = groupNodes[key]
    if not node then
        node = { expanded = true }
        node.onEnter = function(_, row) node.row = row end
        node.onClick = function(_, mouse)
            if mouse == "RightButton" then NS.Menus.ShowGroupMenu(groupId, node.row or panel) end
        end
        groupNodes[key] = node
    end

    local children = {}
    for i = 1, #saveIds do children[#children + 1] = FillSaveItem(saveIds[i], snapshot, available, marked) end
    node.text, node.children = name, children
    return node
end

local function SizeTree()
    if not (tree and panel) then return end

    local top, bottom = tree:GetTop(), panel:GetBottom()
    if top and bottom and top > bottom + 8 then tree:SetHeight(top - bottom - 8) end
end

function UI.RefreshList()
    if not tree or NS.Data.IsPanelCollapsed() then return end

    local snapshot = NS.Core.GetTreeSnapshot()
    local available = NS.Core.GetAvailableSoulAshes()
    local marked = MarkedSaves()
    local roots = {}
    seenSaves, seenGroups = {}, {}

    local groupIds = NS.Data.GetSortedGroupIds()
    for i = 1, #groupIds do
        local groupId = groupIds[i]
        roots[#roots + 1] = GroupNode(groupId, NS.Data.GetGroup(groupId).name,
            NS.Data.GetSortedSaveIdsInGroup(groupId), snapshot, available, marked)
    end

    local ungrouped = NS.Data.GetSortedSaveIdsInGroup(nil)
    if #ungrouped > 0 then
        roots[#roots + 1] = GroupNode(nil, L.UNGROUPED, ungrouped, snapshot, available, marked)
    end

    tree:SetNodes(roots)
    Purge(saveItems, seenSaves)
    Purge(savePlans, seenSaves)
    Purge(groupNodes, seenGroups)
    SizeTree()
end

local function ApplyLayout()
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

    panel:SetShaded(collapsed)
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
        text = "SkillTreeAutoLoad", escape = false,
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

    tree = panel:Add("tree", { items = {}, emptyKey = "EMPTY_LIST" })
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
