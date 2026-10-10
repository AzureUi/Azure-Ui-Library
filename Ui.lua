-- ============================================================
-- Azure UI — v3 with loading screen
-- by Noxi
-- ============================================================

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")
local LocalPlayer      = Players.LocalPlayer

local Azure = {}
Azure.__index = Azure

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

local SPRING = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SMOOTH = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local FAST   = TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- ============================================================
-- Core helper factories (must be defined before everything)
-- ============================================================

local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    return inst
end

local function corner(r, p)
    return new("UICorner", { CornerRadius = UDim.new(0, r or 0), Parent = p })
end

local function stroke(color, thickness, transparency, p)
    return new("UIStroke", {
        Color = color or Color3.new(1, 1, 1),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = p,
    })
end

local function padding(t, r, b, l, p)
    return new("UIPadding", {
        PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0), PaddingLeft = UDim.new(0, l or 0),
        Parent = p,
    })
end

local function tween(inst, info, props)
    if not inst then return end
    local t = TweenService:Create(inst, info or SMOOTH, props)
    t:Play()
    return t
end

local function safeParent(gui)
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then gui.Parent = hui; return end
    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end

local function makeDraggable(frame, handle, onStart, onEnd)
    handle = handle or frame
    local dragging, startMouse, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startMouse = input.Position
            startPos = frame.Position
            if onStart then onStart() end
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - startMouse
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if onEnd then onEnd() end
        end
    end)
end

local function addRipple(button, accent)
    button.ClipsDescendants = true
    button.MouseButton1Down:Connect(function()
        local mouse = UserInputService:GetMouseLocation()
        local relX = mouse.X - button.AbsolutePosition.X
        local relY = mouse.Y - button.AbsolutePosition.Y

        local ripple = new("Frame", {
            BackgroundColor3 = accent or Color3.fromRGB(145, 125, 255),
            BackgroundTransparency = 0.6,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(relX, relY),
            Size = UDim2.fromOffset(0, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 3,
            Parent = button,
        })
        corner(999, ripple)

        local maxSize = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2
        local grow = TweenService:Create(ripple,
            TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { Size = UDim2.fromOffset(maxSize, maxSize), BackgroundTransparency = 1 })
        grow:Play()
        grow.Completed:Connect(function() ripple:Destroy() end)
    end)
end

-- ============================================================
-- Loading screen
-- ============================================================

local function showLoadingScreen(title, subtitle, duration)
    title = title or "Azure"
    subtitle = subtitle or "Loading"
    duration = duration or 1.8

    local gui = new("ScreenGui", {
        Name = "AzureLoading", ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 20000,
    })
    safeParent(gui)

    local overlay = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(10, 10, 15),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Parent = gui,
    })

    local center = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(360, 120),
        Parent = overlay,
    })

    -- logo text
    local titleLbl = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 44),
        Font = Azure.Fonts.Bold,
        Text = title,
        TextColor3 = Azure.Theme.Text,
        TextSize = 40,
        TextTransparency = 1,
        Parent = center,
    })

    -- subtitle
    local subLbl = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 46),
        Size = UDim2.new(1, 0, 0, 18),
        Font = Azure.Fonts.Regular,
        Text = subtitle,
        TextColor3 = Azure.Theme.TextMuted,
        TextSize = 13,
        TextTransparency = 1,
        Parent = center,
    })

    -- loading bar track
    local barTrack = new("Frame", {
        BackgroundColor3 = Azure.Theme.SurfaceHigh,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 84),
        Size = UDim2.fromOffset(280, 4),
        BackgroundTransparency = 1,
        Parent = center,
    })
    corner(2, barTrack)

    local barFill = new("Frame", {
        BackgroundColor3 = Azure.Theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(0, 4),
        Parent = barTrack,
    })
    corner(2, barFill)

    -- glow behind the bar
    local glow = new("Frame", {
        BackgroundColor3 = Azure.Theme.Accent,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(40, 12),
        BackgroundTransparency = 1,
        ZIndex = 0,
        Parent = barTrack,
    })
    corner(6, glow)

    -- fade in overlay + content
    tween(overlay, SMOOTH, { BackgroundTransparency = 0 })
    tween(titleLbl, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { TextTransparency = 0 })
    tween(subLbl, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { TextTransparency = 0 })
    tween(barTrack, SMOOTH, { BackgroundTransparency = 0 })
    tween(glow, SMOOTH, { BackgroundTransparency = 0.7 })

    -- fill the bar
    local fillTween = TweenService:Create(barFill,
        TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Size = UDim2.fromOffset(280, 4) })
    fillTween:Play()

    -- slide the glow along with fill
    task.spawn(function()
        local startT = tick()
        while tick() - startT < duration do
            local alpha = math.clamp((tick() - startT) / duration, 0, 1)
            -- easing out quart
            local eased = 1 - (1 - alpha) ^ 4
            glow.Position = UDim2.new(0, eased * 280, 0.5, 0)
            task.wait()
        end
    end)

    -- fade out
    task.delay(duration, function()
        tween(titleLbl, SMOOTH, { TextTransparency = 1 })
        tween(subLbl, SMOOTH, { TextTransparency = 1 })
        tween(barTrack, SMOOTH, { BackgroundTransparency = 1 })
        tween(glow, SMOOTH, { BackgroundTransparency = 1 })
        tween(overlay, SMOOTH, { BackgroundTransparency = 1 })
        task.wait(0.3)
        gui:Destroy()
    end)

    return gui
end

Azure.ShowLoading = showLoadingScreen

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
    notifHolder = holder
    return holder
end

function Azure:Notify(opts)
    opts = opts or {}
    local holder = getNotifHolder()
    local bar
    if opts.Type == "Success" then bar = self.Theme.Success
    elseif opts.Type == "Warning" then bar = self.Theme.Warning
    elseif opts.Type == "Error" then bar = self.Theme.Error
    else bar = self.Theme.Accent end

    local card = new("Frame", {
        BackgroundColor3 = self.Theme.SurfaceAlt, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, 40, 0, 0),
        Parent = holder,
    })
    corner(self.Radius.Card, card)
    stroke(self.Theme.Stroke, 1, 0.2, card)
    padding(10, 14, 10, 14, card)

    local accent = new("Frame", {
        BackgroundColor3 = bar, BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, 0), Position = UDim2.new(0, -14, 0, 0),
        Parent = card,
    })

    local titleLbl = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
        Font = self.Fonts.Bold, Text = opts.Title or "Azure",
        TextColor3 = self.Theme.Text, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, Parent = card,
    })

    local contentLbl = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 22),
        Size = UDim2.new(1, 0, 0, 18), Font = self.Fonts.Regular,
        Text = opts.Content or "", TextColor3 = self.Theme.TextMuted,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, TextTransparency = 1, Parent = card,
    })

    tween(card, SMOOTH, { BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0) })
    tween(titleLbl, SMOOTH, { TextTransparency = 0 })
    tween(contentLbl, SMOOTH, { TextTransparency = 0 })

    task.delay(opts.Duration or 4, function()
        tween(card, SMOOTH, { BackgroundTransparency = 1, Position = UDim2.new(1, 40, 0, 0) })
        tween(titleLbl, SMOOTH, { TextTransparency = 1 })
        tween(contentLbl, SMOOTH, { TextTransparency = 1 })
        task.wait(0.3)
        card:Destroy()
    end)

    return card
end

-- ============================================================
-- Elements
-- ============================================================

local function makeToggle(parent, cfg, self)
    local state = cfg.CurrentValue == true

    local row = new("Frame", {
        BackgroundColor3 = self.Theme.SurfaceAlt, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 46), Parent = parent,
    })
    corner(self.Radius.Card, row)
    local rowStroke = stroke(self.Theme.Stroke, 1, 0.3, row)
    padding(0, 14, 0, 14, row)

    new("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, cfg.Desc and -8 or 0),
        Size = UDim2.new(0.7, 0, 0, 18), Font = self.Fonts.Medium,
        Text = cfg.Name or "Toggle", TextColor3 = self.Theme.Text,
        TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    if cfg.Desc then
        new("TextLabel", {
            BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 8),
            Size = UDim2.new(0.7, 0, 0, 14), Font = self.Fonts.Regular,
            Text = cfg.Desc, TextColor3 = self.Theme.TextMuted,
            TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
        })
    end

    local pill = new("TextButton", {
        BackgroundColor3 = state and self.Theme.Accent or self.Theme.SurfaceHigh,
        BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 42, 0, 22),
        Text = "", AutoButtonColor = false, Parent = row,
    })
    corner(11, pill)
    local pillStroke = stroke(self.Theme.Stroke, 1, 0.4, pill)

    local knob = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = state and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16), Parent = pill,
    })
    corner(8, knob)

    local function set(v, silent)
        state = v == true
        tween(pill, SPRING, { BackgroundColor3 = state and self.Theme.Accent or self.Theme.SurfaceHigh })
        tween(knob, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = state and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0),
        })
        if not silent and cfg.Callback then task.spawn(cfg.Callback, state) end
    end

    pill.MouseButton1Click:Connect(function() set(not state) end)
    pill.MouseEnter:Connect(function()
        tween(pillStroke, FAST, { Color = self.Theme.StrokeHigh })
        tween(row, FAST, { BackgroundColor3 = self.Theme.SurfaceHigh })
    end)
    pill.MouseLeave:Connect(function()
        tween(pillStroke, FAST, { Color = self.Theme.Stroke })
        tween(row, FAST, { BackgroundColor3 = self.Theme.SurfaceAlt })
    end)

    return { Set = set, Get = function() return state end, Instance = row }
end

local function makeSlider(parent, cfg, self)
    local min = cfg.Range and cfg.Range[1] or 0
    local max = cfg.Range and cfg.Range[2] or 100
    local inc = cfg.Increment or 1
    local suffix = cfg.Suffix or ""
    local value = cfg.CurrentValue or min

    local row = new("Frame", {
        BackgroundColor3 = self.Theme.SurfaceAlt, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 60), Parent = parent,
    })
    corner(self.Radius.Card, row)
    local rowStroke = stroke(self.Theme.Stroke, 1, 0.3, row)
    padding(12, 14, 12, 14, row)

    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 0, 16),
        Font = self.Fonts.Medium, Text = cfg.Name or "Slider",
        TextColor3 = self.Theme.Text, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })

    local valueLbl = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(0.4, 0, 0, 16),
        Position = UDim2.new(0.6, 0, 0, 0), Font = self.Fonts.Medium,
        Text = tostring(value) .. suffix, TextColor3 = self.Theme.Accent,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
    })

    local bar = new("Frame", {
        BackgroundColor3 = self.Theme.SurfaceHigh, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(1, 0, 0, 6), Parent = row,
    })
    corner(3, bar)

    local glow = new("Frame", {
        BackgroundColor3 = self.Theme.Accent, BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 0.6, Parent = bar,
    })
    corner(3, glow)

    local fill = new("Frame", {
        BackgroundColor3 = self.Theme.Accent, BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0), Parent = bar,
    })
    corner(3, fill)

    local knob = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 12, 0, 12), Parent = bar,
    })
    corner(6, knob)
    stroke(self.Theme.Accent, 2, 0, knob)

    local function refresh()
        local alpha = (value - min) / math.max(max - min, 0.0001)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        glow.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLbl.Text = tostring(value) .. suffix
    end

    local dragging = false
    local function updateFromMouse(x)
        local absX, absW = bar.AbsolutePosition.X, bar.AbsoluteSize.X
        local alpha = math.clamp((x - absX) / math.max(absW, 1), 0, 1)
        local raw = min + (max - min) * alpha
        value = math.floor(raw / inc + 0.5) * inc
        refresh()
        if cfg.Callback then task.spawn(cfg.Callback, value) end
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            tween(knob, FAST, { Size = UDim2.new(0, 16, 0, 16) })
            tween(glow, FAST, { BackgroundTransparency = 0.3 })
            updateFromMouse(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            updateFromMouse(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                tween(knob, SMOOTH, { Size = UDim2.new(0, 12, 0, 12) })
                tween(glow, SMOOTH, { BackgroundTransparency = 0.6 })
            end
        end
    end)

    row.MouseEnter:Connect(function() tween(rowStroke, FAST, { Color = self.Theme.StrokeHigh }) end)
    row.MouseLeave:Connect(function()
        if not dragging then tween(rowStroke, FAST, { Color = self.Theme.Stroke }) end
    end)

    refresh()

    return {
        Set = function(v) value = math.clamp(v, min, max); refresh() end,
        Get = function() return value end,
        Instance = row,
    }
end

local function makeButton(parent, cfg, self)
    local btn = new("TextButton", {
        BackgroundColor3 = self.Theme.SurfaceAlt, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 40), AutoButtonColor = false,
        Text = "", ClipsDescendants = true, Parent = parent,
    })
    corner(self.Radius.Card, btn)
    local btnStroke = stroke(self.Theme.Stroke, 1, 0.3, btn)

    local label = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -24, 1, 0),
        Position = UDim2.new(0, 12, 0, 0), Font = self.Fonts.Medium,
        Text = cfg.Name or "Button", TextColor3 = self.Theme.Text,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2, Parent = btn,
    })

    addRipple(btn, self.Theme.Accent)

    btn.MouseEnter:Connect(function()
        tween(btn, FAST, { BackgroundColor3 = self.Theme.SurfaceHigh })
        tween(btnStroke, FAST, { Color = self.Theme.StrokeHigh })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, FAST, { BackgroundColor3 = self.Theme.SurfaceAlt })
        tween(btnStroke, FAST, { Color = self.Theme.Stroke })
    end)
    btn.MouseButton1Down:Connect(function() tween(label, FAST, { TextColor3 = self.Theme.Accent }) end)
    btn.MouseButton1Up:Connect(function() tween(label, SMOOTH, { TextColor3 = self.Theme.Text }) end)
    btn.MouseButton1Click:Connect(function()
        if cfg.Callback then task.spawn(cfg.Callback) end
    end)

    return {
        SetText = function(t) label.Text = t end,
        Get = function() return label.Text end,
        Instance = btn,
    }
end

local function makeInput(parent, cfg, self)
    local row = new("Frame", {
        BackgroundColor3 = self.Theme.SurfaceAlt, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 56), Parent = parent,
    })
    corner(self.Radius.Card, row)
    local rowStroke = stroke(self.Theme.Stroke, 1, 0.3, row)
    padding(10, 14, 10, 14, row)

    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
        Font = self.Fonts.Medium, Text = cfg.Name or "Input",
        TextColor3 = self.Theme.Text, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })

    local box = new("TextBox", {
        BackgroundColor3 = self.Theme.SurfaceHigh, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 24),
        Font = self.Fonts.Regular, Text = cfg.CurrentValue or "",
        PlaceholderText = cfg.Placeholder or "", PlaceholderColor3 = self.Theme.TextDim,
        TextColor3 = self.Theme.Text, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = row,
    })
    corner(self.Radius.Small, box)
    padding(0, 8, 0, 8, box)

    local boxStroke = stroke(self.Theme.Stroke, 1, 0.2, box)
    box.Focused:Connect(function()
        tween(boxStroke, FAST, { Color = self.Theme.Accent })
        tween(rowStroke, FAST, { Color = self.Theme.Accent })
    end)
    box.FocusLost:Connect(function(enter)
        tween(boxStroke, FAST, { Color = self.Theme.Stroke })
        tween(rowStroke, FAST, { Color = self.Theme.Stroke })
        if cfg.Callback then task.spawn(cfg.Callback, box.Text, enter) end
    end)

    return {
        Set = function(t) box.Text = tostring(t or "") end,
        Get = function() return box.Text end,
        Instance = row,
    }
end

local function makeParagraph(parent, cfg, self)
    local card = new("Frame", {
        BackgroundColor3 = self.Theme.SurfaceAlt, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 60), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent,
    })
    corner(self.Radius.Card, card)
    stroke(self.Theme.Stroke, 1, 0.4, card)
    padding(12, 14, 12, 14, card)

    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
        Font = self.Fonts.Bold, Text = cfg.Title or "Info",
        TextColor3 = self.Theme.Text, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
    })

    local body = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 22),
        Size = UDim2.new(1, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.Y,
        Font = self.Fonts.Regular, Text = cfg.Content or "",
        TextColor3 = self.Theme.TextMuted, TextSize = 12, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Parent = card,
    })

    return {
        Set = function(t) body.Text = t end,
        Get = function() return body.Text end,
        Instance = card,
    }
end

local function makeDropdown(parent, cfg, self)
    local options = cfg.Options or {}
    local value = cfg.CurrentValue
    local open = false

    local row = new("Frame", {
        BackgroundColor3 = self.Theme.SurfaceAlt, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 56), ClipsDescendants = false, Parent = parent,
    })
    corner(self.Radius.Card, row)
    local rowStroke = stroke(self.Theme.Stroke, 1, 0.3, row)
    padding(10, 14, 10, 14, row)

    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
        Font = self.Fonts.Medium, Text = cfg.Name or "Dropdown",
        TextColor3 = self.Theme.Text, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })

    local btn = new("TextButton", {
        BackgroundColor3 = self.Theme.SurfaceHigh, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 24),
        AutoButtonColor = false, Text = "", Parent = row,
    })
    corner(self.Radius.Small, btn)

    local valueText = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.new(0, 8, 0, 0), Font = self.Fonts.Regular,
        Text = tostring(value or "Select..."), TextColor3 = self.Theme.Text,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = btn,
    })

    local caretHolder = new("Frame", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 12, 0, 12),
        Rotation = 0, Parent = btn,
    })

    local chevron = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        Font = self.Fonts.Bold, Text = "v",
        TextColor3 = self.Theme.TextMuted, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center, Parent = caretHolder,
    })

    local list = new("Frame", {
        BackgroundColor3 = self.Theme.Surface, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, 6), Size = UDim2.new(1, 0, 0, 0),
        ClipsDescendants = true, Visible = false, ZIndex = 5, Parent = row,
    })
    corner(self.Radius.Small, list)
    stroke(self.Theme.Stroke, 1, 0.2, list)

    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0), Parent = list,
    })

    local buttons = {}

    local function refreshOptions(newOptions)
        for _, b in ipairs(buttons) do b:Destroy() end
        buttons = {}
        options = newOptions or options
        for i, opt in ipairs(options) do
            local optBtn = new("TextButton", {
                BackgroundColor3 = self.Theme.Surface, BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 28), LayoutOrder = i,
                AutoButtonColor = false, Text = tostring(opt),
                Font = self.Fonts.Regular, TextColor3 = self.Theme.TextMuted,
                TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 6, Parent = list,
            })
            padding(0, 10, 0, 10, optBtn)
            optBtn.MouseEnter:Connect(function()
                tween(optBtn, FAST, { BackgroundColor3 = self.Theme.SurfaceHigh, TextColor3 = self.Theme.Text })
            end)
            optBtn.MouseLeave:Connect(function()
                tween(optBtn, FAST, { BackgroundColor3 = self.Theme.Surface, TextColor3 = self.Theme.TextMuted })
            end)
            optBtn.MouseButton1Click:Connect(function()
                value = opt
                valueText.Text = tostring(opt)
                list.Visible = false
                tween(list, SMOOTH, { Size = UDim2.new(1, 0, 0, 0) })
                tween(caretHolder, SMOOTH, { Rotation = 0 })
                open = false
                if cfg.Callback then task.spawn(cfg.Callback, opt) end
            end)
            buttons[#buttons + 1] = optBtn
        end
    end

    btn.MouseButton1Click:Connect(function()
        open = not open
        list.Visible = true
        local h = math.min(#options * 28, 168)
        tween(list, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = open and UDim2.new(1, 0, 0, h) or UDim2.new(1, 0, 0, 0),
        })
        tween(caretHolder, SMOOTH, { Rotation = open and 180 or 0 })
        tween(chevron, FAST, { TextColor3 = open and self.Theme.Accent or self.Theme.TextMuted })
        tween(rowStroke, FAST, { Color = open and self.Theme.Accent or self.Theme.Stroke })
    end)

    refreshOptions(options)

    return {
        Set = function(v) value = v; valueText.Text = tostring(v or "Select...") end,
        Get = function() return value end,
        Refresh = function(o) refreshOptions(o) end,
        Instance = row,
    }
end

local function makeLabel(parent, cfg, self)
    local row = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Parent = parent,
    })
    padding(0, 4, 0, 4, row)

    local label = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        Font = self.Fonts.Regular, Text = cfg.Text or "",
        TextColor3 = cfg.Color or self.Theme.TextMuted,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Parent = row,
    })

    if cfg.Update then
        task.spawn(function()
            while row.Parent do
                task.wait(cfg.UpdateRate or 1)
                local ok, val = pcall(cfg.Update)
                if ok and val ~= nil then label.Text = tostring(val) end
            end
        end)
    end

    return {
        Set = function(t) label.Text = tostring(t or "") end,
        Get = function() return label.Text end,
        Instance = row,
    }
end

local function makeSection(parent, title, self)
    local holder = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = parent,
    })
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 2, 0, 6),
        Size = UDim2.new(1, 0, 0, 16), Font = self.Fonts.Bold,
        Text = string.upper(title or "Section"),
        TextColor3 = self.Theme.TextDim, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    })
    new("Frame", {
        BackgroundColor3 = self.Theme.Stroke, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 0, 1), Parent = holder,
    })
    return holder
end

local function makeDivider(parent, self)
    return new("Frame", {
        BackgroundColor3 = self.Theme.Stroke, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1), Parent = parent,
    })
end

local function makeTab(window, cfg, self)
    local name = cfg.Name or "Tab"

    local content = new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0), CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = self.Theme.Stroke,
        ScrollBarImageTransparency = 0.4, Visible = false,
        Parent = window._contentHolder,
    })
    padding(14, 12, 14, 6, content)

    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = content,
    })

    local order = 0
    local function nextOrder() order = order + 1; return order end

    local tabBtn = new("TextButton", {
        BackgroundColor3 = self.Theme.Surface, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 34), AutoButtonColor = false,
        Text = "", LayoutOrder = nextOrder(), Parent = window._sidebarList,
    })
    corner(self.Radius.Small, tabBtn)

    local accent = new("Frame", {
        BackgroundColor3 = self.Theme.Accent, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 3, 0.4, 0), BackgroundTransparency = 1, Parent = tabBtn,
    })
    corner(2, accent)

    local tabLabel = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 12, 0, 0), Font = self.Fonts.Medium,
        Text = name, TextColor3 = self.Theme.TextMuted,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = tabBtn,
    })

    local tab = { _content = content, _btn = tabBtn, _accent = accent, _label = tabLabel, Instance = content }

    local function select()
        for _, t in ipairs(window._tabs) do
            t._content.Visible = false
            tween(t._btn, SMOOTH, { BackgroundColor3 = self.Theme.Surface })
            tween(t._accent, SMOOTH, { BackgroundTransparency = 1, Size = UDim2.new(0, 3, 0.4, 0) })
            tween(t._label, SMOOTH, { TextColor3 = self.Theme.TextMuted })
        end
        content.Visible = true
        tween(tabBtn, SMOOTH, { BackgroundColor3 = self.Theme.SurfaceHigh })
        tween(accent, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0,
            Size = UDim2.new(0, 3, 0.65, 0),
        })
        tween(tabLabel, SMOOTH, { TextColor3 = self.Theme.Text })
        window._currentTab = tab
    end

    tabBtn.MouseButton1Click:Connect(select)
    tabBtn.MouseEnter:Connect(function()
        if window._currentTab ~= tab then
            tween(tabBtn, FAST, { BackgroundColor3 = self.Theme.SurfaceAlt })
            tween(tabLabel, FAST, { TextColor3 = self.Theme.Text })
        end
    end)
    tabBtn.MouseLeave:Connect(function()
        if window._currentTab ~= tab then
            tween(tabBtn, FAST, { BackgroundColor3 = self.Theme.Surface })
            tween(tabLabel, FAST, { TextColor3 = self.Theme.TextMuted })
        end
    end)

    function tab:Select() select() end
    function tab:CreateSection(title)
        local s = makeSection(content, title, self); s.LayoutOrder = nextOrder(); return s
    end
    function tab:CreateDivider()
        local d = makeDivider(content, self); d.LayoutOrder = nextOrder(); return d
    end
    function tab:CreateToggle(cfg)
        local el = makeToggle(content, cfg, self); el.Instance.LayoutOrder = nextOrder(); return el
    end
    function tab:CreateSlider(cfg)
        local el = makeSlider(content, cfg, self); el.Instance.LayoutOrder = nextOrder(); return el
    end
    function tab:CreateButton(cfg)
        local el = makeButton(content, cfg, self); el.Instance.LayoutOrder = nextOrder(); return el
    end
    function tab:CreateInput(cfg)
        local el = makeInput(content, cfg, self); el.Instance.LayoutOrder = nextOrder(); return el
    end
    function tab:CreateParagraph(cfg)
        local el = makeParagraph(content, cfg, self); el.Instance.LayoutOrder = nextOrder(); return el
    end
    function tab:CreateDropdown(cfg)
        local el = makeDropdown(content, cfg, self); el.Instance.LayoutOrder = nextOrder(); return el
    end
    function tab:CreateLabel(cfg)
        local el = makeLabel(content, cfg, self); el.Instance.LayoutOrder = nextOrder(); return el
    end

    return tab
end

function Azure:CreateWindow(cfg)
    cfg = cfg or {}
    local width  = cfg.Width  or 560
    local height = cfg.Height or 460
    local title  = cfg.Title  or "Azure"

    local gui = new("ScreenGui", {
        Name = "AzureUI", ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 9999,
    })
    safeParent(gui)

    local shadow = new("Frame", {
        Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, width + 8, 0, height + 8),
        ZIndex = 0, Parent = gui,
    })
    corner(self.Radius.Window, shadow)

    local main = new("Frame", {
        Name = "Main", BackgroundColor3 = self.Theme.Background, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, width, 0, height),
        BackgroundTransparency = 1,
        ClipsDescendants = true, Parent = gui,
    })
    corner(self.Radius.Window, main)
    local mainStroke = stroke(self.Theme.Stroke, 1, 0.2, main)

    tween(main, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0,
    })
    tween(shadow, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.7,
    })

    local header = new("Frame", {
        Name = "Header", BackgroundColor3 = self.Theme.Surface,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 42), Parent = main,
    })
    new("Frame", {
        BackgroundColor3 = self.Theme.Accent, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
        BackgroundTransparency = 0.5, Parent = header,
    })
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(0.7, 0, 1, 0), Font = self.Fonts.Bold,
        Text = title, TextColor3 = self.Theme.Text, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
    })

    local close = new("TextButton", {
        BackgroundColor3 = self.Theme.SurfaceHigh, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0, 24, 0, 24), AutoButtonColor = false,
        Text = "x", Font = self.Fonts.Bold,
        TextColor3 = self.Theme.TextMuted, TextSize = 14, Parent = header,
    })
    corner(6, close)
    close.MouseEnter:Connect(function()
        tween(close, FAST, { BackgroundColor3 = self.Theme.Error, TextColor3 = Color3.new(1, 1, 1) })
    end)
    close.MouseLeave:Connect(function()
        tween(close, FAST, { BackgroundColor3 = self.Theme.SurfaceHigh, TextColor3 = self.Theme.TextMuted })
    end)

    local sidebar = new("Frame", {
        Name = "Sidebar", BackgroundColor3 = self.Theme.Surface,
        BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 42),
        Size = UDim2.new(0, 150, 1, -42), Parent = main,
    })
    local sidebarList = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, -16),
        Position = UDim2.new(0, 8, 0, 8), Parent = sidebar,
    })
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4),
        Parent = sidebarList,
    })

    local contentHolder = new("Frame", {
        Name = "Content", BackgroundTransparency = 1,
        Position = UDim2.new(0, 150, 0, 42),
        Size = UDim2.new(1, -150, 1, -42), Parent = main,
    })

    local window = {
        _gui = gui, _main = main, _header = header, _sidebar = sidebar,
        _sidebarList = sidebarList, _contentHolder = contentHolder,
        _tabs = {}, _currentTab = nil, Title = title,
    }

    makeDraggable(main, header,
        function() tween(mainStroke, FAST, { Color = self.Theme.StrokeHigh }) end,
        function() tween(mainStroke, SMOOTH, { Color = self.Theme.Stroke }) end)

    close.MouseButton1Click:Connect(function()
        tween(main, SMOOTH, { BackgroundTransparency = 1 })
        tween(shadow, SMOOTH, { BackgroundTransparency = 1 })
        task.wait(0.25)
        gui:Destroy()
    end)

    function window:CreateTab(cfg)
        cfg = cfg or {}
        local tab = makeTab(window, cfg, self)
        window._tabs[#window._tabs + 1] = tab
        if #window._tabs == 1 then tab:Select() end
        return tab
    end

    function window:SelectTab(tab)
        if tab and tab.Select then tab:Select() end
    end

    function window:Destroy() gui:Destroy() end

    function window:Toggle(state)
        if state == nil then
            main.Visible = not main.Visible
            shadow.Visible = main.Visible
        else
            main.Visible = state
            shadow.Visible = state
        end
    end

    if cfg.ToggleKey then
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == cfg.ToggleKey then window:Toggle() end
        end)
    end

    return window
end

return Azure
