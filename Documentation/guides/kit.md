# 🧱 Kit

Build your addon's own windows from ready-made elements. They take the look of the player's skin and the player's language, remember where the player put them, and respect the game's combat rules for you.

## What it does

- `api:Window` creates a window for your addon. The player moves it, and it opens at the same place next time.
- 28 elements, from buttons to tables, go into a window, into a `group`, `panel`, `bar`, `grid` or tab page, or onto any frame of yours.
- Every element follows the player's skin. Give an element a translation key (the name of one of your `api:Locale` texts) instead of a text, and it changes language with the player.
- Dialogs, menus, notifications, keyboard shortcuts and drag and drop are ready to use.
- Secure elements cast spells, use items and run macros; EbonAPI applies the combat rules of the game for you.

Your settings can still go to the EbonAPI window with `api:Options` ([Interface](interface.md)). The Kit is for everything else: your main window, your bars, your lists.

## Quick example

```lua title="MyAddon.lua"
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

local L = api:Locale({
  enUS = { TITLE = "My addon", HELLO = "Say hello", COUNT = "Hellos: %d" },
  frFR = { TITLE = "Mon addon", HELLO = "Dire bonjour", COUNT = "Bonjours : %d" },
})

local count = 0

local win = api:Window("main", { key = "TITLE" })

local label = win:Add("text", {
  text = function()
    return string.format(L.COUNT, count)
  end,
})

win:Add("button", {
  key = "HELLO",
  onClick = function()
    count = count + 1
    label:Refresh()
  end,
})

api:On("READY", function()
  win:Open()
end)
```

The window has a title bar with a close button, keeps its position between sessions, and closes with **Esc**. Its title and its button change language with the player.

## How it works

You create a window with `api:Window`, add elements to it with `win:Add`, and call `Refresh` on an element when your data changes. The window and its elements take their sizes, gaps and colors from the player's skin, their texts from your translations, and their position from the player's last move.

The examples below add their elements to `win`, a window created with `api:Window`. They show their texts through translation keys and these translations:

```lua
local L = api:Locale({
  enUS = {
    REFRESH = "Refresh", READY = "Ready", REFRESH_KEY = "Refresh key",
    ASHES = "Ashes", SOUL_ASHES = "Soul Ashes", SPENDABLE = "Spendable", CLICK_REFRESH = "Click to refresh.",
    LOG = "Log", LINE = "Line %d",
    RENAME_TITLE = "Rename", RENAME_TEXT = "New name of the route:", RENAME = "Rename", CANCEL = "Cancel", RENAMED = "Renamed to %s",
    ROUTE_TITLE = "Route", SHOW_MAP = "Show on map", SHARE = "Share", OPACITY = "Opacity", ROUTE_SAVED = "Route saved",
    DROP_HERE = "Drop a route here", ROUTE_DROPPED = "Route %s", FROSTFIRE = "Frostfire", ASHFALL = "Ashfall",
    HEARTHSTONE = "Hearthstone",
  },
  frFR = {
    REFRESH = "Actualiser", READY = "Prêt", REFRESH_KEY = "Touche d'actualisation",
    ASHES = "Cendres", SOUL_ASHES = "Cendres d'âme", SPENDABLE = "Dépensables", CLICK_REFRESH = "Cliquez pour actualiser.",
    LOG = "Journal", LINE = "Ligne %d",
    RENAME_TITLE = "Renommer", RENAME_TEXT = "Nouveau nom de la route :", RENAME = "Renommer", CANCEL = "Annuler", RENAMED = "Renommée en %s",
    ROUTE_TITLE = "Route", SHOW_MAP = "Afficher sur la carte", SHARE = "Partager", OPACITY = "Opacité", ROUTE_SAVED = "Route enregistrée",
    DROP_HERE = "Déposez une route ici", ROUTE_DROPPED = "Route %s", FROSTFIRE = "Givrefeu", ASHFALL = "Chute de cendres",
    HEARTHSTONE = "Pierre de foyer",
  },
})
```

### Windows

```lua
local win = api:Window(id, fields)
```

`id` names the window inside your addon: letters, digits and `_`. The same `id` returns the same window, so any file can reach it. A second call with an `id` you already used returns that window as it is: its `fields` are not applied again.

| Field | Default | Effect |
| --- | --- | --- |
| `text` or `key` | | the title: a text, a function that returns it, or a translation key |
| `header` | `true` | a title bar with a close button; `false` gives a bare window |
| `buttons` | | a list of extra header buttons, each with the fields of a `button`, or of an `icon` when it has `icon` |
| `layout` | `"VERTICAL"` | how the elements are placed, see [Layouts](#layouts) |
| `spacing`, `columns`, `wrap` | the skin's for `spacing` and `columns`; for `wrap`, the `width` of the container minus its padding on both sides, or the skin's 320 when it has no `width` | the gap between elements, the columns of `GRID`, the width where `FLOW` goes to the next line |
| `padding` | the skin's | the margin inside the window |
| `width`, `height` | the content | a fixed size; without them, the window fits its content |
| `minWidth` | | the smallest width when the window fits its content |
| `point` | `{ "CENTER" }` | the first position: `{ point, relativeTo, relativePoint, x, y }`; after that, the window stays where the player moves it |
| `move` | `"ALWAYS"` | how the player moves it, see [Moving](#moving) |
| `combat` | | `"HIDE"` hides it during combat, `"FADE"` dims it; a window that holds a secure element is not hidden by `"HIDE"`, use `"FADE"` for it |
| `shown` | `true` without header, `false` with | shows the window at once; a window with a header stays hidden until `win:Open()` |
| `hidden` | | `true`, or a function that returns it, hides the window at every refresh; `false` never shows a window the player closed |
| `escape` | the value of `header` | **Esc** closes the window |
| `scroll` | `"NONE"` | see [Scrolling](#scrolling) |

| Method | Effect |
| --- | --- |
| `win:Open()`, `win:Close()`, `win:Toggle()` | show, hide, or switch; in combat they act at once, except for a window that holds a secure element or has `combat = "HIDE"`: it waits for the end of the fight, and only the last request counts (three `Toggle` in combat make one change) |
| `win:SetTitle(text)` | a new title, also when the window was created with a translation key |
| `win:SetShaded(state)` | `true` keeps only the title bar, `false` shows the content again; it does nothing on a window without a header |
| `win:Add(kind, fields)` | adds an element and returns it |
| `win:Clear()` | removes every element, with their timers and keyboard shortcuts |
| `win:Children()` | the list of its elements |
| `win:SetOrientation(layout)` | another layout, one of those of [Layouts](#layouts) |
| `win:Layout()` | places the elements again |
| `win:Refresh()` | redraws the title and every element |

`win.body` is the frame that holds the elements. With a header, `win.head` is the title bar, `win.title` its text, `win.close` the close button and `win.headButtons` the list of your extra header buttons. A bare window has none of these but `win.body`. Your header buttons are refreshed once per refresh. A skin can leave the close button out (`header.close.show`) or move it (`header.close.y`); the header buttons then start at the edge of the header.

The position of each window is saved for the account, and the window opens there next time. When the player ticks **Lock positions** under **Esc → EbonAPI → Appearance → Layout**, no window moves.

#### Layouts

| `layout` | Places the elements |
| --- | --- |
| `"VERTICAL"` | one under the other; the default of windows, groups, panels and tab pages |
| `"HORIZONTAL"` | side by side; the default of `bar` |
| `"GRID"` | in rows of `columns`; each column is as wide as its widest element; the default of `grid` |
| `"FLOW"` | side by side, going to the next line past `wrap` pixels, or past the width of the container (the skin's 320 when it has no `width`) |
| `"NONE"` | not at all: place each element with its `point`, and give the container a `width` and a `height`, since it does not grow to fit them |

A `layout` is accepted on a `bar`, `grid`, `group`, `panel` and window.

#### Moving

| `move` | The player moves the window |
| --- | --- |
| `"ALWAYS"` | by dragging it |
| `"SHIFT"` | by dragging it with **Shift** held |
| `"HANDLE"` | only by a `handle` element placed in it |
| `"NONE"` | never |

A window that holds a secure element does not move during combat. A `handle` element moves its window with a left-button drag, unless **Lock positions** is ticked or the window has `move = "NONE"`.

### Elements

```lua
local button = win:Add("button", { key = "REFRESH", onClick = refresh })
local label = api:Create("text", MyAddonFrame, { key = "READY" })
```

- `container:Add(kind, fields)` adds an element to a window, a `group`, a `panel`, a `bar`, a `grid` or a tab page, and places it. These are the containers.
- `api:Create(kind, parent, fields)` creates an element on any frame. You place it, with `point` or with the frame's own methods. When `parent` is a Kit container, it behaves like `Add`.
- `api:Elements()` lists the 28 kinds. Each one is described in [Elements](../reference/elements.md).

#### Fields every element takes

| Field | Effect |
| --- | --- |
| `text` | the text shown: a string, or a function that returns it |
| `key` | a translation key, used instead of `text` |
| `tip` | the tooltip: a text, or `function(lines, element)` that fills it |
| `tipKey` | a translation key, for the tooltip text; a key missing from your texts is reported once and only the title shows |
| `link` | an item or spell link: hovering shows the game's tooltip |
| `hidden`, `disabled` | `true`, or a function that returns it; a function that returns `nil` means visible, or enabled. an element that cannot be greyed, such as `heading`, `text`, `status`, `bar`, `grid`, `group`, `panel`, `tabs` or a window, refuses `disabled` |
| `badge` | a small mark on the corner: a text, a number, `true` for a dot |
| `width`, `height` | a fixed size |
| `point` | `{ point, relativeTo, relativePoint, x, y }`; used when you create the element with `api:Create` on your own frame, or in a container whose layout is `NONE`; the other layouts place the element themselves |

These fields belong to `button`, `secure`, `icon`, `slot` and `handle`; any other kind refuses `onClick`, `menu` and `shortcut`. The elements that hold a value (`toggle`, `range`, `select`, `color`, `input`) report changes through `onChange` instead. (`link` works on every kind.)

| Field | Effect |
| --- | --- |
| `onClick` | `function(element, mouseButton)` |
| `menu` | the menu opened by a right-click: a list of items, or a function that returns it; see [Menus](#menus) |
| `shortcut` | the id of a keyboard shortcut that clicks the element, see [Keyboard shortcuts](#keyboard-shortcuts) |
| `link` | **Shift**-click pastes the link into chat |

A function given as `text`, `hidden`, `disabled`, `badge` or as a value to read is called again at every refresh. Data you set by hand, such as the items of a list, stay as you set them unless you gave a function for them. Callbacks receive the element first. When one of your functions raises an error, EbonAPI reports it in the game's error display and carries on.

A `tip` function gets a `lines` object:

```lua
win:Add("button", {
  key = "ASHES",
  tip = function(lines, element)
    lines:Add(L.SOUL_ASHES, "heading")
    lines:Pair(L.SPENDABLE, 1200)
    lines:Add(L.CLICK_REFRESH, "muted", true)
  end,
})
```

`lines:Add(text, color?, wrap?)` adds a line in the color `color` (`"text"` by default); `true` as `wrap` lets a long line break. `lines:Pair(left, right, leftColor?, rightColor?)` adds two texts on one line, `"text"` on the left and `"muted"` on the right by default. Colors are palette names, such as `"heading"`, `"text"` or `"muted"`; the full list is in [Skin parameters](../reference/skin-parameters.md#palette). An unknown color raises an error; inside a `tip` function, it is reported in the game's error display. The title of the tooltip is the text of the element.

#### Saves

`saves` shows a collection of saved items (a list of builds, loadouts or presets) in a narrow panel, 240 pixels wide by default. You give it data and functions; the skin draws it. Every item is a cell with a ring that shows its state and progress, its name and one button. A click on a cell chooses it and opens a drawer with the details; a double-click activates it.

```lua
local saves = panel:Add("saves", {
  view = "grid",
  sort = "cost",
  grouped = false,
  width = 240,
  empty = "No saves yet.",
  onActivate = function(id) Load(id) end,
  onMenu = function(id, anchor) OpenMenu(id, anchor) end,
  onView = function(view) MyAddonDB.view = view end,
  onSort = function(sort, grouped) MyAddonDB.sort, MyAddonDB.grouped = sort, grouped end,
})

saves:SetModel({
  balance = 20259189,
  groups = {
    {
      id = "raid",
      name = "Raid",
      items = {
        {
          id = "a1", name = "Tank", state = "step", owned = 0.56, now = 0.07,
          text = "Now: 91 nodes", nodes = { owned = 288, total = 512 },
          remaining = 55400000, need = 111000, count = 91, progressive = true,
          canActivate = true, tip = "Tank build\nNext step: 111 k",
        },
      },
    },
  },
})
```

| Field | Default | Effect |
| --- | --- | --- |
| `onActivate`, `onMode`, `onMenu`, `onGroupMenu`, `onHover`, `onLeave`, `onNew`, `onSelect`, `onView`, `onSort` | | functions, all optional; see below. Anything else but a function raises `EbonAPI: MyAddon: onActivate expects a function, got <value>`. An error inside one is reported to your addon and the widget goes on |
| `view` | the skin's `widgets.saves.view` | `"list"`, `"grid"` or `"gauge"`; anything else raises `EbonAPI: MyAddon: saves view expects list, grid or gauge, got <value>` |
| `detail` | the skin's `widgets.saves.detail` | `"inline"` opens the drawer under the cell, `"dock"` at the bottom of the panel; the grid always uses `"dock"`. Anything else raises `EbonAPI: MyAddon: saves detail expects inline or dock, got <value>` |
| `sort` | `"name"` | `"name"` (natural order), `"pct"` (the most acquired first) or `"cost"` (the cheapest next step first); anything else raises `EbonAPI: MyAddon: saves sort expects name, pct or cost, got <value>` |
| `grouped` | `true` | `false` shows one list without group titles; a boolean only |
| `width` | the skin's `widgets.saves.width` | the width the panel wants, in pixels, kept between 160 and 400 (`saves:PreferredWidth()`) |
| `empty` | `""` | the text shown when the model holds no item; a text only |

Functions of your addon:

| Function | Called when |
| --- | --- |
| `onActivate(id)` | double-click, Enter, or the play button of a cell |
| `onMode(id)` | the player flips the "Progressive" switch of the drawer, or presses `M` |
| `onMenu(id, anchor)` | right-click on a cell; `anchor` is the cell, to attach your menu to |
| `onGroupMenu(groupId, anchor)` | the player presses the dots button of a group title |
| `onHover(id, frame)`, `onLeave()` | the mouse enters and leaves a cell (to highlight what the save touches) |
| `onNew()` | the player presses the "+" button |
| `onSelect(id)` | the player chooses a cell, by mouse or by keyboard |
| `onView(view)` | the player picks another view; keep it and give it back as `view` next time |
| `onSort(sort, grouped)` | the player picks another sort or switches the groups; keep them too |

The model, given by `saves:SetModel(model)`:

| Field | Meaning |
| --- | --- |
| `balance` | the number you have to spend, or `nil` when unknown. With `sort = "cost"` and `grouped = false`, a line "You have 20,3 M Soul Ashes" is inserted before the first item whose `need` is above `balance` |
| `groups` | list of `{ id, name, items }`, in the order shown. A group `id` is never `""`, except for the group of the items that have none; that group is hidden when it is empty. A click on a title folds or unfolds its group |

An item takes these fields:

| Item field | Meaning |
| --- | --- |
| `id` | required, unique in the whole model, never `""` |
| `name` | the text shown; the search ignores case and accents and also looks in the name of the group |
| `state` | required: `"active"` (is the one in use), `"ready"` (can be activated at once), `"step"` (activated in several steps), `"short"` (too expensive: a padlock), `"blocked"` (a warning triangle) or `"error"` (unreadable: a cross) |
| `owned` | required, the share of the total already acquired, from 0 to 1 |
| `now` | the share more that one click would activate, from 0 to 1 |
| `text` | the state in clear, already translated, for the drawer |
| `nodes` | `{ owned, total }`, shown as "288 / 512 nodes" |
| `remaining` | the cost left (a number), `nil` when active or unreadable |
| `need` | the key of the `"cost"` sort: `0` when active, a very large number when unreadable, else the cost of the next step |
| `count` | the number of things one activation does; the button of the drawer reads "Activate · 91" |
| `progressive` | `true` shows a lightning bolt on the cell and sets the "Progressive" switch |
| `marked` | a problem text: the cell gets a warning triangle and this text leads its tooltip |
| `canActivate`, `why` | `false` hides the play button and a double-click shows `why` on the status line and in the error display |
| `tip` | the body of the tooltip, several lines |

A model that is not a table with `groups`, an item without `id`, a duplicate `id`, an unknown `state`, or an `owned` or `now` outside 0 to 1 is not drawn: the problem is reported to your addon and the widget keeps its previous model.

Methods:

| Method | Effect |
| --- | --- |
| `saves:SetModel(model)` | gives the data and redraws; keeps the chosen item if its `id` is still there, the folded groups, the scroll position and the focus |
| `saves:SetView(view)`, `saves:SetDetail(detail)` | change the view or the drawer place, with the values of the fields above |
| `saves:SetSort(sort, grouped)` | changes the sort; `grouped` stays as it is when `nil` |
| `saves:SetStatus(text, kind)` | shows `text` on the status line (two lines at most) for 9 seconds; `kind` is `nil`, `"ok"` (green) or `"bad"` (red). `nil` or `""` brings back the reminder "Click: details · Double-click: activate · Right-click: menu" |
| `saves:SetHeight(height)` | the height of the whole widget |
| `saves:Select(id)` | chooses an item and opens its drawer; `nil` clears the choice |
| `saves:Selected()` | the `id` of the chosen item, or `nil` |
| `saves:Refresh()` | redraws from the model |
| `saves:PreferredWidth()` | the width the widget wants, from `width` or the skin |
| `saves:SetReduced(on)` | `true` folds the widget into one line (a drop-down of the items, two arrows to step through them, the play button); `false` brings the full display back. Your addon decides when, usually from a button of its own |
| `saves:Focus()` | takes the keyboard, as a click in the widget does |

The tool bar holds three buttons for the views, a magnifier, a sort button and a "+" button. The magnifier opens a field with the count of matches ("3/11") and a cross; some skins keep it open. The sort button picks name, progress or cost, and switches the groups on or off. The list shows one line per item with a small ring, the grid shows square cells, the gauge shows lines with a progress bar.

The keyboard works after a click in the widget and stops when the mouse leaves it, on **Esc**, or when the widget hides, so the game keys come back:

| Key | Effect |
| --- | --- |
| Up, Down | choose the previous or next item; in the grid, one row up or down |
| Left, Right | in the grid only: the previous or next item |
| Enter | activate the chosen item |
| Space | open or close the drawer (chooses the first item when none is chosen) |
| `M` | flip the "Progressive" switch of the chosen item |
| Esc | closes the drawer; with the drawer closed, gives the keyboard back |

The Menu key and Shift+F10 do not open the menu: it opens on a right-click on a cell, from the dots button of the drawer and from the dots button of a group title.

In the search field, Up and Down change the chosen item, Enter activates it and Esc closes the field.

#### Refreshing

Every element has `Refresh()`, `SetBadge(text)` and `Owner()`. `element:Refresh()` reads its functions again and redraws it. `element:SetBadge(text)` sets the mark on its corner; `nil` or `""` removes it. `element:Owner()` returns the name of your addon. `api:RefreshUI()` refreshes every element of your addon. EbonAPI does it for you at `READY` and when the language or the interface scale changes; after that, call `Refresh` when your data changes.

### Scrolling

`api:Window`, `group` and `panel` take a `scroll` field; any other kind refuses it:

| `scroll` | Effect |
| --- | --- |
| `"NONE"` | no scrolling: the container grows with its content; the default |
| `"VERTICAL"` | a bar on the right, the mouse wheel scrolls up and down |
| `"HORIZONTAL"` | a bar at the bottom, the mouse wheel scrolls sideways |
| `"BOTH"` | both bars; the wheel scrolls up and down, **Shift** + wheel sideways |

With a vertical bar, the container is `height` pixels high, or the skin's height when you give none: 240 pixels in the default skin. With a horizontal bar, it is `width` pixels wide, or the skin's width: 320 pixels in the default skin. In the other direction it fits its content. When a scrolled area reaches its end, the wheel scrolls the container around it. Lists, trees, tables, `api:CopyBox` and the choices of a dialog scroll on their own.

```lua
local log = win:Add("group", { key = "LOG", scroll = "VERTICAL", height = 160 })

for index = 1, 40 do
  log:Add("text", { text = string.format(L.LINE, index) })
end
```

An area that holds a secure element does not scroll during combat.

### Dialogs

```lua
api:Dialog({
  titleKey = "RENAME_TITLE",
  textKey = "RENAME_TEXT",
  input = L.FROSTFIRE,
  maxLetters = 32,
  acceptKey = "RENAME",
  cancelKey = "CANCEL",
  onAccept = function(name)
    api:Print(string.format(L.RENAMED, name))
  end,
})
```

| Field | Effect |
| --- | --- |
| `title`, `titleKey` | a title above the text |
| `text`, `textKey` | the question |
| `accept`, `acceptKey` | the label of the accept button, `OK` in the player's language by default; **Enter** in the text field accepts too |
| `cancel`, `cancelKey` | the label of the cancel button; without it, there is no cancel button |
| `input` | a text field, filled with this text |
| `maxLetters` | the longest text the field accepts |
| `choices` | a list to choose from: `{ text = ..., value = ... }` or `{ key = ..., value = ... }`; a choice without `value` is not selected at first; the accept button stays grey until a row is clicked, or until `value` matches a choice; the list scrolls past 6 rows in the default skin |
| `value` | the choice selected at first |
| `onAccept` | `function(value)`: the typed text, the chosen value, or `nil` (also for a chosen choice that has no `value`) |
| `onCancel` | `function(value)`, called by the cancel button, by **Esc**, and when another dialog opens, with the same `value` each time: the typed text, else the chosen value, else `nil` |

One dialog shows at a time: opening another one cancels the first. **Esc** cancels the dialog. Three shortcuts cover the common cases:

| Method | Shows |
| --- | --- |
| `api:Confirm(text, onYes, onNo)` | **Yes** and **No**, in the player's language |
| `api:Prompt(text, default, onAccept, onCancel)` | a text field with **OK** and **Cancel** |
| `api:CopyBox(text, title)` | `title` as the question, then `text` selected in a field the player cannot edit, with `Press Ctrl+C to copy.` and a **Close** button |

### Menus

```lua
api:OpenMenu({
  { title = true, key = "ROUTE_TITLE" },
  { key = "SHOW_MAP", onClick = function(item) showMap() end },
  { key = "SHARE", disabled = not api:IsChannelJoined() },
  { key = "OPACITY", range = { min = 0, max = 1, step = 0.05, value = 0.8, percent = true },
    onChange = function(value, item) setOpacity(value) end },
})
```

`api:OpenMenu(items, anchor?)` opens the menu under `anchor`, as wide as `anchor`, or at the cursor. Without `anchor`, a menu already open closes first, so a second call elsewhere opens the menu at the new place of the cursor. It returns `true`, or `false` when `items` is not a table. An element's `menu` field opens the same menu on a right-click.

| Item field | Effect |
| --- | --- |
| `text`, `key` | the label |
| `onClick` | `function(item)`, then the menu closes |
| `checked` | marks the current choice |
| `title` | `true` makes the line a title that cannot be clicked |
| `disabled` | greys the line; a click does nothing and the menu stays open |
| `range` | a slider in the line: `min`, `max`, `step`, `value`, `percent`, `format` |
| `onChange` | `function(value, item)`, when the slider of `range` moves |

### Notifications

```lua
api:Notify(L.ROUTE_SAVED, { duration = 6, onClick = function() win:Open() end })
```

`api:Notify(text, fields?)` shows a notification at the top of the screen and returns it. Notifications shown together stack under each other, the oldest at the top. A click closes it and calls `onClick`; otherwise it fades out after `duration` seconds.

| Field | Default |
| --- | --- |
| `title` | your addon name |
| `icon` | your addon's icon, see [Connecting your addon](connection.md) |
| `duration` | the skin's, 4 seconds by default |
| `onClick` | `function()`, called after the click closed it |
| `sound` | a game sound name, played when it appears |

### Keyboard shortcuts

```lua
win:Add("button", { key = "REFRESH", shortcut = "REFRESH", onClick = refresh })
win:Add("shortcut", { key = "REFRESH_KEY", target = "REFRESH" })
```

`shortcut` is an id of letters, digits and `_`. An element with `shortcut = "REFRESH"` is clicked when the player presses the keyboard key bound to `REFRESH`. The `shortcut` element needs a `target`, the id of the element it binds, and lets the player choose that key: a click, then the key, with **Alt**, **Ctrl** or **Shift** if wanted. A right-click removes the key, **Esc** cancels.

The `shortcut` element reads `Refresh key: None` while no key is set, and `Press a key...` while it waits. A key pressed with modifiers is saved in the order **Alt**, **Ctrl**, **Shift**, then the key.

`api:GetShortcut(id)` returns the keyboard key, such as `"CTRL-K"`, or `nil`. `api:SetShortcut(id, key)` binds a keyboard key from your code; `nil` removes it; it returns `true` when the key was saved. Shortcuts are saved for the account and applied out of combat.

### Drag and drop

A `list` or `tree` item can be dragged when it has a `drag` value, and so can a `slot` with `drag`; a `drag` of `false` or `nil` means it cannot be dragged. A small box with the text of the source follows the cursor. An element of the same addon with an `onDrop` field receives it:

```lua
local routes = win:Add("list", {
  items = { { key = "FROSTFIRE", drag = "frostfire" }, { key = "ASHFALL", drag = "ashfall" } },
})

win:Add("slot", {
  key = "DROP_HERE",
  onDrop = function(element, payload, source, item)
    api:Print(string.format(L.ROUTE_DROPPED, tostring(payload)))
  end,
})
```

`onDrop(element, payload, source, item)` gets the dragged value, the element it came from and, for a list, the item under the cursor. Dropping an element on itself does nothing. A `slot` also takes what the game cursor holds, such as an item or a spell from the spellbook: `onDrop` then gets `{ kind, id, detail }`, the values of the game's `GetCursorInfo`, as `payload`, with `nil` as `source` and `item`. A `slot` without `onDrop` leaves the object on the cursor.

### Combat

The game forbids changing secure buttons during combat. EbonAPI keeps to that rule:

- `secure` elements, and `icon` elements with a `spell`, `item` or `macro`, cannot be created during combat: that is a contract error.
- Changing their action, greying them, showing or hiding them, and placing the elements of a window that holds one wait until the fight ends.
- `api:AfterCombat(fn)` runs `fn` now when out of combat and returns `true`; during combat, it runs `fn` when the fight ends and returns `false`. An error in `fn` goes to the game's error display and never reaches the caller.
- `win:Open()`, `win:Close()` and `win:Toggle()` wait for the end of the fight only for a window that holds a secure element or has `combat = "HIDE"`.

```lua
api:AfterCombat(function()
  win:Add("secure", { key = "HEARTHSTONE", item = "Hearthstone" })
end)
```

## Events

The Kit emits no event.

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:Window(id, fields?)` | id, fields | the window | id not made of letters, digits and `_`; fields not a table; a field that is refused, see [Errors](#errors) |
| `api:Create(kind, parent?, fields?)` | kind, frame, fields | the element | unknown kind; fields not a table; a field that is refused, see [Errors](#errors); secure element during combat |
| `container:Add(kind, fields)` | kind, fields | the element | as `api:Create` |
| `container:Clear()` | | the container | |
| `container:Children()` | | the list of its elements | |
| `container:SetOrientation(layout)` | layout | the container | layout is not one of the five |
| `container:Layout()` | | the container | |
| `win:Open()`, `win:Close()`, `win:Toggle()` | | the window | |
| `win:SetTitle(text)` | text | the window | |
| `win:SetShaded(state)` | `true` or `false` | the window | |
| `win:Refresh()` | | the window | |
| `element:Refresh()` | | the element | |
| `element:SetBadge(text)` | text, number, `true` or `nil` | the element | |
| `element:Owner()` | | the name of your addon | |
| `api:Elements()` | | sorted list of the kinds | |
| `api:RefreshUI()` | | | |
| `api:Dialog(fields)` | fields | the dialog | fields not a table; a choice that is not a table |
| `api:Confirm(text, onYes?, onNo?)` | text, functions | the dialog | |
| `api:Prompt(text, default?, onAccept?, onCancel?)` | text, text, functions | the dialog | |
| `api:CopyBox(text, title?)` | text, title | the dialog | |
| `api:OpenMenu(items, anchor?)` | list of items, frame | `true`, or `false` when items is not a table | |
| `api:Notify(text, fields?)` | text, fields | the notification | fields given and not a table |
| `api:GetShortcut(id)` | id | the keyboard key, or `nil` | |
| `api:SetShortcut(id, key)` | id, keyboard key or `nil` | `true` when saved | id not made of letters, digits and `_` |
| `api:AfterCombat(fn)` | function | `true` when run now, `false` when waiting for the end of combat | fn is not a function |

### Errors

These are raised as written, with your addon's name in place of `MyAddon`:

- `EbonAPI: MyAddon: api:Window expects an id of letters, digits or _, got <id>`, and the same text with `api:SetShortcut`.
- `EbonAPI: MyAddon: api:Window expects a table, got <type>`
- `EbonAPI: MyAddon: scroll expects NONE, VERTICAL, HORIZONTAL or BOTH, got <value>`
- `EbonAPI: MyAddon: unknown element "<kind>" (known: <the 28 kinds>)`
- `EbonAPI: MyAddon: element "<kind>" expects a table, got <type>`
- `EbonAPI: MyAddon: a secure element cannot be created during combat`
- `EbonAPI: MyAddon: SetOrientation expects VERTICAL, HORIZONTAL, GRID, FLOW or NONE, got <value>`
- `EbonAPI: MyAddon: layout expects VERTICAL, HORIZONTAL, GRID, FLOW or NONE, got <value>`
- `EbonAPI: MyAddon: element "<kind>" does not scroll, it does not accept scroll`
- `EbonAPI: MyAddon: element "<kind>" does not handle <onClick, menu or shortcut>`
- `EbonAPI: MyAddon: element "<kind>" cannot be disabled`
- `EbonAPI: MyAddon: <field> expects a function, got <value>`, for `preClick` and every field named `on` followed by a capital, such as `onClick`
- `EbonAPI: MyAddon: <field> expects a number, got <value>`, for `min`, `max`, `step`, `spacing`, `wrap`, `padding` and `columns`
- `EbonAPI: MyAddon: columns expects a whole number of at least 1, got <value>`
- `EbonAPI: MyAddon: step expects a number above 0, got <value>`
- `EbonAPI: MyAddon: range expects min lower than max, got min <a> and max <b>`
- `EbonAPI: MyAddon: frame expects flat, small or large, got <value>`
- `EbonAPI: MyAddon: <tip or link> expects a string or a function, got <value>`
- `EbonAPI: MyAddon: tipKey expects a string, got <value>`
- `EbonAPI: MyAddon: color expects a palette color, got <value> (known: <the palette colors>)`
- `EbonAPI: MyAddon: name expects a frame name of letters, digits or _, got <value>`
- `EbonAPI: MyAddon: the frame name "<name>" is already used`
- `EbonAPI: MyAddon: shortcut expects an id of letters, digits or _, got <value>`
- `EbonAPI: MyAddon: shortcut expects a target, the shortcut name of the element it binds, got <value>`
- `EbonAPI: MyAddon: api:Dialog choices expects tables with text and value, got <value> at <index>`
- `EbonAPI: MyAddon: api:Notify expects a table, got <type>`
- `EbonAPI: MyAddon: api:Dialog expects a table, got <type>`
- `EbonAPI: MyAddon: api:AfterCombat expects a function, got <type>`

All of them are listed in [Errors](../reference/errors.md#kit).

## Limits

| | Value |
| --- | --- |
| Window and shortcut ids | letters, digits and `_` |
| Element kinds | the 28 of [Elements](../reference/elements.md) |
| `layout` | `VERTICAL`, `HORIZONTAL`, `GRID`, `FLOW`, `NONE` |
| `move` | `ALWAYS`, `SHIFT`, `HANDLE`, `NONE` |
| `combat` | `HIDE`, `FADE` |
| `scroll` | `NONE`, `VERTICAL`, `HORIZONTAL`, `BOTH` |
| Dialogs | one at a time |
| Notifications | no limit; they stack |

Sizes, gaps and colors come from the player's skin: see [Skin parameters](../reference/skin-parameters.md#kit).

!!! tip "🎮 Try it"
    Open the window of the quick example, then pick another **Skin** under **Esc → EbonAPI → Appearance** and press **Reload the interface**: your window takes the new look. Change **Language** on the **General** page: its title and its button follow at once.

## See also

- [Elements](../reference/elements.md) for the fields and methods of each kind.
- [Minimap button](minimap.md) for your button around the minimap.
- [Interface](interface.md) for your settings in the EbonAPI window.
- [Errors](../reference/errors.md#kit) for the messages of the Kit.
