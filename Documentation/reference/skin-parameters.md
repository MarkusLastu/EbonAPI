# Skin parameters

Every value a skin can set, with the values it accepts and its value in Azeroth, the default skin. Write them in a skin as nested tables that follow the path: `header.title.align` is `header = { title = { align = ... } }`. See [Skins](../guides/skins.md).

| Section | Parameters |
| --- | --- |
| [Player settings](#player-settings) | 8 |
| [Palette](#palette) | 33 |
| [Contrast](#contrast) | 7 |
| [Fonts](#fonts) | 16 |
| [Media](#media) | 15 |
| [Borders](#borders) | 15 |
| [Window](#window) | 29 |
| [Windows](#windows) | 8 |
| [Game menu](#game-menu) | 5 |
| [Header](#header) | 50 |
| [Footer](#footer) | 14 |
| [Column](#column) | 45 |
| [Page](#page) | 46 |
| [Controls](#controls) | 88 |
| [Kit](#kit) | 85 |
| [Saves](#saves) | 30 |
| [Chat](#chat) | 10 |

## Player settings

The eight parameters of the **Appearance** page. A skin gives their starting values; the player's choice passes over them, whatever the skin. See [What the player changes](../guides/skins.md#what-the-player-changes).

| Parameter | Accepts | Default |
| --- | --- | --- |
| `background` | color `0xRRGGBB` | `0x000000` |
| `accent` | color `0xRRGGBB` | `0xFFD100` |
| `scale` | number, 0.2 to 1.4 | `1` |
| `opacity` | number, 0.25 to 1 | `1` |
| `shadow` | number, 0 to 1 | `0.5` |
| `corners` | whole number, 0 to 16 | `0` |
| `tabs` | `LEFT`, `RIGHT` | `"LEFT"` |
| `locked` | `true` or `false` | `false` |

## Palette

The colors of the interface, by name. Elements, the Kit and other parameters refer to them by these names, such as `heading` or `muted`. A color may carry an alpha: `{ 0xRRGGBB, alpha }`.

| Parameter | Accepts | Default |
| --- | --- | --- |
| `palette.bg` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0xFFFFFF` |
| `palette.bgSoft` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `{ 0x0C0C1A, 0.9 }` |
| `palette.card` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `{ 0x191919, 0.6 }` |
| `palette.border` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0xFFFFFF` |
| `palette.borderDim` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0x666666` |
| `palette.button` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0x2A1A0A` |
| `palette.buttonBorder` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0x8C6E3C` |
| `palette.buttonHover` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0xFFD100` |
| `palette.buttonDisabledBorder` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `{ 0x8C6E3C, 0.4 }` |
| `palette.buttonText` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0xFFD100` |
| `palette.buttonDisabledText` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `{ 0x808080, 1 }` |
| `palette.checkbox` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0x000000` |
| `palette.checkboxBorder` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0x8C6E3C` |
| `palette.checked` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0xFFD100` |
| `palette.thumb` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0x8C6E3C` |
| `palette.selected` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0x3263CC` |
| `palette.selectedText` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0xFFFFFF` |
| `palette.text` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0xFFFFFF` |
| `palette.muted` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0x9D9D9D` |
| `palette.title` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0xFFD100` |
| `palette.heading` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0xFFD100` |
| `palette.menu` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0xFFD100` |
| `palette.shadow` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0x000000` |
| `palette.focus` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0xFFD100` |
| `palette.buttonHoverFill` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0x3A2410` |
| `palette.rowHover` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `{ 0x3263CC, 0.45 }` |
| `palette.headerBg` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `{ 0x000000, 0 }` |
| `palette.navBg` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `{ 0x000000, 0.35 }` |
| `palette.pageBg` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `{ 0x000000, 0 }` |
| `palette.footerBg` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `{ 0x000000, 0 }` |
| `palette.success` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0x40FF40` |
| `palette.caution` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `0xFF9900` |
| `palette.well` | color `0xRRGGBB`, or `{ 0xRRGGBB, alpha }` | `{ 0x0C0C1A, 0.9 }` |

## Contrast

How far EbonAPI lightens or darkens colors to keep text readable. See [What the player changes](../guides/skins.md#what-the-player-changes).

`contrast.light` and `contrast.dark` are the two greys, from 0 (black) to 1 (white), that EbonAPI uses for the text of buttons and of selected items: the lighter one when the text must stand out on a dark color, the darker one on a light color.

When a color must be lightened or darkened, it moves a share of the way toward white or black at each try. `contrast.step` is that share, from 0.01 to 1, and `contrast.attempts` is the most tries, from 1 to 200. `contrast.mutedStep` is how much more opaque `muted` becomes at each try after a change of background.

| Parameter | Accepts | Default |
| --- | --- | --- |
| `contrast.minimum` | number, 1 to 21 | `4.5` |
| `contrast.enforce` | `true` or `false` | `true` |
| `contrast.light` | number, 0 to 1 | `0.96` |
| `contrast.dark` | number, 0 to 1 | `0.04` |
| `contrast.step` | number, 0.01 to 1 | `0.15` |
| `contrast.attempts` | whole number, 1 to 200 | `30` |
| `contrast.mutedStep` | number, 0.01 to 1 | `0.05` |

## Fonts

The four font roles, `small`, `normal`, `large` and `button`, and the shadow under texts. `"game"` is the game's own font.

| Parameter | Accepts | Default |
| --- | --- | --- |
| `fonts.small.file` | font file, or `"game"` | `"game"` |
| `fonts.small.size` | whole number, 6 to 40 | `10` |
| `fonts.small.outline` | `MONOCHROME`, `NONE`, `OUTLINE`, `THICKOUTLINE` | `"NONE"` |
| `fonts.normal.file` | font file, or `"game"` | `"game"` |
| `fonts.normal.size` | whole number, 6 to 40 | `12` |
| `fonts.normal.outline` | `MONOCHROME`, `NONE`, `OUTLINE`, `THICKOUTLINE` | `"NONE"` |
| `fonts.large.file` | font file, or `"game"` | `"game"` |
| `fonts.large.size` | whole number, 6 to 40 | `16` |
| `fonts.large.outline` | `MONOCHROME`, `NONE`, `OUTLINE`, `THICKOUTLINE` | `"NONE"` |
| `fonts.button.file` | font file, or `"game"` | `"game"` |
| `fonts.button.size` | whole number, 6 to 40 | `10` |
| `fonts.button.outline` | `AUTO`, `MONOCHROME`, `NONE`, `OUTLINE`, `THICKOUTLINE` | `"AUTO"` |
| `fonts.shadow.x` | number, -4 to 4 | `1` |
| `fonts.shadow.y` | number, -4 to 4 | `-1` |
| `fonts.shadow.color` | color `0xRRGGBB` | `0x000000` |
| `fonts.shadow.alpha` | number, 0 to 1 | `1` |

## Media

The textures EbonAPI draws with, such as the plain texture of fills, the arrow of drop-downs, the icon of EbonAPI's minimap button and the icon shown when an addon has none.

| Parameter | Accepts | Default |
| --- | --- | --- |
| `media.solid` | texture path, or `""` for none | `"Interface\\Buttons\\WHITE8X8"` |
| `media.rounded` | texture path, or `""` for none | `"Interface\\Tooltips\\UI-Tooltip-Border"` |
| `media.arrow` | texture path, or `""` for none | `"Interface\\Buttons\\Arrow-Down-Up"` |
| `media.shadow` | texture path, or `""` for none | `"Interface\\AddOns\\EbonAPI\\Media\\Shadow"` |
| `media.grain` | texture path, or `""` for none | `"Interface\\AddOns\\EbonAPI\\Media\\Grain"` |
| `media.circle` | texture path, or `""` for none | `"Interface\\AddOns\\EbonAPI\\Media\\Circle"` |
| `media.chevron` | texture path, or `""` for none | `"Interface\\AddOns\\EbonAPI\\Media\\Chevron"` |
| `media.ring` | texture path, or `""` for none | `"Interface\AddOns\EbonAPI\Media\Ring.tga"` |
| `media.icons` | texture path, or `""` for none | `"Interface\AddOns\EbonAPI\Media\Icons.tga"` |
| `media.sidebar` | texture path, or `""` for none | `"Interface\\AddOns\\EbonAPI\\Media\\Sidebar"` |
| `media.error` | texture path, or `""` for none | `"Interface\\AddOns\\EbonAPI\\Media\\Error"` |
| `media.warning` | texture path, or `""` for none | `"Interface\\AddOns\\EbonAPI\\Media\\Warning"` |
| `media.icon` | texture path, or `""` for none | `"Interface\\Icons\\INV_Misc_Gear_01"` |
| `media.addonIcon` | texture path, or `""` for none | `"Interface\\Icons\\INV_Misc_QuestionMark"` |
| `media.pointer` | texture path, or `""` for none | `"Interface\\AddOns\\EbonAPI\\Media\\Pointer"` |

## Borders

The borders of frames: flat, rounded with the player's `corners`, or drawn from textures with `border.style = "TEXTURE"`.

| Parameter | Accepts | Default |
| --- | --- | --- |
| `border.size` | whole number, 1 to 8 | `1` |
| `border.round.base` | whole number, 0 to 32 | `4` |
| `border.round.small` | whole number, 2 to 64 | `10` |
| `border.round.inset` | number, 0 to 0.5 | `0.25` |
| `border.style` | `ROUND`, `TEXTURE` | `"TEXTURE"` |
| `border.large.background` | texture path, or `""` for none | `"Interface\\DialogFrame\\UI-DialogBox-Background"` |
| `border.large.edge` | texture path, or `""` for none | `"Interface\\DialogFrame\\UI-DialogBox-Border"` |
| `border.large.size` | whole number, 1 to 64 | `32` |
| `border.large.inset` | whole number, 0 to 32 | `11` |
| `border.large.tile` | whole number, 0 to 256 | `32` |
| `border.small.background` | texture path, or `""` for none | `"Interface\\Tooltips\\UI-Tooltip-Background"` |
| `border.small.edge` | texture path, or `""` for none | `"Interface\\Tooltips\\UI-Tooltip-Border"` |
| `border.small.size` | whole number, 1 to 64 | `16` |
| `border.small.inset` | whole number, 0 to 32 | `4` |
| `border.small.tile` | whole number, 0 to 256 | `16` |

## Window

The EbonAPI window: margins, layer, background texture and gradient, shadow, frosted glass, fading and sounds. When `window.glass.enabled` is `true`, `window.glass.edgeSize` is the thickness, in pixels, of the four glass edge lines, from 1 to 8.

| Parameter | Accepts | Default |
| --- | --- | --- |
| `window.padding` | whole number, 0 to 60 | `18` |
| `window.spacing` | whole number, 0 to 60 | `14` |
| `window.card.border` | palette name | `"border"` |
| `window.strata` | `BACKGROUND`, `DIALOG`, `FULLSCREEN`, `FULLSCREEN_DIALOG`, `HIGH`, `LOW`, `MEDIUM`, `TOOLTIP` | `"HIGH"` |
| `window.texture` | texture path, or `""` for none | `""` |
| `window.textureAlpha` | number, 0 to 1 | `1` |
| `window.gradient.orientation` | `HORIZONTAL`, `NONE`, `VERTICAL` | `"NONE"` |
| `window.gradient.color` | palette name | `"text"` |
| `window.gradient.from` | number, 0 to 1 | `0` |
| `window.gradient.to` | number, 0 to 1 | `0.06` |
| `window.shadow.base` | number, 0 to 64 | `4` |
| `window.shadow.spread` | number, 0 to 64 | `14` |
| `window.shadow.alphaBase` | number, 0 to 1 | `0.25` |
| `window.shadow.alphaSpread` | number, 0 to 1 | `0.5` |
| `window.shadow.x` | number, -32 to 32 | `0` |
| `window.shadow.y` | number, -32 to 32 | `0` |
| `window.shadow.level` | whole number, -8 to 0 | `-1` |
| `window.glass.enabled` | `true` or `false` | `false` |
| `window.glass.tint` | color `0xRRGGBB` | `0xFFFFFF` |
| `window.glass.darken` | number, 0 to 1 | `0.35` |
| `window.glass.milk` | number, 0 to 1 | `0.1` |
| `window.glass.grain` | number, 0 to 1 | `0.06` |
| `window.glass.sheen` | number, 0 to 1 | `0.08` |
| `window.glass.sheenHeight` | number, 0 to 1 | `0.4` |
| `window.glass.edge` | number, 0 to 1 | `0.12` |
| `window.glass.edgeSize` | whole number, 1 to 8 | `1` |
| `window.fade` | number, 0 to 2 | `0` |
| `window.sound.open` | sound file or game sound name, or `""` for none | `""` |
| `window.sound.close` | sound file or game sound name, or `""` for none | `""` |

## Windows

Which parts of the EbonAPI window open in windows of their own, and how windows snap together when the player moves them.

| Parameter | Accepts | Default |
| --- | --- | --- |
| `windows.detach.header` | `true` or `false` | `false` |
| `windows.detach.nav` | `true` or `false` | `false` |
| `windows.detach.page` | `true` or `false` | `false` |
| `windows.detach.pages` | `true` or `false` | `false` |
| `windows.detach.list` | list of texts | `{}` |
| `windows.gap` | whole number, 0 to 60 | `8` |
| `windows.snap` | whole number, 0 to 60 | `12` |
| `windows.cascade` | whole number, 0 to 120 | `24` |

## Game menu

The EbonAPI button in the game's Esc menu, and the EbonAPI page of the game's interface options.

| Parameter | Accepts | Default |
| --- | --- | --- |
| `panel.button.width` | whole number, 40 to 600 | `240` |
| `panel.button.height` | whole number, 16 to 60 | `24` |
| `panel.margin` | number, 0 to 60 | `16` |
| `panel.gap` | number, 0 to 60 | `12` |
| `gamemenu.gap` | number, 0 to 20 | `1` |

## Header

The title bar of the EbonAPI window: title, banner, version, search box, close button, history buttons, roll-up and column buttons.

| Parameter | Accepts | Default |
| --- | --- | --- |
| `header.show` | `true` or `false` | `true` |
| `header.height` | whole number, 16 to 160 | `40` |
| `header.controls` | `LEFT`, `RIGHT` | `"RIGHT"` |
| `header.title.show` | `true` or `false` | `true` |
| `header.title.x` | number, -60 to 200 | `2` |
| `header.title.y` | number, -60 to 160 | `2` |
| `header.title.align` | `CENTER`, `SIDE` | `"CENTER"` |
| `header.title.color` | palette name | `"heading"` |
| `header.title.font` | `small`, `normal`, `large` or `button` | `"normal"` |
| `header.banner.texture` | texture path, or `""` for none | `"Interface\\DialogFrame\\UI-DialogBox-Header"` |
| `header.banner.width` | whole number, 16 to 1024 | `300` |
| `header.banner.height` | whole number, 8 to 256 | `64` |
| `header.banner.y` | number, -100 to 100 | `12` |
| `header.version.show` | `true` or `false` | `false` |
| `header.version.gap` | number, 0 to 60 | `8` |
| `header.version.y` | number, -20 to 20 | `1` |
| `header.search.show` | `true` or `false` | `true` |
| `header.search.width` | whole number, 40 to 600 | `160` |
| `header.search.height` | whole number, 12 to 60 | `20` |
| `header.search.gap` | number, 0 to 60 | `10` |
| `header.search.inset` | number, 0 to 30 | `6` |
| `header.search.insetY` | number, 0 to 20 | `2` |
| `header.search.position` | `CENTER`, `CONTROLS`, `OPPOSITE` | `"CONTROLS"` |
| `header.close.show` | `true` or `false` | `true` |
| `header.close.size` | whole number, 10 to 60 | `32` |
| `header.close.y` | number, -60 to 160 | `4` |
| `header.close.brick` | brick name, slot `close` | `"native"` |
| `header.close.width` | whole number, 10 to 120 | `32` |
| `header.close.glyph` | text | `""` |
| `header.close.hover` | color `0xRRGGBB` | `0xE81123` |
| `header.close.ink` | color `0xRRGGBB` | `0x4D0000` |
| `header.inset` | number, -60 to 60 | `-14` |
| `header.spacing` | whole number, 0 to 40 | `4` |
| `header.history.show` | `true` or `false` | `false` |
| `header.history.back` | text | `"<"` |
| `header.history.forward` | text | `">"` |
| `header.history.width` | whole number, 10 to 80 | `22` |
| `header.minimize.show` | `true` or `false` | `false` |
| `header.minimize.width` | whole number, 10 to 120 | `32` |
| `header.minimize.glyph` | text | `"-"` |
| `header.minimize.color` | color `0xRRGGBB` | `0xFEBC2E` |
| `header.minimize.ink` | color `0xRRGGBB` | `0x995700` |
| `header.zoom.glyph` | text | `"+"` |
| `header.zoom.color` | color `0xRRGGBB` | `0x28C840` |
| `header.zoom.ink` | color `0xRRGGBB` | `0x006500` |
| `header.sidebar.show` | `true` or `false` | `false` |
| `header.sidebar.size` | whole number, 6 to 40 | `16` |
| `header.sidebar.width` | whole number, 10 to 120 | `22` |
| `header.rule.show` | `true` or `false` | `false` |
| `header.rule.size` | whole number, 1 to 8 | `1` |

## Footer

The status bar at the bottom of the EbonAPI window.

| Parameter | Accepts | Default |
| --- | --- | --- |
| `footer.show` | `true` or `false` | `false` |
| `footer.height` | whole number, 8 to 80 | `22` |
| `footer.version` | `true` or `false` | `true` |
| `footer.rule` | `true` or `false` | `true` |
| `footer.ruleSize` | whole number, 1 to 8 | `1` |
| `footer.inset` | number, -60 to 60 | `2` |
| `footer.refresh` | number, 0.1 to 60 | `1` |
| `footer.badge.show` | `true` or `false` | `false` |
| `footer.badge.color` | palette name | `"focus"` |
| `footer.badge.text` | palette name | `"selectedText"` |
| `footer.badge.padding` | number, 0 to 40 | `8` |
| `footer.items` | `true` or `false` | `false` |
| `footer.gap` | whole number, 0 to 60 | `10` |
| `footer.icon` | whole number, 6 to 40 | `12` |

## Column

The column of tabs of the EbonAPI window: width, frame, icon rail, tree, section titles and tabs.

| Parameter | Accepts | Default |
| --- | --- | --- |
| `nav.width` | whole number, 60 to 500 | `175` |
| `nav.inset` | whole number, 0 to 40 | `10` |
| `nav.padding` | whole number, 0 to 60 | `6` |
| `nav.divider.size` | whole number, 0 to 8 | `0` |
| `nav.divider.color` | palette name | `"borderDim"` |
| `nav.frame` | `LARGE`, `NONE`, `SMALL` | `"NONE"` |
| `nav.rail.show` | `true` or `false` | `false` |
| `nav.rail.width` | whole number, 16 to 120 | `36` |
| `nav.rail.gap` | whole number, 0 to 40 | `4` |
| `nav.rail.icon` | whole number, 8 to 80 | `20` |
| `nav.rail.spacing` | whole number, 0 to 40 | `4` |
| `nav.rail.indicator` | whole number, 0 to 8 | `2` |
| `nav.rail.color` | palette name | `"headerBg"` |
| `nav.rail.crop` | number, 0 to 0.45 | `0.08` |
| `nav.rail.indicatorColor` | palette name | `"focus"` |
| `nav.rail.desaturate` | `true` or `false` | `true` |
| `nav.rail.dim` | number, 0 to 1 | `0.6` |
| `nav.rail.filter` | `true` or `false` | `true` |
| `nav.tree.collapsible` | `true` or `false` | `false` |
| `nav.tree.expanded` | `true` or `false` | `true` |
| `nav.tree.guides` | `true` or `false` | `false` |
| `nav.tree.chevron` | whole number, 4 to 40 | `10` |
| `nav.tree.chevronColor` | palette name | `"text"` |
| `nav.tree.guideColor` | palette name | `"borderDim"` |
| `nav.tree.guideWidth` | whole number, 1 to 8 | `1` |
| `nav.tree.margin` | whole number, 0 to 20 | `2` |
| `nav.section.brick` | brick name, slot `section` | `"default"` |
| `nav.section.show` | `true` or `false` | `true` |
| `nav.section.x` | number, -20 to 60 | `2` |
| `nav.section.height` | whole number, 8 to 60 | `20` |
| `nav.section.before` | whole number, 0 to 60 | `6` |
| `nav.section.after` | whole number, 0 to 60 | `2` |
| `nav.section.upper` | `true` or `false` | `false` |
| `nav.section.color` | palette name | `"muted"` |
| `nav.section.font` | `small`, `normal`, `large` or `button` | `"small"` |
| `nav.tab.brick` | brick name, slot `tab` | `"native"` |
| `nav.tab.height` | whole number, 12 to 80 | `18` |
| `nav.tab.gap` | whole number, 0 to 40 | `1` |
| `nav.tab.indent` | whole number, 0 to 80 | `12` |
| `nav.tab.align` | `CENTER`, `LEFT`, `RIGHT` | `"LEFT"` |
| `nav.tab.bar` | whole number, 1 to 16 | `3` |
| `nav.tab.font` | `small`, `normal`, `large` or `button` | `"normal"` |
| `nav.tab.padding` | number, 0 to 60 | `8` |
| `nav.tab.glow.selected` | number, 0 to 1 | `1` |
| `nav.tab.glow.hover` | number, 0 to 1 | `0.5` |

## Page

The page of the EbonAPI window: size, title, descriptions, the layout of options, the tab strip and the path above the page, and the look of **Connected addons**.

| Parameter | Accepts | Default |
| --- | --- | --- |
| `page.width` | whole number, 200 to 1600 | `600` |
| `page.height` | whole number, 150 to 1200 | `480` |
| `page.gutter` | whole number, 0 to 60 | `16` |
| `page.top` | whole number, 0 to 200 | `46` |
| `page.title.show` | `true` or `false` | `true` |
| `page.title.y` | number, -40 to 40 | `2` |
| `page.description.show` | `true` or `false` | `true` |
| `page.description.gap` | number, 0 to 40 | `6` |
| `page.unit` | whole number, 60 to 600 | `170` |
| `page.gap.x` | whole number, 0 to 80 | `14` |
| `page.gap.y` | whole number, 0 to 80 | `12` |
| `page.addons` | `CARDS`, `LIST` | `"CARDS"` |
| `page.inset.x` | whole number, 0 to 120 | `6` |
| `page.inset.y` | whole number, 0 to 120 | `4` |
| `page.layout` | `FLOW`, `LIST` | `"FLOW"` |
| `page.descriptions` | `BOTH`, `INLINE`, `TOOLTIP` | `"TOOLTIP"` |
| `page.description.below` | number, 0 to 40 | `4` |
| `page.title.color` | palette name | `"heading"` |
| `page.title.font` | `small`, `normal`, `large` or `button` | `"large"` |
| `page.description.color` | palette name | `"text"` |
| `page.description.font` | `small`, `normal`, `large` or `button` | `"small"` |
| `page.strip.show` | `true` or `false` | `false` |
| `page.strip.height` | whole number, 10 to 80 | `26` |
| `page.strip.padding` | number, 0 to 60 | `12` |
| `page.strip.border` | whole number, 0 to 8 | `1` |
| `page.strip.color` | palette name | `"headerBg"` |
| `page.strip.tab` | palette name | `"pageBg"` |
| `page.strip.accent` | palette name | `"focus"` |
| `page.strip.text` | palette name | `"title"` |
| `page.strip.tabs` | whole number, 1 to 12 | `1` |
| `page.strip.idle` | palette name | `"headerBg"` |
| `page.strip.idleText` | palette name | `"muted"` |
| `page.strip.separator` | palette name | `"borderDim"` |
| `page.strip.close` | whole number, 0 to 40 | `16` |
| `page.strip.font` | `small`, `normal`, `large` or `button` | `"button"` |
| `page.strip.separatorWidth` | whole number, 1 to 8 | `1` |
| `page.close.size` | whole number, 10 to 60 | `32` |
| `page.close.width` | whole number, 10 to 120 | `32` |
| `page.close.gap` | number, 0 to 60 | `10` |
| `page.close.glyph` | text | `""` |
| `page.frame` | `LARGE`, `NONE`, `SMALL` | `"NONE"` |
| `page.crumbs.show` | `true` or `false` | `false` |
| `page.crumbs.height` | whole number, 8 to 60 | `20` |
| `page.crumbs.separator` | text | `">"` |
| `page.crumbs.color` | palette name | `"muted"` |
| `page.crumbs.font` | `small`, `normal`, `large` or `button` | `"small"` |

## Controls

The controls of the pages and of the Kit: tooltips, buttons, check boxes, sliders, drop-downs, menus, color swatches, text fields, headings, texts, groups and scroll bars. Each `brick` parameter chooses the brick of its slot, see [Bricks](../guides/skins.md#bricks).

| Parameter | Accepts | Default |
| --- | --- | --- |
| `widgets.disabledAlpha` | number, 0 to 1 | `0.5` |
| `widgets.tooltip.anchor` | `ANCHOR_BOTTOMLEFT`, `ANCHOR_BOTTOMRIGHT`, `ANCHOR_CURSOR`, `ANCHOR_LEFT`, `ANCHOR_RIGHT`, `ANCHOR_TOPLEFT`, `ANCHOR_TOPRIGHT` | `"ANCHOR_RIGHT"` |
| `widgets.tooltip.skinned` | `true` or `false` | `false` |
| `widgets.button.brick` | brick name, slot `button` | `"native"` |
| `widgets.button.height` | whole number, 10 to 80 | `22` |
| `widgets.button.padding` | number, 0 to 40 | `15` |
| `widgets.execute.brick` | brick name, slot `execute` | `"native"` |
| `widgets.execute.height` | whole number, 10 to 80 | `22` |
| `widgets.toggle.brick` | brick name, slot `toggle` | `"native"` |
| `widgets.toggle.height` | whole number, 10 to 80 | `26` |
| `widgets.toggle.size` | whole number, 6 to 60 | `26` |
| `widgets.toggle.mark` | number, -16 to 20 | `3` |
| `widgets.toggle.markTexture` | texture path, or `""` for none | `""` |
| `widgets.toggle.roundKnob` | `true` or `false` | `false` |
| `widgets.toggle.gap` | number, 0 to 40 | `2` |
| `widgets.toggle.margin` | number, 0 to 40 | `2` |
| `widgets.toggle.switch.width` | whole number, 10 to 120 | `28` |
| `widgets.toggle.switch.height` | whole number, 6 to 60 | `14` |
| `widgets.range.brick` | brick name, slot `range` | `"native"` |
| `widgets.range.height` | whole number, 20 to 160 | `52` |
| `widgets.range.top` | number, 0 to 60 | `16` |
| `widgets.range.bar` | whole number, 4 to 60 | `17` |
| `widgets.range.track` | whole number, 1 to 30 | `4` |
| `widgets.range.thumb.width` | whole number, 2 to 60 | `32` |
| `widgets.range.thumb.height` | whole number, 2 to 60 | `32` |
| `widgets.range.labels` | number, 0 to 30 | `3` |
| `widgets.range.edit.width` | whole number, 20 to 200 | `60` |
| `widgets.range.edit.height` | whole number, 10 to 60 | `16` |
| `widgets.range.edit.y` | number, 0 to 30 | `2` |
| `widgets.range.fill` | `true` or `false` | `false` |
| `widgets.range.fillColor` | palette name | `"checked"` |
| `widgets.range.roundThumb` | `true` or `false` | `false` |
| `widgets.select.brick` | brick name, slot `select` | `"default"` |
| `widgets.select.height` | whole number, 20 to 160 | `42` |
| `widgets.select.top` | number, 0 to 60 | `16` |
| `widgets.select.padding` | number, 0 to 40 | `8` |
| `widgets.select.arrow.size` | whole number, 4 to 40 | `12` |
| `widgets.select.arrow.right` | number, 0 to 60 | `22` |
| `widgets.select.arrow.x` | number, 0 to 40 | `6` |
| `widgets.select.arrow.y` | number, -20 to 20 | `1` |
| `widgets.menu.row` | whole number, 10 to 60 | `20` |
| `widgets.menu.gap` | whole number, 0 to 20 | `1` |
| `widgets.menu.padding` | whole number, 0 to 30 | `3` |
| `widgets.menu.inset` | number, 0 to 40 | `12` |
| `widgets.menu.offset` | number, -20 to 40 | `2` |
| `widgets.menu.strata` | `BACKGROUND`, `DIALOG`, `FULLSCREEN`, `FULLSCREEN_DIALOG`, `HIGH`, `LOW`, `MEDIUM`, `TOOLTIP` | `"FULLSCREEN_DIALOG"` |
| `widgets.menu.brick` | brick name, slot `row` | `"list"` |
| `widgets.menu.title.font` | `small`, `normal`, `large` or `button` | `"small"` |
| `widgets.menu.title.color` | palette name | `"heading"` |
| `widgets.menu.title.align` | `CENTER`, `LEFT`, `RIGHT` | `"LEFT"` |
| `widgets.color.brick` | brick name, slot `color` | `"default"` |
| `widgets.color.height` | whole number, 10 to 80 | `22` |
| `widgets.color.size` | whole number, 6 to 60 | `18` |
| `widgets.color.gap` | number, 0 to 40 | `6` |
| `widgets.color.margin` | number, 0 to 40 | `2` |
| `widgets.input.brick` | brick name, slot `input` | `"native"` |
| `widgets.input.height` | whole number, 20 to 160 | `42` |
| `widgets.input.top` | number, 0 to 60 | `16` |
| `widgets.input.field` | whole number, 10 to 80 | `20` |
| `widgets.input.padding` | number, 0 to 40 | `6` |
| `widgets.input.paddingY` | number, 0 to 20 | `2` |
| `widgets.input.line` | whole number, 8 to 40 | `14` |
| `widgets.input.lines` | whole number, 2 to 30 | `4` |
| `widgets.input.linePad` | whole number, 0 to 40 | `8` |
| `widgets.input.bottom` | whole number, 0 to 40 | `2` |
| `widgets.input.gap` | whole number, 0 to 20 | `2` |
| `widgets.heading.brick` | brick name, slot `heading` | `"default"` |
| `widgets.heading.height` | whole number, 10 to 80 | `22` |
| `widgets.heading.gap` | number, 0 to 60 | `8` |
| `widgets.heading.lines` | `AFTER`, `BOTH`, `NONE` | `"BOTH"` |
| `widgets.heading.size` | whole number, 1 to 8 | `1` |
| `widgets.heading.upper` | `true` or `false` | `false` |
| `widgets.heading.color` | palette name | `"heading"` |
| `widgets.text.brick` | brick name, slot `text` | `"default"` |
| `widgets.text.extra` | whole number, 0 to 40 | `4` |
| `widgets.group.brick` | brick name, slot `group` | `"card"` |
| `widgets.group.padding` | whole number, 0 to 60 | `12` |
| `widgets.group.title` | whole number, 0 to 80 | `18` |
| `widgets.group.titleX` | number, -20 to 60 | `2` |
| `widgets.group.upper` | `true` or `false` | `false` |
| `widgets.group.color` | palette name | `"heading"` |
| `widgets.group.font` | `small`, `normal`, `large` or `button` | `"normal"` |
| `widgets.group.frame` | `FLAT`, `LARGE`, `SMALL` | `"SMALL"` |
| `widgets.scroll.brick` | brick name, slot `scroll` | `"default"` |
| `widgets.scroll.width` | whole number, 1 to 40 | `6` |
| `widgets.scroll.thumb` | whole number, 4 to 200 | `40` |
| `widgets.scroll.step` | whole number, 1 to 400 | `40` |
| `widgets.scroll.trackAlpha` | number, 0 to 1 | `1` |

## Kit

Sizes and colors of the [Kit](../guides/kit.md): margins, icons, badges, progress bars, lists, tables, notifications, charts, dialogs, minimap buttons, models and combat fading.

| Parameter | Accepts | Default |
| --- | --- | --- |
| `kit.padding` | whole number, 0 to 40 | `8` |
| `kit.spacing` | whole number, 0 to 40 | `6` |
| `kit.inset` | whole number, 0 to 20 | `4` |
| `kit.gap` | whole number, 0 to 20 | `2` |
| `kit.columns` | whole number, 1 to 20 | `4` |
| `kit.wrap` | whole number, 40 to 2000 | `320` |
| `kit.text.font` | `small`, `normal`, `large` or `button` | `"small"` |
| `kit.bar.color` | palette name | `"card"` |
| `kit.bar.border` | palette name | `"borderDim"` |
| `kit.header` | whole number, 12 to 60 | `30` |
| `kit.control` | whole number, 8 to 60 | `22` |
| `kit.icon.size` | whole number, 12 to 96 | `32` |
| `kit.icon.inset` | whole number, 0 to 12 | `2` |
| `kit.icon.trim` | number, 0 to 0.2 | `0.08` |
| `kit.icon.color` | palette name | `"checkbox"` |
| `kit.icon.border` | palette name | `"buttonBorder"` |
| `kit.icon.hover` | palette name | `"buttonHover"` |
| `kit.icon.checked` | palette name | `"checked"` |
| `kit.badge.size` | whole number, 6 to 40 | `14` |
| `kit.badge.level` | whole number, 1 to 10 | `3` |
| `kit.badge.color` | palette name | `"focus"` |
| `kit.badge.text` | palette name | `"selectedText"` |
| `kit.progress.height` | whole number, 4 to 60 | `14` |
| `kit.progress.color` | palette name | `"checked"` |
| `kit.progress.background` | palette name | `"bgSoft"` |
| `kit.progress.border` | palette name | `"borderDim"` |
| `kit.row` | whole number, 10 to 60 | `20` |
| `kit.slot` | whole number, 10 to 80 | `24` |
| `kit.indent` | whole number, 0 to 60 | `12` |
| `kit.list` | whole number, 40 to 800 | `200` |
| `kit.scroll.width` | whole number, 40 to 2000 | `320` |
| `kit.scroll.height` | whole number, 40 to 2000 | `240` |
| `kit.table.row` | whole number, 10 to 60 | `18` |
| `kit.table.sort` | whole number, 4 to 24 | `8` |
| `kit.table.column` | whole number, 10 to 200 | `20` |
| `kit.table.selected` | palette name | `"selected"` |
| `kit.table.hover` | palette name | `"rowHover"` |
| `kit.toast.width` | whole number, 100 to 600 | `260` |
| `kit.toast.duration` | number, 1 to 30 | `4` |
| `kit.toast.top` | whole number, 0 to 600 | `120` |
| `kit.toast.icon` | whole number, 12 to 64 | `24` |
| `kit.toast.fade` | number, 0 to 5 | `0.5` |
| `kit.drag` | whole number, 0 to 60 | `12` |
| `kit.ghost.width` | whole number, 20 to 600 | `170` |
| `kit.ghost.color` | palette name | `"selected"` |
| `kit.ghost.border` | palette name | `"focus"` |
| `kit.handle` | whole number, 6 to 40 | `12` |
| `kit.dot.color` | palette name | `"thumb"` |
| `kit.dot.hover` | palette name | `"buttonHover"` |
| `kit.pointer` | whole number, 16 to 160 | `48` |
| `kit.aim.every` | number, 0.01 to 1 | `0.05` |
| `kit.timer.every` | number, 0.01 to 1 | `0.1` |
| `kit.timer.font` | `small`, `normal`, `large` or `button` | `"small"` |
| `kit.chart.color` | palette name | `"checked"` |
| `kit.chart.height` | whole number, 20 to 400 | `60` |
| `kit.chart.background` | palette name | `"bgSoft"` |
| `kit.chart.border` | palette name | `"borderDim"` |
| `kit.dialog.width` | whole number, 160 to 800 | `320` |
| `kit.dialog.copy` | whole number, 20 to 400 | `80` |
| `kit.dialog.button` | whole number, 20 to 200 | `80` |
| `kit.dialog.choices` | whole number, 1 to 20 | `6` |
| `kit.dialog.offset` | number, -600 to 600 | `120` |
| `kit.dialog.field.color` | palette name | `"bgSoft"` |
| `kit.dialog.field.border` | palette name | `"borderDim"` |
| `kit.dialog.title.font` | `small`, `normal`, `large` or `button` | `"normal"` |
| `kit.dialog.title.color` | palette name | `"heading"` |
| `kit.dialog.title.align` | `CENTER`, `LEFT`, `RIGHT` | `"CENTER"` |
| `kit.minimap.brick` | brick name, slot `minimap` | `"native"` |
| `kit.minimap.size` | whole number, 16 to 48 | `31` |
| `kit.minimap.inset` | whole number, 0 to 16 | `4` |
| `kit.minimap.ring` | whole number, 0 to 12 | `2` |
| `kit.minimap.offset` | number, -40 to 60 | `10` |
| `kit.minimap.corner` | number, 0 to 40 | `10` |
| `kit.minimap.angle` | number, 0 to 360 | `225` |
| `kit.minimap.group.angle` | number, 0 to 360 | `245` |
| `kit.minimap.group.columns` | whole number, 1 to 12 | `4` |
| `kit.model.width` | whole number, 40 to 800 | `160` |
| `kit.model.height` | whole number, 40 to 800 | `220` |
| `kit.model.turn` | number, 0 to 1 | `0.02` |
| `kit.model.zoom.step` | number, 0 to 2 | `0.25` |
| `kit.model.zoom.min` | number, -10 to 0 | `-1` |
| `kit.model.zoom.max` | number, 0 to 10 | `3` |
| `kit.combatAlpha` | number, 0 to 1 | `0.3` |
| `kit.animation` | number, 0 to 2 | `0.15` |
| `kit.rescale.delay` | number, 0 to 1 | `0.01` |

## Saves

The `saves` element of the Kit ([Kit](../guides/kit.md#saves)): a list of saved items drawn as rows, square cells or gauges, with a drawer for the chosen one. A skin that sets none of them inherits them from its parent. `view` and `detail` are only the starting values; the player's own choice, which the addon keeps, wins over them. In the grid the drawer is always docked. `search` keeps the search field open. `row.*` dresses the rows of the list and the gauges (`row.hover` is the hovered row, `row.selected` the chosen one), `cell.*` the cells of the grid, `group.*` the titles and the card around the items of a group (`group.upper` writes the titles in capitals), `drawer.*` the drawer. The ring of a state takes `owned` for the share acquired, `now` for the share a click would activate (and for an active save) and `later` for the lightning bolt of a progressive save; `ring.size` is the ring of a row and `ring.big` that of the drawer.

| Parameter | Accepts | Default |
| --- | --- | --- |
| `widgets.saves.brick` | brick `saves`: `default` | "default" |
| `widgets.saves.view` | `list`, `grid` or `gauge` | "grid" |
| `widgets.saves.detail` | `inline` or `dock` | "dock" |
| `widgets.saves.search` | `true` or `false` | `false` |
| `widgets.saves.width` | whole number, 160 to 400 | `240` |
| `widgets.saves.font` | `small`, `normal`, `large` or `button` | "normal" |
| `widgets.saves.small.font` | `small`, `normal`, `large` or `button` | "small" |
| `widgets.saves.row.height` | whole number, 20 to 48 | `28` |
| `widgets.saves.row.gap` | whole number, 0 to 10 | `2` |
| `widgets.saves.row.frame` | `FLAT`, `LARGE`, `SMALL` | "FLAT" |
| `widgets.saves.row.fill` | palette name | "well" |
| `widgets.saves.row.border` | palette name | "borderDim" |
| `widgets.saves.row.hover` | palette name | "rowHover" |
| `widgets.saves.row.selected` | palette name | "selected" |
| `widgets.saves.cell.size` | whole number, 36 to 80 | `50` |
| `widgets.saves.cell.gap` | whole number, 0 to 12 | `5` |
| `widgets.saves.cell.frame` | `FLAT`, `LARGE`, `SMALL` | "SMALL" |
| `widgets.saves.cell.fill` | palette name | "card" |
| `widgets.saves.group.frame` | `FLAT`, `LARGE`, `SMALL` | "FLAT" |
| `widgets.saves.group.fill` | palette name | "card" |
| `widgets.saves.group.color` | palette name | "heading" |
| `widgets.saves.group.upper` | `true` or `false` | `false` |
| `widgets.saves.drawer.frame` | `FLAT`, `LARGE`, `SMALL` | "SMALL" |
| `widgets.saves.drawer.fill` | palette name | "well" |
| `widgets.saves.drawer.border` | palette name | "borderDim" |
| `widgets.saves.owned` | palette name | "heading" |
| `widgets.saves.now` | palette name | "success" |
| `widgets.saves.later` | palette name | "caution" |
| `widgets.saves.ring.size` | whole number, 12 to 32 | `18` |
| `widgets.saves.ring.big` | whole number, 24 to 64 | `38` |

## Chat

The colors of the chat lines EbonAPI prints. Addons read them, as color codes, in `EbonAPI.Log.COLOR`.

| Parameter | Accepts | Default |
| --- | --- | --- |
| `chat.prefix` | color `0xRRGGBB` | `0x8A6FD4` |
| `chat.text` | color `0xRRGGBB` | `0xD1D1F6` |
| `chat.error` | color `0xRRGGBB` | `0xFF4444` |
| `chat.warn` | color `0xRRGGBB` | `0xFF9900` |
| `chat.success` | color `0xRRGGBB` | `0x40FF40` |
| `chat.highlight` | color `0xRRGGBB` | `0xFFD200` |
| `chat.muted` | color `0xRRGGBB` | `0x9090A0` |
| `chat.gold` | color `0xRRGGBB` | `0xFFD700` |
| `chat.silver` | color `0xRRGGBB` | `0xC7C7CF` |
| `chat.copper` | color `0xRRGGBB` | `0xEDA55F` |
