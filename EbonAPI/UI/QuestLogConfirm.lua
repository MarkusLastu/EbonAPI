EbonAPI = EbonAPI or {}
EbonAPI.QuestLogConfirm = {}

local QuestLogConfirm = EbonAPI.QuestLogConfirm
local L = EbonAPI.L

local format = string.format

-- Rows of the quest tree before it scrolls.
local MAX_ROWS = 12

-- Draws the confirmation of a grouped abandon with the Kit only. It never reads the quest log: the model comes
-- from EbonAPI.QuestLog.
--   model = { count = n, categories = { { title, quests = { { title, level, done, failed, progress = { a, b },
--             items } } } } }

local function difficulty(level)
  if type(GetQuestDifficultyColor) == "function" and level then
    return GetQuestDifficultyColor(level)
  end

  return nil
end

local function questItem(quest)
  local item = { text = quest.title, prefix = quest.level, color = difficulty(quest.level) }

  if quest.done then
    item.tag, item.tagColor = L.QUESTLOG_DONE, "success"
  elseif quest.failed then
    item.tag, item.tagColor = L.QUESTLOG_FAILED, "danger"
  elseif quest.progress then
    item.suffix, item.suffixColor = format(L.QUESTLOG_PROGRESS, quest.progress[1], quest.progress[2]), "muted"
  end

  return item
end

local function treeItems(model, folded)
  local items = {}

  for _, category in ipairs(model.categories) do
    local children = {}

    for _, quest in ipairs(category.quests) do
      children[#children + 1] = questItem(quest)
    end

    local title = category.title
    items[#items + 1] = {
      text = (title and title ~= "") and title or L.QUESTLOG_NO_CATEGORY,
      color = "heading",
      tag = #children,
      expanded = not folded,
      children = children,
    }
  end

  return items
end

local function alertTexts(model)
  local alerts = {}

  for _, category in ipairs(model.categories) do
    for _, quest in ipairs(category.quests) do
      if quest.done then
        alerts[#alerts + 1] = format(L.QUESTLOG_ALERT_DONE, quest.title)
      end

      if quest.items then
        alerts[#alerts + 1] = format(L.QUESTLOG_ALERT_ITEMS, quest.title, quest.items)
      end
    end
  end

  return alerts
end

function QuestLogConfirm.open(model, onAccept)
  local count = model.count
  local scope = #model.categories >= 2 and format(L.QUESTLOG_CONFIRM_SCOPE, #model.categories) or ""
  local folded = count > EbonAPI.QuestLog.FOLD_AT

  return EbonAPI.Kit.openDialog({
    owner = "EbonAPI",
    title = count == 1 and L.QUESTLOG_CONFIRM_ONE or format(L.QUESTLOG_CONFIRM, count),
    text = scope,
    accept = format(L.QUESTLOG_CONFIRM_ACCEPT, count),
    cancel = L.UI_CANCEL,
    danger = true,
    onAccept = onAccept,
    content = function(box)
      box:Add("tree", { items = treeItems(model, folded), maxRows = MAX_ROWS, frame = "SMALL", size = "medium" })

      local alerts = alertTexts(model)

      if #alerts > 0 then
        local bar = box:Add("bar", { frame = "SMALL", layout = "VERTICAL", border = "danger" })

        for _, line in ipairs(alerts) do
          bar:Add("text", { text = line, color = "danger" })
        end
      end
    end,
  })
end
