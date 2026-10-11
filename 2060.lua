-- ============================================================
-- 海洋之星 · Phantom 融合版 v4.0
-- Delta 适配 + 反检测 + 远程 UI 加载修复
-- 本地执行 / 远程 loadstring 加载 均可用
-- ============================================================

-- ============================================================
-- 模块 1 · Delta 兼容层
-- ============================================================

local Delta = { Name = "Delta", Version = "2.7x", Identified = false, Features = {} }

do
    local ok, id = pcall(identifyexecutor)
    if ok and type(id) == "string" and string.find(string.lower(id), "delta", 1, true) then
        Delta.Identified = true
    end
    if not Delta.Identified then
        local ok2, g = pcall(getgenv)
        if ok2 and type(g) == "table" and (g.Delta or g.__DELTA__ or rawget(g, "delta")) then
            Delta.Identified = true
        end
    end
    if not Delta.Identified then
        local ok3, r = pcall(getrenv)
        if ok3 and type(r) == "table" and (r.Delta or r.__DELTA__) then
            Delta.Identified = true
        end
    end
end

local function probe(name, fn)
    local ok, result = pcall(fn)
    if ok and result ~= nil then
        Delta.Features[name] = true
        return result
    end
    Delta.Features[name] = false
    return nil
end

local raw = {}
raw.getgenv          = probe("getgenv",          function() return getgenv end)
raw.getrenv          = probe("getrenv",          function() return getrenv end)
raw.hookfunction     = probe("hookfunction",     function() return hookfunction end)
raw.hookmetamethod   = probe("hookmetamethod",   function() return hookmetamethod end)
raw.newcclosure      = probe("newcclosure",      function() return newcclosure end)
raw.checkcaller      = probe("checkcaller",      function() return checkcaller end)
raw.getrawmetatable  = probe("getrawmetatable",  function() return getrawmetatable end)
raw.setreadonly      = probe("setreadonly",      function() return setreadonly end)
raw.getconnections   = probe("getconnections",   function() return getconnections end)
raw.gethui           = probe("gethui",           function() return gethui end)
raw.protectgui       = probe("protectgui",       function() return protectgui end)
raw.getnamecallmethod= probe("getnamecallmethod",function() return getnamecallmethod end)
raw.islclosure       = probe("islclosure",       function() return islclosure end)
raw.iscclosure       = probe("iscclosure",       function() return iscclosure end)
raw.identifyexecutor = probe("identifyexecutor", function() return identifyexecutor end)
raw.setthreadidentity= probe("setthreadidentity",function() return setthreadidentity end)
raw.getthreadidentity= probe("getthreadidentity",function() return getthreadidentity end)

if not raw.newcclosure      then raw.newcclosure = function(f) return f end end
if not raw.checkcaller      then raw.checkcaller = function() return false end end
if not raw.getrawmetatable  then raw.getrawmetatable = getmetatable end
if not raw.setreadonly      then raw.setreadonly = function() end end
if not raw.getconnections   then raw.getconnections = function() return {} end end
if not raw.getnamecallmethod then raw.getnamecallmethod = function() return nil end end
if not raw.islclosure       then raw.islclosure = function() return false end end
if not raw.iscclosure       then raw.iscclosure = function() return true end end
if not raw.setthreadidentity then raw.setthreadidentity = setthreadidentity or function() end end
if not raw.getthreadidentity then raw.getthreadidentity = getthreadidentity or function() return 8 end end

if not raw.gethui then
    raw.gethui = function()
        local ok, cg = pcall(function() return game:GetService("CoreGui") end)
        return ok and cg or nil
    end
end

if not raw.protectgui then
    raw.protectgui = protect_gui or protectgui or function() end
end

raw.getupvalue  = debug.getupvalue
raw.setupvalue  = debug.setupvalue
raw.getinfo     = debug.getinfo
raw.getconstant = debug.getconstant or function() return nil end
raw.setconstant = debug.setconstant or function() end
raw.getupvalues = debug.getupvalues or function() return {} end
raw.setupvalues = debug.setupvalues or function() end
raw.getstack    = debug.getstack or function() return {} end
raw.setstack    = debug.setstack or function() end

-- ============================================================
-- 模块 2 · Phantom 反检测运行时
-- ============================================================

local Config = {
    BlockKeywords = {
        "anticheat","anti_cheat","ac_","detect","detection","ban","kick","report","log","flag",
        "violation","exploit","cheat","byfron","hyperion","guard","shield","sentinel","watchdog",
        "screenshot","screengrab","evidence","proof","staff","admin"
    },
    RemoteRateLimit = 12,
    RandomDelay = {0.025, 0.11},
    Heartbeat = 0.8,
    ProtectUI = true,
    Quiet = true,
    DeltaCompat = true,
}

local genv = raw.getgenv and raw.getgenv() or _G
local Phantom = {}
local original = {}
local remoteCount = {}
local lastReset = tick()
local active = true

if raw.setthreadidentity then pcall(raw.setthreadidentity, 8) end

-- identifyexecutor 伪装
if raw.identifyexecutor and raw.hookfunction then
    original.identifyexecutor = raw.identifyexecutor
    local fakeIdentify = raw.newcclosure(function()
        if raw.checkcaller() then return original.identifyexecutor() end
        return "Roblox"
    end)
    pcall(function() raw.hookfunction(raw.identifyexecutor, fakeIdentify) end)
    genv.identifyexecutor = fakeIdentify
end

-- getgenv 净化
if raw.getgenv then
    original.getgenv = raw.getgenv
    local fakeGenv = setmetatable({}, {
        __index = function(_, key)
            if key == "Phantom" then return Phantom end
            if key == "Delta" or key == "__DELTA__" or key == "delta" then return nil end
            return nil
        end,
        __newindex = function() end,
        __metatable = "locked"
    })
    local fakeGetGenv = raw.newcclosure(function(...)
        if raw.checkcaller() then return original.getgenv(...) end
        return fakeGenv
    end)
    pcall(function() raw.hookfunction(raw.getgenv, fakeGetGenv) end)
    genv.getgenv = fakeGetGenv
end

-- debug.getinfo 伪装
if raw.getinfo then
    local oldGetInfo = raw.getinfo
    local function fakeGetInfo(...)
        local info = oldGetInfo(...)
        if type(info) == "table" then
            info.source = "=[C]"; info.short_src = "[C]"; info.what = "C"
            info.name = nil; info.namewhat = nil
            info.linedefined = -1; info.lastlinedefined = -1
        end
        return info
    end
    local hookedGetInfo = raw.newcclosure(function(...)
        if raw.checkcaller() then return oldGetInfo(...) end
        return fakeGetInfo(...)
    end)
    pcall(function() raw.hookfunction(debug.getinfo, hookedGetInfo) end)
    debug.getinfo = hookedGetInfo
end

-- getconnections 隐藏
if raw.getconnections then
    local oldGetConnections = raw.getconnections
    local fakeGetConnections = raw.newcclosure(function(signal)
        if raw.checkcaller() then return oldGetConnections(signal) end
        return {}
    end)
    pcall(function() raw.hookfunction(raw.getconnections, fakeGetConnections) end)
    genv.getconnections = fakeGetConnections
end

-- __namecall 远程过滤
local function installNamecallHook()
    local oldNamecall
    local handler = raw.newcclosure(function(self, ...)
        local method = raw.getnamecallmethod()
        if method == "FireServer" or method == "InvokeServer" then
            local remote = self
            local name = remote.Name or ""
            local path = ""
            pcall(function() path = remote:GetFullName() end)
            local lower = string.lower(name .. " " .. path)
            for _, kw in ipairs(Config.BlockKeywords) do
                if string.find(lower, kw, 1, true) then return nil end
            end
            local now = tick()
            if now - lastReset > 1 then remoteCount = {}; lastReset = now end
            local key = path
            remoteCount[key] = (remoteCount[key] or 0) + 1
            if remoteCount[key] > Config.RemoteRateLimit then return nil end
            local delay = Config.RandomDelay[1] + math.random() * (Config.RandomDelay[2] - Config.RandomDelay[1])
            task.wait(delay)
        end
        return oldNamecall(self, ...)
    end)

    if raw.hookmetamethod then
        oldNamecall = raw.hookmetamethod(game, "__namecall", handler)
    else
        local mt = raw.getrawmetatable(game)
        raw.setreadonly(mt, false)
        oldNamecall = mt.__namecall
        mt.__namecall = handler
        raw.setreadonly(mt, true)
    end
end
pcall(installNamecallHook)

-- Kick 拦截
local LocalPlayerRef = game:GetService("Players").LocalPlayer
if LocalPlayerRef and raw.hookfunction then
    local oldKick = LocalPlayerRef.Kick
    pcall(function()
        raw.hookfunction(LocalPlayerRef.Kick, raw.newcclosure(function(self, message)
            if raw.checkcaller() then return oldKick(self, message) end
            if Config.Quiet then return nil end
            return oldKick(self, message)
        end))
    end)
end

-- 日志过滤
if warn and raw.hookfunction then
    local oldWarn = warn
    pcall(function()
        raw.hookfunction(warn, raw.newcclosure(function(...)
            local msg = table.concat({...}, " ")
            local lower = string.lower(msg)
            for _, kw in ipairs(Config.BlockKeywords) do
                if string.find(lower, kw, 1, true) then return end
            end
            return oldWarn(...)
        end))
    end)
end

if print and raw.hookfunction then
    local oldPrint = print
    pcall(function()
        raw.hookfunction(print, raw.newcclosure(function(...)
            local msg = table.concat({...}, " ")
            local lower = string.lower(msg)
            for _, kw in ipairs(Config.BlockKeywords) do
                if string.find(lower, kw, 1, true) then return end
            end
            return oldPrint(...)
        end))
    end)
end

-- 远程扫描与阻断
local function scanAndBlock()
    local ok, rs = pcall(function() return game:GetService("ReplicatedStorage") end)
    if not ok or not rs then return end
    for _, obj in ipairs(rs:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local lower = string.lower(obj.Name .. " " .. obj:GetFullName())
            for _, kw in ipairs(Config.BlockKeywords) do
                if string.find(lower, kw, 1, true) then
                    if obj:IsA("RemoteEvent") then
                        for _, conn in ipairs(raw.getconnections(obj.OnClientEvent)) do
                            pcall(function() conn:Disconnect() end)
                        end
                    else
                        for _, conn in ipairs(raw.getconnections(obj.OnClientInvoke)) do
                            pcall(function() conn:Disconnect() end)
                        end
                    end
                end
            end
        end
    end
end

-- 人性化输入
function Phantom.MouseMove(x, y, duration)
    duration = duration or (0.1 + math.random() * 0.25)
    local uis = game:GetService("UserInputService")
    local start = uis:GetMouseLocation()
    local steps = math.max(8, math.floor(duration * 60))
    for i = 1, steps do
        local t = i / steps
        local ease = t * t * (3 - 2 * t)
        local nx = start.X + (x - start.X) * ease + math.random(-2, 2)
        local ny = start.Y + (y - start.Y) * ease + math.random(-2, 2)
        game:GetService("VirtualInputManager"):SendMouseMoveEvent(nx, ny, false, game)
        task.wait(duration / steps)
    end
end

function Phantom.KeyPress(key, hold)
    hold = hold or (0.05 + math.random() * 0.08)
    local vim = game:GetService("VirtualInputManager")
    vim:SendKeyEvent(true, key, false, game)
    task.wait(hold)
    vim:SendKeyEvent(false, key, false, game)
end

-- 心跳自愈
task.spawn(function()
    while active do
        task.wait(Config.Heartbeat)
        pcall(scanAndBlock)
        local hui = raw.gethui and raw.gethui()
        if hui then
            for _, child in ipairs(hui:GetChildren()) do
                local name = string.lower(child.Name)
                for _, kw in ipairs(Config.BlockKeywords) do
                    if string.find(name, kw, 1, true) then
                        pcall(function() child:Destroy() end)
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- 模块 3 · UI 安全挂载工具（修复远程加载 UI 不显示）
-- ============================================================

local UIMount = {}

-- 探测一个可写入的父级
function UIMount.ResolveParent()
    local candidates = {}

    if raw.gethui then
        local ok, hui = pcall(raw.gethui)
        if ok and hui then table.insert(candidates, hui) end
    end

    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then table.insert(candidates, cg) end

    local ok2, plr = pcall(function() return game:GetService("Players").LocalPlayer end)
    if ok2 and plr then
        local ok3, pg = pcall(function() return plr:WaitForChild("PlayerGui", 5) end)
        if ok3 and pg then table.insert(candidates, pg) end
    end

    for _, parent in ipairs(candidates) do
        local ok, err = pcall(function()
            local test = Instance.new("Folder")
            test.Name = "__phantom_ui_probe_" .. tostring(math.random(100000, 999999))
            test.Parent = parent
            test:Destroy()
        end)
        if ok then return parent end
    end
    return nil
end

-- 创建并保护 ScreenGui
function UIMount.CreateGui(name)
    -- 清理旧实例（多路径）
    if raw.gethui then
        pcall(function()
            local hui = raw.gethui()
            if hui then
                local old = hui:FindFirstChild(name)
                if old then old:Destroy() end
            end
        end)
    end
    pcall(function()
        local cg = game:GetService("CoreGui")
        local old = cg:FindFirstChild(name)
        if old then old:Destroy() end
    end)
    pcall(function()
        local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            local old = pg:FindFirstChild(name)
            if old then old:Destroy() end
        end
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999999

    -- 保护
    if raw.protectgui then pcall(raw.protectgui, gui) end

    -- 挂载（带降级重试）
    local parent = UIMount.ResolveParent()
    if parent then
        local ok = pcall(function() gui.Parent = parent end)
        if not ok or gui.Parent == nil then
            -- 降到 PlayerGui
            local plr = game:GetService("Players").LocalPlayer
            local pg = plr:WaitForChild("PlayerGui", 10)
            if pg then gui.Parent = pg end
        end
    else
        local plr = game:GetService("Players").LocalPlayer
        local pg = plr:WaitForChild("PlayerGui", 10)
        if pg then gui.Parent = pg end
    end

    return gui
end

-- 供外部远程脚本调用
function Phantom.Protect(gui)
    if Config.ProtectUI and gui then
        pcall(function() raw.protectgui(gui) end)
        local parent = UIMount.ResolveParent()
        if parent then
            pcall(function() gui.Parent = parent end)
        end
    end
end

-- 远程加载包装器（解决远程加载 UI 不显示）
getgenv().LoadOceanStar = function(url)
    if raw.setthreadidentity then pcall(raw.setthreadidentity, 8) end
    local ok, content = pcall(function() return game:HttpGet(url) end)
    if not ok or not content or #content == 0 then
        return false, "HttpGet failed"
    end
    local chunk = loadstring(content)
    if not chunk then return false, "loadstring failed" end
    local execOk, execErr = pcall(chunk)
    if not execOk then return false, execErr end
    return true
end

-- ============================================================
-- 模块 4 · 海洋之星 UI 主脚本
-- ============================================================

local Players         = game:GetService("Players")
local UserInputService= game:GetService("UserInputService")
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")

-- 安全获取 CoreGui（带 pcall）
local CoreGui
do
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok then CoreGui = cg end
end

getgenv().OceanStarConfig = {
    ["自瞄启用"] = true, ["忽略人机"] = true, ["忽略倒地"] = true,
    ["触摸框X"] = 1460, ["触摸框Y"] = 1020, ["触摸框大小"] = 80,
    ["连点启用"] = false, ["连点速度"] = 50, ["连点框X"] = 1450, ["连点框Y"] = 1010,
    ["便捷开关"] = true, ["显示触摸框"] = false
}

-- 用安全挂载工具创建 ScreenGui
local ScreenGui = UIMount.CreateGui("OceanStar_Final")

local LiquidGlass = {}
local GlassStyle = { Rounding = 24, TintColor = Color3.fromRGB(245, 248, 252), Alpha = 0.85, GlowAlpha = 0.15, NoiseAlpha = 0.02 }

function LiquidGlass.Apply(frame, isMain)
    if not frame then return end

    local glow = Instance.new("Frame")
    glow.Size = UDim2.new(1, 30, 1, 30)
    glow.Position = UDim2.new(0, -15, 0, -15)
    glow.BackgroundColor3 = Color3.fromRGB(180, 210, 240)
    glow.BackgroundTransparency = 1 - GlassStyle.GlowAlpha
    glow.BorderSizePixel = 0
    glow.ZIndex = 0
    glow.Parent = frame
    Instance.new("UICorner", glow).CornerRadius = UDim.new(0, GlassStyle.Rounding + 15)

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = GlassStyle.TintColor
    bg.BackgroundTransparency = 1 - GlassStyle.Alpha
    bg.BorderSizePixel = 0
    bg.ZIndex = 1
    bg.Parent = frame
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, GlassStyle.Rounding)

    local grad = Instance.new("UIGradient", bg)
    grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(225, 235, 245))
    grad.Rotation = 90
    grad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.3)})

    local noise = Instance.new("ImageLabel")
    noise.Size = UDim2.new(1, 0, 1, 0)
    noise.BackgroundTransparency = 1
    noise.Image = "rbxassetid://10183605738"
    noise.ImageTransparency = 1 - GlassStyle.NoiseAlpha
    noise.ImageColor3 = Color3.fromRGB(0, 0, 0)
    noise.ScaleType = Enum.ScaleType.Tile
    noise.TileSize = UDim2.new(0, 64, 0, 64)
    noise.ZIndex = 5
    noise.Parent = frame
    Instance.new("UICorner", noise).CornerRadius = UDim.new(0, GlassStyle.Rounding)

    local border = Instance.new("Frame")
    border.Size = UDim2.new(1, -2, 1, -2)
    border.Position = UDim2.new(0, 1, 0, 1)
    border.BackgroundTransparency = 1
    border.ZIndex = 6
    border.Parent = frame
    Instance.new("UICorner", border).CornerRadius = UDim.new(0, GlassStyle.Rounding)

    local stroke = Instance.new("UIStroke", border)
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(150, 180, 210)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    if isMain then
        getgenv().MainRainbowStroke = stroke
    end
end

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0.7, 0, 0.8, 0)
Main.Position = UDim2.new(0.5, 0, 0.5, 0)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundTransparency = 1
Main.Active = true
Main.Draggable = true
Main.ZIndex = 2
Main.Parent = ScreenGui

local MainConstraint = Instance.new("UISizeConstraint", Main)
MainConstraint.MinSize = Vector2.new(500, 380)
MainConstraint.MaxSize = Vector2.new(800, 550)

LiquidGlass.Apply(Main, true)

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 150, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(235, 238, 242)
Sidebar.BackgroundTransparency = 0.3
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 3
Sidebar.Parent = Main
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 24)

local TitleFrame = Instance.new("Frame")
TitleFrame.Size = UDim2.new(1, 0, 0, 65)
TitleFrame.BackgroundTransparency = 1
TitleFrame.ZIndex = 4
TitleFrame.Parent = Sidebar

local Avatar = Instance.new("ImageLabel")
Avatar.Size = UDim2.new(0, 36, 0, 36)
Avatar.Position = UDim2.new(0, 12, 0, 14)
Avatar.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
Avatar.Image = "rbxassetid://0"
Avatar.ZIndex = 5
Avatar.Parent = TitleFrame
Instance.new("UICorner", Avatar).CornerRadius = UDim.new(0, 18)

local NameLabel = Instance.new("TextLabel")
NameLabel.Size = UDim2.new(1, -60, 0, 20)
NameLabel.Position = UDim2.new(0, 56, 0, 10)
NameLabel.BackgroundTransparency = 1
NameLabel.Text = "海洋之星"
NameLabel.TextColor3 = Color3.fromRGB(40, 40, 40)
NameLabel.TextSize = 14
NameLabel.Font = Enum.Font.GothamBold
NameLabel.TextXAlignment = Enum.TextXAlignment.Left
NameLabel.ZIndex = 5
NameLabel.Parent = TitleFrame

local VersionLabel = Instance.new("TextLabel")
VersionLabel.Size = UDim2.new(1, -60, 0, 16)
VersionLabel.Position = UDim2.new(0, 56, 0, 30)
VersionLabel.BackgroundTransparency = 1
VersionLabel.Text = "内核·2.0"
VersionLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
VersionLabel.TextSize = 11
VersionLabel.Font = Enum.Font.Gotham
VersionLabel.TextXAlignment = Enum.TextXAlignment.Left
VersionLabel.ZIndex = 5
VersionLabel.Parent = TitleFrame

local Pages = {}
local NavButtons = {}
local currentTab = "人物自瞄"

local function SwitchPage(tabName)
    currentTab = tabName
    for name, page in pairs(Pages) do
        page.Visible = (name == tabName)
    end
    for name, btn in pairs(NavButtons) do
        local isActive = (name == tabName)
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(235, 238, 242),
            BackgroundTransparency = isActive and 0 or 0.6,
            TextColor3 = isActive and Color3.fromRGB(0, 122, 255) or Color3.fromRGB(80, 80, 80)
        }):Play()
        btn.Font = isActive and Enum.Font.GothamBold or Enum.Font.GothamMedium
    end
end

local Navs = {"人物绘制", "人物自瞄", "瞄准范围", "我的物资", "获取数据", "程序设置"}
for i, n in ipairs(Navs) do
    local NB = Instance.new("TextButton")
    NB.Size = UDim2.new(1, -20, 0, 36)
    NB.Position = UDim2.new(0, 10, 0, 75 + (i-1)*42)
    NB.BackgroundColor3 = Color3.fromRGB(235, 238, 242)
    NB.BackgroundTransparency = 0.6
    NB.BorderSizePixel = 0
    NB.Text = n
    NB.TextColor3 = Color3.fromRGB(80, 80, 80)
    NB.TextSize = 13
    NB.Font = Enum.Font.GothamMedium
    NB.ZIndex = 4
    NB.Parent = Sidebar
    Instance.new("UICorner", NB).CornerRadius = UDim.new(0, 8)
    NB.MouseButton1Click:Connect(function() SwitchPage(n) end)
    NavButtons[n] = NB
end

local BottomFrame = Instance.new("Frame")
BottomFrame.Size = UDim2.new(1, 0, 0, 85)
BottomFrame.Position = UDim2.new(0, 0, 1, -85)
BottomFrame.BackgroundTransparency = 1
BottomFrame.ZIndex = 4
BottomFrame.Parent = Sidebar

local ImageIDs = {"rbxassetid://0", "rbxassetid://0", "rbxassetid://0", "rbxassetid://0", "rbxassetid://0", "rbxassetid://0"}
for i = 1, 6 do
    local Thumb = Instance.new("ImageLabel")
    Thumb.Size = UDim2.new(0, 26, 0, 26)
    Thumb.Position = UDim2.new(0, 12 + ((i-1)%3)*32, 0, 8 + math.floor((i-1)/3)*32)
    Thumb.BackgroundColor3 = Color3.fromRGB(200, 205, 210)
    Thumb.BackgroundTransparency = 0.2
    Thumb.BorderSizePixel = 0
    Thumb.Image = ImageIDs[i]
    Thumb.ZIndex = 5
    Thumb.Parent = BottomFrame
    Instance.new("UICorner", Thumb).CornerRadius = UDim.new(0, 8)
end

local Footer = Instance.new("TextLabel")
Footer.Size = UDim2.new(1, 0, 0, 20)
Footer.Position = UDim2.new(0, 0, 0, 62)
Footer.BackgroundTransparency = 1
Footer.Text = "今天也要赢哦~"
Footer.TextColor3 = Color3.fromRGB(100, 100, 100)
Footer.TextSize = 11
Footer.Font = Enum.Font.Gotham
Footer.TextXAlignment = Enum.TextXAlignment.Center
Footer.ZIndex = 5
Footer.Parent = BottomFrame

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -150, 1, 0)
ContentArea.Position = UDim2.new(0, 150, 0, 0)
ContentArea.BackgroundTransparency = 1
ContentArea.ZIndex = 4
ContentArea.Parent = Main

local ContentMask = Instance.new("Frame")
ContentMask.Size = UDim2.new(1, -20, 1, -20)
ContentMask.Position = UDim2.new(0, 10, 0, 10)
ContentMask.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ContentMask.BackgroundTransparency = 0.5
ContentMask.BorderSizePixel = 0
ContentMask.ZIndex = 4
ContentMask.Parent = ContentArea
Instance.new("UICorner", ContentMask).CornerRadius = UDim.new(0, 24)

local function CreatePage(name)
    local Page = Instance.new("ScrollingFrame")
    Page.Name = name
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.BorderSizePixel = 0
    Page.ScrollBarThickness = 2
    Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.Visible = false
    Page.ZIndex = 5
    Page.Parent = ContentArea
    local Padding = Instance.new("UIPadding", Page)
    Padding.PaddingTop = UDim.new(0, 15)
    Padding.PaddingLeft = UDim.new(0, 15)
    Padding.PaddingRight = UDim.new(0, 15)
    Padding.PaddingBottom = UDim.new(0, 15)
    local Layout = Instance.new("UIListLayout", Page)
    Layout.Padding = UDim.new(0, 8)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Pages[name] = Page
    return Page
end

local function CreateRow(parent, height)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, height)
    Row.BackgroundTransparency = 1
    Row.Parent = parent
    return Row
end

local function SplitRow(row)
    local L = Instance.new("Frame")
    L.Size = UDim2.new(0.5, -6, 1, 0)
    L.BackgroundTransparency = 1
    L.Parent = row
    local R = Instance.new("Frame")
    R.Size = UDim2.new(0.5, -6, 1, 0)
    R.Position = UDim2.new(0.5, 6, 0, 0)
    R.BackgroundTransparency = 1
    R.Parent = row
    return L, R
end

local function CreateSection(parent, text)
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 24)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(120, 130, 140)
    Label.TextSize = 12
    Label.Font = Enum.Font.GothamMedium
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = parent
end

local function CreateToggle(parent, name, default)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 28)
    Frame.BackgroundTransparency = 1
    Frame.Parent = parent
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.7, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(60, 60, 60)
    Label.TextSize = 12
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame
    local B = Instance.new("TextButton")
    B.Size = UDim2.new(0, 38, 0, 20)
    B.Position = UDim2.new(1, -38, 0.5, -10)
    B.BackgroundColor3 = default and Color3.fromRGB(0, 122, 255) or Color3.fromRGB(210, 210, 210)
    B.BorderSizePixel = 0
    B.Text = ""
    B.Parent = Frame
    Instance.new("UICorner", B).CornerRadius = UDim.new(0, 10)
    local C = Instance.new("Frame")
    C.Size = UDim2.new(0, 16, 0, 16)
    C.Position = default and UDim2.new(1, -17, 0.5, -8) or UDim2.new(0, 1, 0.5, -8)
    C.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    C.BorderSizePixel = 0
    C.Parent = B
    Instance.new("UICorner", C).CornerRadius = UDim.new(0, 8)
    B.MouseButton1Click:Connect(function()
        local state = not getgenv().OceanStarConfig[name]
        getgenv().OceanStarConfig[name] = state
        TweenService:Create(B, TweenInfo.new(0.2), {BackgroundColor3 = state and Color3.fromRGB(0, 122, 255) or Color3.fromRGB(210, 210, 210)}):Play()
        TweenService:Create(C, TweenInfo.new(0.2), {Position = state and UDim2.new(1, -17, 0.5, -8) or UDim2.new(0, 1, 0.5, -8)}):Play()
    end)
end

local function CreateSlider(parent, name, default)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 36)
    Frame.BackgroundTransparency = 1
    Frame.Parent = parent
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.6, 0, 0, 18)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(60, 60, 60)
    Label.TextSize = 11
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame
    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Size = UDim2.new(0.4, 0, 0, 18)
    ValueLabel.Position = UDim2.new(0.6, 0, 0, 0)
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.Text = tostring(default)
    ValueLabel.TextColor3 = Color3.fromRGB(0, 122, 255)
    ValueLabel.TextSize = 11
    ValueLabel.Font = Enum.Font.GothamMedium
    ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    ValueLabel.Parent = Frame
    local BarBG = Instance.new("Frame")
    BarBG.Size = UDim2.new(1, 0, 0, 3)
    BarBG.Position = UDim2.new(0, 0, 0, 24)
    BarBG.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    BarBG.BackgroundTransparency = 0.2
    BarBG.BorderSizePixel = 0
    BarBG.Parent = Frame
    Instance.new("UICorner", BarBG).CornerRadius = UDim.new(0, 2)
    local BarFill = Instance.new("Frame")
    local initRel = (default - 0) / (2000 - 0)
    BarFill.Size = UDim2.new(initRel, 0, 1, 0)
    BarFill.BackgroundColor3 = Color3.fromRGB(0, 122, 255)
    BarFill.BorderSizePixel = 0
    BarFill.Parent = BarBG
    Instance.new("UICorner", BarFill).CornerRadius = UDim.new(0, 2)
    local dragging = false
    local function update(x)
        local rel = math.clamp((x - BarBG.AbsolutePosition.X) / BarBG.AbsoluteSize.X, 0, 1)
        local val = math.floor(0 + (2000 - 0) * rel)
        BarFill.Size = UDim2.new(rel, 0, 1, 0)
        ValueLabel.Text = tostring(val)
        getgenv().OceanStarConfig[name] = val
    end
    BarBG.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local P1 = CreatePage("人物自瞄")
CreateSection(P1, "触摸瞄准 / 触摸位置")
local R1 = CreateRow(P1, 30)
local L1, R1_2 = SplitRow(R1)
CreateToggle(L1, "自瞄启用", true)
CreateSlider(R1_2, "触摸框X", 1460)
local R2 = CreateRow(P1, 30)
local L2, R2_2 = SplitRow(R2)
CreateToggle(L2, "忽略人机", true)
CreateSlider(R2_2, "触摸框Y", 1020)
local R3 = CreateRow(P1, 30)
local L3, R3_2 = SplitRow(R3)
CreateToggle(L3, "忽略倒地", true)
CreateSlider(R3_2, "触摸框大小", 80)
CreateSection(P1, "连点器调节")
local R4 = CreateRow(P1, 30)
local L4, R4_2 = SplitRow(R4)
CreateToggle(L4, "连点启用", false)
CreateSlider(R4_2, "连点速度", 50)
local R5 = CreateRow(P1, 30)
local L5, R5_2 = SplitRow(R5)
CreateToggle(L5, "便捷开关", true)
CreateSlider(R5_2, "连点框X", 1450)
local R6 = CreateRow(P1, 30)
local L6, R6_2 = SplitRow(R6)
CreateToggle(L6, "显示触摸框", false)
CreateSlider(R6_2, "连点框Y", 1010)

local P2 = CreatePage("海洋之心")
CreateSection(P2, "海洋之心 · 功能设置")
local R7 = CreateRow(P2, 30)
local L7, R7_2 = SplitRow(R7)
CreateToggle(L7, "方框透视", true)
CreateSlider(R7_2, "方框粗细", 1)

local P3 = CreatePage("海洋之泪")
CreateSection(P3, "海洋之泪 · 功能设置")
local R8 = CreateRow(P3, 30)
local L8, R8_2 = SplitRow(R8)
CreateToggle(L8, "穿墙模式", false)
CreateSlider(R8_2, "穿墙距离", 100)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -35, 0, 15)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 18
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.ZIndex = 10
CloseBtn.Parent = Main
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 12)
CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
end)

SwitchPage("人物自瞄")

local IslandConfig = {
    CollapsedSize = UDim2.new(0, 150, 0, 40),
    ExpandedSize = UDim2.new(0, 320, 0, 130),
    PositionY = UDim.new(0, 8),
    BgColor = Color3.fromRGB(15, 15, 18),
    AccentColor = Color3.fromRGB(0, 122, 255),
    AnimSpeed = 0.4
}

local Island = Instance.new("Frame")
Island.Name = "Island"
Island.Size = IslandConfig.CollapsedSize
Island.Position = UDim2.new(0.5, 0, 0, IslandConfig.PositionY.Offset)
Island.AnchorPoint = Vector2.new(0.5, 0)
Island.BackgroundColor3 = IslandConfig.BgColor
Island.BorderSizePixel = 0
Island.ZIndex = 50
Island.Parent = ScreenGui
Instance.new("UICorner", Island).CornerRadius = UDim.new(0, 20)

local IslandStroke = Instance.new("UIStroke", Island)
IslandStroke.Color = Color3.fromRGB(50, 50, 55)
IslandStroke.Thickness = 2
IslandStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local IslandShadow = Instance.new("Frame")
IslandShadow.Size = UDim2.new(0, IslandConfig.CollapsedSize.X.Offset + 20, 0, IslandConfig.CollapsedSize.Y.Offset + 20)
IslandShadow.Position = UDim2.new(0.5, 0, 0, IslandConfig.PositionY.Offset - 10)
IslandShadow.AnchorPoint = Vector2.new(0.5, 0)
IslandShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
IslandShadow.BackgroundTransparency = 0.7
IslandShadow.BorderSizePixel = 0
IslandShadow.ZIndex = 49
IslandShadow.Parent = ScreenGui
Instance.new("UICorner", IslandShadow).CornerRadius = UDim.new(0, 30)

local function updateShadow()
    IslandShadow.Position = UDim2.new(0.5, 0, 0, Island.Position.Y.Offset - 10)
end
Island:GetPropertyChangedSignal("Position"):Connect(updateShadow)

local CollapsedContent = Instance.new("Frame")
CollapsedContent.Size = UDim2.new(1, 0, 1, 0)
CollapsedContent.BackgroundTransparency = 1
CollapsedContent.ZIndex = 51
CollapsedContent.Parent = Island

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 8, 0, 8)
StatusDot.Position = UDim2.new(0, 16, 0.5, -4)
StatusDot.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
StatusDot.BorderSizePixel = 0
StatusDot.ZIndex = 52
StatusDot.Parent = CollapsedContent
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

local CollapsedText = Instance.new("TextLabel")
CollapsedText.Size = UDim2.new(0, 80, 1, 0)
CollapsedText.Position = UDim2.new(0, 30, 0, 0)
CollapsedText.BackgroundTransparency = 1
CollapsedText.Text = "海洋之星"
CollapsedText.TextColor3 = Color3.fromRGB(255, 255, 255)
CollapsedText.TextSize = 13
CollapsedText.Font = Enum.Font.GothamBold
CollapsedText.TextXAlignment = Enum.TextXAlignment.Left
CollapsedText.ZIndex = 52
CollapsedText.Parent = CollapsedContent

local ClockLabel = Instance.new("TextLabel")
ClockLabel.Size = UDim2.new(0, 40, 1, 0)
ClockLabel.Position = UDim2.new(1, -45, 0, 0)
ClockLabel.BackgroundTransparency = 1
ClockLabel.Text = "00:00"
ClockLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
ClockLabel.TextSize = 11
ClockLabel.Font = Enum.Font.Gotham
ClockLabel.TextXAlignment = Enum.TextXAlignment.Right
ClockLabel.ZIndex = 52
ClockLabel.Parent = CollapsedContent

local ExpandedContent = Instance.new("Frame")
ExpandedContent.Size = UDim2.new(1, 0, 1, 0)
ExpandedContent.BackgroundTransparency = 1
ExpandedContent.ZIndex = 51
ExpandedContent.Visible = false
ExpandedContent.Parent = Island

local ExpandedTitle = Instance.new("TextLabel")
ExpandedTitle.Size = UDim2.new(1, -30, 0, 20)
ExpandedTitle.Position = UDim2.new(0, 15, 0, 15)
ExpandedTitle.BackgroundTransparency = 1
ExpandedTitle.Text = "海洋之星 · 运行中"
ExpandedTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
ExpandedTitle.TextSize = 14
ExpandedTitle.Font = Enum.Font.GothamBold
ExpandedTitle.TextXAlignment = Enum.TextXAlignment.Left
ExpandedTitle.ZIndex = 52
ExpandedTitle.Parent = ExpandedContent

local InfoFrame = Instance.new("Frame")
InfoFrame.Size = UDim2.new(1, -30, 0, 30)
InfoFrame.Position = UDim2.new(0, 15, 0, 40)
InfoFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
InfoFrame.BorderSizePixel = 0
InfoFrame.ZIndex = 52
InfoFrame.Parent = ExpandedContent
Instance.new("UICorner", InfoFrame).CornerRadius = UDim.new(0, 10)

local FpsLabel = Instance.new("TextLabel")
FpsLabel.Size = UDim2.new(0.5, 0, 1, 0)
FpsLabel.Position = UDim2.new(0, 10, 0, 0)
FpsLabel.BackgroundTransparency = 1
FpsLabel.Text = "FPS: --"
FpsLabel.TextColor3 = IslandConfig.AccentColor
FpsLabel.TextSize = 13
FpsLabel.Font = Enum.Font.GothamBold
FpsLabel.TextXAlignment = Enum.TextXAlignment.Left
FpsLabel.ZIndex = 53
FpsLabel.Parent = InfoFrame

local TimeLabel = Instance.new("TextLabel")
TimeLabel.Size = UDim2.new(0.5, -10, 1, 0)
TimeLabel.Position = UDim2.new(0.5, 0, 0, 0)
TimeLabel.BackgroundTransparency = 1
TimeLabel.Text = "--:--"
TimeLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
TimeLabel.TextSize = 13
TimeLabel.Font = Enum.Font.Gotham
TimeLabel.TextXAlignment = Enum.TextXAlignment.Right
TimeLabel.ZIndex = 53
TimeLabel.Parent = InfoFrame

local BtnFrame = Instance.new("Frame")
BtnFrame.Size = UDim2.new(1, -30, 0, 32)
BtnFrame.Position = UDim2.new(0, 15, 0, 80)
BtnFrame.BackgroundTransparency = 1
BtnFrame.ZIndex = 52
BtnFrame.Parent = ExpandedContent

local Btn1 = Instance.new("TextButton")
Btn1.Size = UDim2.new(1, 0, 1, 0)
Btn1.BackgroundColor3 = IslandConfig.AccentColor
Btn1.BorderSizePixel = 0
Btn1.Text = Main.Visible and "隐藏主界面" or "打开主界面"
Btn1.TextColor3 = Color3.fromRGB(255, 255, 255)
Btn1.TextSize = 13
Btn1.Font = Enum.Font.GothamBold
Btn1.ZIndex = 53
Btn1.Parent = BtnFrame
Instance.new("UICorner", Btn1).CornerRadius = UDim.new(0, 10)

Btn1.MouseButton1Click:Connect(function()
    Main.Visible = not Main.Visible
    Btn1.Text = Main.Visible and "隐藏主界面" or "打开主界面"
end)

local isExpanded = false
local isAnimating = false

local function ToggleIsland()
    if isAnimating then return end
    isAnimating = true
    isExpanded = not isExpanded

    local targetSize = isExpanded and IslandConfig.ExpandedSize or IslandConfig.CollapsedSize
    local targetY = isExpanded and (IslandConfig.PositionY.Offset + 5) or IslandConfig.PositionY.Offset
    local tweenInfo = TweenInfo.new(IslandConfig.AnimSpeed, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    TweenService:Create(Island, tweenInfo, {
        Size = targetSize,
        Position = UDim2.new(0.5, 0, 0, targetY)
    }):Play()

    TweenService:Create(IslandShadow, tweenInfo, {
        Size = UDim2.new(0, targetSize.X.Offset + 20, 0, targetSize.Y.Offset + 20),
        Position = UDim2.new(0.5, 0, 0, targetY - 10)
    }):Play()

    if isExpanded then
        CollapsedContent.Visible = false
        ExpandedContent.Visible = true
        for _, child in ipairs(ExpandedContent:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                child.TextTransparency = 1
                TweenService:Create(child, tweenInfo, {TextTransparency = 0}):Play()
            end
        end
    else
        CollapsedContent.Visible = true
        ExpandedContent.Visible = false
    end
    task.delay(IslandConfig.AnimSpeed, function() isAnimating = false end)
end

Island.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        ToggleIsland()
    end
end)

local frameCount = 0
local lastTime = tick()

RunService.RenderStepped:Connect(function()
    local osTime = os.date("*t")
    local timeStr = string.format("%02d:%02d", osTime.hour, osTime.min)
    ClockLabel.Text = timeStr
    TimeLabel.Text = timeStr

    frameCount = frameCount + 1
    if tick() - lastTime >= 1 then
        local fps = math.floor(frameCount / (tick() - lastTime))
        FpsLabel.Text = "FPS: " .. fps
        frameCount = 0
        lastTime = tick()
    end

    local hue = (tick() % 4) / 4
    local rainbowColor = Color3.fromHSV(hue, 0.8, 1)

    if getgenv().MainRainbowStroke then
        getgenv().MainRainbowStroke.Color = rainbowColor
    end

    if IslandStroke then
        IslandStroke.Color = rainbowColor
    end
end)

-- 挂载后校验
task.defer(function()
    task.wait(0.1)
    if ScreenGui and ScreenGui.Parent == nil then
        local plr = Players.LocalPlayer
        local pg = plr and plr:WaitForChild("PlayerGui", 5)
        if pg then ScreenGui.Parent = pg end
    end
end)

-- 暴露
genv.Phantom = Phantom
genv.PhantomConfig = Config
genv.Delta = Delta
genv.OceanStarUI = ScreenGui

print("========================================")
print("[+] 海洋之星 · Phantom 融合版 v4.0")
print("[+] Delta 适配 / 反检测 / 远程UI修复")
print("========================================")

return Phantom
