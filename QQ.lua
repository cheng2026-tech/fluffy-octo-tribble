-- ========================================================
-- 熙脚本.lua  ·  纯本地 UI 版 V3.1 Fixed
-- 作者：大肥鱼  |  修复：自瞄速度、注入器适配、台式机缩放
-- ========================================================

local _genv = (type(getgenv) == "function" and getgenv()) or _G
if _genv.__XixiRuntime and _genv.__XixiRuntime.Cleanup then
    pcall(_genv.__XixiRuntime.Cleanup)
end
local Runtime = {Connections={}, Instances={}, Alive=true}
_genv.__XixiRuntime = Runtime

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer

local function TrackConn(c)
    if c and type(c.Disconnect) == "function" then table.insert(Runtime.Connections, c) end
    return c
end
local function TrackInst(i)
    if i and typeof(i) == "Instance" then table.insert(Runtime.Instances, i) end
    return i
end
function Runtime.Cleanup()
    if not Runtime.Alive then return end
    Runtime.Alive = false
    for i = #Runtime.Connections, 1, -1 do
        pcall(function() Runtime.Connections[i]:Disconnect() end)
        Runtime.Connections[i] = nil
    end
    for i = #Runtime.Instances, 1, -1 do
        pcall(function() Runtime.Instances[i]:Destroy() end)
        Runtime.Instances[i] = nil
    end
    if _genv then _genv.__XixiRuntime = nil end
end

if CoreGui:FindFirstChild("XixiUI") then CoreGui.XixiUI:Destroy() end

-- ==================== 点击音效 ====================
local UIClickSound = Instance.new("Sound")
UIClickSound.Name = "XixiUIClick"
UIClickSound.SoundId = "rbxassetid://87675581703510"
UIClickSound.Volume = 0.35
UIClickSound.PlaybackSpeed = 1.0

local function PlayClick(pitch)
    pcall(function()
        local s = UIClickSound:Clone()
        s.PlaybackSpeed = pitch or 1.0
        s.Parent = SoundService
        s:Play()
        s.Ended:Connect(function() s:Destroy() end)
        task.delay(2, function() if s and s.Parent then s:Destroy() end end)
    end)
end

-- ==================== 配置 ====================
local Config = {
    ["自瞄启用"]=false, ["忽略人机"]=true, ["忽略倒地"]=true,
    ["自瞄范围"]=300, ["自瞄速度"]=150,  -- 单位毫秒，默认150ms
    ["连点启用"]=false, ["连点速度"]=50,  -- 单位毫秒
    ["显示FPS"]=false, ["夜视"]=false, ["全图点亮"]=false, ["去雾"]=false,
    ["无限跳跃"]=false, ["穿墙"]=false, ["无敌"]=false,
    ["千倍速度"]=false, ["防挂机"]=false,
    ["移动速度"]=16, ["跳跃高度"]=50, ["视野"]=70, ["重力"]=196,
    ["团队高亮"]=false, ["敌对高亮"]=false, ["ESP透视"]=false,
    ["跳舞"]=false, ["喷火"]=false, ["光环"]=false,
    ["倒立"]=false, ["大头"]=false, ["巨大化"]=false,
    ["彩虹拖尾"]=false, ["火焰拖尾"]=false, ["冰霜拖尾"]=false,
    ["彩虹名字"]=false, ["客户端字幕"]=false, ["全屏特效"]=false,
}
getgenv().XixiConfig = Config

-- ==================== 受保护 GUI 创建 ====================
local function GetProtectedParent()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    return CoreGui
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "XixiUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if syn and syn.protect_gui then pcall(syn.protect_gui, ScreenGui) end
ScreenGui.Parent = GetProtectedParent()
TrackInst(ScreenGui)

-- ==================== 自适应 ====================
local Main
local function ApplyResponsive()
    if not Main then return end
    local vp = workspace.CurrentCamera.ViewportSize
    local sw, sh = vp.X, vp.Y
    local baseW, baseH = 620, 440
    local scale = math.min((sw - 40) / baseW, (sh - 40) / baseH)
    scale = math.clamp(scale, 0.6, 1.6)  -- 上限提高到1.6，台式机更大
    local sc = Main:FindFirstChild("ResponsiveScale")
    if not sc then
        sc = Instance.new("UIScale")
        sc.Name = "ResponsiveScale"
        sc.Parent = Main
    end
    sc.Scale = scale
    Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    Main.AnchorPoint = Vector2.new(0.5, 0.5)
end

-- ==================== 玻璃 ====================
local function ApplyGlass(frame)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1,0,1,0)
    bg.BackgroundColor3 = Color3.fromRGB(245,248,252)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel = 0
    bg.ZIndex = 1
    bg.Parent = frame
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0,20)
    local grad = Instance.new("UIGradient", bg)
    grad.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(225,235,245))
    grad.Rotation = 90
    local border = Instance.new("Frame")
    border.Size = UDim2.new(1,-2,1,-2)
    border.Position = UDim2.new(0,1,0,1)
    border.BackgroundTransparency = 1
    border.ZIndex = 6
    border.Parent = frame
    Instance.new("UICorner", border).CornerRadius = UDim.new(0,20)
    local st = Instance.new("UIStroke", border)
    st.Thickness = 1.2
    st.Color = Color3.fromRGB(150,180,210)
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
end

-- ==================== 主窗口 ====================
Main = Instance.new("Frame")
Main.Size = UDim2.new(0,620,0,440)
Main.BackgroundTransparency = 1
Main.Active = true
Main.Draggable = true
Main.ZIndex = 2
Main.Parent = ScreenGui
ApplyGlass(Main)

-- ==================== 侧边栏 ====================
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0,140,1,0)
Sidebar.BackgroundColor3 = Color3.fromRGB(235,238,242)
Sidebar.BackgroundTransparency = 0.3
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 3
Sidebar.Parent = Main
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0,20)

-- ==================== 自适应头像 ====================
local AvatarFrame = Instance.new("Frame")
AvatarFrame.Size = UDim2.new(0,52,0,52)
AvatarFrame.Position = UDim2.new(0,10,0,10)
AvatarFrame.BackgroundColor3 = Color3.fromRGB(200,205,215)
AvatarFrame.BorderSizePixel = 0
AvatarFrame.ZIndex = 5
AvatarFrame.Parent = Sidebar
Instance.new("UICorner", AvatarFrame).CornerRadius = UDim.new(0,26)
local AvStroke = Instance.new("UIStroke", AvatarFrame)
AvStroke.Color = Color3.fromRGB(0,122,255)
AvStroke.Thickness = 2
AvStroke.Transparency = 0.2

local AvatarImg = Instance.new("ImageLabel")
AvatarImg.Size = UDim2.new(1,-4,1,-4)
AvatarImg.Position = UDim2.new(0,2,0,2)
AvatarImg.BackgroundTransparency = 1
AvatarImg.ZIndex = 6
AvatarImg.Parent = AvatarFrame
Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(0,24)

local AvatarBg = Instance.new("TextLabel")
AvatarBg.Size = UDim2.new(1,0,1,0)
AvatarBg.BackgroundTransparency = 1
AvatarBg.Text = "…"
AvatarBg.TextColor3 = Color3.fromRGB(150,150,150)
AvatarBg.TextSize = 20
AvatarBg.Font = Enum.Font.GothamBold
AvatarBg.ZIndex = 5
AvatarBg.Parent = AvatarFrame

task.spawn(function()
    local ok, url = pcall(function()
        return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end)
    if ok and url and typeof(url) == "string" and #url > 0 then
        AvatarImg.Image = url
        AvatarBg.Visible = false
    else
        AvatarBg.Text = string.sub(LocalPlayer.DisplayName, 1, 1)
    end
    task.spawn(function()
        while AvatarFrame.Parent do
            local oku, u = pcall(function()
                return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
            end)
            if oku and u then AvatarImg.Image = u end
            task.wait(30)
        end
    end)
end)

local NameLabel = Instance.new("TextLabel")
NameLabel.Size = UDim2.new(1,-16,0,18)
NameLabel.Position = UDim2.new(0,8,0,68)
NameLabel.BackgroundTransparency = 1
NameLabel.Text = LocalPlayer.DisplayName
NameLabel.TextColor3 = Color3.fromRGB(40,40,40)
NameLabel.TextSize = 12
NameLabel.Font = Enum.Font.GothamBold
NameLabel.TextXAlignment = Enum.TextXAlignment.Left
NameLabel.TextTruncate = Enum.TextTruncate.AtEnd
NameLabel.ZIndex = 5
NameLabel.Parent = Sidebar

local VerLabel = Instance.new("TextLabel")
VerLabel.Size = UDim2.new(1,-16,0,14)
VerLabel.Position = UDim2.new(0,8,0,86)
VerLabel.BackgroundTransparency = 1
VerLabel.Text = "熙脚本 V3.1 · 本地版"
VerLabel.TextColor3 = Color3.fromRGB(120,120,120)
VerLabel.TextSize = 9
VerLabel.Font = Enum.Font.Gotham
VerLabel.TextXAlignment = Enum.TextXAlignment.Left
VerLabel.ZIndex = 5
VerLabel.Parent = Sidebar

-- ==================== 导航 ====================
local Navs = {"公告","通用","战斗","移动","视觉","娱乐","音乐","服务器","国内脚本","爱国者","设置"}
local Pages = {}
local NavButtons = {}
local currentTab = "公告"

local function SwitchPage(name)
    currentTab = name
    for n, p in pairs(Pages) do p.Visible = (n == name) end
    for n, b in pairs(NavButtons) do
        local active = (n == name)
        TweenService:Create(b, TweenInfo.new(0.15), {
            BackgroundColor3 = active and Color3.fromRGB(255,255,255) or Color3.fromRGB(235,238,242),
            BackgroundTransparency = active and 0 or 0.6,
            TextColor3 = active and Color3.fromRGB(0,122,255) or Color3.fromRGB(80,80,80)
        }):Play()
        b.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
    end
end

for i, n in ipairs(Navs) do
    local NB = Instance.new("TextButton")
    NB.Size = UDim2.new(1,-16,0,26)
    NB.Position = UDim2.new(0,8,0,110+(i-1)*28)
    NB.BackgroundColor3 = Color3.fromRGB(235,238,242)
    NB.BackgroundTransparency = 0.6
    NB.BorderSizePixel = 0
    NB.Text = n
    NB.TextColor3 = Color3.fromRGB(80,80,80)
    NB.TextSize = 11
    NB.Font = Enum.Font.GothamMedium
    NB.ZIndex = 4
    NB.Parent = Sidebar
    Instance.new("UICorner", NB).CornerRadius = UDim.new(0,8)
    NB.MouseButton1Click:Connect(function()
        PlayClick(0.9)
        SwitchPage(n)
    end)
    NavButtons[n] = NB
end

-- ==================== 内容区 ====================
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1,-140,1,0)
ContentArea.Position = UDim2.new(0,140,0,0)
ContentArea.BackgroundTransparency = 1
ContentArea.ZIndex = 4
ContentArea.Parent = Main

local ContentMask = Instance.new("Frame")
ContentMask.Size = UDim2.new(1,-16,1,-16)
ContentMask.Position = UDim2.new(0,8,0,8)
ContentMask.BackgroundColor3 = Color3.fromRGB(255,255,255)
ContentMask.BackgroundTransparency = 0.5
ContentMask.BorderSizePixel = 0
ContentMask.ZIndex = 4
ContentMask.Parent = ContentArea
Instance.new("UICorner", ContentMask).CornerRadius = UDim.new(0,20)

local function CreatePage(name)
    local P = Instance.new("ScrollingFrame")
    P.Name = name
    P.Size = UDim2.new(1,0,1,0)
    P.BackgroundTransparency = 1
    P.BorderSizePixel = 0
    P.ScrollBarThickness = 2
    P.CanvasSize = UDim2.new(0,0,0,0)
    P.AutomaticCanvasSize = Enum.AutomaticSize.Y
    P.Visible = false
    P.ZIndex = 5
    P.Parent = ContentArea
    local pad = Instance.new("UIPadding", P)
    pad.PaddingTop = UDim2.new(0,12)
    pad.PaddingLeft = UDim2.new(0,12)
    pad.PaddingRight = UDim2.new(0,12)
    pad.PaddingBottom = UDim2.new(0,12)
    local layout = Instance.new("UIListLayout", P)
    layout.Padding = UDim.new(0,6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    Pages[name] = P
    return P
end

local function Section(parent, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,0,20)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(120,130,140)
    l.TextSize = 11
    l.Font = Enum.Font.GothamMedium
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
end

local function Toggle(parent, key, onChange)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,24)
    f.BackgroundTransparency = 1
    f.Parent = parent
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.72,0,1,0)
    l.BackgroundTransparency = 1
    l.Text = key
    l.TextColor3 = Color3.fromRGB(60,60,60)
    l.TextSize = 11
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    local state = Config[key] or false
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,32,0,16)
    b.Position = UDim2.new(1,-32,0.5,-8)
    b.BackgroundColor3 = state and Color3.fromRGB(0,122,255) or Color3.fromRGB(200,200,200)
    b.BorderSizePixel = 0
    b.Text = ""
    b.Parent = f
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(0,12,0,12)
    c.Position = state and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)
    c.BackgroundColor3 = Color3.fromRGB(255,255,255)
    c.BorderSizePixel = 0
    c.Parent = b
    Instance.new("UICorner", c).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(function()
        PlayClick(state and 0.95 or 1.15)
        state = not state
        Config[key] = state
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = state and Color3.fromRGB(0,122,255) or Color3.fromRGB(200,200,200)}):Play()
        TweenService:Create(c, TweenInfo.new(0.15), {Position = state and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)}):Play()
        if onChange then pcall(onChange, state) end
    end)
end

local function Slider(parent, key, min, max, onChange)
    local def = Config[key] or min
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,30)
    f.BackgroundTransparency = 1
    f.Parent = parent
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.6,0,0,14)
    l.BackgroundTransparency = 1
    l.Text = key
    l.TextColor3 = Color3.fromRGB(60,60,60)
    l.TextSize = 10
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    local vl = Instance.new("TextLabel")
    vl.Size = UDim2.new(0.4,0,0,14)
    vl.Position = UDim2.new(0.6,0,0,0)
    vl.BackgroundTransparency = 1
    vl.Text = tostring(def)
    vl.TextColor3 = Color3.fromRGB(0,122,255)
    vl.TextSize = 10
    vl.Font = Enum.Font.GothamMedium
    vl.TextXAlignment = Enum.TextXAlignment.Right
    vl.Parent = f
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1,0,0,3)
    bar.Position = UDim2.new(0,0,0,20)
    bar.BackgroundColor3 = Color3.fromRGB(200,200,200)
    bar.BackgroundTransparency = 0.2
    bar.BorderSizePixel = 0
    bar.Parent = f
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0,2)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((def-min)/(max-min),0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(0,122,255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0,2)
    local dragging = false
    local function up(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * rel)
        fill.Size = UDim2.new(rel,0,1,0)
        vl.Text = tostring(val)
        Config[key] = val
        if onChange then pcall(onChange, val) end
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            PlayClick(1.25)
            dragging = true; up(input.Position.X)
        end
    end)
    TrackConn(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            up(input.Position.X)
        end
    end))
    TrackConn(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

local function RemoteButton(parent, name, icon, url)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,26)
    btn.BackgroundColor3 = Color3.fromRGB(240,242,245)
    btn.BorderSizePixel = 0
    btn.Text = (icon or "📦").."  "..name
    btn.TextColor3 = Color3.fromRGB(60,60,60)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamMedium
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    local pad = Instance.new("UIPadding", btn)
    pad.PaddingLeft = UDim.new(0,10)
    btn.MouseButton1Click:Connect(function()
        PlayClick(1.1)
        btn.Text = "⏳ " .. name
        task.spawn(function()
            local ok, err = pcall(function()
                local src = game:HttpGet(url)
                local fn, compileErr = loadstring(src)
                if not fn then error(compileErr or "compile failed") end
                fn()
            end)
            if ok then
                btn.Text = "✅ " .. name
                task.wait(1.5)
                btn.Text = (icon or "📦").."  "..name
            else
                btn.Text = "❌ " .. name
                warn("[熙熙] "..name..": "..tostring(err))
                task.wait(2)
                btn.Text = (icon or "📦").."  "..name
            end
        end)
    end)
    return btn
end

-- ==================== 功能实现 ====================
local Feature = {}
Feature.Conns = {}
local function Reg(k, on, off) Feature[k] = {on=on, off=off} end
local function Fire(k, state)
    local f = Feature[k]; if not f then return end
    if state then if f.on then pcall(f.on) end
    else
        if f.off then pcall(f.off) end
        if Feature.Conns[k] then pcall(function() Feature.Conns[k]:Disconnect() end); Feature.Conns[k] = nil end
    end
end

Reg("无限跳跃", function()
    Feature.Conns["无限跳跃"] = UserInputService.JumpRequest:Connect(function()
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("Humanoid") then c.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end)
Reg("穿墙", function()
    Feature.Conns["穿墙"] = RunService.Stepped:Connect(function()
        local c = LocalPlayer.Character
        if c then for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end end
    end)
end, function()
    local c = LocalPlayer.Character
    if c then for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = true end
    end end
end)
Reg("无敌", function()
    Feature.Conns["无敌"] = RunService.Heartbeat:Connect(function()
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("Humanoid") then c.Humanoid.MaxHealth = math.huge; c.Humanoid.Health = math.huge end
    end)
end)
Reg("千倍速度", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed = 1000 end
end, function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed = 16 end
end)
Reg("防挂机", function()
    Feature.Conns["防挂机"] = LocalPlayer.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
end)
Reg("夜视", function()
    Lighting.Brightness = 2; Lighting.ClockTime = 14
    Lighting.FogEnd = 100000; Lighting.GlobalShadows = false
end, function()
    Lighting.Brightness = 1; Lighting.GlobalShadows = true
end)
Reg("去雾", function()
    Lighting.FogEnd = 100000; Lighting.FogStart = 50000
end, function()
    Lighting.FogEnd = 1000; Lighting.FogStart = 0
end)
Reg("全图点亮", function()
    Lighting.Brightness = 5; Lighting.ClockTime = 14; Lighting.FogEnd = 100000
    Lighting.GlobalShadows = false; Lighting.OutdoorAmbient = Color3.fromRGB(200,200,200)
end, function()
    Lighting.Brightness = 1; Lighting.GlobalShadows = true
end)
Reg("团队高亮", function()
    local myTeam = LocalPlayer.Team
    Feature.Conns["团队高亮"] = RunService.RenderStepped:Connect(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Team == myTeam then
                if not p.Character:FindFirstChild("TeamGlow") then
                    local hl = Instance.new("Highlight"); hl.Name = "TeamGlow"
                    hl.FillColor = Color3.fromRGB(0,100,255); hl.OutlineColor = Color3.fromRGB(0,150,255)
                    hl.FillTransparency = 0.5; hl.Parent = p.Character
                end
            end
        end
    end)
end, function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then local hl = p.Character:FindFirstChild("TeamGlow"); if hl then hl:Destroy() end end
    end
end)
Reg("敌对高亮", function()
    local myTeam = LocalPlayer.Team
    Feature.Conns["敌对高亮"] = RunService.RenderStepped:Connect(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Team ~= myTeam then
                if not p.Character:FindFirstChild("EnemyGlow") then
                    local hl = Instance.new("Highlight"); hl.Name = "EnemyGlow"
                    hl.FillColor = Color3.fromRGB(255,0,0); hl.OutlineColor = Color3.fromRGB(255,50,50)
                    hl.FillTransparency = 0.5; hl.Parent = p.Character
                end
            end
        end
    end)
end, function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then local hl = p.Character:FindFirstChild("EnemyGlow"); if hl then hl:Destroy() end end
    end
end)
Reg("ESP透视", function()
    Feature.Conns["ESP透视"] = RunService.RenderStepped:Connect(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and not p.Character:FindFirstChild("ESPGlow") then
                local hl = Instance.new("Highlight"); hl.Name = "ESPGlow"
                hl.FillColor = Color3.fromRGB(255,215,0); hl.OutlineColor = Color3.fromRGB(255,255,255)
                hl.FillTransparency = 0.4; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = p.Character
            end
        end
    end)
end, function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then local hl = p.Character:FindFirstChild("ESPGlow"); if hl then hl:Destroy() end end
    end
end)
Reg("跳舞", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Humanoid") then
        local anim = Instance.new("Animation"); anim.AnimationId = "rbxassetid://5918726674"
        local track = c.Humanoid:LoadAnimation(anim); track:Play()
        Feature.Conns["跳舞"] = {Disconnect = function() track:Stop() end}
    end
end)
Reg("喷火", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local fire = Instance.new("ParticleEmitter"); fire.Name = "FireFX"
        fire.Texture = "rbxassetid://241876428"
        fire.Color = ColorSequence.new(Color3.fromRGB(255,100,0))
        fire.Rate = 30; fire.Speed = NumberRange.new(3,6); fire.Lifetime = NumberRange.new(0.5,1)
        fire.Parent = c.HumanoidRootPart
    end
end, function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local fx = c.HumanoidRootPart:FindFirstChild("FireFX"); if fx then fx:Destroy() end
    end
end)
Reg("光环", function()
    local c = LocalPlayer.Character
    if c then
        local hl = Instance.new("Highlight"); hl.Name = "PlayerGlow"
        hl.FillColor = Color3.fromRGB(255,255,0); hl.OutlineColor = Color3.fromRGB(255,200,0)
        hl.FillTransparency = 0.3; hl.Parent = c
    end
end, function()
    local c = LocalPlayer.Character
    if c then local hl = c:FindFirstChild("PlayerGlow"); if hl then hl:Destroy() end end
end)
Reg("倒立", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        c.HumanoidRootPart.CFrame = c.HumanoidRootPart.CFrame * CFrame.Angles(0,0,math.rad(180))
    end
end)
Reg("大头", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Head") then c.Head.Size = Vector3.new(4,4,4) end
end, function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Head") then c.Head.Size = Vector3.new(2,1,1) end
end)
Reg("巨大化", function()
    local c = LocalPlayer.Character
    if c then for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then v.Size = v.Size * 3 end
    end end
end, function()
    local c = LocalPlayer.Character
    if c then for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then v.Size = v.Size / 3 end
    end end
end)
Reg("全屏特效", function()
    local fx = Instance.new("ColorCorrectionEffect"); fx.Name = "ScreenFX"
    fx.TintColor = Color3.fromRGB(255,100,200); fx.Parent = Lighting
end, function()
    local fx = Lighting:FindFirstChild("ScreenFX"); if fx then fx:Destroy() end
end)
Reg("彩虹拖尾", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local hrp = c.HumanoidRootPart
        local trail = Instance.new("Trail"); trail.Name = "PlayerTrail"
        local a0 = Instance.new("Attachment"); a0.Parent = hrp
        local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0,-2,0); a1.Parent = hrp
        trail.Attachment0 = a0; trail.Attachment1 = a1
        trail.Color = ColorSequence.new(Color3.fromRGB(255,0,0), Color3.fromRGB(0,255,0), Color3.fromRGB(0,0,255))
        trail.Lifetime = 0.5; trail.Parent = hrp
    end
end, function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local t = c.HumanoidRootPart:FindFirstChild("PlayerTrail"); if t then t:Destroy() end
    end
end)
Reg("火焰拖尾", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local hrp = c.HumanoidRootPart
        local trail = Instance.new("Trail"); trail.Name = "FireTrail"
        local a0 = Instance.new("Attachment"); a0.Parent = hrp
        local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0,-2,0); a1.Parent = hrp
        trail.Attachment0 = a0; trail.Attachment1 = a1
        trail.Color = ColorSequence.new(Color3.fromRGB(255,50,0), Color3.fromRGB(255,150,0), Color3.fromRGB(255,255,0))
        trail.Lifetime = 0.3; trail.Parent = hrp
    end
end, function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local t = c.HumanoidRootPart:FindFirstChild("FireTrail"); if t then t:Destroy() end
    end
end)
Reg("冰霜拖尾", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local hrp = c.HumanoidRootPart
        local trail = Instance.new("Trail"); trail.Name = "IceTrail"
        local a0 = Instance.new("Attachment"); a0.Parent = hrp
        local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0,-2,0); a1.Parent = hrp
        trail.Attachment0 = a0; trail.Attachment1 = a1
        trail.Color = ColorSequence.new(Color3.fromRGB(100,200,255), Color3.fromRGB(200,240,255))
        trail.Lifetime = 0.4; trail.Parent = hrp
    end
end, function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local t = c.HumanoidRootPart:FindFirstChild("IceTrail"); if t then t:Destroy() end
    end
end)
Reg("彩虹名字", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Head") then
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0,150,0,30); bb.StudsOffset = Vector3.new(0,3,0)
        bb.AlwaysOnTop = true; bb.Parent = c.Head
        local nl = Instance.new("TextLabel"); nl.Size = UDim2.new(1,0,1,0)
        nl.BackgroundTransparency = 1; nl.Text = LocalPlayer.DisplayName .. " 👑"
        nl.Font = Enum.Font.GothamBold; nl.TextSize = 14; nl.Name = "RainbowName"
        nl.TextStrokeTransparency = 0; nl.TextStrokeColor3 = Color3.fromRGB(0,0,0); nl.Parent = bb
        local hue = 0
        Feature.Conns["彩虹名字"] = RunService.RenderStepped:Connect(function(dt)
            hue = (hue + dt*0.5) % 1
            nl.TextColor3 = Color3.fromHSV(hue, 1, 1)
        end)
    end
end, function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Head") then
        local bb = c.Head:FindFirstChild("BillboardGui"); if bb then bb:Destroy() end
    end
end)
Reg("客户端字幕", function()
    local subGui = Instance.new("ScreenGui"); subGui.Name = "SubtitleGui"
    subGui.ResetOnSpawn = false; subGui.Parent = CoreGui
    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(0,500,0,60); subLabel.Position = UDim2.new(0.5,-250,0,10)
    subLabel.Text = LocalPlayer.Name .. " 已入侵服务器"
    subLabel.Font = Enum.Font.GothamBold; subLabel.TextSize = 22; subLabel.BackgroundTransparency = 1
    subLabel.TextStrokeTransparency = 0; subLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    subLabel.Parent = subGui
    Feature.Conns["客户端字幕"] = {Disconnect = function() if subGui then subGui:Destroy() end end}
end)

-- ==================== FPS ====================
local fpsGui = Instance.new("ScreenGui"); fpsGui.Name = "XixiFPS"
fpsGui.ResetOnSpawn = false; fpsGui.Parent = CoreGui
local FPSLabel = Instance.new("TextLabel")
FPSLabel.Size = UDim2.new(0,180,0,24); FPSLabel.Position = UDim2.new(0,8,0,8)
FPSLabel.BackgroundTransparency = 1; FPSLabel.Font = Enum.Font.GothamBold
FPSLabel.TextSize = 14; FPSLabel.TextXAlignment = Enum.TextXAlignment.Left
FPSLabel.RichText = true; FPSLabel.TextStrokeTransparency = 0; FPSLabel.Visible = false
FPSLabel.Parent = fpsGui
local fc, lt = 0, tick()
TrackConn(RunService.RenderStepped:Connect(function()
    if Config["显示FPS"] then
        FPSLabel.Visible = true; fc = fc + 1
        local e = tick() - lt
        if e >= 0.5 then
            local fps = math.floor(fc/e); fc = 0; lt = tick()
            local c = fps >= 30 and "80,255,80" or "255,80,80"
            FPSLabel.Text = '<font color="rgb(255,255,255)">FPS: </font><font color="rgb('..c..')">'..fps..'</font>'
        end
    else FPSLabel.Visible = false end
end))

-- ==================== 自瞄（修复单位） ====================
local aimAcc = 0
TrackConn(RunService.RenderStepped:Connect(function(dt)
    if not Config["自瞄启用"] then return end
    aimAcc = aimAcc + dt
    if aimAcc < Config["自瞄速度"]/1000 then return end  -- 毫秒转秒
    aimAcc = 0
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local maxR = Config["自瞄范围"]; local myTeam = LocalPlayer.Team
    local target, minD = nil, maxR
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChild("Humanoid")
            if hrp and hum then
                local dead = hum.Health <= 0
                local teammate = (p.Team == myTeam)
                if not teammate and not (Config["忽略倒地"] and dead) then
                    local d = (hrp.Position - myRoot.Position).Magnitude
                    if d < minD then minD = d; target = hrp end
                end
            end
        end
    end
    if target then
        local cam = workspace.CurrentCamera
        cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, target.Position), 0.35)
    end
end))

-- ==================== 连点 ====================
local clickAcc = 0
TrackConn(RunService.RenderStepped:Connect(function(dt)
    if not Config["连点启用"] then return end
    clickAcc = clickAcc + dt
    if clickAcc >= Config["连点速度"]/1000 then
        clickAcc = 0
        local s = workspace.CurrentCamera.ViewportSize
        VirtualUser:Button1Down(Vector2.new(s.X/2, s.Y/2))
        VirtualUser:Button1Up(Vector2.new(s.X/2, s.Y/2))
    end
end))

-- ==================== 数值应用 ====================
TrackConn(RunService.Heartbeat:Connect(function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Humanoid") then
        if not Config["千倍速度"] then c.Humanoid.WalkSpeed = Config["移动速度"] end
        c.Humanoid.JumpHeight = Config["跳跃高度"]
    end
    if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = Config["视野"] end
    workspace.Gravity = Config["重力"]
end))

-- ==================== 页面：公告 ====================
local P_ann = CreatePage("公告")
Section(P_ann, "熙脚本 · 本地版 V3.1")
local annText = Instance.new("TextLabel")
annText.Size = UDim2.new(1,0,0,220); annText.BackgroundTransparency = 1
annText.Text = "👤 脚本：熙熙\n👤 作者：大肥鱼\n\n🔄 持续更新\n\n" .. LocalPlayer.DisplayName .. " 欢迎使用"
annText.TextColor3 = Color3.fromRGB(70,70,70); annText.TextSize = 12; annText.TextWrapped = true
annText.TextXAlignment = Enum.TextXAlignment.Left; annText.TextYAlignment = Enum.TextYAlignment.Top
annText.Parent = P_ann

-- ==================== 页面：通用 ====================
local P_gen = CreatePage("通用")
Section(P_gen, "基础功能")
local gr1 = Instance.new("Frame"); gr1.Size = UDim2.new(1,0,0,24); gr1.BackgroundTransparency=1; gr1.Parent = P_gen
local gl1 = Instance.new("Frame"); gl1.Size = UDim2.new(0.5,-4,1,0); gl1.BackgroundTransparency=1; gl1.Parent = gr1
local gr1r = Instance.new("Frame"); gr1r.Size = UDim2.new(0.5,-4,1,0); gr1r.Position=UDim2.new(0.5,4,0,0); gr1r.BackgroundTransparency=1; gr1r.Parent = gr1
Toggle(gl1, "无限跳跃", function(v) Fire("无限跳跃", v) end)
Toggle(gr1r, "穿墙", function(v) Fire("穿墙", v) end)
local gr2 = Instance.new("Frame"); gr2.Size = UDim2.new(1,0,0,24); gr2.BackgroundTransparency=1; gr2.Parent = P_gen
local gl2 = Instance.new("Frame"); gl2.Size = UDim2.new(0.5,-4,1,0); gl2.BackgroundTransparency=1; gl2.Parent = gr2
local gr2r = Instance.new("Frame"); gr2r.Size = UDim2.new(0.5,-4,1,0); gr2r.Position=UDim2.new(0.5,4,0,0); gr2r.BackgroundTransparency=1; gr2r.Parent = gr2
Toggle(gl2, "无敌", function(v) Fire("无敌", v) end)
Toggle(gr2r, "千倍速度", function(v) Fire("千倍速度", v) end)
Toggle(P_gen, "防挂机", function(v) Fire("防挂机", v) end)
Section(P_gen, "自瞄 / 连点")
Toggle(P_gen, "自瞄启用")
local ar = Instance.new("Frame"); ar.Size = UDim2.new(1,0,0,30); ar.BackgroundTransparency=1; ar.Parent = P_gen
local al = Instance.new("Frame"); al.Size = UDim2.new(0.5,-4,1,0); al.BackgroundTransparency=1; al.Parent = ar
local arr = Instance.new("Frame"); arr.Size = UDim2.new(0.5,-4,1,0); arr.Position=UDim2.new(0.5,4,0,0); arr.BackgroundTransparency=1; arr.Parent = ar
Slider(al, "自瞄范围", 50, 1000)
Slider(arr, "自瞄速度", 10, 500)  -- 毫秒，10~500ms
Toggle(P_gen, "连点启用")
Slider(P_gen, "连点速度", 10, 500)

-- ==================== 页面：战斗 ====================
local P_fight = CreatePage("战斗")
Section(P_fight, "标记")
local fr1 = Instance.new("Frame"); fr1.Size = UDim2.new(1,0,0,24); fr1.BackgroundTransparency=1; fr1.Parent = P_fight
local fl1 = Instance.new("Frame"); fl1.Size = UDim2.new(0.5,-4,1,0); fl1.BackgroundTransparency=1; fl1.Parent = fr1
local fr1r = Instance.new("Frame"); fr1r.Size = UDim2.new(0.5,-4,1,0); fr1r.Position=UDim2.new(0.5,4,0,0); fr1r.BackgroundTransparency=1; fr1r.Parent = fr1
Toggle(fl1, "团队高亮", function(v) Fire("团队高亮", v) end)
Toggle(fr1r, "敌对高亮", function(v) Fire("敌对高亮", v) end)
Toggle(P_fight, "ESP透视", function(v) Fire("ESP透视", v) end)

-- ==================== 页面：移动 ====================
local P_move = CreatePage("移动")
Section(P_move, "数值调节")
Slider(P_move, "移动速度", 1, 500)
Slider(P_move, "跳跃高度", 1, 500)
Slider(P_move, "视野", 30, 120)
Slider(P_move, "重力", 1, 500)

-- ==================== 页面：视觉 ====================
local P_vis = CreatePage("视觉")
Section(P_vis, "光照")
local vr1 = Instance.new("Frame"); vr1.Size = UDim2.new(1,0,0,24); vr1.BackgroundTransparency=1; vr1.Parent = P_vis
local vl1 = Instance.new("Frame"); vl1.Size = UDim2.new(0.5,-4,1,0); vl1.BackgroundTransparency=1; vl1.Parent = vr1
local vr1r = Instance.new("Frame"); vr1r.Size = UDim2.new(0.5,-4,1,0); vr1r.Position=UDim2.new(0.5,4,0,0); vr1r.BackgroundTransparency=1; vr1r.Parent = vr1
Toggle(vl1, "夜视", function(v) Fire("夜视", v) end)
Toggle(vr1r, "去雾", function(v) Fire("去雾", v) end)
Toggle(P_vis, "全图点亮", function(v) Fire("全图点亮", v) end)
Section(P_vis, "界面")
Toggle(P_vis, "显示FPS")

-- ==================== 页面：娱乐 ====================
local P_fun = CreatePage("娱乐")
Section(P_fun, "趣味")
local er1 = Instance.new("Frame"); er1.Size = UDim2.new(1,0,0,24); er1.BackgroundTransparency=1; er1.Parent = P_fun
local el1 = Instance.new("Frame"); el1.Size = UDim2.new(0.5,-4,1,0); el1.BackgroundTransparency=1; el1.Parent = er1
local er1r = Instance.new("Frame"); er1r.Size = UDim2.new(0.5,-4,1,0); er1r.Position=UDim2.new(0.5,4,0,0); er1r.BackgroundTransparency=1; er1r.Parent = er1
Toggle(el1, "跳舞", function(v) Fire("跳舞", v) end)
Toggle(er1r, "喷火", function(v) Fire("喷火", v) end)
local er2 = Instance.new("Frame"); er2.Size = UDim2.new(1,0,0,24); er2.BackgroundTransparency=1; er2.Parent = P_fun
local el2 = Instance.new("Frame"); el2.Size = UDim2.new(0.5,-4,1,0); el2.BackgroundTransparency=1; el2.Parent = er2
local er2r = Instance.new("Frame"); er2r.Size = UDim2.new(0.5,-4,1,0); er2r.Position=UDim2.new(0.5,4,0,0); er2r.BackgroundTransparency=1; er2r.Parent = er2
Toggle(el2, "光环", function(v) Fire("光环", v) end)
Toggle(er2r, "倒立", function(v) Fire("倒立", v) end)
local er3 = Instance.new("Frame"); er3.Size = UDim2.new(1,0,0,24); er3.BackgroundTransparency=1; er3.Parent = P_fun
local el3 = Instance.new("Frame"); el3.Size = UDim2.new(0.5,-4,1,0); el3.BackgroundTransparency=1; el3.Parent = er3
local er3r = Instance.new("Frame"); er3r.Size = UDim2.new(0.5,-4,1,0); er3r.Position=UDim2.new(0.5,4,0,0); er3r.BackgroundTransparency=1; er3r.Parent = er3
Toggle(el3, "大头", function(v) Fire("大头", v) end)
Toggle(er3r, "巨大化", function(v) Fire("巨大化", v) end)
local er4 = Instance.new("Frame"); er4.Size = UDim2.new(1,0,0,24); er4.BackgroundTransparency=1; er4.Parent = P_fun
local el4 = Instance.new("Frame"); el4.Size = UDim2.new(0.5,-4,1,0); el4.BackgroundTransparency=1; el4.Parent = er4
local er4r = Instance.new("Frame"); er4r.Size = UDim2.new(0.5,-4,1,0); er4r.Position=UDim2.new(0.5,4,0,0); er4r.BackgroundTransparency=1; er4r.Parent = er4
Toggle(el4, "彩虹拖尾", function(v) Fire("彩虹拖尾", v) end)
Toggle(er4r, "火焰拖尾", function(v) Fire("火焰拖尾", v) end)
local er5 = Instance.new("Frame"); er5.Size = UDim2.new(1,0,0,24); er5.BackgroundTransparency=1; er5.Parent = P_fun
local el5 = Instance.new("Frame"); el5.Size = UDim2.new(0.5,-4,1,0); el5.BackgroundTransparency=1; el5.Parent = er5
local er5r = Instance.new("Frame"); er5r.Size = UDim2.new(0.5,-4,1,0); er5r.Position=UDim2.new(0.5,4,0,0); er5r.BackgroundTransparency=1; er5r.Parent = er5
Toggle(el5, "冰霜拖尾", function(v) Fire("冰霜拖尾", v) end)
Toggle(er5r, "彩虹名字", function(v) Fire("彩虹名字", v) end)
Toggle(P_fun, "客户端字幕", function(v) Fire("客户端字幕", v) end)
Toggle(P_fun, "全屏特效", function(v) Fire("全屏特效", v) end)

-- ==================== 页面：音乐 ====================
local P_music = CreatePage("音乐")
Section(P_music, "音乐区")
local MusicList = {
    {name="进击的巨人", icon="🎵", id="89711807693889"},
    {name="误闯天家", icon="🎶", id="124384558101360"},
    {name="DJ喂喂喂", icon="🎧", id="90054735589094"},
    {name="Unhappy", icon="🔊", id="88523902860927"},
    {name="震撼小曲二", icon="🎼", id="137717310854691"},
    {name="曾经的王", icon="🕺", id="121931252233493"},
    {name="离开我的依赖", icon="🌻", id="112834898401032"},
    {name="雨爱", icon="🌸", id="79277371759525"},
    {name="iqoo", icon="🎁", id="75047041148646"},
    {name="玉米饼", icon="🌽", id="142376088"},
    {name="我太想进步了", icon="🍺", id="126846792948717"},
    {name="最初的记忆", icon="💜", id="108869978075942"},
    {name="海与你", icon="🥶", id="76421239273915"},
    {name="失眠", icon="😴", id="138048397060431"},
    {name="祖国人进行曲", icon="🎃", id="86555185586884"},
}
for _, m in ipairs(MusicList) do
    local f = Instance.new("Frame"); f.Size = UDim2.new(1,0,0,28); f.BackgroundTransparency=1; f.Parent = P_music
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(1,-64,1,0); l.BackgroundTransparency=1
    l.Text = m.icon.."  "..m.name; l.TextColor3 = Color3.fromRGB(60,60,60)
    l.TextSize = 11; l.Font = Enum.Font.Gotham; l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f
    local b = Instance.new("TextButton"); b.Size = UDim2.new(0,56,0,22); b.Position = UDim2.new(1,-56,0.5,-11)
    b.BackgroundColor3 = Color3.fromRGB(0,122,255); b.BorderSizePixel = 0
    b.Text = "播放"; b.TextColor3 = Color3.fromRGB(255,255,255); b.TextSize = 10
    b.Font = Enum.Font.GothamBold; b.Parent = f
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    local playing, sound = false, nil
    b.MouseButton1Click:Connect(function()
        PlayClick(1.1)
        if playing then
            if sound then sound:Stop(); sound:Destroy(); sound=nil end
            playing=false; b.Text="播放"
        else
            sound = Instance.new("Sound"); sound.SoundId = "rbxassetid://"..m.id
            sound.Volume = 1; sound.Parent = workspace; sound:Play()
            sound.Ended:Connect(function() if sound then sound:Destroy() end; sound=nil; playing=false; b.Text="播放" end)
            playing=true; b.Text="停止"
        end
    end)
end

-- ==================== 页面：服务器 ====================
local P_srv = CreatePage("服务器")
Section(P_srv, "服务器脚本（点击加载）")
local ServerScripts = {
    {n="灾难之岛", i="🎍", u="https://raw.githubusercontent.com/hgvuyguyg/new/main/灾难之岛"},
    {n="巴掌", i="🤲", u="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/巴掌"},
    {n="汉堡包", i="🍔", u="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/汉堡"},
    {n="机器人", i="🤖", u="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/机器人"},
    {n="住宅大逃杀", i="🚪", u="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/住宅屠杀"},
    {n="降落或死亡", i="🛩️", u="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/死亡"},
    {n="砧板鲶鱼", i="🐟", u="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/钓鱼"},
    {n="死铁轨", i="🚂", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/铁轨"},
    {n="键盘逃脱", i="⌨️", u="https://raw.githubusercontent.com/ccdushii/zzzzzzzzz/refs/heads/main/ssssssssss"},
    {n="驾驶帝国", i="🚗", u="https://raw.githubusercontent.com/xiaopi77/xiaopi77/refs/heads/main/Roblox-Pi-Drivingempire-Script.lua"},
    {n="排干湖水", i="💧", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/%E6%8E%92%E5%B9%B2%E6%B9%96%E6%B0%B4"},
    {n="Doors", i="🚪", u="https://raw.githubusercontent.com/XxwanhexxX/doors-zh/refs/heads/main/Abysall.Hub"},
    {n="弹药", i="🔫", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/%E5%BC%B9%E8%8D%AF"},
    {n="99夜", i="🌲", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/99"},
    {n="幸运方块", i="🎲", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/%E5%B9%B8%E8%BF%90%E6%96%B9%E5%9D%97"},
    {n="重型钓鱼", i="🐬", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/重型钓鱼"},
    {n="脂肪", i="🍔", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/脂肪"},
    {n="福瑞医院", i="🚑", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/福瑞医院"},
    {n="关注", i="❤️", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/关注"},
    {n="吃吃世界", i="🍱", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/吃吃世界"},
    {n="城市供电", i="🚦", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/为你的城市供电"},
    {n="抛硬币", i="🎃", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/抛一枚硬币"},
    {n="Po大Po", i="🌰", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/拉大便"},
    {n="Blox Fruit", i="🍎", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/blox"},
    {n="悬崖豪宅", i="🥂", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/豪宅悬崖"},
    {n="草地增亮", i="🌿", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/草地增亮"},
    {n="餐厅大亨3", i="☕", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/餐厅大亨"},
    {n="破坏者谜团2", i="☠️", u="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/mm2"},
    {n="画画", i="🛴", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/画画"},
    {n="咖啡馆", i="🍵", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/拥有咖啡馆"},
    {n="快躲起来", i="🐾", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/躲起来"},
    {n="钓鱼吧", i="🦈", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/调"},
    {n="清洗键盘", i="⌨️", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/清洗键盘"},
    {n="装载卡车", i="🚛", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/装载卡车"},
    {n="Fisch", i="🐠", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/船鱼"},
    {n="种植花园2", i="☘️", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/种植菜园二"},
    {n="活了7天", i="🐻", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/活了7天"},
    {n="被遗弃", i="👻", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/被遗弃"},
    {n="河北唐县", i="🚙", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/河北"},
    {n="末日", i="🤢", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/末日"},
    {n="零售大亨2", i="🛷", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/零售大亨"},
    {n="采矿大亨", i="🦇", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/采矿"},
    {n="启示录", i="⚠️", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/启示录"},
    {n="战争大亨", i="🦚", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/战争"},
    {n="海上100天", i="💧", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/海上100天"},
    {n="俄亥俄州", i="🦉", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/ohio"},
    {n="割草冒险", i="🌱", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/割草冒险"},
    {n="种植者", i="🤑", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/种植者"},
    {n="剑点击", i="🖕", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/剑1"},
    {n="超级商店", i="🥓", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/在超级商店生存"},
    {n="寒冷生存", i="🥶", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/在寒冷生存"},
    {n="训练一只鸡", i="🐓", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/训练鸡肉"},
    {n="长途旅行", i="🚘", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/长途旅行"},
    {n="最强战场", i="👾", u="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/最强"},
    {n="获得球员", i="🎈", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/获得球员"},
    {n="伐木大亨2", i="🌳", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/伐木大亨"},
    {n="偷一个蛋", i="🥚", u="https://pastefy.app/4lHhgnhn/raw"},
    {n="变身升级", i="🐛", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/变身升级"},
    {n="肌肉墙壁", i="💪", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/肌肉墙壁"},
    {n="翅膀脑残", i="🍪", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/翅膀脑残"},
    {n="踢球进太空", i="🐃", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/踢球太空"},
    {n="魔法战利品", i="✨", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/魔法战利品"},
    {n="夜幕降临", i="🐼", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/夜幕降临"},
    {n="恐龙生活", i="🦖", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/恐龙生活"},
    {n="双跳车", i="🚲", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/双跳车"},
    {n="谋杀之岛2", i="🌶", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/谋杀之岛"},
    {n="抢劫", i="🍃", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/抢劫"},
    {n="僵尸键盘", i="🐊", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/僵尸键盘"},
    {n="清理树叶", i="🍁", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/清理树叶"},
    {n="开箱脆皮", i="🍰", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/开箱脆皮"},
    {n="脑残倒下", i="🐊", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/脑残倒下"},
    {n="木材农场", i="🌲", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/我的木材农场"},
    {n="后空翻", i="💀", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/后空翻键盘"},
    {n="点击加排水", i="💧", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/点击加排水"},
    {n="肌肉进化", i="💪", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/加一肌肉精华"},
    {n="抽军队", i="🍼", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/抽军队"},
    {n="合并核弹", i="😺", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/合并核弹"},
    {n="速度进化", i="🐒", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/加速度进化"},
    {n="逃跑者", i="👻", u="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/淘宝"},
    {n="击杀头目", i="🎅", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/击杀头目"},
    {n="沙滩逃脱", i="🏖", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/加一沙滩"},
    {n="Dit", i="🦰", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/dit"},
    {n="探矿", i="👀", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/正在挖矿"},
    {n="蝗虫之屋", i="🦗", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/蝗虫之王"},
    {n="英雄进化", i="🐲", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/加油英雄"},
    {n="拯救猫咪", i="🐱", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/拯救猫"},
    {n="恐怖寿司", i="😱", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/寿司"},
    {n="蛛丝逃脱", i="🕸", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/加一蜘蛛"},
    {n="跳墙逃脱", i="🛫", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/加一跳墙"},
    {n="键帽", i="🍅", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/按键帽"},
    {n="51区真相", i="🤫", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/51真相"},
    {n="每步减重", i="🦵", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/走路减重"},
    {n="矿井", i="🛶", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/矿井"},
    {n="神秘杀手", i="👹", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/神秘的杀手"},
    {n="寻找菜鸟", i="🍸", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/寻找菜鸟"},
    {n="技能点传奇", i="⚔", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/加一技能点"},
    {n="忍者键盘", i="🌑", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/加一忍者"},
    {n="破碎之梦", i="❤️", u="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/破碎"},
    {n="钓鱼垃圾", i="🐡", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/钓鱼垃圾"},
    {n="新手间接式", i="🤨", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/新手间接式"},
    {n="烤或死", i="🍖", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/烤活死"},
    {n="加一跳跃", i="🦘", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/加一跳跃逃脱"},
    {n="挖掘逃脱", i="🎃", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/挖掘逃出监狱"},
    {n="飞行世界", i="✈️", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/飞行世界"},
    {n="空乘模拟", i="🛫", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/空乘模拟机"},
    {n="帕索角色", i="🤑", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/帕索角色扮演"},
    {n="玩具长臂", i="🤳", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/玩具长臂"},
    {n="墨水", i="😢", u="https://raw.githubusercontent.com/hgvuyguyg/inkgames.github.io/refs/heads/main/ringta.lua"},
    {n="无尽旅馆", i="😎", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/k"},
    {n="力量传奇", i="💪", u="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/力量"},
    {n="路线06", i="🐍", u="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/路线"},
    {n="战斗大亨", i="🤠", u="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/战斗大亨"},
    {n="偷走巴掌", i="🖐", u="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/1巴掌"},
}
for _, s in ipairs(ServerScripts) do RemoteButton(P_srv, s.n, s.i, s.u) end

-- ==================== 页面：国内脚本 ====================
local P_cn = CreatePage("国内脚本")
Section(P_cn, "国内主脚本")
local CnScripts = {
    {n="小皮脚本", i="🇨🇳", u="https://raw.githubusercontent.com/xiaopi77/xiaopi77/main/QQ1002100032-Roblox-Pi-script.lua"},
    {n="黑洞脚本", i="🕳", u="https://gitee.com/BS_script/script/raw/master/BS_Script.Luau"},
    {n="ROB脚本", i="🤖", u="https://raw.githubusercontent.com/idrobsc/rob_script/refs/heads/main/rob.v4"},
    {n="黄某脚本", i="😞", u="https://rawscripts.net/raw/Universal-Script-HMscript-50384"},
    {n="Loarder脚本", i="🤔", u="https://raw.githubusercontent.com/Jilxi/123/refs/heads/main/Loader.lua"},
    {n="落叶Pro Hub", i="🍂", u="https://raw.githubusercontent.com/SyndromeXph/Luoye-Pro-Hub/refs/heads/main/Script/Loader.lua"},
    {n="叶脚本", i="🍃", u="https://raw.githubusercontent.com/roblox-ye/QQ515966991/refs/heads/main/ROBLOX-CNVIP-XIAOYE.lua"},
    {n="夜脚本", i="🌙", u="https://raw.githubusercontent.com/ylt410/roblox-Script/refs/heads/main/yejiaoben"},
    {n="星脚本", i="⭐", u="https://raw.githubusercontent.com/zilinskaslandon/XingJiaoBen-2026-/refs/heads/main/%E6%98%9F%E8%84%9A%E6%9C%AC.lua"},
    {n="浅脚本", i="💧", u="https://raw.githubusercontent.com/renlua/shallow/main/Script_Hub.lua"},
    {n="VOTR脚本", i="🎮", u="https://raw.githubusercontent.com/VOTR-HUB/MAIN/refs/heads/main/VOTR-MAIN"},
    {n="秋脚本", i="🍁", u="https://raw.githubusercontent.com/WS857960/-/main/秋·自制脚本新源码.txt"},
}
for _, s in ipairs(CnScripts) do RemoteButton(P_cn, s.n, s.i, s.u) end

-- ==================== 页面：爱国者 ====================
local P_pt = CreatePage("爱国者")
Section(P_pt, "爱国者脚本库")
local PatriotScripts = {
    {n="黑洞中心", i="🕳", u="https://gitee.com/BS_script/script/raw/master/BS_Script.Luau"},
    {n="ROB V2", i="🤖", u="https://raw.githubusercontent.com/Zyb150933/ROB/refs/heads/main/ROB.V2"},
    {n="ROB 活动", i="🎁", u="https://raw.githubusercontent.com/idrobsc/rob_script/refs/heads/main/ROB.活动"},
    {n="ROB V4", i="🤖", u="https://raw.githubusercontent.com/idrobsc/rob_script/refs/heads/main/rob.v4"},
    {n="夜脚本", i="🌙", u="https://raw.githubusercontent.com/ylt410/roblox-Script/refs/heads/main/yejiaoben"},
    {n="恐脚本", i="😱", u="https://raw.githubusercontent.com/kongbaNB/9178/refs/heads/main/恐脚本.NB"},
    {n="超高速跑者", i="💨", u="https://pastefy.app/yEEgIs1r/raw"},
    {n="圣奥里", i="✨", u="https://pastefy.app/Wot0aN3V/raw"},
    {n="翻瓶", i="🍾", u="https://pastefy.app/AaMGGRLH/raw"},
    {n="最强战场", i="👾", u="https://pastefy.app/1ZEycK4m/raw"},
    {n="8球池", i="🎱", u="https://pastefy.app/gR2WUm0k/raw"},
    {n="终极战场", i="⚔", u="https://pastefy.app/qunhKqEl/raw"},
    {n="国人电梯", i="🛗", u="https://pastefy.app/eCUUlx4W/raw"},
    {n="Blox Fruit", i="🍎", u="https://pastefy.app/cE1CuNwC/raw"},
    {n="RB汉化", i="🌐", u="https://api.luarmor.net/files/v3/loaders/4fe525637e43a1be8cb0cdf902d107c2.lua"},
    {n="假延迟", i="📡", u="https://raw.githubusercontent.com/JOzhe510/JOjiaoben/main/Desync(1).lua"},
    {n="防甩飞", i="🛡", u="https://raw.githubusercontent.com/Linux6699/DaHubRevival/main/AntiFling.lua"},
    {n="高级黑洞", i="🕳", u="https://raw.githubusercontent.com/xiaopi77/xiaopi77/refs/heads/main/blackhole.lua"},
    {n="五子棋", i="⚫", u="https://pastefy.app/YiG9QQae/raw"},
    {n="俄罗斯方块", i="🟦", u="https://files.catbox.moe/4g6uay.txt"},
    {n="贪吃蛇", i="🐍", u="https://pastefy.app/6TWyR3SJ/raw"},
    {n="扫雷", i="💣", u="https://pastefy.app/TN9CoOPt/raw"},
    {n="光影", i="🌅", u="https://raw.githubusercontent.com/MZEEN2424/Graphics/main/Graphics.xml"},
    {n="RTX高仿", i="💎", u="https://pastebin.com/raw/Bkf0BJb3"},
    {n="超高画质", i="🌟", u="https://pastebin.com/raw/jHBfJYmS"},
}
for _, s in ipairs(PatriotScripts) do RemoteButton(P_pt, s.n, s.i, s.u) end

-- ==================== 页面：设置 ====================
local P_set = CreatePage("设置")
Section(P_set, "面板")
local resetBtn = Instance.new("TextButton")
resetBtn.Size = UDim2.new(1,0,0,28)
resetBtn.BackgroundColor3 = Color3.fromRGB(240,240,240)
resetBtn.BorderSizePixel = 0
resetBtn.Text = "🔄 重置所有功能"
resetBtn.TextColor3 = Color3.fromRGB(60,60,60)
resetBtn.TextSize = 11
resetBtn.Font = Enum.Font.GothamMedium
resetBtn.Parent = P_set
Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0,6)
resetBtn.MouseButton1Click:Connect(function()
    PlayClick(0.8)
    for k, v in pairs(Config) do
        if type(v) == "boolean" then
            Config[k] = false
            if Feature[k] then Fire(k, false) end
        end
    end
    print("[熙脚本] 已重置")
end)

-- ==================== 关闭按钮 ====================
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0,22,0,22)
CloseBtn.Position = UDim2.new(1,-32,0,14)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255,90,90)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
CloseBtn.TextSize = 16
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.ZIndex = 10
CloseBtn.Parent = Main
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0,11)
CloseBtn.MouseButton1Click:Connect(function()
    PlayClick(0.75)
    Main.Visible = false
end)

SwitchPage("公告")

-- ==================== 自适应触发 ====================
ApplyResponsive()
TrackConn(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ApplyResponsive))

-- ==================== 灵动岛 ====================
local Island = Instance.new("Frame")
Island.Size = UDim2.new(0,150,0,34)
Island.Position = UDim2.new(0.5,0,0,8)
Island.AnchorPoint = Vector2.new(0.5,0)
Island.BackgroundColor3 = Color3.fromRGB(15,15,18)
Island.BorderSizePixel = 0
Island.ZIndex = 50
Island.Parent = ScreenGui
Instance.new("UICorner", Island).CornerRadius = UDim.new(0,17)

local IsDot = Instance.new("Frame")
IsDot.Size = UDim2.new(0,7,0,7); IsDot.Position = UDim2.new(0,14,0.5,-3.5)
IsDot.BackgroundColor3 = Color3.fromRGB(50,255,100); IsDot.BorderSizePixel = 0
IsDot.ZIndex = 52; IsDot.Parent = Island
Instance.new("UICorner", IsDot).CornerRadius = UDim.new(1,0)

local IsImg = Instance.new("ImageLabel")
IsImg.Size = UDim2.new(0,22,0,22); IsImg.Position = UDim2.new(0,26,0.5,-11)
IsImg.BackgroundColor3 = Color3.fromRGB(80,80,80); IsImg.BorderSizePixel = 0
IsImg.ZIndex = 52; IsImg.Parent = Island
Instance.new("UICorner", IsImg).CornerRadius = UDim.new(1,0)
task.spawn(function()
    local ok, url = pcall(function()
        return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end)
    if ok and url then IsImg.Image = url end
end)

local IsText = Instance.new("TextLabel")
IsText.Size = UDim2.new(0,60,1,0); IsText.Position = UDim2.new(0,54,0,0)
IsText.BackgroundTransparency = 1; IsText.Text = LocalPlayer.DisplayName
IsText.TextColor3 = Color3.fromRGB(255,255,255); IsText.TextSize = 11
IsText.Font = Enum.Font.GothamBold; IsText.TextXAlignment = Enum.TextXAlignment.Left
IsText.TextTruncate = Enum.TextTruncate.AtEnd
IsText.ZIndex = 52; IsText.Parent = Island

local IsClock = Instance.new("TextLabel")
IsClock.Size = UDim2.new(0,36,1,0); IsClock.Position = UDim2.new(1,-40,0,0)
IsClock.BackgroundTransparency = 1; IsClock.Text = "00:00"
IsClock.TextColor3 = Color3.fromRGB(180,180,200); IsClock.TextSize = 10
IsClock.Font = Enum.Font.Gotham; IsClock.TextXAlignment = Enum.TextXAlignment.Right
IsClock.ZIndex = 52; IsClock.Parent = Island

Island.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        PlayClick(1.05)
        Main.Visible = not Main.Visible
    end
end)

TrackConn(RunService.RenderStepped:Connect(function()
    local t = os.date("*t")
    IsClock.Text = string.format("%02d:%02d", t.hour, t.min)
end))

-- ==================== 启动信息 ====================
print("========================================")
print("[+] 熙脚本.lua V3.1 修复版 加载完成")
print("[+] 玩家头像: " .. LocalPlayer.DisplayName .. " (" .. LocalPlayer.Name .. ")")
print("[+] 修复：自瞄速度单位、注入器保护、台式机缩放")
print("========================================")
