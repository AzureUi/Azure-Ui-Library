-- ============================================================
-- Azure UI  v4.0
-- by Noxi
--
-- Quick start (bottom of file has a full example):
--   local Azure  = loadstring(...)()
--   local Window = Azure:CreateWindow({ Title = "Azure", ToggleKey = Enum.KeyCode.RightShift })
--   local Tab    = Window:CreateTab({ Name = "Main" })
--   Tab:CreateToggle({ Name = "Hello", Callback = print })
-- ============================================================

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService       = game:GetService("GuiService")
local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")
local Workspace        = game:GetService("Workspace")
local LocalPlayer      = Players.LocalPlayer

local Azure = {}
Azure.__index = Azure
Azure.Version = "4.0"

-- ============================================================
-- Theme
-- ============================================================

Azure.Theme = {
    Background  = Color3.fromRGB(14, 14, 20),
    Surface     = Color3.fromRGB(20, 20, 28),
    SurfaceAlt  = Color3.fromRGB(27, 27, 37),
    SurfaceHigh = Color3.fromRGB(35, 35, 47),
    Stroke      = Color3.fromRGB(42, 42, 58),
    StrokeHigh  = Color3.fromRGB(95, 95, 140),
    Accent      = Color3.fromRGB(145, 125, 255),
    AccentDim   = Color3.fromRGB(90, 75, 180),
    Text        = Color3.fromRGB(238, 236, 250),
    TextMuted   = Color3.fromRGB(138, 136, 160),
    TextDim     = Color3.fromRGB(92, 92, 112),
    Success     = Color3.fromRGB(120, 220, 160),
    Warning     = Color3.fromRGB(240, 190, 110),
    Error       = Color3.fromRGB(240, 120, 120),
}

Azure.Fonts = {
    Regular = Enum.Font.Gotham,
    Medium  = Enum.Font.GothamMedium,
    Bold    = Enum.Font.GothamBold,
}

Azure.Radius = { Window = 14, Card = 10, Small = 6 }

local Q = Enum.EasingStyle.Quart
local O = Enum.EasingDirection.Out

local SPRING = TweenInfo.new(0.35, Enum.EasingStyle.Back, O)
local SMOOTH = TweenInfo.new(0.22, Q, O)
local FAST   = TweenInfo.new(0.12, Q, O)
local SLOW   = TweenInfo.new(0.45, Q, O)

-- ============================================================
-- Helpers
-- ============================================================

local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    return inst
end

local function corner(r, parent)
    return new("UICorner", { CornerRadius = UDim.new(0, r or 0), Parent = parent })
end

local function stroke(color, thickness, transparency, parent)
    return new("UIStroke", {
        Color = color or Color3.new(1, 1, 1),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function padding(t, r, b, l, parent)
    return new("UIPadding", {
        PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0), PaddingLeft = UDim.new(0, l or 0),
        Parent = parent,
    })
end

local function tween(inst, info, props)
    if not inst or not inst.Parent then return end
    local t = TweenService:Create(inst, info or SMOOTH, props)
    t:Play()
    return t
end

local function newMaid()
    local maid = { _items = {} }
    function maid:Give(item)
        self._items[#self._items + 1] = item
        return item
    end
    function maid:Clean()
        for _, item in ipairs(self._items) do
            if typeof(item) == "RBXScriptConnection" then
                item:Disconnect()
            elseif typeof(item) == "Instance" then
                item:Destroy()
            end
        end
        table.clear(self._items)
    end
    return maid
end

local function safeParent(gui)
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then
        gui.Parent = hui
        return
    end
    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local function isClick(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

-- Smooth, screen-clamped dragging. Global connections go into `maid`.
local function makeDraggable(frame, handle, maid, onStart, onEnd)
    local dragging, startMouse, startPos = false, nil, nil

    maid:Give(handle.InputBegan:Connect(function(input)
        if isClick(input) then
            dragging = true
            startMouse = input.Position
            startPos = frame.Position
            if onStart then onStart() end
        end
    end))

    maid:Give(UserInputService.InputChanged:Connect(function(input)
        if not dragging or not isMove(input) then return end
        local d = input.Position - startMouse
        local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
        local x = math.clamp(startPos.X.Offset + d.X, -vp.X * startPos.X.Scale, vp.X * (1 - startPos.X.Scale))
        local y = math.clamp(startPos.Y.Offset + d.Y, -vp.Y * startPos.Y.Scale, vp.Y * (1 - startPos.Y.Scale))
        TweenService:Create(frame, TweenInfo.new(0.08, Enum.EasingStyle.Quad, O), {
            Position = UDim2.new(startPos.X.Scale, x, startPos.Y.Scale, y),
        }):Play()
    end))

    maid:Give(UserInputService.InputEnded:Connect(function(input)
        if dragging and isClick(input) then
            dragging = false
            if onEnd then onEnd() end
        end
    end))
end

-- Click ripple. `host` must clip (use a CanvasGroup so corners clip too).
local function addRipple(host, trigger, color)
    trigger.InputBegan:Connect(function(input)
        if not isClick(input) then return end
        local inset = GuiService:GetGuiInset()
        local rel = Vector2.new(input.Position.X, input.Position.Y) + inset - host.AbsolutePosition

        local ripple = new("Frame", {
            BackgroundColor3 = color, BackgroundTransparency = 0.65, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(rel.X, rel.Y),
            Size = UDim2.fromOffset(0, 0), ZIndex = 3, Parent = host,
        })
        corner(999, ripple)

        local size = math.max(host.AbsoluteSize.X, host.AbsoluteSize.Y) * 2.4
        local grow = tween(ripple, TweenInfo.new(0.6, Q, O), {
            Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1,
        })
        if grow then grow.Completed:Connect(function() ripple:Destroy() end) end
    end)
end

-- Subtle squish on press.
local function addPress(trigger, target, amount)
    local scale = new("UIScale", { Parent = target })
    trigger.MouseButton1Down:Connect(function() tween(scale, FAST, { Scale = amount or 0.985 }) end)
    local function release() tween(scale, SPRING, { Scale = 1 }) end
    trigger.MouseButton1Up:Connect(release)
    trigger.MouseLeave:Connect(release)
end

local function hoverRow(row, rowStroke, T, restColor)
    restColor = restColor or T.SurfaceAlt
    row.MouseEnter:Connect(function()
        tween(rowStroke, FAST, { Color = T.StrokeHigh, Transparency = 0 })
        tween(row, FAST, { BackgroundColor3 = T.SurfaceHigh })
    end)
    row.MouseLeave:Connect(function()
        tween(rowStroke, SMOOTH, { Color = T.Stroke, Transparency = 0.3 })
        tween(row, SMOOTH, { BackgroundColor3 = restColor })
    end)
end

-- ============================================================
-- Loading screen
-- ============================================================

--[[
Azure:Load({
    Title    = "Azure",
    Subtitle = "optional small line under the title",   -- not required
    Steps    = { "Initializing", "Loading assets", ... },
    Duration = 2.6,
})
returns { Finished = <signal>, Destroy = function }
]]
function Azure:Load(opts)
    opts = opts or {}
    local T = self.Theme
    local title = opts.Title or "Azure"
    local steps = opts.Steps or { "Initializing", "Loading assets", "Building interface", "Finalizing" }
    local duration = opts.Duration or 2.6

    local gui = new("ScreenGui", {
        Name = "AzureLoading", ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 20000,
    })
    safeParent(gui)

    local finished = Instance.new("BindableEvent")

    local overlay = new("CanvasGroup", {
        BackgroundColor3 = Color3.fromRGB(10, 10, 15), BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Parent = gui,
    })
    -- soft vignette so the screen isn't flat black
    local vignette = new("Frame", {
        BackgroundColor3 = T.AccentDim, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.93, Parent = overlay,
    })
    new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Rotation = 90, Parent = vignette,
    })

    local center = new("Frame", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(360, 230), Parent = overlay,
    })
    local centerScale = new("UIScale", { Scale = 0.92, Parent = center })

    -- spinner
    local spinner = new("Frame", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(76, 76), Parent = center,
    })
    local track = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = spinner })
    corner(999, track)
    stroke(T.SurfaceHigh, 3, 0, track)

    local arc = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = spinner })
    corner(999, arc)
    stroke(T.Accent, 3, 0, arc)
    local arcGrad = new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.38, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = arc:FindFirstChildOfClass("UIStroke"),
    })
    local spin = TweenService:Create(arcGrad,
        TweenInfo.new(1.1, Enum.EasingStyle.Linear, O, -1), { Rotation = 360 })
    spin:Play()

    local monogram = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Font = self.Fonts.Bold, Text = string.upper(string.sub(title, 1, 1)),
        TextColor3 = T.Accent, TextSize = 28, TextTransparency = 1, Parent = spinner,
    })
    local pulse = TweenService:Create(monogram,
        TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { TextSize = 32 })

    -- text
    local titleLbl = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 100 + 10),
        Size = UDim2.new(1, 0, 0, 34), Font = self.Fonts.Bold, Text = title,
        TextColor3 = T.Text, TextSize = 28, TextTransparency = 1, Parent = center,
    })
    local subLbl = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 138),
        Size = UDim2.new(1, 0, 0, 16), Font = self.Fonts.Regular,
        Text = opts.Subtitle or steps[1], TextColor3 = T.TextMuted,
        TextSize = 12, TextTransparency = 1, Parent = center,
    })

    -- bar
    local barTrack = new("Frame", {
        BackgroundColor3 = T.SurfaceHigh, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 170),
        Size = UDim2.fromOffset(260, 4), BackgroundTransparency = 1, Parent = center,
    })
    corner(2, barTrack)
    local barFill = new("Frame", {
        BackgroundColor3 = T.Accent, BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1), Parent = barTrack,
    })
    corner(2, barFill)
    local barGrad = new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, T.AccentDim),
            ColorSequenceKeypoint.new(1, T.Accent),
        }),
        Parent = barFill,
    })
    local percent = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 184),
        Size = UDim2.new(1, 0, 0, 14), Font = self.Fonts.Medium, Text = "0%",
        TextColor3 = T.TextDim, TextSize = 11, TextTransparency = 1, Parent = center,
    })

    -- enter
    tween(overlay, SMOOTH, { GroupTransparency = 0 })
    tween(centerScale, SLOW, { Scale = 1 })
    tween(monogram, SLOW, { TextTransparency = 0 })
    tween(titleLbl, SLOW, { TextTransparency = 0, Position = UDim2.new(0, 0, 0, 100) })
    task.delay(0.1, function() tween(subLbl, SLOW, { TextTransparency = 0 }) end)
    task.delay(0.15, function()
        tween(barTrack, SLOW, { BackgroundTransparency = 0 })
        tween(percent, SLOW, { TextTransparency = 0 })
    end)
    pulse:Play()

    -- progress is driven by a NumberValue so bar, %, and step text stay in sync
    local progress = Instance.new("NumberValue")
    local lastStep = 1
    progress.Changed:Connect(function(v)
        barFill.Size = UDim2.fromScale(v, 1)
        percent.Text = string.format("%d%%", math.floor(v * 100 + 0.5))
        local idx = math.clamp(math.floor(v * #steps) + 1, 1, #steps)
        if idx ~= lastStep then
            lastStep = idx
            subLbl.Text = steps[idx]
            subLbl.TextTransparency = 0.8
            tween(subLbl, FAST, { TextTransparency = 0 })
        end
    end)

    local shimmer = TweenService:Create(barGrad,
        TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Offset = Vector2.new(0.3, 0) })
    barGrad.Offset = Vector2.new(-0.3, 0)
    shimmer:Play()

    local destroyed = false
    local function destroy()
        if destroyed then return end
        destroyed = true
        spin:Cancel(); pulse:Cancel(); shimmer:Cancel()
        progress:Destroy()
        finished:Fire()
        tween(centerScale, SMOOTH, { Scale = 1.08 })
        tween(overlay, TweenInfo.new(0.4, Q, O), { GroupTransparency = 1 })
        task.delay(0.45, function()
            if gui then gui:Destroy() end
            finished:Destroy()
        end)
    end

    task.delay(0.2, function()
        if destroyed then return end
        local t = tween(progress, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Value = 1 })
        if t then
            t.Completed:Connect(function()
                if destroyed then return end
                subLbl.Text = "Ready"
                tween(barFill, FAST, { BackgroundColor3 = T.Success })
                tween(percent, FAST, { TextColor3 = T.Success })
                task.delay(0.35, destroy)
            end)
        end
    end)

    return { Finished = finished.Event, Gui = gui, Destroy = destroy }
end

-- backwards-compatible with v3: Azure.ShowLoading(title, subtitle, duration)
function Azure.ShowLoading(title, subtitle, duration)
    return Azure:Load({ Title = title, Subtitle = subtitle, Duration = duration })
end

-- ============================================================
-- Notifications
-- ============================================================

local notifHolder
local function getNotifHolder()
    if notifHolder and notifHolder.Parent then return notifHolder end
    local gui = new("ScreenGui", {
        Name = "AzureNotifications", ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 10000,
    })
    safeParent(gui)
    local holder = new("Frame", {
        Name = "Holder", BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20),
        Size = UDim2.new(0, 300, 1, -40), Parent = gui,
    })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8),
        Parent = holder,
    })
    gui.Destroying:Connect(function() notifHolder = nil end)
    notifHolder = holder
    return holder
end

--[[ Azure:Notify({ Title, Content, Type = "Info"|"Success"|"Warning"|"Error", Duration }) ]]
function Azure:Notify(opts)
    opts = opts or {}
    local T = self.Theme
    local holder = getNotifHolder()
    local duration = opts.Duration or 4
    local color = ({ Success = T.Success, Warning = T.Warning, Error = T.Error })[opts.Type] or T.Accent

    -- wrapper owns the layout slot, card animates freely inside it
    local wrapper = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        LayoutOrder = os.clock() * 1000 // 1, Parent = holder,
    })
    local card = new("CanvasGroup", {
        BackgroundColor3 = T.SurfaceAlt, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 64), Position = UDim2.new(0, 60, 0, 0),
        GroupTransparency = 1, Parent = wrapper,
    })
    corner(self.Radius.Card, card)
    stroke(T.Stroke, 1, 0.2, card)

    new("Frame", {
        BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0), Parent = card,
    })
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 9),
        Size = UDim2.new(1, -28, 0, 16), Font = self.Fonts.Bold,
        Text = opts.Title or "Azure", TextColor3 = T.Text, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
    })
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 27),
        Size = UDim2.new(1, -28, 0, 28), Font = self.Fonts.Regular,
        Text = opts.Content or "", TextColor3 = T.TextMuted, TextSize = 12,
        TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        Parent = card,
    })

    local timer = new("Frame", {
        BackgroundColor3 = color, BackgroundTransparency = 0.3, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 2), Parent = card,
    })

    local hit = new("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 10, Parent = card,
    })

    tween(wrapper, SMOOTH, { Size = UDim2.new(1, 0, 0, 64) })
    tween(card, SLOW, { Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0 })
    tween(timer, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })

    local dismissed = false
    local function dismiss()
        if dismissed then return end
        dismissed = true
        tween(card, SMOOTH, { Position = UDim2.new(0, 60, 0, 0), GroupTransparency = 1 })
        task.delay(0.15, function()
            tween(wrapper, SMOOTH, { Size = UDim2.new(1, 0, 0, 0) })
        end)
        task.delay(0.5, function() wrapper:Destroy() end)
    end

    hit.MouseButton1Click:Connect(dismiss)
    task.delay(duration, dismiss)

    return { Instance = card, Dismiss = dismiss }
end

-- ============================================================
-- Elements
-- Each factory: (parent, cfg, api, maid) -> { Instance, Set, Get, ... }
-- ============================================================

local function makeSection(parent, cfg, api)
    local T = api.Theme
    local title = type(cfg) == "string" and cfg or (cfg and cfg.Name) or "Section"
    local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = parent })

    local dot = new("Frame", {
        BackgroundColor3 = T.Accent, BorderSizePixel = 0,
        Position = UDim2.new(0, 2, 0, 10), Size = UDim2.fromOffset(4, 4), Parent = holder,
    })
    corner(2, dot)
    local label = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 4),
        Size = UDim2.new(1, -14, 0, 16), Font = api.Fonts.Bold,
        Text = string.upper(title), TextColor3 = T.TextDim, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    })
    new("Frame", {
        BackgroundColor3 = T.Stroke, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 0, 1), Parent = holder,
    })

    return { Instance = holder, Set = function(t) label.Text = string.upper(tostring(t)) end }
end

local function makeDivider(parent, _, api)
    local line = new("Frame", {
        BackgroundColor3 = api.Theme.Stroke, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1), Parent = parent,
    })
    return { Instance = line }
end

local function makeLabel(parent, cfg, api)
    local T = api.Theme
    local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Parent = parent })
    padding(0, 4, 0, 4, row)

    local label = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Font = api.Fonts.Regular, Text = cfg.Text or "",
        TextColor3 = cfg.Color or T.TextMuted, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = row,
    })

    if cfg.Update then
        task.spawn(function()
            while row and row.Parent do
                task.wait(cfg.UpdateRate or 1)
                local ok, val = pcall(cfg.Update)
                if ok and val ~= nil then label.Text = tostring(val) end
            end
        end)
    end

    return {
        Instance = row,
        Set = function(t) label.Text = tostring(t or "") end,
        Get = function() return label.Text end,
    }
end

local function makeParagraph(parent, cfg, api)
    local T = api.Theme
    local card = new("Frame", {
        BackgroundColor3 = T.SurfaceAlt, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent,
    })
    corner(api.Radius.Card, card)
    stroke(T.Stroke, 1, 0.4, card)
    padding(12, 14, 12, 14, card)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = card })

    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1,
        Font = api.Fonts.Bold, Text = cfg.Title or "Info", TextColor3 = T.Text, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
    })
    local body = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2,
        AutomaticSize = Enum.AutomaticSize.Y, Font = api.Fonts.Regular,
        Text = cfg.Content or "", TextColor3 = T.TextMuted, TextSize = 12, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        Parent = card,
    })

    return {
        Instance = card,
        Set = function(t) body.Text = tostring(t or "") end,
        Get = function() return body.Text end,
    }
end

local function makeButton(parent, cfg, api)
    local T = api.Theme
    local row = new("CanvasGroup", {
        BackgroundColor3 = T.SurfaceAlt, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 40), Parent = parent,
    })
    corner(api.Radius.Card, row)
    local rowStroke = stroke(T.Stroke, 1, 0.3, row)

    local hit = new("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 6, Parent = row,
    })
    local label = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -44, 1, 0), Font = api.Fonts.Medium,
        Text = cfg.Name or "Button", TextColor3 = T.Text, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = row,
    })
    local arrow = new("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(14, 20),
        Font = api.Fonts.Bold, Text = ">", TextColor3 = T.TextDim, TextSize = 13,
        ZIndex = 4, Parent = row,
    })

    addRipple(row, hit, T.Accent)
    addPress(hit, row, 0.985)

    hit.MouseEnter:Connect(function()
        tween(row, FAST, { BackgroundColor3 = T.SurfaceHigh })
        tween(rowStroke, FAST, { Color = T.StrokeHigh, Transparency = 0 })
        tween(arrow, SPRING, { Position = UDim2.new(1, -9, 0.5, 0), TextColor3 = T.Accent })
    end)
    hit.MouseLeave:Connect(function()
        tween(row, SMOOTH, { BackgroundColor3 = T.SurfaceAlt })
        tween(rowStroke, SMOOTH, { Color = T.Stroke, Transparency = 0.3 })
        tween(arrow, SMOOTH, { Position = UDim2.new(1, -14, 0.5, 0), TextColor3 = T.TextDim })
    end)
    hit.MouseButton1Down:Connect(function() tween(label, FAST, { TextColor3 = T.Accent }) end)
    hit.MouseButton1Up:Connect(function() tween(label, SMOOTH, { TextColor3 = T.Text }) end)
    hit.MouseButton1Click:Connect(function()
        if cfg.Callback then task.spawn(cfg.Callback) end
    end)

    return {
        Instance = row,
        SetText = function(t) label.Text = tostring(t) end,
        Get = function() return label.Text end,
    }
end

local function makeToggle(parent, cfg, api)
    local T = api.Theme
    local state = cfg.CurrentValue == true

    local row = new("TextButton", {
        BackgroundColor3 = T.SurfaceAlt, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, cfg.Desc and 54 or 44),
        Text = "", AutoButtonColor = false, Parent = parent,
    })
    corner(api.Radius.Card, row)
    local rowStroke = stroke(T.Stroke, 1, 0.3, row)

    local nameLbl = new("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 14, 0.5, cfg.Desc and -9 or 0),
        Size = UDim2.new(1, -80, 0, 18), Font = api.Fonts.Medium,
        Text = cfg.Name or "Toggle", TextColor3 = state and T.Text or T.TextMuted, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    if cfg.Desc then
        new("TextLabel", {
            BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 14, 0.5, 10), Size = UDim2.new(1, -80, 0, 14),
            Font = api.Fonts.Regular, Text = cfg.Desc, TextColor3 = T.TextDim, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
        })
    end

    local pill = new("Frame", {
        BackgroundColor3 = state and T.Accent or T.SurfaceHigh, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(42, 22), Parent = row,
    })
    corner(11, pill)
    local pillStroke = stroke(state and T.Accent or T.Stroke, 1, 0.4, pill)

    local knob = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = state and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0),
        Size = UDim2.fromOffset(16, 16), Parent = pill,
    })
    corner(8, knob)

    local function set(v, silent)
        state = v == true
        tween(pill, SMOOTH, { BackgroundColor3 = state and T.Accent or T.SurfaceHigh })
        tween(pillStroke, SMOOTH, { Color = state and T.Accent or T.Stroke })
        tween(nameLbl, SMOOTH, { TextColor3 = state and T.Text or T.TextMuted })
        tween(knob, SPRING, { Position = state and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0) })
        -- stretch on move, settle back
        tween(knob, FAST, { Size = UDim2.fromOffset(21, 14) })
        task.delay(0.1, function() tween(knob, SPRING, { Size = UDim2.fromOffset(16, 16) }) end)
        if not silent and cfg.Callback then task.spawn(cfg.Callback, state) end
    end

    addPress(row, row, 0.985)
    hoverRow(row, rowStroke, T)
    row.MouseButton1Click:Connect(function() set(not state) end)

    return { Instance = row, Set = set, Get = function() return state end }
end

local function makeSlider(parent, cfg, api, maid)
    local T = api.Theme
    local min = cfg.Range and cfg.Range[1] or 0
    local max = cfg.Range and cfg.Range[2] or 100
    local inc = cfg.Increment or 1
    local suffix = cfg.Suffix or ""

    local decimals = 0
    local incStr = tostring(inc)
    local dot = string.find(incStr, "%.")
    if dot then decimals = #incStr - dot end

    local function snap(v)
        v = math.floor(v / inc + 0.5) * inc
        return tonumber(string.format("%." .. decimals .. "f", math.clamp(v, min, max)))
    end

    local value = snap(cfg.CurrentValue or min)

    local row = new("Frame", {
        BackgroundColor3 = T.SurfaceAlt, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 62), Parent = parent,
    })
    corner(api.Radius.Card, row)
    local rowStroke = stroke(T.Stroke, 1, 0.3, row)

    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 10),
        Size = UDim2.new(0.6, -14, 0, 16), Font = api.Fonts.Medium,
        Text = cfg.Name or "Slider", TextColor3 = T.Text, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local valueLbl = new("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 10), Size = UDim2.new(0.4, 0, 0, 16),
        Font = api.Fonts.Medium, Text = tostring(value) .. suffix,
        TextColor3 = T.Accent, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
    })

    local hit = new("Frame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 34),
        Size = UDim2.new(1, -28, 0, 20), Parent = row,
    })
    local bar = new("Frame", {
        BackgroundColor3 = T.SurfaceHigh, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0, 6), Parent = hit,
    })
    corner(3, bar)
    local glow = new("Frame", {
        BackgroundColor3 = T.Accent, BackgroundTransparency = 0.7, BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0), Parent = bar,
    })
    corner(3, glow)
    local fill = new("Frame", {
        BackgroundColor3 = T.Accent, BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), Parent = bar,
    })
    corner(3, fill)
    local knob = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(12, 12), Parent = bar,
    })
    corner(6, knob)
    stroke(T.Accent, 2, 0, knob)

    local DRAG = TweenInfo.new(0.1, Q, O)
    local function refresh(animated)
        local alpha = (value - min) / math.max(max - min, 0.0001)
        valueLbl.Text = tostring(value) .. suffix
        if animated then
            tween(fill, DRAG, { Size = UDim2.new(alpha, 0, 1, 0) })
            tween(glow, DRAG, { Size = UDim2.new(alpha, 0, 1, 0) })
            tween(knob, DRAG, { Position = UDim2.new(alpha, 0, 0.5, 0) })
        else
            fill.Size = UDim2.new(alpha, 0, 1, 0)
            glow.Size = UDim2.new(alpha, 0, 1, 0)
            knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        end
    end

    local dragging, hovering = false, false
    local function updateFromX(x)
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local new_ = snap(min + (max - min) * alpha)
        if new_ ~= value then
            value = new_
            refresh(true)
            if cfg.Callback then task.spawn(cfg.Callback, value) end
        end
    end

    maid:Give(hit.InputBegan:Connect(function(input)
        if isClick(input) then
            dragging = true
            tween(knob, SPRING, { Size = UDim2.fromOffset(17, 17) })
            tween(glow, FAST, { BackgroundTransparency = 0.35 })
            tween(rowStroke, FAST, { Color = T.Accent, Transparency = 0 })
            updateFromX(input.Position.X)
        end
    end))
    maid:Give(UserInputService.InputChanged:Connect(function(input)
        if dragging and isMove(input) then updateFromX(input.Position.X) end
    end))
    maid:Give(UserInputService.InputEnded:Connect(function(input)
        if dragging and isClick(input) then
            dragging = false
            tween(knob, SPRING, { Size = UDim2.fromOffset(12, 12) })
            tween(glow, SMOOTH, { BackgroundTransparency = 0.7 })
            tween(rowStroke, SMOOTH, hovering
                and { Color = T.StrokeHigh, Transparency = 0 }
                or { Color = T.Stroke, Transparency = 0.3 })
        end
    end))

    row.MouseEnter:Connect(function()
        hovering = true
        if not dragging then tween(rowStroke, FAST, { Color = T.StrokeHigh, Transparency = 0 }) end
    end)
    row.MouseLeave:Connect(function()
        hovering = false
        if not dragging then tween(rowStroke, SMOOTH, { Color = T.Stroke, Transparency = 0.3 }) end
    end)

    refresh(false)

    return {
        Instance = row,
        Set = function(v, silent)
            value = snap(v)
            refresh(true)
            if not silent and cfg.Callback then task.spawn(cfg.Callback, value) end
        end,
        Get = function() return value end,
    }
end

local function makeInput(parent, cfg, api)
    local T = api.Theme
    local row = new("Frame", {
        BackgroundColor3 = T.SurfaceAlt, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 62), Parent = parent,
    })
    corner(api.Radius.Card, row)
    local rowStroke = stroke(T.Stroke, 1, 0.3, row)

    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 10),
        Size = UDim2.new(1, -28, 0, 16), Font = api.Fonts.Medium,
        Text = cfg.Name or "Input", TextColor3 = T.Text, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })

    local box = new("TextBox", {
        BackgroundColor3 = T.SurfaceHigh, BorderSizePixel = 0,
        Position = UDim2.new(0, 14, 0, 30), Size = UDim2.new(1, -28, 0, 24),
        Font = api.Fonts.Regular, Text = cfg.CurrentValue or "",
        PlaceholderText = cfg.Placeholder or "", PlaceholderColor3 = T.TextDim,
        TextColor3 = T.Text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false, Parent = row,
    })
    corner(api.Radius.Small, box)
    padding(0, 8, 0, 8, box)
    local boxStroke = stroke(T.Stroke, 1, 0.2, box)

    if cfg.Numeric then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            local clean = string.gsub(box.Text, "[^%d%.%-]", "")
            if clean ~= box.Text then box.Text = clean end
        end)
    end

    box.Focused:Connect(function()
        tween(boxStroke, FAST, { Color = T.Accent, Transparency = 0 })
        tween(rowStroke, FAST, { Color = T.Accent, Transparency = 0.2 })
        tween(box, FAST, { BackgroundColor3 = T.Surface })
    end)
    box.FocusLost:Connect(function(enter)
        tween(boxStroke, SMOOTH, { Color = T.Stroke, Transparency = 0.2 })
        tween(rowStroke, SMOOTH, { Color = T.Stroke, Transparency = 0.3 })
        tween(box, SMOOTH, { BackgroundColor3 = T.SurfaceHigh })
        local text = box.Text
        if cfg.Callback then task.spawn(cfg.Callback, text, enter) end
        if cfg.ClearTextAfterFocusLost then box.Text = "" end
    end)

    return {
        Instance = row,
        Set = function(t) box.Text = tostring(t or "") end,
        Get = function() return box.Text end,
    }
end

local function makeDropdown(parent, cfg, api)
    local T = api.Theme
    local options = cfg.Options or {}
    local value = cfg.CurrentValue
    local open = false
    local HEADER = 60
    local ITEM = 28

    local row = new("Frame", {
        BackgroundColor3 = T.SurfaceAlt, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, HEADER), ClipsDescendants = true, Parent = parent,
    })
    corner(api.Radius.Card, row)
    local rowStroke = stroke(T.Stroke, 1, 0.3, row)

    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 10),
        Size = UDim2.new(1, -28, 0, 16), Font = api.Fonts.Medium,
        Text = cfg.Name or "Dropdown", TextColor3 = T.Text, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })

    local btn = new("TextButton", {
        BackgroundColor3 = T.SurfaceHigh, BorderSizePixel = 0,
        Position = UDim2.new(0, 14, 0, 30), Size = UDim2.new(1, -28, 0, 24),
        AutoButtonColor = false, Text = "", Parent = row,
    })
    corner(api.Radius.Small, btn)
    local btnStroke = stroke(T.Stroke, 1, 0.3, btn)

    local valueText = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 0),
        Size = UDim2.new(1, -30, 1, 0), Font = api.Fonts.Regular,
        Text = value ~= nil and tostring(value) or "Select...",
        TextColor3 = value ~= nil and T.Text or T.TextDim, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn,
    })
    local chevron = new("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(14, 14),
        Font = api.Fonts.Bold, Text = ">", TextColor3 = T.TextMuted, TextSize = 13,
        Rotation = 90, Parent = btn,
    })

    local list = new("ScrollingFrame", {
        BackgroundColor3 = T.Surface, BorderSizePixel = 0,
        Position = UDim2.new(0, 14, 0, HEADER), Size = UDim2.new(1, -28, 0, 0),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2, ScrollBarImageColor3 = T.Accent, Parent = row,
    })
    corner(api.Radius.Small, list)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

    local buttons = {}

    local function listHeight() return math.min(#options * ITEM, ITEM * 6) end

    local function colorOption(optBtn, opt)
        tween(optBtn, FAST, { TextColor3 = (opt == value) and T.Accent or T.TextMuted })
    end

    local function setOpen(state)
        open = state
        local h = listHeight()
        tween(row, TweenInfo.new(0.3, Q, O), { Size = UDim2.new(1, 0, 0, open and (HEADER + h + 10) or HEADER) })
        tween(list, TweenInfo.new(0.3, Q, O), { Size = UDim2.new(1, -28, 0, open and h or 0) })
        tween(chevron, SPRING, { Rotation = open and 270 or 90 })
        tween(chevron, FAST, { TextColor3 = open and T.Accent or T.TextMuted })
        tween(btnStroke, FAST, { Color = open and T.Accent or T.Stroke })
        tween(rowStroke, FAST, { Color = open and T.Accent or T.Stroke, Transparency = open and 0.2 or 0.3 })
    end

    local function select(opt, silent)
        value = opt
        valueText.Text = tostring(opt)
        valueText.TextColor3 = T.Text
        for i, b in ipairs(buttons) do colorOption(b, options[i]) end
        if not silent and cfg.Callback then task.spawn(cfg.Callback, opt) end
    end

    local function build(newOptions)
        for _, b in ipairs(buttons) do b:Destroy() end
        buttons = {}
        options = newOptions or options
        for i, opt in ipairs(options) do
            local optBtn = new("TextButton", {
                BackgroundColor3 = T.Surface, BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, ITEM), LayoutOrder = i, AutoButtonColor = false,
                Text = tostring(opt), Font = api.Fonts.Regular,
                TextColor3 = (opt == value) and T.Accent or T.TextMuted, TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = list,
            })
            padding(0, 10, 0, 10, optBtn)
            optBtn.MouseEnter:Connect(function()
                tween(optBtn, FAST, { BackgroundColor3 = T.SurfaceHigh })
                if opt ~= value then tween(optBtn, FAST, { TextColor3 = T.Text }) end
            end)
            optBtn.MouseLeave:Connect(function()
                tween(optBtn, FAST, { BackgroundColor3 = T.Surface })
                colorOption(optBtn, opt)
            end)
            optBtn.MouseButton1Click:Connect(function()
                select(opt)
                setOpen(false)
            end)
            buttons[i] = optBtn
        end
        if open then setOpen(true) end
    end

    btn.MouseButton1Click:Connect(function() setOpen(not open) end)
    btn.MouseEnter:Connect(function() if not open then tween(btn, FAST, { BackgroundColor3 = T.StrokeHigh }) end end)
    btn.MouseLeave:Connect(function() tween(btn, SMOOTH, { BackgroundColor3 = T.SurfaceHigh }) end)

    build(options)

    return {
        Instance = row,
        Set = function(v, silent) select(v, silent) end,
        Get = function() return value end,
        Refresh = function(o) build(o) end,
    }
end

local function makeKeybind(parent, cfg, api, maid)
    local T = api.Theme
    local key = cfg.CurrentKeybind
    local listening = false

    local row = new("Frame", {
        BackgroundColor3 = T.SurfaceAlt, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 44), Parent = parent,
    })
    corner(api.Radius.Card, row)
    local rowStroke = stroke(T.Stroke, 1, 0.3, row)
    hoverRow(row, rowStroke, T)

    new("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.new(1, -110, 0, 18),
        Font = api.Fonts.Medium, Text = cfg.Name or "Keybind", TextColor3 = T.Text, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })

    local btn = new("TextButton", {
        BackgroundColor3 = T.SurfaceHigh, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X,
        AutoButtonColor = false, Font = api.Fonts.Medium, TextSize = 12,
        TextColor3 = T.TextMuted, Text = key and key.Name or "None", Parent = row,
    })
    corner(api.Radius.Small, btn)
    padding(0, 10, 0, 10, btn)
    local btnStroke = stroke(T.Stroke, 1, 0.3, btn)
    new("UISizeConstraint", { MinSize = Vector2.new(48, 24), Parent = btn })
    addPress(btn, btn, 0.94)

    local function render()
        btn.Text = listening and "..." or (key and key.Name or "None")
        tween(btnStroke, FAST, { Color = listening and T.Accent or T.Stroke })
        tween(btn, FAST, { TextColor3 = listening and T.Accent or T.TextMuted })
    end

    btn.MouseButton1Click:Connect(function()
        listening = true
        render()
    end)

    maid:Give(UserInputService.InputBegan:Connect(function(input, gp)
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                listening = false
                key = (input.KeyCode ~= Enum.KeyCode.Escape) and input.KeyCode or nil
                render()
                if cfg.OnChanged then task.spawn(cfg.OnChanged, key) end
            end
        elseif not gp and key and input.KeyCode == key then
            if cfg.Callback then task.spawn(cfg.Callback, key) end
        end
    end))

    return {
        Instance = row,
        Set = function(k) key = k; render() end,
        Get = function() return key end,
    }
end

-- ============================================================
-- Tab
-- ============================================================

local ELEMENTS = {
    Section   = makeSection,
    Divider   = makeDivider,
    Label     = makeLabel,
    Paragraph = makeParagraph,
    Button    = makeButton,
    Toggle    = makeToggle,
    Slider    = makeSlider,
    Input     = makeInput,
    Dropdown  = makeDropdown,
    Keybind   = makeKeybind,
}

local TAB_H, TAB_GAP = 34, 4

local function makeTab(window, cfg, api)
    local T = api.Theme
    local name = cfg.Name or "Tab"
    local index = #window._tabs + 1

    -- page: CanvasGroup so the whole page can fade/slide as one
    local page = new("CanvasGroup", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        GroupTransparency = 1, Visible = false, Parent = window._contentHolder,
    })
    local scroll = new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = T.Accent,
        ScrollBarImageTransparency = 0.5, Parent = page,
    })
    padding(14, 14, 14, 12, scroll)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = scroll })

    local order = 0
    local function nextOrder() order += 1; return order end

    local btn = new("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, TAB_H), AutoButtonColor = false,
        Text = "", LayoutOrder = index, Parent = window._sidebarList,
    })
    local label = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -14, 1, 0), Font = api.Fonts.Medium, Text = name,
        TextColor3 = T.TextMuted, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = btn,
    })

    local tab = { Instance = page, Name = name }

    function tab:Select()
        local prev = window._currentTab
        if prev == tab then return end
        window._currentTab = tab

        if prev then
            tween(prev._page, FAST, { GroupTransparency = 1 })
            tween(prev._label, SMOOTH, { TextColor3 = T.TextMuted })
            tween(prev._label, SMOOTH, { Position = UDim2.new(0, 14, 0, 0) })
            task.delay(0.13, function()
                if window._currentTab ~= prev then prev._page.Visible = false end
            end)
        end

        page.Position = UDim2.new(0, 0, 0, 16)
        page.GroupTransparency = 1
        page.Visible = true
        tween(page, SLOW, { Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0 })
        tween(label, SMOOTH, { TextColor3 = T.Text, Position = UDim2.new(0, 18, 0, 0) })

        -- slide the shared highlight to this tab
        local y = 8 + (index - 1) * (TAB_H + TAB_GAP)
        local hl = window._highlight
        if not hl.Visible then
            hl.Position = UDim2.new(0, 8, 0, y)
            hl.Visible = true
        else
            tween(hl, TweenInfo.new(0.35, Enum.EasingStyle.Back, O), { Position = UDim2.new(0, 8, 0, y) })
        end
    end

    btn.MouseButton1Click:Connect(function() tab:Select() end)
    btn.MouseEnter:Connect(function()
        if window._currentTab ~= tab then
            tween(label, FAST, { TextColor3 = T.Text, Position = UDim2.new(0, 18, 0, 0) })
        end
    end)
    btn.MouseLeave:Connect(function()
        if window._currentTab ~= tab then
            tween(label, SMOOTH, { TextColor3 = T.TextMuted, Position = UDim2.new(0, 14, 0, 0) })
        end
    end)

    tab._page, tab._label = page, label

    for elementName, factory in pairs(ELEMENTS) do
        tab["Create" .. elementName] = function(_, elCfg)
            local el = factory(scroll, elCfg or {}, api, window._maid)
            el.Instance.LayoutOrder = nextOrder()
            return el
        end
    end

    return tab
end

-- ============================================================
-- Window
-- ============================================================

function Azure:CreateWindow(cfg)
    cfg = cfg or {}
    local api    = self
    local T      = self.Theme
    local width  = cfg.Width  or 560
    local height = cfg.Height or 460
    local title  = cfg.Title  or "Azure"
    local maid   = newMaid()

    local gui = new("ScreenGui", {
        Name = "AzureUI", ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 9999, Enabled = true,
    })
    safeParent(gui)

    -- Root holds shadow + window so they move, scale and collapse together
    local root = new("Frame", {
        Name = "Root", BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(width, height), Visible = false, Parent = gui,
    })
    local rootScale = new("UIScale", { Scale = 0.9, Parent = root })

    local shadow = new("ImageLabel", {
        Name = "Shadow", BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 56, 1, 56), Image = "rbxassetid://6014261993",
        ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 0, Parent = root,
    })

    local main = new("CanvasGroup", {
        Name = "Main", BackgroundColor3 = T.Background, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Parent = root,
    })
    corner(self.Radius.Window, main)
    local mainStroke = stroke(T.Stroke, 1, 0.2, main)

    -- Header
    local header = new("Frame", {
        Name = "Header", BackgroundColor3 = T.Surface, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 44), Parent = main,
    })
    local line = new("Frame", {
        BackgroundColor3 = T.Accent, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), Parent = header,
    })
    local lineGrad = new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.15),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Offset = Vector2.new(-1, 0), Parent = line,
    })
    TweenService:Create(lineGrad,
        TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Offset = Vector2.new(1, 0) }):Play()

    local dotLogo = new("Frame", {
        BackgroundColor3 = T.Accent, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 16, 0.5, 0), Size = UDim2.fromOffset(8, 8), Parent = header,
    })
    corner(4, dotLogo)
    TweenService:Create(dotLogo,
        TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { BackgroundTransparency = 0.6 }):Play()

    local titleLbl = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 32, 0, 0),
        Size = UDim2.new(0.6, 0, 1, 0), Font = self.Fonts.Bold, Text = title,
        TextColor3 = T.Text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
    })

    local function headerButton(text, xOffset, hoverColor)
        local b = new("TextButton", {
            BackgroundColor3 = T.SurfaceHigh, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOffset, 0.5, 0),
            Size = UDim2.fromOffset(24, 24), AutoButtonColor = false,
            Text = text, Font = self.Fonts.Bold, TextColor3 = T.TextMuted, TextSize = 14,
            Parent = header,
        })
        corner(6, b)
        addPress(b, b, 0.88)
        b.MouseEnter:Connect(function()
            tween(b, FAST, { BackgroundColor3 = hoverColor, TextColor3 = Color3.new(1, 1, 1) })
        end)
        b.MouseLeave:Connect(function()
            tween(b, SMOOTH, { BackgroundColor3 = T.SurfaceHigh, TextColor3 = T.TextMuted })
        end)
        return b
    end
    local closeBtn = headerButton("x", -10, T.Error)
    local minBtn   = headerButton("-", -40, T.AccentDim)

    -- Sidebar
    local sidebar = new("Frame", {
        Name = "Sidebar", BackgroundColor3 = T.Surface, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 44), Size = UDim2.new(0, 150, 1, -44), Parent = main,
    })
    new("Frame", {
        BackgroundColor3 = T.Stroke, BackgroundTransparency = 0.4, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 1, 1, 0), Parent = sidebar,
    })

    local highlight = new("Frame", {
        Name = "Highlight", BackgroundColor3 = T.SurfaceHigh, BorderSizePixel = 0,
        Size = UDim2.new(1, -16, 0, TAB_H), Visible = false, Parent = sidebar,
    })
    corner(self.Radius.Small, highlight)
    local hlBar = new("Frame", {
        BackgroundColor3 = T.Accent, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 3, 0.55, 0), Parent = highlight,
    })
    corner(2, hlBar)

    local sidebarList = new("Frame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 8),
        Size = UDim2.new(1, -16, 1, -60), Parent = sidebar,
    })
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, TAB_GAP), Parent = sidebarList })

    local footer = new("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 16, 1, -10), Size = UDim2.new(1, -32, 0, 14),
        Font = self.Fonts.Regular, Text = LocalPlayer and LocalPlayer.DisplayName or "",
        TextColor3 = T.TextDim, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = sidebar,
    })

    local contentHolder = new("Frame", {
        Name = "Content", BackgroundTransparency = 1, ClipsDescendants = true,
        Position = UDim2.new(0, 150, 0, 44), Size = UDim2.new(1, -150, 1, -44), Parent = main,
    })

    local window = {
        _gui = gui, _root = root, _main = main, _maid = maid,
        _sidebarList = sidebarList, _contentHolder = contentHolder, _highlight = highlight,
        _tabs = {}, _currentTab = nil, _visible = false, _collapsed = false, Title = title,
    }

    -- Animations
    local function animateIn()
        root.Visible = true
        window._visible = true
        tween(rootScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, O), { Scale = 1 })
        tween(main, SLOW, { GroupTransparency = 0 })
        tween(shadow, SLOW, { ImageTransparency = 0.55 })
    end

    local function animateOut(done)
        window._visible = false
        tween(rootScale, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Scale = 0.92 })
        tween(main, SMOOTH, { GroupTransparency = 1 })
        tween(shadow, SMOOTH, { ImageTransparency = 1 })
        task.delay(0.26, function()
            if not window._visible then root.Visible = false end
            if done then done() end
        end)
    end

    makeDraggable(root, header, maid,
        function() tween(mainStroke, FAST, { Color = T.StrokeHigh, Transparency = 0 }) end,
        function() tween(mainStroke, SMOOTH, { Color = T.Stroke, Transparency = 0.2 }) end)

    -- Collapse to header
    minBtn.MouseButton1Click:Connect(function()
        window._collapsed = not window._collapsed
        local h = window._collapsed and 44 or height
        tween(root, TweenInfo.new(0.35, Enum.EasingStyle.Quart, O), { Size = UDim2.fromOffset(width, h) })
        minBtn.Text = window._collapsed and "+" or "-"
    end)

    local destroying = false
    function window:Destroy()
        if destroying then return end
        destroying = true
        animateOut(function()
            maid:Clean()
            gui:Destroy()
        end)
    end
    closeBtn.MouseButton1Click:Connect(function() window:Destroy() end)

    function window:Toggle(state)
        if destroying then return end
        if state == nil then state = not window._visible end
        if state then animateIn() else animateOut() end
    end

    function window:SetTitle(t) titleLbl.Text = tostring(t); window.Title = t end

    function window:Notify(opts) return api:Notify(opts) end

    function window:CreateTab(tabCfg)
        local tab = makeTab(window, tabCfg or {}, api)
        window._tabs[#window._tabs + 1] = tab
        if #window._tabs == 1 then tab:Select() end
        return tab
    end

    function window:SelectTab(tab)
        if tab and tab.Select then tab:Select() end
    end

    if cfg.ToggleKey then
        maid:Give(UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == cfg.ToggleKey then window:Toggle() end
        end))
    end

    gui.Destroying:Connect(function()
        maid:Clean()
        notifHolder = notifHolder -- notifications live in their own gui
    end)

    -- Loading screen (on by default; pass Loading = false to skip, or a table to customise)
    if cfg.Loading == false then
        animateIn()
    else
        local loadCfg = type(cfg.Loading) == "table" and cfg.Loading or {}
        loadCfg.Title = loadCfg.Title or title
        local loader = api:Load(loadCfg)
        loader.Finished:Connect(animateIn)
    end

    return window
end

return Azure

--[[ ============================================================
Example

local Azure = loadstring(game:HttpGet("YOUR_URL"))()

local Window = Azure:CreateWindow({
    Title = "Azure",
    ToggleKey = Enum.KeyCode.RightShift,
    -- Loading = false,                          -- skip loading screen
    -- Loading = { Duration = 3, Steps = {...} } -- customise it
})

local Main = Window:CreateTab({ Name = "Main" })
Main:CreateSection("Player")
Main:CreateToggle({ Name = "Godmode", Desc = "Take no damage", Callback = function(v) print(v) end })
Main:CreateSlider({ Name = "WalkSpeed", Range = {16, 100}, Increment = 1, CurrentValue = 16, Suffix = " sp", Callback = print })
Main:CreateDropdown({ Name = "Team", Options = {"Red", "Blue", "Green"}, CurrentValue = "Red", Callback = print })
Main:CreateKeybind({ Name = "Fly", CurrentKeybind = Enum.KeyCode.F, Callback = function() print("fly") end })
Main:CreateInput({ Name = "Name", Placeholder = "type here", Callback = print })
Main:CreateButton({ Name = "Notify me", Callback = function()
    Azure:Notify({ Title = "Azure", Content = "Hello!", Type = "Success" })
end })

local About = Window:CreateTab({ Name = "About" })
About:CreateParagraph({ Title = "Azure UI", Content = "Clean, animated UI library." })
============================================================ ]]
