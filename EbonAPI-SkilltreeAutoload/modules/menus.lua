local NS = SkillTreeAutoLoad
local L = NS.L
local COLOR = NS.COLOR
local Colorize = NS.Colorize

local Menus = {}
NS.Menus = Menus

local function CleanName(raw)
    if type(raw) ~= "string" then return nil end

    local name = EbonAPI.Lib.stripColor(raw)
    name = name:gsub("[%c|]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end

    return name
end

local function RejectName(raw)
    NS.api:Report(NS.api:Problem("SAVE.NAME_INVALID", { entered = tostring(raw), rule = L.RULE_NAME_EMPTY }))
end

local function CaptureFailed(err)
    NS.api:Report(NS.api:Problem("SAVE.CAPTURE_FAILED", { detail = tostring(err) }))
end

local function CountNodes(nodeRanks)
    local count = 0
    for _ in pairs(nodeRanks or {}) do count = count + 1 end
    return count
end

StaticPopupDialogs["STAL_INPUT_TEXT"] = {
    text = "%s",
    hasEditBox = true,
    maxLetters = 40,
    OnShow = function(self)
        local data = self.data
        self.editBox:SetText((data and data.default) or "")
        self.editBox:HighlightText()
    end,
    OnAccept = function(self)
        local data = self.data
        if data and data.onAccept then data.onAccept(self.editBox:GetText()) end
        self:Hide()
    end,
    EditBoxOnEnterPressed = function(self)
        local dialog = self:GetParent()
        if dialog.data and dialog.data.onAccept then
            dialog.data.onAccept(self:GetText())
        end
        dialog:Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["STAL_CONFIRM"] = {
    text = "%s",
    OnAccept = function(self)
        local data = self.data
        if data and data.onAccept then data.onAccept() end
        self:Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function ResetLink(editBox)
    if editBox:GetText() ~= NS.Update.URL then editBox:SetText(NS.Update.URL) end
    editBox:HighlightText()
end

StaticPopupDialogs["STAL_UPDATE_LINK"] = {
    hasEditBox = true,
    hasWideEditBox = true,
    maxLetters = 0,
    OnShow = function(self)
        ResetLink(self.wideEditBox)
        self.wideEditBox:SetFocus()
    end,
    EditBoxOnTextChanged = ResetLink,
    EditBoxOnEnterPressed = function(self)
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function Menus.Localize()
    local input, confirm, link =
        StaticPopupDialogs["STAL_INPUT_TEXT"], StaticPopupDialogs["STAL_CONFIRM"], StaticPopupDialogs["STAL_UPDATE_LINK"]

    input.button1, input.button2 = L.POPUP_OK, L.POPUP_CANCEL
    confirm.button1, confirm.button2 = L.POPUP_YES, L.POPUP_NO
    link.text, link.button1 = L.POPUP_UPDATE, L.POPUP_OK
end

Menus.Localize()

function Menus.ShowUpdateLink()
    local version, installed = NS.Update.GetAvailable()
    if version then StaticPopup_Show("STAL_UPDATE_LINK", version, installed) end
end

function Menus.PromptText(prompt, default, onAccept)
    StaticPopup_Show("STAL_INPUT_TEXT", prompt, nil,
        { default = default, onAccept = onAccept })
end

function Menus.Confirm(text, onAccept)
    StaticPopup_Show("STAL_CONFIRM", text, nil, { onAccept = onAccept })
end

local dropdown = CreateFrame("Frame", "STAL_ActionMenu", UIParent, "UIDropDownMenuTemplate")

local function AddButton(level, text, func, hasArrow, menuList)
    local info = UIDropDownMenu_CreateInfo()
    info.text = text
    info.notCheckable = true
    info.func = func
    info.hasArrow = hasArrow
    info.menuList = menuList
    UIDropDownMenu_AddButton(info, level)
end

local function AddToggle(level, text, checked, func)
    local info = UIDropDownMenu_CreateInfo()
    info.text = text
    info.checked = checked
    info.func = func
    UIDropDownMenu_AddButton(info, level)
end

local function OpenMenu(anchor)
    ToggleDropDownMenu(1, nil, dropdown, anchor, 0, 0)

    local list = _G["DropDownList1"]
    if not (list and list:IsShown()) then return end

    list:ClearAllPoints()
    if NS.Data.IsCompact() or NS.Data.GetPanelSide() == "LEFT" then
        list:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
    else
        list:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
    end
end

function Menus.NewSave()
    Menus.PromptText(L.PROMPT_NEW_SAVE, nil, function(raw)
        local name = CleanName(raw)
        if not name then
            RejectName(raw)
            return
        end

        local nodeRanks, err = NS.Core.CaptureTreeState()
        if not nodeRanks then
            CaptureFailed(err)
            return
        end

        NS.Data.CreateSave(name, nil, nodeRanks)
        NS.UI.RefreshList()
    end)
end

local WIDTHS = { 200, 240, 280 }

function Menus.ShowPanelMenu(anchor)
    UIDropDownMenu_Initialize(dropdown, function(_, level, menuList)
        level = level or 1

        if level == 2 and menuList == "WIDTH" then
            local current = NS.UI.GetPanelWidth()
            for _, width in ipairs(WIDTHS) do
                AddToggle(level, tostring(width), current == width, function()
                    CloseDropDownMenus()
                    NS.UI.SetPanelWidth(width)
                end)
            end
            return
        end

        AddButton(level, L.MENU_NEW_SAVE, Menus.NewSave)

        AddButton(level, L.MENU_NEW_GROUP, function()
            Menus.PromptText(L.PROMPT_NEW_GROUP, nil, function(raw)
                local name = CleanName(raw)
                if not name then
                    RejectName(raw)
                    return
                end
                NS.Data.CreateGroup(name)
                NS.UI.RefreshList()
            end)
        end)

        AddToggle(level, L.MENU_COMPACT, NS.Data.IsCompact(), function()
            NS.UI.SetCompact(not NS.Data.IsCompact())
        end)

        AddToggle(level, L.MENU_PREVIEW_CAMERA, NS.Data.IsPreviewCamera(), function()
            NS.Data.SetPreviewCamera(not NS.Data.IsPreviewCamera())
        end)

        AddToggle(level, L.MENU_DETAIL_DOCK, NS.UI.GetDetail() == "dock", function()
            NS.UI.SetDetail(NS.UI.GetDetail() == "dock" and "inline" or "dock")
        end)

        AddButton(level, L.MENU_PANEL_WIDTH, nil, true, "WIDTH")
    end, "MENU")

    OpenMenu(anchor)
end

function Menus.ShowSaveMenu(saveId, anchor)
    if not NS.Data.GetSave(saveId) then return end

    UIDropDownMenu_Initialize(dropdown, function(_, level, menuList)
        level = level or 1

        if level == 1 then
            AddButton(level, L.MENU_RENAME, function()
                local save = NS.Data.GetSave(saveId)
                Menus.PromptText(L.PROMPT_RENAME, save and save.name, function(raw)
                    local newName = CleanName(raw)
                    if not newName then
                        RejectName(raw)
                        return
                    end
                    if NS.Data.RenameSave(saveId, newName) then NS.UI.RefreshList() end
                end)
            end)

            AddButton(level, L.MENU_MOVE, nil, true, "MOVE")

            AddButton(level, L.MENU_UPDATE, function()
                local save = NS.Data.GetSave(saveId)
                if not save then return end

                local nodeRanks, err = NS.Core.CaptureTreeState()
                if not nodeRanks then
                    CaptureFailed(err)
                    return
                end

                local function apply()
                    if NS.Data.UpdateSaveContent(saveId, nodeRanks) then
                        NS.UI.RefreshList()
                    end
                end

                local newCount = CountNodes(nodeRanks)
                local oldCount = CountNodes(save.nodeRanks)
                if newCount < oldCount then
                    NS.api:Notify(string.format(L.MSG_UPDATE_SHRINKS, newCount, oldCount))
                    Menus.Confirm(string.format(L.CONFIRM_SHRINK_SAVE,
                        save.name, newCount, oldCount), apply)
                else
                    apply()
                end
            end)

            AddButton(level, Colorize(COLOR.ERROR, L.MENU_DELETE), function()
                local save = NS.Data.GetSave(saveId)
                Menus.Confirm(string.format(L.CONFIRM_DELETE_SAVE, save and save.name or saveId), function()
                    if NS.Data.DeleteSave(saveId) then NS.UI.RefreshList() end
                end)
            end)

        elseif level == 2 and menuList == "MOVE" then
            local function moveTo(groupId)
                return function()
                    CloseDropDownMenus()
                    if NS.Data.MoveSaveToGroup(saveId, groupId) then
                        NS.UI.RefreshList()
                    end
                end
            end

            AddButton(level, L.UNGROUPED, moveTo(nil))
            for _, groupId in ipairs(NS.Data.GetSortedGroupIds()) do
                AddButton(level, NS.Data.GetGroup(groupId).name, moveTo(groupId))
            end
        end
    end, "MENU")

    OpenMenu(anchor)
end

function Menus.ShowGroupMenu(groupId, anchor)
    if not NS.Data.GetGroup(groupId) then return end

    UIDropDownMenu_Initialize(dropdown, function(_, level)
        level = level or 1

        AddButton(level, L.MENU_RENAME_GROUP, function()
            local group = NS.Data.GetGroup(groupId)
            Menus.PromptText(L.PROMPT_RENAME_GROUP, group and group.name, function(raw)
                local newName = CleanName(raw)
                if not newName then
                    RejectName(raw)
                    return
                end
                if NS.Data.RenameGroup(groupId, newName) then NS.UI.RefreshList() end
            end)
        end)

        AddButton(level, Colorize(COLOR.ERROR, L.MENU_DELETE_GROUP), function()
            local group = NS.Data.GetGroup(groupId)
            Menus.Confirm(string.format(L.CONFIRM_DELETE_GROUP,
                group and group.name or groupId, L.UNGROUPED), function()
                if NS.Data.DeleteGroup(groupId) then NS.UI.RefreshList() end
            end)
        end)
    end, "MENU")

    OpenMenu(anchor)
end
