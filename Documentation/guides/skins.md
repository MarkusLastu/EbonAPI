# 🎨 Skins

Change the whole look of the interface in one Lua file: colors, fonts, sizes, textures and sounds. The EbonAPI window and every window built with the Kit follow it. The player picks the skin under **Appearance**.

## What it does

- A skin sets **skin parameters**. Each color, dimension, font, texture and sound has a named skin parameter; [Skin parameters](../reference/skin-parameters.md) is the complete catalog.
- A skin can start from another one, its **parent**, and change only what it wants.
- A skin can replace the **bricks** the interface is built from: the buttons, the tabs, the check boxes, the sliders.
- The player picks a skin under **Esc → EbonAPI → Appearance**. The EbonAPI window, the pages of the addons, and every window built with the [Kit](kit.md) take its look.

Seven skins come with EbonAPI. **Azeroth** is the default and looks like the game's own windows. **AutoCallboard** starts from Azeroth. **Midnight**, **Split**, **VSCode**, **Porcelain** and **Tiling** start from AutoCallboard.

## Quick example

```lua title="Interface/AddOns/EbonAPI/Skins/Night/Night.lua"
EbonAPI:RegisterSkin("Night", {
  parent = "AutoCallboard",
  accent = 0x3FA7F5,
  palette = {
    heading = 0x3FA7F5,
    border = { 0x3FA7F5, 0.6 },
  },
  header = {
    height = 32,
    title = { align = "SIDE" },
  },
})
```

```xml title="Interface/AddOns/EbonAPI/Skins/Skins.xml"
<Script file="Night\Night.lua"/>
```

Add the `Script` line to `Skins.xml`, next to the ones that are already there. Open **Esc → EbonAPI → Appearance**, choose **Night** under **Skin** and press **Reload the interface**.

## How it works

### The skin file

A skin lives in its own folder of `Interface/AddOns/EbonAPI/Skins`, named after the skin, with its Lua file and its media. `Skins/Skins.xml` lists the skin files, one `<Script file="Name\Name.lua"/>` line per skin.

The file calls `EbonAPI:RegisterSkin(name, values)` once. The name is the one the player sees in the list; two skins cannot share it.

### Values

The table holds skin parameters, written as nested tables that follow their path. These two skins set the same skin parameter, `header.title.align`:

```lua
EbonAPI:RegisterSkin("A", { header = { title = { align = "SIDE" } } })
EbonAPI:RegisterSkin("B", { ["header.title.align"] = "SIDE" })
```

Two keys are not skin parameters: `parent` and `bricks`. Every other key is a skin parameter name, or the start of one.

Skin parameter names are in English and never translated. [Skin parameters](../reference/skin-parameters.md) lists all 504 skin parameters, with the values each one accepts and its value in the default skin.

| Kind | Written as |
| --- | --- |
| color | `0xRRGGBB`, such as `0x3FA7F5`, from `0x000000` to `0xFFFFFF` |
| palette color | `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` with an alpha from 0 to 1 |
| number | a number between the bounds of the parameter; some take whole numbers only |
| choice | one of the words listed for the parameter, such as `"LEFT"` |
| true or false | `true` or `false` |
| palette name | the name of a palette color, such as `"heading"` |
| font role | `"small"`, `"normal"`, `"large"` or `"button"` |
| font | a font file, or `"game"` for the game's font |
| texture | a texture path, or `""` for none |
| sound | a sound file, a game sound name, or `""` for none |
| brick | the name of a brick, see [Bricks](#bricks) |
| list | a list of texts |
| text | any text |

**Media.** A font, texture or sound file named without a backslash is looked for in the skin's folder: `"Night.ttf"` in the skin `Night` is `Interface\AddOns\EbonAPI\Skins\Night\Night.ttf`. A path with a backslash, such as `"Interface\\Buttons\\WHITE8X8"`, is used as it is. So is the name of a game sound, which has no dot.

A skin with a value that does not fit is refused. Every problem is reported, nothing of the skin is registered, and `EbonAPI:RegisterSkin` returns `false`. The name stays free, so you can register the corrected table under the same name. The messages are listed in [Errors](../reference/errors.md#skins).

### Parents

`parent` names the skin to start from. Every skin parameter and every brick the skin does not set comes from its parent, then from the parent's parent, and at last from the default skin, Azeroth. Without `parent`, a skin starts from Azeroth.

The parent has to exist when the skin is applied. A parent that does not exist, or parents that lead back to each other, are reported and the default skin fills the gaps.

### What the player changes

Eight parameters belong to the player. The **Appearance** page has a control for each one:

| Parameter | Control in **Appearance** |
| --- | --- |
| `background` | **Background**, under **Colors** |
| `accent` | **Accent**, under **Colors** |
| `scale` | **Interface scale**, under **Windows** |
| `opacity` | **Background opacity**, under **Windows** |
| `shadow` | **Shadow under windows**, under **Windows** |
| `corners` | **Corners**, under **Windows** |
| `tabs` | **Tabs**, under **Layout** |
| `locked` | **Lock positions**, under **Layout** |

A skin gives their starting values. When the player changes one, the player's value wins over the skin's. The **Defaults** button gives the skin's values back; the addons then apply their own values again. Your addon reads these values with `api:GetParameter`, see [Interface](interface.md#parameters).

The palette follows the background, the accent and the opacity:

| The player changes | Palette colors |
| --- | --- |
| `background` | the background colors take it: `bg`, `bgSoft`, `card`, `checkbox`, `headerBg`, `navBg`, `pageBg`, `footerBg`; `text`, `muted` and `title` turn white or black, whichever reads better on it |
| `accent` | every other color takes the new accent, with the same brightness it had against the skin's accent, except `shadow`, `success` and `selectedText`, which do not change; `buttonText` and `buttonDisabledText` take the grey of `contrast.light` |
| `opacity` | the background colors `bg`, `bgSoft`, `card`, `headerBg`, `navBg`, `pageBg` and `footerBg` become more or less transparent |

The same rules apply to the values the skin itself sets. When your skin sets `background`, `accent` or `opacity` to something other than its parent does, the palette colors it inherits from that parent follow your values. A palette color your skin sets itself stays as written.

While `contrast.enforce` is `true`, EbonAPI lightens or darkens colors until they reach a contrast of `contrast.minimum` against what they are read on, 4.5 to 1 by default: `button` and `buttonHoverFill` against `buttonText`, `selected` against `selectedText`, and `menu` against black. Once the player changed the background or the accent, it does the same for `heading`, `buttonHover`, `checked`, `thumb`, `focus` and `success` against the background. After a change of background, `muted` becomes more opaque until it reads well.

### Bricks

The interface is built from bricks, one kind per **slot**. Each slot has a parameter that names the brick to use:

| Slot | Chosen by | Bricks that come with EbonAPI | Used by Azeroth |
| --- | --- | --- | --- |
| `close` | `header.close.brick` | `default`, `flat` | `native` |
| `section` | `nav.section.brick` | `default` | `default` |
| `tab` | `nav.tab.brick` | `fill`, `bar`, `text`, `list` | `native` |
| `button` | `widgets.button.brick` | `default` | `native` |
| `execute` | `widgets.execute.brick` | `default` | `native` |
| `toggle` | `widgets.toggle.brick` | `box`, `switch` | `native` |
| `range` | `widgets.range.brick` | `default` | `native` |
| `select` | `widgets.select.brick` | `default` | `default` |
| `row` | `widgets.menu.brick` | `fill`, `list` | `list` |
| `color` | `widgets.color.brick` | `default` | `default` |
| `input` | `widgets.input.brick` | `default` | `native` |
| `heading` | `widgets.heading.brick` | `default` | `default` |
| `text` | `widgets.text.brick` | `default` | `default` |
| `saves` | `widgets.saves.brick` | `default` | `default` |
| `group` | `widgets.group.brick` | `card`, `plain`, `line` | `card` |
| `scroll` | `widgets.scroll.brick` | `default` | `default` |
| `minimap` | `kit.minimap.brick` | `flat` | `native` |

The `native` bricks are Azeroth's own; a skin that starts from Azeroth can choose them by name. A skin also reaches the bricks of its parents by name. Porcelain adds `lights` to the `close` slot.

The `saves` slot is the whole `saves` element of the [Kit](kit.md#saves): the brick is the widget itself, and `default` builds the one that EbonAPI draws from the `widgets.saves.*` parameters, which most skins only tune. The view a skin sets is the starting one; the player's choice, which your addon keeps, wins over it.

#### Your own bricks

A skin adds bricks under `bricks`, by slot and by name, and chooses them with the slot's parameter:

```lua
EbonAPI:RegisterSkin("Glass", {
  parent = "AutoCallboard",
  widgets = { button = { brick = "glass" } },
  bricks = {
    button = {
      glass = function(parent, B)
        local button = B.baseButton(parent, function(self)
          local key = self.disabledState and "muted" or (self.hovered and "buttonHover" or "text")

          B.paint(self.label, "SetTextColor", key)
          B.labelFont(self, key)
        end)
        local fill = button:CreateTexture(nil, "BACKGROUND")

        fill:SetTexture(B.media("solid"))
        fill:SetAllPoints(button)
        B.paint(fill, "SetVertexColor", "card")
        button:Visual()

        return button
      end,
    },
  },
})
```

A brick is a function `(parent, B)` that builds a widget on `parent` and returns it. `B` holds the helpers below. The widget must have every method and field of its slot; EbonAPI sets the callbacks and the widget calls them when the player acts. A brick that raises an error, returns something that is not a widget, or returns a widget that misses a method or a field is reported, and the brick of the default skin takes its place. The same happens when a parameter names a brick that no skin provides. Each brick is reported once.

| Slot | Methods | Fields | The widget calls |
| --- | --- | --- | --- |
| `button`, `execute` | `SetLabel(text)`, `SetSelected(state)`, `SetDisabledState(state)`, `TextWidth()`, `Fit(width)` | `label` | `self.onClick(self, mouseButton)` when clicked while not disabled |
| `tab` | the same, and `SetPadding(padding)` | `label` | `self.onClick(self, mouseButton)` |
| `close` | `SetLabel(text)`, `SetSelected(state)`, `SetDisabledState(state)`, `TextWidth()` | `label` | `self.onClick(self, mouseButton)`; it may also call `self.onShade(self)`, which rolls the window up |
| `row` | `SetLabel(text)`, `SetSelected(state)`, `SetDisabledState(state)`, `TextWidth()`, `SetTextKey(name)` | `label` | `self.onClick(self, mouseButton)` |
| `section` | `SetLabel(text)` | | |
| `toggle` | `SetLabel(text)`, `SetValue(value)`, `SetDisabledState(state)`, `TextWidth()` | | `self.onToggle(value)` after the player changes it |
| `range` | `SetTitle(text)`, `SetRange(min, max, step, percent)`, `SetValue(value)`, `SetDisabledState(state)`, `SetFormat(fn)` | | `self.onCommit(value)` when the player sets a value |
| `select` | `SetTitle(text)`, `SetItems(items)`, `SetValue(key)`, `SetDisabledState(state)` | | `self.onPick(key)` |
| `color` | `SetLabel(text)`, `SetColor(r, g, b, a)`, `SetDisabledState(state)`, `TextWidth()` | | `self.onPick(r, g, b, a)` |
| `input` | `SetTitle(text)`, `SetLines(count)`, `SetValue(text)`, `SetDisabledState(state)` | | `self.onCommit(text)` when the player validates the text or leaves the field |
| `heading` | `SetLabel(text)` | | |
| `text` | `SetContent(text, width, size, color)` | | |
| `saves` | `SetModel(model)`, `SetView(view)`, `SetDetail(detail)`, `SetSort(sort, grouped)`, `SetStatus(text, kind)`, `SetHeight(height)`, `SetWidth(width)`, `Select(id)`, `Selected()`, `Refresh()`, `PreferredWidth()` | | `self.spec.onActivate(id)`, `onMode(id)`, `onMenu(id, anchor)`, `onGroupMenu(groupId, anchor)`, `onHover(id, frame)`, `onLeave()`, `onNew()`, `onSelect(id)`, `onView(view)`, `onSort(sort, grouped)`, each only when `self.spec` has it (the Kit sets `spec` and `owner`) |
| `group` | `SetLabel(text)`, `SetInnerHeight(height)` | `box`, the frame that holds the content | |
| `scroll` | `SetMode(mode)`, `SetView(width, height)`, `SetContentHeight(height)`, `SetContentWidth(width)`, `Offset()`, `SetOffset(value)`, `HorizontalOffset()`, `SetHorizontalOffset(value)`, `Wheel(delta, horizontal)` | `child`, the scrolled frame; `bar`, `hbar`, the two bars | |
| `minimap` | | `icon` | |

What the methods mean:

- `TextWidth()` returns the width the widget needs for its text, in pixels. `Fit(width)` sets the width of a button; without a width, it uses `TextWidth()`. `SetPadding(padding)` sets the space between the edge of a tab and its label.
- `SetItems(items)` receives a list of tables, each with a `key`, the `text` to show, and `disabled = true` for a greyed one. `SetValue(key)` shows the text of the item that has this key, and `onPick(key)` gives back the key of the chosen one. `SetItems(items)` also refreshes the text shown for the current value, so `SetValue(key)` may come before `SetItems(items)`.
- `SetTextKey(name)` gives the label a palette color, or the usual one with `nil`.
- `SetRange(min, max, step, percent)` sets the bounds of a slider; with `percent` set, values show as percentages. `SetFormat(fn)` gives a function that turns a value into the text shown. The number field shows up to six decimals, without trailing zeros. `SetValue(value)` rounds the value to the step, counted from `min`, and keeps it between `min` and `max`; `SetRange` does the same to the value the widget holds. Neither calls `onCommit`. A value the player types is rounded and kept in the range before `onCommit` receives it, and a disabled range ignores what is typed. When the function given to `SetFormat` raises an error, `EbonAPI: range formatter failed: <error>` is reported once, and the value shows with the usual rules.
- `SetContent(text, width, size, color)` fills a `text` brick and returns its height. `size` is `"small"`, `"medium"` or `"large"`; `color` is a palette name.
- `SetMode(mode)` of a `scroll` brick takes `"VERTICAL"`, `"HORIZONTAL"` or `"BOTH"`, and raises `EbonAPI: the scroll brick expects VERTICAL, HORIZONTAL or BOTH, got <mode>` for anything else. `Wheel(delta, horizontal)` returns `true` when the widget used the mouse wheel. A scroll that is frozen passes the wheel to the scroll that holds it, and returns `true` when there is none.
- A `minimap` brick receives the minimap button itself instead of a parent, dresses it and returns it.

#### Helpers

| Helper | Does |
| --- | --- |
| `B.build(slot, name, parent)` | builds a brick that comes with EbonAPI, to change its look and return it; raises `EbonAPI: Bricks.build: no built-in brick "<name>" for slot "<slot>"` for another name |
| `B.baseButton(parent, visual)` | a button that already has the methods and the `label` of the button slots and calls `onClick`; `visual(button)` runs at every change and reads `button.hovered`, `button.selectedState`, `button.disabledState` and `button.textKey`; `button:Visual()` runs it |
| `B.toggleRow(parent, build)` | a check box row with its label; `build(row)` creates the box and returns it with its width |
| `B.value(key)` | the value of a parameter for the skin in use |
| `B.media(name)` | the texture of `media.<name>`, such as `B.media("solid")` |
| `B.paint(region, method, name)` | calls `region:method(r, g, b, a)` with a palette color, and again each time the palette changes |
| `B.unpaint(region, method)` | stops following the palette |
| `B.font(text, role, outline?)` | sets the font of the text `text` from the font role `role`: `"small"`, `"normal"`, `"large"` or `"button"`; `outline` replaces the role's outline |
| `B.labelFont(button, name)` | the font of the button's label; with the outline `AUTO`, the label is outlined when its color is light |
| `B.unframe(frame)` | removes the border and background a brick put on a frame |
| `B.enterTip(widget)`, `B.hideTip()` | show and hide the tooltip EbonAPI gave the widget |

### Choosing a skin

The player picks the skin under **Esc → EbonAPI → Appearance → Skin**, for the whole account. The list shows the default skin first, then the others in alphabetical order. The new skin applies at the next reload of the interface: the page says `The skin "<name>" applies at the next interface reload.` and shows the **Reload the interface** button next to the list. When the chosen skin is no longer installed, the default skin applies. With **Trace** on, kind `skin` shows `skin <name> is not installed, Azeroth applies`, where `<name>` is the skin that was saved.

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `EbonAPI:RegisterSkin(name, values)` | skin name, table | `true`, or `false` when something in the table did not fit and the skin was refused | name not a non-empty string, values not a table, name already taken |

The parameters the player changes are read with `api:GetParameter`, see [Interface](interface.md#api).

## Events

| Event | Arguments | Sticky | When |
| --- | --- | --- | --- |
| `PARAMETER_CHANGED` | name, value | no | the player changed one of the eight parameters, or pressed **Defaults**; it is not sent when the skin changes. See [Interface](interface.md#api) |

## Limits

| | Value |
| --- | --- |
| Skin parameters | 504, listed in [Skin parameters](../reference/skin-parameters.md) |
| Palette colors | 33 |
| Brick slots | 17 |
| Parameters the player changes | 8 |
| Color | a whole number from `0x000000` to `0xFFFFFF`; the alpha of a palette color, from 0 to 1 |
| `contrast.minimum` | 1 to 21, 4.5 in Azeroth |
| Skins | one name each |

!!! tip "🎮 Try it"
    Open **Esc → EbonAPI → Appearance**. Choose **Night** under **Skin**, press **Reload the interface** and look at the EbonAPI window. Then change **Accent** under **Colors**: the window repaints at once, and the player's choice passes over your skin's. **Defaults** gives the skin's accent back.

## See also

- [Skin parameters](../reference/skin-parameters.md) for every parameter.
- [Errors](../reference/errors.md#skins) for what a skin can get wrong.
- [Interface](interface.md) for the eight parameters your own windows can read.
- [Kit](kit.md) for the windows that follow the skin.
