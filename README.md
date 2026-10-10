# Azure UI

A clean, animated UI library for Roblox. Dark theme, smooth tweens, and a built-in loading screen.

**Version:** 4.1 · **Author:** Noxi

## Features

- Compact loading card with spinner, progress bar and status steps
- Animated window: pop-in, drag, collapse to header, fade-out on close
- Sliding sidebar highlight and fading tab pages
- Elements: Toggle, Slider, Button, Input, Dropdown, Keybind, Paragraph, Label, Section, Divider
- Notifications with a countdown bar, click to dismiss
- Touch and mouse support
- Fully themeable via `Azure.Theme`

## Installation

Load the script however you host it:

```lua
local Azure = loadstring(game:HttpGet("YOUR_URL_HERE"))()
```

Or paste `Azure.lua` into a ModuleScript and `require` it.

## Quick start

```lua
local Azure = loadstring(game:HttpGet("YOUR_URL_HERE"))()

local Window = Azure:CreateWindow({
    Title = "Azure",
    ToggleKey = Enum.KeyCode.RightShift,
})

local Main = Window:CreateTab({ Name = "Main" })

Main:CreateSection("Player")

Main:CreateToggle({
    Name = "Godmode",
    Desc = "Take no damage",
    CurrentValue = false,
    Callback = function(value) print("Godmode:", value) end,
})

Main:CreateSlider({
    Name = "WalkSpeed",
    Range = {16, 100},
    Increment = 1,
    CurrentValue = 16,
    Suffix = " sp",
    Callback = function(value) print(value) end,
})

Main:CreateButton({
    Name = "Say hello",
    Callback = function()
        Azure:Notify({ Title = "Azure", Content = "Hello!", Type = "Success" })
    end,
})
```

## Window

```lua
local Window = Azure:CreateWindow({
    Title     = "Azure",                    -- window title
    Width     = 560,                        -- default 560
    Height    = 460,                        -- default 460
    ToggleKey = Enum.KeyCode.RightShift,    -- show/hide key (optional)
    Loading   = true,                       -- true (default), false, or a table
})
```

### Loading screen

On by default. Pass `false` to skip it, or a table to customise it:

```lua
Loading = {
    Title    = "Azure",
    Subtitle = "Starting up",                       -- optional
    Duration = 3,                                   -- seconds, default 2.4
    Steps    = { "Initializing", "Loading", "Ready" },
}
```

You can also show it by itself:

```lua
local loader = Azure:Load({ Title = "My Script", Duration = 2 })
loader.Finished:Wait()
```

### Window methods

| Method | Description |
| --- | --- |
| `Window:CreateTab({ Name })` | Adds a tab and returns it. The first tab is selected automatically. |
| `Window:SelectTab(tab)` | Switches to a tab. |
| `Window:Toggle(state?)` | Shows or hides the window. Omit `state` to flip it. |
| `Window:SetTitle(text)` | Changes the title. |
| `Window:Notify(opts)` | Same as `Azure:Notify`. |
| `Window:Destroy()` | Animates out and cleans up everything. |

The header has a collapse button (`-`) that shrinks the window to its title bar, and a close button (`x`).

## Elements

All elements are created on a tab: `Tab:CreateX(config)`. Each one returns a table with `Instance` and, where it makes sense, `Set` and `Get`.

### Section / Divider

```lua
Tab:CreateSection("Combat")
Tab:CreateDivider()
```

### Label

```lua
local label = Tab:CreateLabel({
    Text       = "Hello",
    Color      = Color3.fromRGB(255, 255, 255),   -- optional
    Update     = function() return os.date("%X") end,  -- optional, polled
    UpdateRate = 1,                                    -- seconds, default 1
})
label.Set("New text")
```

### Paragraph

```lua
local p = Tab:CreateParagraph({ Title = "About", Content = "Some longer text that wraps." })
p.Set("Updated content")
```

### Button

```lua
local btn = Tab:CreateButton({
    Name = "Click me",
    Callback = function() print("clicked") end,
})
btn.SetText("Clicked!")
```

### Toggle

```lua
local toggle = Tab:CreateToggle({
    Name = "Enabled",
    Desc = "Optional description",
    CurrentValue = false,
    Callback = function(state) print(state) end,
})
toggle.Set(true)        -- fires the callback
toggle.Set(true, true)  -- silent, no callback
print(toggle.Get())
```

### Slider

```lua
local slider = Tab:CreateSlider({
    Name = "FOV",
    Range = {30, 120},
    Increment = 1,          -- decimals work too, e.g. 0.1
    CurrentValue = 70,
    Suffix = "°",
    Callback = function(value) print(value) end,
})
slider.Set(90)
```

### Input

```lua
local input = Tab:CreateInput({
    Name = "Username",
    Placeholder = "Type here...",
    CurrentValue = "",
    Numeric = false,                  -- only allow numbers
    ClearTextAfterFocusLost = false,
    Callback = function(text, enterPressed) print(text, enterPressed) end,
})
```

### Dropdown

```lua
local dropdown = Tab:CreateDropdown({
    Name = "Team",
    Options = { "Red", "Blue", "Green" },
    CurrentValue = "Red",
    Callback = function(option) print(option) end,
})
dropdown.Set("Blue")
dropdown.Refresh({ "One", "Two", "Three" })   -- replace the options
```

The list opens inline and pushes the elements below it down.

### Keybind

```lua
local bind = Tab:CreateKeybind({
    Name = "Fly",
    CurrentKeybind = Enum.KeyCode.F,
    Callback  = function(key) print("pressed", key.Name) end,   -- when the key is pressed
    OnChanged = function(key) print("rebound to", key) end,     -- when the user rebinds (nil if cleared)
})
```

Click the key button to rebind. Press `Escape` while listening to clear it.

## Notifications

```lua
Azure:Notify({
    Title    = "Azure",
    Content  = "Something happened",
    Type     = "Info",     -- "Info" (default), "Success", "Warning", "Error"
    Duration = 4,          -- seconds
})
```

Click a notification to dismiss it early. `Azure:Notify` returns `{ Instance, Dismiss }`.

## Theming

Edit `Azure.Theme` before creating a window:

```lua
Azure.Theme.Accent = Color3.fromRGB(80, 170, 255)
Azure.Theme.AccentDim = Color3.fromRGB(50, 110, 180)
```

Available keys: `Background`, `Surface`, `SurfaceAlt`, `SurfaceHigh`, `Stroke`, `StrokeHigh`, `Accent`, `AccentDim`, `Text`, `TextMuted`, `TextDim`, `Success`, `Warning`, `Error`.

Fonts live in `Azure.Fonts` and corner radii in `Azure.Radius`.

## Notes

- Elements read theme colours when they are created, so set your theme first.
- The window shadow uses `rbxassetid://6014261993`. If it doesn't load, only the glow around the window is affected.
- The GUI is parented to `gethui()` when available, then `CoreGui`, then `PlayerGui`.
- Closing the window disconnects all of its input connections.

## Changelog

**4.1**
- Fixed the loading screen getting stuck at 0%
- Loading screen is now a small centered card instead of a full-screen overlay

**4.0**
- Full rewrite: new loading screen, sliding tab highlight, page transitions, collapse button
- New `CreateKeybind` and `Numeric` input option
- Dropdowns expand inline instead of being clipped
- Notifications animate correctly and stack smoothly
- Fixed shadow not following the window while dragging
- Fixed input connection leaks on close
