-- ============================================================
-- 海洋之星 · XAC V5.0 —— 主UI + 下载器 + 反作弊内核
-- 单文件完整版
-- ============================================================

local _genv = (type(getgenv) == "function" and getgenv()) or _G

-- ============================================================
-- 第一部分：XAC 反作弊内核
-- ============================================================
local XAC = {}
if _genv.__XAC and _genv.__XAC.Alive then pcall(_genv.__XAC.Destroy) end
_genv.__XAC = XAC

XAC.Alive = true
XAC.Hooks = {}
XAC.Conns = {}
XAC.Instances = {}
XAC.Limiter = {}
XAC.TimeOffset = 0
XAC.ReportKeywords = {
    "flag","cheat","detect","report","kick","ban","exploit","hack","violation",
    "suspicious","speed","teleport","anticheat","anti_cheat","ac_","_ac","guard",
    "shield","secure","verify","sanction","punish","abuse","abnormal","illegal",
    "inject","execute","script","bypass","hook","memory","debug","probe","scan",
    "integrity","trust","sentinel","watchdog","byfron","hyperion"
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local CoreGui = game:GetService("CoreGui")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local _real = {
    getgenv = getgenv, getrawmetatable = getrawmetatable, setreadonly = setreadonly,
    hookfunction = hookfunction, hookmetamethod = hookmetamethod,
    newcclosure = newcclosure or function(f) return f end,
    identifyexecutor = identifyexecutor, getconnections = getconnections,
    sethiddenproperty = sethiddenproperty, setscriptable = setscriptable,
    gethui = gethui, protect_gui = syn and syn.protect_gui,
    tick = tick, clock = os.clock, wait = task.wait,
}

local function NC(f) return _real.newcclosure(f) end
local function TrackConn(c) if c then table.insert(XAC.Conns, c) end return c end
local function TrackInst(i) if i then table.insert(XAC.Instances, i) end return i end

local Sandbox = _real.getgenv and _real.getgenv() or _G

XAC.Cap = {
    hookfunction = type(_real.hookfunction) == "function",
    getrawmetatable = type(_real.getrawmetatable) == "function",
    setreadonly = type(_real.setreadonly) == "function",
    getconnections = type(_real.getconnections) == "function",
    sethiddenproperty = type(_real.sethiddenproperty) == "function",
    setscriptable = type(_real.setscriptable) == "function",
    gethui = type(_real.gethui) == "function",
    protect_gui = type(_real.protect_gui) == "function",
    newcclosure = type(_real.newcclosure) == "function",
    decompile = type(decompile) == "function",
    getscriptbytecode = type(getscriptbytecode) == "function",
    getscripthash = type(getscripthash) == "function",
    writefile = type(writefile) == "function",
    readfile = type(readfile) == "function",
    isfile = type(isfile) == "function",
    makefolder = type(makefolder) == "function",
    isfolder = type(isfolder) == "function",
}

local function FakeExecutor()
    local fake = "Roblox"
    for _, name in ipairs({"identifyexecutor","getexecutorname","getexploitname"}) do
        if Sandbox[name] then Sandbox[name] = NC(function() return fake end) end
    end
    if Sandbox.getscriptname then Sandbox.getscriptname = NC(function() return "RobloxScript" end) end
    if Sandbox.getscripthash then Sandbox.getscripthash = NC(function() return "0" end) end
    if Sandbox.is_sirhurt_closure then Sandbox.is_sirhurt_closure = NC(function() return false end) end
    if Sandbox.is_synapse_closure then Sandbox.is_synapse_closure = NC(function() return false end) end
    if Sandbox.isfunctionhash then Sandbox.isfunctionhash = NC(function() return false end) end
    if Sandbox.checkcaller then Sandbox.checkcaller = NC(function() return true end) end
    if Sandbox.getreg then Sandbox.getreg = NC(function() return {} end) end
    if Sandbox.getgc then Sandbox.getgc = NC(function() return {} end) end
    if Sandbox.getloadedmodules then Sandbox.getloadedmodules = NC(function() return {} end) end
end

local function ScrubGenv()
    if not _real.getgenv then return end
    local g = _real.getgenv()
    local blacklist = {"__XAC","__XixiRuntime","XixiConfig","_genv","XAC","Config","__XixiDownloaderGui"}
    for k in pairs(g) do
        for _, b in ipairs(blacklist) do
            if k == b then g[k] = nil break end
        end
    end
end

local ACKeyWords = {
    "anticheat","anti_cheat","ac_","_ac","guard","shield","sentinel","watchdog",
    "protector","detector","checker","verifier","validator","sanction","punisher",
    "bansystem","banmod","exploiterdetect","exploitguard","hackshield","cheatdetect",
    "clientdetect","clientguard","securitymodule","integritycheck","integrity",
    "byfron","hyperion","remotevalidator","remoteguard","logservice","reportservice",
}

local function IsACName(n)
    local low = n:lower()
    for _, kw in ipairs(ACKeyWords) do
        if low:find(kw, 1, true) then return true end
    end
    return false
end

local function KillNode(obj)
    pcall(function()
        if obj:IsA("Script") or obj:IsA("LocalScript") then
            if _real.setscriptable then pcall(_real.setscriptable, obj, true) end
            pcall(function() obj.Disabled = true end)
        end
        if obj.Parent then pcall(function() obj.Parent = nil end) end
        pcall(function() obj:Destroy() end)
    end)
end

local function SweepRoot(root)
    if not root then return end
    local stack = {root}
    local guard = 0
    while #stack > 0 and guard < 20000 do
        guard = guard + 1
        local node = table.remove(stack)
        if node then
            local ok, children = pcall(function() return node:GetChildren() end)
            if ok and children then
                for _, child in ipairs(children) do
                    table.insert(stack, child)
                    if IsACName(child.Name) then KillNode(child) end
                end
            end
        end
    end
end

function XAC.KillAntiCheat()
    pcall(SweepRoot, ReplicatedFirst)
    pcall(SweepRoot, ReplicatedStorage)
    pcall(SweepRoot, StarterPlayer)
    if LocalPlayer then
        pcall(SweepRoot, LocalPlayer:FindFirstChild("PlayerScripts"))
        pcall(SweepRoot, LocalPlayer:FindFirstChild("PlayerGui"))
        pcall(SweepRoot, LocalPlayer)
    end
end

local function InstallACReaper()
    XAC.KillAntiCheat()
    TrackConn(game.DescendantAdded:Connect(function(obj)
        if IsACName(obj.Name) then task.defer(function() KillNode(obj) end) end
    end))
    task.spawn(function()
        while XAC.Alive do
            _real.wait(1.5)
            pcall(XAC.KillAntiCheat)
        end
    end)
end

local function ContainsReport(payload, depth)
    depth = depth or 0
    if depth > 4 then return false end
    local t = type(payload)
    if t == "string" then
        local low = payload:lower()
        for _, kw in ipairs(XAC.ReportKeywords) do
            if low:find(kw, 1, true) then return true end
        end
        return false
    elseif t == "table" then
        for k, v in pairs(payload) do
            if type(k) == "string" and ContainsReport(k, depth + 1) then return true end
            if ContainsReport(v, depth + 1) then return true end
        end
    end
    return false
end

local function ThrottleKey(remote, method)
    return tostring(remote) .. "::" .. tostring(method)
end

function XAC.LimitedFire(remote, interval, method, ...)
    interval = interval or 0.033
    method = method or "FireServer"
    local key = ThrottleKey(remote, method)
    local now = _real.tick() + XAC.TimeOffset
    if XAC.Limiter[key] and now - XAC.Limiter[key] < interval then return nil end
    XAC.Limiter[key] = now
    if method == "FireServer" then return remote:FireServer(...) end
    if method == "InvokeServer" then return remote:InvokeServer(...) end
end

local function InstallRemoteHook()
    if not XAC.Cap.getrawmetatable then return end
    local mt = _real.getrawmetatable(game)
    if not mt then return end
    local oldNamecall = mt.__namecall
    if not oldNamecall then return end
    if XAC.Cap.setreadonly then pcall(_real.setreadonly, mt, false) end
    mt.__namecall = NC(function(self, ...)
        local method = getnamecallmethod and getnamecallmethod() or nil
        if method == "FireServer" or method == "InvokeServer" then
            local args = {...}
            for _, a in ipairs(args) do
                if ContainsReport(a) then return nil end
            end
            if XAC.Config and XAC.Config.ThrottleRemotes then
                local key = ThrottleKey(self, method)
                local now = _real.tick() + XAC.TimeOffset
                local interval = (XAC.Config.RemoteInterval or 0.033)
                if XAC.Limiter[key] and now - XAC.Limiter[key] < interval then return nil end
                XAC.Limiter[key] = now
            end
        end
        return oldNamecall(self, ...)
    end)
    if XAC.Cap.setreadonly then pcall(_real.setreadonly, mt, true) end
    XAC.Hooks.__namecall = true
end

local Spoofed = setmetatable({}, {__mode = "k"})

local function InstallPropertySpoof(char)
    if not char or Spoofed[char] then return end
    Spoofed[char] = true
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        if XAC.Cap.getrawmetatable then
            local hum_mt = _real.getrawmetatable(hum)
            if hum_mt and hum_mt.__index then
                local oldIndex = hum_mt.__index
                if XAC.Cap.setreadonly then pcall(_real.setreadonly, hum_mt, false) end
                hum_mt.__index = NC(function(self, key)
                    if key == "WalkSpeed" then return XAC.Config and XAC.Config.FakeWalkSpeed or 16 end
                    if key == "JumpPower" then return XAC.Config and XAC.Config.FakeJumpPower or 50 end
                    return oldIndex(self, key)
                end)
                if XAC.Cap.setreadonly then pcall(_real.setreadonly, hum_mt, true) end
            end
        end
    end)
end

local function InstallWorkspaceSpoof()
    if not XAC.Cap.getrawmetatable then return end
    pcall(function()
        local ws_mt = _real.getrawmetatable(workspace)
        if ws_mt and ws_mt.__index then
            local oldIndex = ws_mt.__index
            if XAC.Cap.setreadonly then pcall(_real.setreadonly, ws_mt, false) end
            ws_mt.__index = NC(function(self, key)
                if key == "Gravity" then return XAC.Config and XAC.Config.FakeGravity or 196.2 end
                return oldIndex(self, key)
            end)
            if XAC.Cap.setreadonly then pcall(_real.setreadonly, ws_mt, true) end
        end
    end)
end

local function InstallTimeSpoof()
    if not XAC.Cap.hookfunction then return end
    local oldTick = tick
    local oldClock = os.clock
    pcall(function()
        _G.tick = NC(function() return oldTick() + XAC.TimeOffset end)
        os.clock = NC(function() return oldClock() + XAC.TimeOffset end)
    end)
end

function XAC.BumpTime(d) XAC.TimeOffset = XAC.TimeOffset + (d or 0) return XAC.TimeOffset end
function XAC.ResetTime() XAC.TimeOffset = 0 end

local function InstallConnectionHider()
    if not XAC.Cap.getconnections or not XAC.Cap.hookfunction then return end
    pcall(function()
        local oldGetConns = getconnections
        local hidden = setmetatable({}, {__mode = "k"})
        _G.getconnections = NC(function(conn)
            if hidden[conn] then return {} end
            return oldGetConns(conn)
        end)
        XAC.HideConnection = function(c) hidden[c] = true end
    end)
end

local function InstallDebugSpoof()
    if not debug then return end
    pcall(function()
        local oldGetInfo = debug.getinfo
        debug.getinfo = NC(function(...)
            local info = oldGetInfo(...)
            if type(info) == "table" then
                info.source = "=[C]"
                info.short_src = "[C]"
                info.what = "C"
                info.currentline = -1
            end
            return info
        end)
    end)
end

local function InstallNamecallGuard()
    if not XAC.Cap.getrawmetatable then return end
    pcall(function()
        local mt = _real.getrawmetatable(game)
        if not mt then return end
        local oldNamecall = mt.__namecall
        if XAC.Cap.setreadonly then pcall(_real.setreadonly, mt, false) end
        mt.__namecall = NC(function(self, ...)
            local method = getnamecallmethod and getnamecallmethod() or nil
            if method == "Kick" and self == LocalPlayer then return end
            if method == "Destroy" and (self == LocalPlayer or self == LocalPlayer.Character) then return end
            return oldNamecall(self, ...)
        end)
        if XAC.Cap.setreadonly then pcall(_real.setreadonly, mt, true) end
    end)
end

local function InstallGuiWatcher()
    if LocalPlayer:FindFirstChild("PlayerGui") then
        TrackConn(LocalPlayer.PlayerGui.ChildAdded:Connect(function(obj)
            if IsACName(obj.Name) then KillNode(obj) end
        end))
    end
    TrackConn(CoreGui.ChildAdded:Connect(function(obj)
        if IsACName(obj.Name) then KillNode(obj) end
    end))
end

local function InstallKickBlocker()
    if not LocalPlayer then return end
    pcall(function()
        if XAC.Cap.getrawmetatable then
            local mt = _real.getrawmetatable(LocalPlayer)
            if mt and mt.__index then
                local oldIndex = mt.__index
                if XAC.Cap.setreadonly then pcall(_real.setreadonly, mt, false) end
                mt.__index = NC(function(self, key)
                    if key == "Kick" then return NC(function() end) end
                    return oldIndex(self, key)
                end)
                if XAC.Cap.setreadonly then pcall(_real.setreadonly, mt, true) end
            end
        end
    end)
end

local function InstallErrorSink()
    local oldError = error
    local oldWarn = warn
    _G.error = NC(function(msg, level)
        if type(msg) == "string" and ContainsReport(msg) then return nil end
        return oldError(msg, level)
    end)
    _G.warn = NC(function(...)
        for _, a in ipairs({...}) do
            if ContainsReport(tostring(a)) then return end
        end
        return oldWarn(...)
    end)
end

function XAC.NewProtectedGui(name)
    local gui = Instance.new("ScreenGui")
    gui.Name = name or "RobloxChatWindow"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if XAC.Cap.protect_gui then pcall(_real.protect_gui, gui) end
    local parent = nil
    if XAC.Cap.gethui then
        local ok, hui = pcall(_real.gethui)
        if ok and hui then parent = hui end
    end
    if XAC.Cap.protect_gui then
        gui.Parent = CoreGui
    elseif parent then
        gui.Parent = parent
    else
        gui.Parent = CoreGui
    end
    TrackInst(gui)
    return gui
end

function XAC.Enable(opts)
    opts = opts or {}
    XAC.Config = {
        Enabled = true,
        ThrottleRemotes = opts.ThrottleRemotes ~= false,
        RemoteInterval = opts.RemoteInterval or 0.033,
        FakeWalkSpeed = opts.FakeWalkSpeed or 16,
        FakeJumpPower = opts.FakeJumpPower or 50,
        FakeGravity = opts.FakeGravity or 196.2,
        HideExecutor = opts.HideExecutor ~= false,
        KillAntiCheat = opts.KillAntiCheat ~= false,
        SpoofProperties = opts.SpoofProperties ~= false,
        SpoofTime = opts.SpoofTime ~= false,
        BlockKick = opts.BlockKick ~= false,
    }
    if XAC.Config.HideExecutor then FakeExecutor() ScrubGenv() end
    if XAC.Config.KillAntiCheat then InstallACReaper() end
    InstallRemoteHook()
    InstallNamecallGuard()
    if XAC.Config.SpoofProperties then InstallWorkspaceSpoof() end
    if XAC.Config.SpoofTime then InstallTimeSpoof() end
    if XAC.Config.BlockKick then InstallKickBlocker() end
    InstallConnectionHider()
    InstallDebugSpoof()
    InstallGuiWatcher()
    InstallErrorSink()
    if LocalPlayer.Character then InstallPropertySpoof(LocalPlayer.Character) end
    TrackConn(LocalPlayer.CharacterAdded:Connect(function(char)
        _real.wait(0.1)
        InstallPropertySpoof(char)
    end))
    return true
end

function XAC.Destroy()
    XAC.Alive = false
    for _, c in ipairs(XAC.Conns) do pcall(function() c:Disconnect() end) end
    for _, i in ipairs(XAC.Instances) do pcall(function() i:Destroy() end) end
    XAC.Conns = {} XAC.Instances = {} XAC.Hooks = {} XAC.Limiter = {}
    if _genv.__XAC == XAC then _genv.__XAC = nil end
end

XAC.Enable()

-- ============================================================
-- 第二部分：配置表 + 主 UI
-- ============================================================
local Config = {
    ["自瞄启用"] = true, ["忽略人机"] = true, ["忽略倒地"] = true,
    ["触摸框X"] = 1460, ["触摸框Y"] = 1020, ["触摸框大小"] = 80,
    ["连点启用"] = false, ["极速模式"] = false, ["连点速度"] = 50.0,
    ["连点框X"] = 1450, ["连点框Y"] = 1010, ["连点框大小"] = 100,
    ["便捷开关"] = true, ["显示触摸框"] = false,
    ["显示FPS"] = true, ["夜视"] = false, ["去雾"] = false,
    ["无限跳跃"] = false, ["穿墙"] = false, ["无敌"] = false,
    ["千倍速度"] = false, ["踏空"] = false, ["防挂机"] = false,
    ["点击传送"] = false, ["自动连点"] = false, ["加速"] = false,
    ["隐身"] = false, ["全图点亮"] = false,
    ["团队高亮"] = false, ["敌对高亮"] = false, ["自动攻击"] = false,
    ["ESP透视"] = false, ["跳舞"] = false, ["喷火"] = false,
    ["光环"] = false, ["倒立"] = false, ["大头"] = false,
    ["全屏特效"] = false, ["彩虹拖尾"] = false, ["火焰拖尾"] = false,
    ["冰霜拖尾"] = false, ["彩虹名字"] = false, ["巨大化"] = false,
    ["客户端字幕"] = false, ["移动速度"] = 16, ["跳跃高度"] = 50,
    ["重力"] = 196, ["视野"] = 70,
}
_genv.XixiConfig = Config

if CoreGui:FindFirstChild("OceanStarUI") then CoreGui.OceanStarUI:Destroy() end

local Theme = {
    BgGlass = Color3.fromRGB(40, 42, 50),
    Accent = Color3.fromRGB(0, 122, 255),
    TextMain = Color3.fromRGB(40, 40, 40),
    TextSub = Color3.fromRGB(120, 120, 120),
    ToggleOff = Color3.fromRGB(200, 200, 200),
}

local MainGui = XAC.NewProtectedGui("OceanStarUI")

local Overlay = Instance.new("Frame")
Overlay.Size = UDim2.new(1, 0, 1, 0)
Overlay.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
Overlay.BackgroundTransparency = 0.55
Overlay.ZIndex = 1
Overlay.Parent = MainGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 720, 0, 520)
MainFrame.Position = UDim2.new(0.5, -360, 0.5, -260)
MainFrame.BackgroundColor3 = Theme.BgGlass
MainFrame.BackgroundTransparency = 0.15
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ZIndex = 2
MainFrame.Parent = MainGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 20)

local UIStroke = Instance.new("UIStroke", MainFrame)
UIStroke.Color = Color3.fromRGB(255, 255, 255)
UIStroke.Transparency = 0.82
UIStroke.Thickness = 1.5

local UIGradient = Instance.new("UIGradient", MainFrame)
UIGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 200, 220)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 180)),
})
UIGradient.Rotation = 90
UIGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.9),
    NumberSequenceKeypoint.new(0.5, 0.95),
    NumberSequenceKeypoint.new(1, 0.85),
})

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 180, 1, 0)
Sidebar.BackgroundTransparency = 1
Sidebar.ZIndex = 3
Sidebar.Parent = MainFrame

local AvatarArea = Instance.new("Frame")
AvatarArea.Size = UDim2.new(1, 0, 0, 80)
AvatarArea.BackgroundTransparency = 1
AvatarArea.ZIndex = 4
AvatarArea.Parent = Sidebar

local AvatarImg = Instance.new("ImageLabel")
AvatarImg.Size = UDim2.new(0, 48, 0, 48)
AvatarImg.Position = UDim2.new(0, 16, 0, 16)
AvatarImg.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
AvatarImg.ZIndex = 5
AvatarImg.Parent = AvatarArea
Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(0, 24)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -80, 0, 20)
TitleLabel.Position = UDim2.new(0, 72, 0, 18)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "海洋之星"
TitleLabel.TextColor3 = Theme.TextMain
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 5
TitleLabel.Parent = AvatarArea

local SubTitleLabel = Instance.new("TextLabel")
SubTitleLabel.Size = UDim2.new(1, -80, 0, 14)
SubTitleLabel.Position = UDim2.new(0, 72, 0, 38)
SubTitleLabel.BackgroundTransparency = 1
SubTitleLabel.Text = "内核 · XAC V5.0"
SubTitleLabel.TextColor3 = Theme.TextSub
SubTitleLabel.TextSize = 10
SubTitleLabel.Font = Enum.Font.Gotham
SubTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
SubTitleLabel.ZIndex = 5
SubTitleLabel.Parent = AvatarArea

local NavContainer = Instance.new("Frame")
NavContainer.Size = UDim2.new(1, -16, 1, -100)
NavContainer.Position = UDim2.new(0, 8, 0, 80)
NavContainer.BackgroundTransparency = 1
NavContainer.ZIndex = 4
NavContainer.Parent = Sidebar

local NavLayout = Instance.new("UIListLayout", NavContainer)
NavLayout.Padding = UDim.new(0, 8)
NavLayout.SortOrder = Enum.SortOrder.LayoutOrder

local NavButtons = {}
local Pages = {}
local ActivePage = nil

local function SwitchPage(pageName)
    if ActivePage and NavButtons[ActivePage] then
        TweenService:Create(NavButtons[ActivePage], TweenInfo.new(0.2), {
            BackgroundTransparency = 0.6, TextColor3 = Theme.TextSub,
        }):Play()
    end
    ActivePage = pageName
    if NavButtons[pageName] then
        TweenService:Create(NavButtons[pageName], TweenInfo.new(0.2), {
            BackgroundTransparency = 0, TextColor3 = Theme.TextMain,
        }):Play()
    end
    for name, page in pairs(Pages) do
        page.Visible = (name == pageName)
    end
end

local function CreateNavButton(name, text, order, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundTransparency = 0.6
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Theme.TextSub
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamMedium
    btn.LayoutOrder = order
    btn.ZIndex = 5
    btn.Parent = NavContainer
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    NavButtons[name] = btn
    btn.MouseButton1Click:Connect(function()
        if onClick then onClick() else SwitchPage(name) end
    end)
    return btn
end

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -190, 1, -20)
ContentArea.Position = UDim2.new(0, 180, 0, 10)
ContentArea.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ContentArea.BackgroundTransparency = 0.88
ContentArea.BorderSizePixel = 0
ContentArea.ZIndex = 3
ContentArea.Parent = MainFrame
Instance.new("UICorner", ContentArea).CornerRadius = UDim.new(0, 16)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 70)
Header.BackgroundTransparency = 1
Header.ZIndex = 4
Header.Parent = ContentArea

local HeaderTitle = Instance.new("TextLabel")
HeaderTitle.Size = UDim2.new(1, -100, 0, 30)
HeaderTitle.Position = UDim2.new(0, 16, 0, 10)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Text = "人物自瞄"
HeaderTitle.TextColor3 = Theme.TextMain
HeaderTitle.TextSize = 18
HeaderTitle.Font = Enum.Font.GothamBold
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
HeaderTitle.ZIndex = 5
HeaderTitle.Parent = Header

local FPSLabel = Instance.new("TextLabel")
FPSLabel.Size = UDim2.new(1, -100, 0, 20)
FPSLabel.Position = UDim2.new(0, 16, 0, 40)
FPSLabel.BackgroundTransparency = 1
FPSLabel.Text = "真人 0 / 人机 0   0 FPS"
FPSLabel.TextColor3 = Theme.TextSub
FPSLabel.TextSize = 11
FPSLabel.Font = Enum.Font.Gotham
FPSLabel.TextXAlignment = Enum.TextXAlignment.Left
FPSLabel.ZIndex = 5
FPSLabel.Parent = Header

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -20, 1, -80)
ScrollFrame.Position = UDim2.new(0, 10, 0, 70)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(180, 180, 180)
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollFrame.ZIndex = 4
ScrollFrame.Parent = ContentArea

local ScrollLayout = Instance.new("UIListLayout", ScrollFrame)
ScrollLayout.Padding = UDim.new(0, 16)
ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -34, 0, 12)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 16
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.ZIndex = 10
CloseBtn.Parent = MainFrame
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(1, 0)
CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

-- ============================================================
-- 第三部分：控件封装
-- ============================================================
local function CreateSection(parent, titleText)
    local SectionFrame = Instance.new("Frame")
    SectionFrame.Size = UDim2.new(1, 0, 0, 20)
    SectionFrame.BackgroundTransparency = 1
    SectionFrame.Parent = parent
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = titleText
    Label.TextColor3 = Theme.TextSub
    Label.TextSize = 11
    Label.Font = Enum.Font.GothamMedium
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = SectionFrame
    return SectionFrame
end

local function CreateToggleRow(parent, key, labelText, onChange)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 28)
    Row.BackgroundTransparency = 1
    Row.Parent = parent
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.6, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = labelText
    Label.TextColor3 = Theme.TextMain
    Label.TextSize = 13
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row
    local state = Config[key] or false
    local ToggleBg = Instance.new("Frame")
    ToggleBg.Size = UDim2.new(0, 42, 0, 22)
    ToggleBg.Position = UDim2.new(1, -42, 0.5, -11)
    ToggleBg.BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff
    ToggleBg.BorderSizePixel = 0
    ToggleBg.Parent = Row
    Instance.new("UICorner", ToggleBg).CornerRadius = UDim.new(1, 0)
    local ToggleKnob = Instance.new("Frame")
    ToggleKnob.Size = UDim2.new(0, 18, 0, 18)
    ToggleKnob.Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    ToggleKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ToggleKnob.BorderSizePixel = 0
    ToggleKnob.Parent = ToggleBg
    Instance.new("UICorner", ToggleKnob).CornerRadius = UDim.new(1, 0)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = ToggleBg
    btn.MouseButton1Click:Connect(function()
        state = not state
        Config[key] = state
        TweenService:Create(ToggleBg, TweenInfo.new(0.2), {BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff}):Play()
        TweenService:Create(ToggleKnob, TweenInfo.new(0.2), {Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)}):Play()
        if onChange then pcall(onChange, state) end
    end)
    return Row
end

local function CreateSliderRow(parent, key, labelText, min, max, onChange)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 40)
    Row.BackgroundTransparency = 1
    Row.Parent = parent
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.5, 0, 0, 16)
    Label.BackgroundTransparency = 1
    Label.Text = labelText
    Label.TextColor3 = Theme.TextMain
    Label.TextSize = 12
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row
    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0.5, 0, 0, 16)
    valLabel.Position = UDim2.new(0.5, 0, 0, 0)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(Config[key] or min)
    valLabel.TextColor3 = Theme.Accent
    valLabel.TextSize = 12
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = Row
    local Track = Instance.new("Frame")
    Track.Size = UDim2.new(1, 0, 0, 4)
    Track.Position = UDim2.new(0, 0, 0, 24)
    Track.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
    Track.BorderSizePixel = 0
    Track.Parent = Row
    Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)
    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new(math.clamp(((Config[key] or min) - min) / (max - min), 0, 1), 0, 1, 0)
    Fill.BackgroundColor3 = Theme.Accent
    Fill.BorderSizePixel = 0
    Fill.Parent = Track
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)
    local dragging = false
    local function updateValue(x)
        local rel = math.clamp((x - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * rel)
        Fill.Size = UDim2.new(rel, 0, 1, 0)
        valLabel.Text = tostring(val)
        Config[key] = val
        if onChange then pcall(onChange, val) end
    end
    Track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateValue(input.Position.X)
        end
    end)
    TrackConn(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateValue(input.Position.X)
        end
    end))
    TrackConn(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    return Row
end

local function CreateButtonRow(parent, labelText, onClick)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 32)
    Row.BackgroundTransparency = 1
    Row.Parent = parent
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
    btn.BorderSizePixel = 0
    btn.Text = labelText
    btn.TextColor3 = Theme.TextMain
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = Row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(function()
        if onClick then pcall(onClick) end
    end)
    return Row
end

-- ============================================================
-- 第四部分：功能实现
-- ============================================================
local Feature = {}
Feature.Conns = {}
local function Reg(k, on, off) Feature[k] = {on=on, off=off} end
local function Fire(k, state)
    local f = Feature[k]
    if not f then return end
    if state then
        if f.on then pcall(f.on) end
    else
        if f.off then pcall(f.off) end
        if Feature.Conns[k] then pcall(function() Feature.Conns[k]:Disconnect() end) Feature.Conns[k] = nil end
    end
end

Reg("无限跳跃", function()
    Feature.Conns["无限跳跃"] = TrackConn(UserInputService.JumpRequest:Connect(function()
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("Humanoid") then c.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
    end))
end)

Reg("穿墙", function()
    Feature.Conns["穿墙"] = TrackConn(RunService.Stepped:Connect(function()
        local c = LocalPlayer.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end))
end, function()
    local c = LocalPlayer.Character
    if c then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
end)

Reg("无敌", function()
    Feature.Conns["无敌"] = TrackConn(RunService.Heartbeat:Connect(function()
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("Humanoid") then
            c.Humanoid.MaxHealth = math.huge
            c.Humanoid.Health = math.huge
        end
    end))
end)

Reg("千倍速度", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed = 1000 end
end, function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed = 16 end
end)

Reg("踏空", function()
    local c = LocalPlayer.Character
    if not c or not c:FindFirstChild("HumanoidRootPart") then return end
    local hrp = c.HumanoidRootPart
    local y = hrp.Position.Y
    Feature.Conns["踏空"] = TrackConn(RunService.RenderStepped:Connect(function()
        if hrp and hrp.Parent then
            hrp.Velocity = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z)
            hrp.CFrame = CFrame.new(hrp.Position.X, y, hrp.Position.Z)
        end
    end))
end)

Reg("防挂机", function()
    TrackConn(LocalPlayer.Idled:Connect(function()
        local vu = game:GetService("VirtualUser")
        vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end))
end)

Reg("点击传送", function()
    local mouse = LocalPlayer:GetMouse()
    Feature.Conns["点击传送"] = TrackConn(mouse.Button1Down:Connect(function()
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("HumanoidRootPart") and mouse.Hit then
            local target = mouse.Hit.p + Vector3.new(0, 3, 0)
            XAC.BumpTime(1.5)
            c.HumanoidRootPart.CFrame = CFrame.new(target)
            task.delay(1.5, XAC.ResetTime)
        end
    end))
end)

Reg("自动连点", function()
    Feature.Conns["自动连点"] = TrackConn(RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        local s = cam.ViewportSize
        local vu = game:GetService("VirtualUser")
        vu:Button1Down(Vector2.new(s.X/2, s.Y/2))
        vu:Button1Up(Vector2.new(s.X/2, s.Y/2))
    end))
end)

Reg("加速", function()
    Feature.Conns["加速"] = TrackConn(RunService.RenderStepped:Connect(function()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("Animation") then v.Speed = 2 end
        end
    end))
end)

Reg("隐身", function()
    local c = LocalPlayer.Character
    if c then for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then v.Transparency = 0.8 end
    end end
end, function()
    local c = LocalPlayer.Character
    if c then for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then v.Transparency = 0 end
    end end
end)

Reg("夜视", function()
    local Lighting = game:GetService("Lighting")
    Lighting.Brightness = 2
    Lighting.ClockTime = 14
    Lighting.FogEnd = 100000
    Lighting.GlobalShadows = false
end, function()
    local Lighting = game:GetService("Lighting")
    Lighting.Brightness = 1
    Lighting.GlobalShadows = true
end)

Reg("去雾", function()
    local Lighting = game:GetService("Lighting")
    Lighting.FogEnd = 100000
    Lighting.FogStart = 50000
end, function()
    local Lighting = game:GetService("Lighting")
    Lighting.FogEnd = 1000
    Lighting.FogStart = 0
end)

Reg("全图点亮", function()
    local Lighting = game:GetService("Lighting")
    Lighting.Brightness = 5
    Lighting.ClockTime = 14
    Lighting.FogEnd = 100000
    Lighting.GlobalShadows = false
    Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
end, function()
    local Lighting = game:GetService("Lighting")
    Lighting.Brightness = 1
    Lighting.GlobalShadows = true
end)

Reg("团队高亮", function()
    local myTeam = LocalPlayer.Team
    Feature.Conns["团队高亮"] = TrackConn(RunService.RenderStepped:Connect(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Team == myTeam then
                if not p.Character:FindFirstChild("TeamGlow") then
                    local hl = Instance.new("Highlight")
                    hl.Name = "TeamGlow"
                    hl.FillColor = Color3.fromRGB(0, 100, 255)
                    hl.OutlineColor = Color3.fromRGB(0, 150, 255)
                    hl.FillTransparency = 0.5
                    hl.Parent = p.Character
                end
            end
        end
    end))
end, function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local hl = p.Character:FindFirstChild("TeamGlow")
            if hl then hl:Destroy() end
        end
    end
end)

Reg("敌对高亮", function()
    local myTeam = LocalPlayer.Team
    Feature.Conns["敌对高亮"] = TrackConn(RunService.RenderStepped:Connect(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Team ~= myTeam then
                if not p.Character:FindFirstChild("EnemyGlow") then
                    local hl = Instance.new("Highlight")
                    hl.Name = "EnemyGlow"
                    hl.FillColor = Color3.fromRGB(255, 0, 0)
                    hl.OutlineColor = Color3.fromRGB(255, 50, 50)
                    hl.FillTransparency = 0.5
                    hl.Parent = p.Character
                end
            end
        end
    end))
end, function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local hl = p.Character:FindFirstChild("EnemyGlow")
            if hl then hl:Destroy() end
        end
    end
end)

Reg("自动攻击", function()
    Feature.Conns["自动攻击"] = TrackConn(RunService.Heartbeat:Connect(function()
        local c = LocalPlayer.Character
        if not c or not c:FindFirstChild("HumanoidRootPart") then return end
        local myTeam = LocalPlayer.Team
        local nearest, minDist = nil, 15
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Team ~= myTeam then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                local hum = p.Character:FindFirstChild("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    local d = (hrp.Position - c.HumanoidRootPart.Position).Magnitude
                    if d < minDist then minDist = d nearest = p.Character end
                end
            end
        end
        if nearest then
            XAC.BumpTime(0.3)
            c.HumanoidRootPart.CFrame = nearest.HumanoidRootPart.CFrame + Vector3.new(2, 0, 0)
            local tool = c:FindFirstChildOfClass("Tool")
            if tool and tool:FindFirstChild("Handle") then
                firetouchinterest(tool.Handle, nearest, 0)
                firetouchinterest(tool.Handle, nearest, 1)
            end
        end
    end))
end)

Reg("ESP透视", function()
    Feature.Conns["ESP透视"] = TrackConn(RunService.RenderStepped:Connect(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and not p.Character:FindFirstChild("ESPGlow") then
                local hl = Instance.new("Highlight")
                hl.Name = "ESPGlow"
                hl.FillColor = Color3.fromRGB(255, 215, 0)
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.FillTransparency = 0.4
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = p.Character
            end
        end
    end))
end, function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local hl = p.Character:FindFirstChild("ESPGlow")
            if hl then hl:Destroy() end
        end
    end
end)

Reg("跳舞", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Humanoid") then
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://5918726674"
        local track = c.Humanoid:LoadAnimation(anim)
        track:Play()
        Feature.Conns["跳舞"] = {Disconnect = function() track:Stop() end}
    end
end)

Reg("喷火", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local fire = Instance.new("ParticleEmitter")
        fire.Name = "FireFX"
        fire.Texture = "rbxassetid://241876428"
        fire.Color = ColorSequence.new(Color3.fromRGB(255, 100, 0))
        fire.Rate = 30
        fire.Speed = NumberRange.new(3, 6)
        fire.Lifetime = NumberRange.new(0.5, 1)
        fire.Parent = c.HumanoidRootPart
    end
end, function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local fx = c.HumanoidRootPart:FindFirstChild("FireFX")
        if fx then fx:Destroy() end
    end
end)

Reg("光环", function()
    local c = LocalPlayer.Character
    if c then
        local hl = Instance.new("Highlight")
        hl.Name = "PlayerGlow"
        hl.FillColor = Color3.fromRGB(255, 255, 0)
        hl.OutlineColor = Color3.fromRGB(255, 200, 0)
        hl.FillTransparency = 0.3
        hl.Parent = c
    end
end, function()
    local c = LocalPlayer.Character
    if c then
        local hl = c:FindFirstChild("PlayerGlow")
        if hl then hl:Destroy() end
    end
end)

Reg("倒立", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        c.HumanoidRootPart.CFrame = c.HumanoidRootPart.CFrame * CFrame.Angles(0, 0, math.rad(180))
    end
end)

Reg("大头", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Head") then c.Head.Size = Vector3.new(4, 4, 4) end
end, function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Head") then c.Head.Size = Vector3.new(2, 1, 1) end
end)

Reg("全屏特效", function()
    local fx = Instance.new("ColorCorrectionEffect")
    fx.Name = "ScreenFX"
    fx.TintColor = Color3.fromRGB(255, 100, 200)
    fx.Parent = game:GetService("Lighting")
end, function()
    local fx = game:GetService("Lighting"):FindFirstChild("ScreenFX")
    if fx then fx:Destroy() end
end)

Reg("彩虹拖尾", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local hrp = c.HumanoidRootPart
        local trail = Instance.new("Trail")
        trail.Name = "PlayerTrail"
        local a0 = Instance.new("Attachment") a0.Parent = hrp
        local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -2, 0) a1.Parent = hrp
        trail.Attachment0 = a0 trail.Attachment1 = a1
        trail.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0), Color3.fromRGB(0, 0, 255))
        trail.Lifetime = 0.5
        trail.Parent = hrp
    end
end, function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local t = c.HumanoidRootPart:FindFirstChild("PlayerTrail")
        if t then t:Destroy() end
    end
end)

Reg("火焰拖尾", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local hrp = c.HumanoidRootPart
        local trail = Instance.new("Trail")
        trail.Name = "FireTrail"
        local a0 = Instance.new("Attachment") a0.Parent = hrp
        local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -2, 0) a1.Parent = hrp
        trail.Attachment0 = a0 trail.Attachment1 = a1
        trail.Color = ColorSequence.new(Color3.fromRGB(255, 50, 0), Color3.fromRGB(255, 150, 0), Color3.fromRGB(255, 255, 0))
        trail.Lifetime = 0.3
        trail.Parent = hrp
    end
end, function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local t = c.HumanoidRootPart:FindFirstChild("FireTrail")
        if t then t:Destroy() end
    end
end)

Reg("冰霜拖尾", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local hrp = c.HumanoidRootPart
        local trail = Instance.new("Trail")
        trail.Name = "IceTrail"
        local a0 = Instance.new("Attachment") a0.Parent = hrp
        local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -2, 0) a1.Parent = hrp
        trail.Attachment0 = a0 trail.Attachment1 = a1
        trail.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255), Color3.fromRGB(200, 240, 255))
        trail.Lifetime = 0.4
        trail.Parent = hrp
    end
end, function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local t = c.HumanoidRootPart:FindFirstChild("IceTrail")
        if t then t:Destroy() end
    end
end)

Reg("彩虹名字", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Head") then
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0, 150, 0, 30)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        bb.Parent = c.Head
        local nl = Instance.new("TextLabel")
        nl.Size = UDim2.new(1, 0, 1, 0)
        nl.BackgroundTransparency = 1
        nl.Text = LocalPlayer.DisplayName .. " 👑"
        nl.Font = Enum.Font.GothamBold
        nl.TextSize = 14
        nl.Name = "RainbowName"
        nl.TextStrokeTransparency = 0
        nl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        nl.Parent = bb
        local hue = 0
        Feature.Conns["彩虹名字"] = TrackConn(RunService.RenderStepped:Connect(function(dt)
            hue = (hue + dt * 0.5) % 1
            nl.TextColor3 = Color3.fromHSV(hue, 1, 1)
        end))
    end
end, function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Head") then
        local bb = c.Head:FindFirstChild("BillboardGui")
        if bb then bb:Destroy() end
    end
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

Reg("客户端字幕", function()
    local subGui = XAC.NewProtectedGui("SubtitleGui")
    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(0, 500, 0, 80)
    subLabel.Position = UDim2.new(0.5, -250, 0, 10)
    subLabel.Text = LocalPlayer.Name .. " 已入侵服务器"
    subLabel.Font = Enum.Font.GothamBold
    subLabel.TextSize = 24
    subLabel.BackgroundTransparency = 1
    subLabel.TextStrokeTransparency = 0
    subLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    subLabel.Parent = subGui
    Feature.Conns["客户端字幕"] = {Disconnect = function() if subGui then subGui:Destroy() end end}
end)

-- ============================================================
-- 第五部分：下载器独立窗口
-- ============================================================
local DownloaderState = {
    Alive = true,
    Running = false,
    CancelRequested = false,
    GameId = tostring(game.GameId or 0),
    Root = "XixiDownloader",
    Folders = {
        Scripts = "XixiDownloader/Scripts",
        Bytecode = "XixiDownloader/Bytecode",
        Remotes = "XixiDownloader/Remotes",
    },
    Options = {
        SkipGet = false,
        SkipExisting = true,
        IncludeWorkspacePlayers = false,
        HideExisting = false,
        SaveBytecode = false,
        SpeedDelay = 0.01,
    },
    Targets = {
        Scripts = true,
        Remotes = true,
        NilInstance = true,
    },
    Stats = {
        ScriptsFound = 0, ScriptsSaved = 0, RemotesFound = 0, RemotesSaved = 0,
        Errors = 0, Skipped = 0, Total = 0, Done = 0, Current = "空闲",
    },
    AlreadyGot = {},
}

local function EnsureDownloadFolders()
    if not XAC.Cap.isfolder or not XAC.Cap.makefolder then return end
    for _, f in ipairs({DownloaderState.Root, DownloaderState.Folders.Scripts, DownloaderState.Folders.Bytecode, DownloaderState.Folders.Remotes}) do
        if not isfolder(f) then pcall(makefolder, f) end
    end
end
EnsureDownloadFolders()

local function LoadDownloadHistory()
    local histFile = DownloaderState.Root .. "/history.txt"
    if XAC.Cap.isfile and isfile(histFile) then
        local ok, content = pcall(readfile, histFile)
        if ok and content then
            for line in content:gmatch("[^\r\n]+") do
                DownloaderState.AlreadyGot[line] = true
            end
        end
    end
end
LoadDownloadHistory()

local function SaveDownloadHistory(hash)
    if not hash then return end
    local histFile = DownloaderState.Root .. "/history.txt"
    pcall(function()
        if XAC.Cap.isfile and isfile(histFile) then
            local old = readfile(histFile)
            writefile(histFile, old .. "\n" .. hash)
        else
            writefile(histFile, hash)
        end
    end)
end

local function SafeName(s)
    if type(s) ~= "string" then return "nil" end
    s = s:gsub("[\\/:*?\"<>|]", "_")
    if #s > 100 then s = s:sub(1, 100) end
    return s
end

local function GetInstancePath(inst)
    local parts = {}
    local cur = inst
    local guard = 0
    while cur and cur ~= game and guard < 50 do
        guard = guard + 1
        table.insert(parts, 1, SafeName(cur.Name))
        local ok, parent = pcall(function() return cur.Parent end)
        if not ok then break end
        cur = parent
    end
    return table.concat(parts, "/")
end

local function MakeDirsFor(path)
    if not XAC.Cap.isfolder or not XAC.Cap.makefolder then return end
    local dir = path:match("^(.*)/[^/]+$")
    if not dir then return end
    local acc = ""
    for part in dir:gmatch("[^/]+") do
        acc = (acc == "") and part or (acc .. "/" .. part)
        if not isfolder(acc) then pcall(makefolder, acc) end
    end
end

local function SafeWriteFile(path, content)
    if not content or content == "" then return false end
    MakeDirsFor(path)
    return pcall(writefile, path, content)
end

-- 下载器 UI
if _genv.__XixiDownloaderGui then
    pcall(function() _genv.__XixiDownloaderGui:Destroy() end)
end

local DlGui = XAC.NewProtectedGui("XixiDownloaderGui")
_genv.__XixiDownloaderGui = DlGui

local DlTheme = {
    BgDark = Color3.fromRGB(18, 20, 24),
    BgPanel = Color3.fromRGB(26, 29, 34),
    BgRow = Color3.fromRGB(34, 38, 44),
    BgRowAlt = Color3.fromRGB(40, 44, 52),
    Accent = Color3.fromRGB(0, 140, 220),
    AccentBright = Color3.fromRGB(0, 170, 255),
    Green = Color3.fromRGB(0, 200, 100),
    Red = Color3.fromRGB(230, 70, 70),
    Text = Color3.fromRGB(230, 232, 238),
    TextDim = Color3.fromRGB(150, 155, 165),
    TextSubtle = Color3.fromRGB(110, 115, 125),
    Border = Color3.fromRGB(55, 60, 70),
}

local DW, DH = 560, 640
local DlMain = Instance.new("Frame")
DlMain.Name = "DlMain"
DlMain.Size = UDim2.new(0, DW, 0, DH)
DlMain.Position = UDim2.new(0.5, -DW/2 + 40, 0.5, -DH/2 + 40)
DlMain.BackgroundColor3 = DlTheme.BgDark
DlMain.BackgroundTransparency = 0.02
DlMain.BorderSizePixel = 0
DlMain.Active = true
DlMain.Draggable = true
DlMain.Visible = false
DlMain.ZIndex = 100
DlMain.Parent = DlGui
Instance.new("UICorner", DlMain).CornerRadius = UDim.new(0, 12)

local DlStroke = Instance.new("UIStroke", DlMain)
DlStroke.Color = DlTheme.Border
DlStroke.Thickness = 1

local DlTitleBar = Instance.new("Frame")
DlTitleBar.Size = UDim2.new(1, 0, 0, 44)
DlTitleBar.BackgroundColor3 = DlTheme.BgPanel
DlTitleBar.BorderSizePixel = 0
DlTitleBar.ZIndex = 2
DlTitleBar.Parent = DlMain
Instance.new("UICorner", DlTitleBar).CornerRadius = UDim.new(0, 12)

local DlTitleFix = Instance.new("Frame")
DlTitleFix.Size = UDim2.new(1, 0, 0, 12)
DlTitleFix.Position = UDim2.new(0, 0, 1, -12)
DlTitleFix.BackgroundColor3 = DlTheme.BgPanel
DlTitleFix.BorderSizePixel = 0
DlTitleFix.ZIndex = 2
DlTitleFix.Parent = DlTitleBar

local DlTitle = Instance.new("TextLabel")
DlTitle.Size = UDim2.new(1, -80, 1, 0)
DlTitle.Position = UDim2.new(0, 16, 0, 0)
DlTitle.BackgroundTransparency = 1
DlTitle.Text = "下载器 | " .. DownloaderState.GameId
DlTitle.TextColor3 = DlTheme.Text
DlTitle.TextSize = 15
DlTitle.Font = Enum.Font.GothamBold
DlTitle.TextXAlignment = Enum.TextXAlignment.Left
DlTitle.ZIndex = 3
DlTitle.Parent = DlTitleBar

local DlCloseBtn = Instance.new("TextButton")
DlCloseBtn.Size = UDim2.new(0, 26, 0, 26)
DlCloseBtn.Position = UDim2.new(1, -34, 0, 9)
DlCloseBtn.BackgroundColor3 = DlTheme.Red
DlCloseBtn.Text = "×"
DlCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DlCloseBtn.TextSize = 16
DlCloseBtn.Font = Enum.Font.GothamBold
DlCloseBtn.BorderSizePixel = 0
DlCloseBtn.ZIndex = 3
DlCloseBtn.Parent = DlTitleBar
Instance.new("UICorner", DlCloseBtn).CornerRadius = UDim.new(1, 0)
DlCloseBtn.MouseButton1Click:Connect(function() DlMain.Visible = false end)

local DlContent = Instance.new("Frame")
DlContent.Size = UDim2.new(1, -24, 1, -60)
DlContent.Position = UDim2.new(0, 12, 0, 52)
DlContent.BackgroundTransparency = 1
DlContent.ZIndex = 1
DlContent.Parent = DlMain

local StatusCard = Instance.new("Frame")
StatusCard.Size = UDim2.new(1, 0, 0, 60)
StatusCard.BackgroundColor3 = DlTheme.BgPanel
StatusCard.BorderSizePixel = 0
StatusCard.Parent = DlContent
Instance.new("UICorner", StatusCard).CornerRadius = UDim.new(0, 8)
local StatusStroke = Instance.new("UIStroke", StatusCard)
StatusStroke.Color = DlTheme.Border
StatusStroke.Thickness = 1

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -20, 0, 22)
StatusText.Position = UDim2.new(0, 12, 0, 6)
StatusText.BackgroundTransparency = 1
StatusText.Text = "状态：空闲 · 已保存 0 / 0"
StatusText.TextColor3 = DlTheme.Text
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = StatusCard

local StatusSub = Instance.new("TextLabel")
StatusSub.Size = UDim2.new(1, -20, 0, 18)
StatusSub.Position = UDim2.new(0, 12, 0, 30)
StatusSub.BackgroundTransparency = 1
StatusSub.Text = "脚本：0 · 远程：0 · 跳过：0 · 错误：0"
StatusSub.TextColor3 = DlTheme.TextDim
StatusSub.TextSize = 11
StatusSub.Font = Enum.Font.Gotham
StatusSub.TextXAlignment = Enum.TextXAlignment.Left
StatusSub.Parent = StatusCard

local ProgressBg = Instance.new("Frame")
ProgressBg.Size = UDim2.new(1, 0, 0, 6)
ProgressBg.Position = UDim2.new(0, 0, 0, 52)
ProgressBg.BackgroundColor3 = DlTheme.BgRow
ProgressBg.BorderSizePixel = 0
ProgressBg.Parent = StatusCard
Instance.new("UICorner", ProgressBg).CornerRadius = UDim.new(1, 0)

local ProgressFill = Instance.new("Frame")
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = DlTheme.AccentBright
ProgressFill.BorderSizePixel = 0
ProgressFill.Parent = ProgressBg
Instance.new("UICorner", ProgressFill).CornerRadius = UDim.new(1, 0)

local MainBtn = Instance.new("TextButton")
MainBtn.Size = UDim2.new(1, 0, 0, 46)
MainBtn.Position = UDim2.new(0, 0, 0, 72)
MainBtn.BackgroundColor3 = DlTheme.Accent
MainBtn.BorderSizePixel = 0
MainBtn.Text = "初始化扫描"
MainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MainBtn.TextSize = 15
MainBtn.Font = Enum.Font.GothamBold
MainBtn.Parent = DlContent
Instance.new("UICorner", MainBtn).CornerRadius = UDim.new(0, 8)
local MainBtnStroke = Instance.new("UIStroke", MainBtn)
MainBtnStroke.Color = DlTheme.AccentBright
MainBtnStroke.Thickness = 1

local function MakeDlSectionTitle(parent, text, yPos)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.Position = UDim2.new(0, 4, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = DlTheme.TextDim
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
    return lbl
end

local function MakeDlToggleRow(parent, yPos, labelText, initialValue, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.Position = UDim2.new(0, 0, 0, yPos)
    row.BackgroundColor3 = DlTheme.BgRow
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = DlTheme.Text
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row
    local state = initialValue
    local tbg = Instance.new("Frame")
    tbg.Size = UDim2.new(0, 40, 0, 20)
    tbg.Position = UDim2.new(1, -52, 0.5, -10)
    tbg.BackgroundColor3 = state and DlTheme.Green or DlTheme.BgRowAlt
    tbg.BorderSizePixel = 0
    tbg.Parent = row
    Instance.new("UICorner", tbg).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = tbg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(tbg, TweenInfo.new(0.2), {BackgroundColor3 = state and DlTheme.Green or DlTheme.BgRowAlt}):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}):Play()
        if onChange then pcall(onChange, state) end
    end)
    return row
end

local function MakeDlTargetRow(parent, yPos, key, tag, tagColor, labelText)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.Position = UDim2.new(0, 0, 0, yPos)
    row.BackgroundColor3 = DlTheme.BgRow
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    local tagFrame = Instance.new("Frame")
    tagFrame.Size = UDim2.new(0, 28, 0, 28)
    tagFrame.Position = UDim2.new(0, 4, 0.5, -14)
    tagFrame.BackgroundColor3 = tagColor
    tagFrame.BorderSizePixel = 0
    tagFrame.Parent = row
    Instance.new("UICorner", tagFrame).CornerRadius = UDim.new(0, 6)
    local tagLabel = Instance.new("TextLabel")
    tagLabel.Size = UDim2.new(1, 0, 1, 0)
    tagLabel.BackgroundTransparency = 1
    tagLabel.Text = tag
    tagLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    tagLabel.TextSize = 14
    tagLabel.Font = Enum.Font.GothamBold
    tagLabel.Parent = tagFrame
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -130, 1, 0)
    label.Position = UDim2.new(0, 40, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = DlTheme.Text
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row
    local state = DownloaderState.Targets[key]
    local tbg = Instance.new("Frame")
    tbg.Size = UDim2.new(0, 40, 0, 20)
    tbg.Position = UDim2.new(1, -52, 0.5, -10)
    tbg.BackgroundColor3 = state and DlTheme.AccentBright or DlTheme.BgRowAlt
    tbg.BorderSizePixel = 0
    tbg.Parent = row
    Instance.new("UICorner", tbg).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = tbg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row
    btn.MouseButton1Click:Connect(function()
        state = not state
        DownloaderState.Targets[key] = state
        TweenService:Create(tbg, TweenInfo.new(0.2), {BackgroundColor3 = state and DlTheme.AccentBright or DlTheme.BgRowAlt}):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}):Play()
    end)
    return row
end

MakeDlSectionTitle(DlContent, "导出选项", 128)
local dlToggleY = 152
MakeDlToggleRow(DlContent, dlToggleY, "导出时跳过已 Get 的文件", DownloaderState.Options.SkipGet, function(v) DownloaderState.Options.SkipGet = v end)
MakeDlToggleRow(DlContent, dlToggleY + 34, "导出时跳过已有文件", DownloaderState.Options.SkipExisting, function(v) DownloaderState.Options.SkipExisting = v end)
MakeDlToggleRow(DlContent, dlToggleY + 68, "包含 Workspace 玩家模型内的脚本 / 远程", DownloaderState.Options.IncludeWorkspacePlayers, function(v) DownloaderState.Options.IncludeWorkspacePlayers = v end)
MakeDlToggleRow(DlContent, dlToggleY + 102, "扫描时隐藏已存在于工作区的文件", DownloaderState.Options.HideExisting, function(v) DownloaderState.Options.HideExisting = v end)
MakeDlToggleRow(DlContent, dlToggleY + 136, "仅保存字节码（不反编译）", DownloaderState.Options.SaveBytecode, function(v) DownloaderState.Options.SaveBytecode = v end)

MakeDlSectionTitle(DlContent, "下载目标", dlToggleY + 178)
MakeDlTargetRow(DlContent, dlToggleY + 202, "Scripts", "S", DlTheme.Accent, "所有脚本（Script / ModuleScript / LocalScript）")
MakeDlTargetRow(DlContent, dlToggleY + 242, "Remotes", "R", DlTheme.Accent, "所有远程（RemoteEvent / RemoteFunction / Bindable）")
MakeDlTargetRow(DlContent, dlToggleY + 282, "NilInstance", "N", DlTheme.TextSubtle, "NilInstance 脚本（无法反编译的实例）")

MakeDlSectionTitle(DlContent, "收集速度（秒）", dlToggleY + 326)
local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(0, 60, 0, 20)
SpeedLabel.Position = UDim2.new(1, -64, 0, dlToggleY + 326)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = string.format("%.2f", DownloaderState.Options.SpeedDelay)
SpeedLabel.TextColor3 = DlTheme.AccentBright
SpeedLabel.TextSize = 12
SpeedLabel.Font = Enum.Font.GothamBold
SpeedLabel.TextXAlignment = Enum.TextXAlignment.Right
SpeedLabel.Parent = DlContent

local DlTrack = Instance.new("Frame")
DlTrack.Size = UDim2.new(1, 0, 0, 6)
DlTrack.Position = UDim2.new(0, 0, 0, dlToggleY + 350)
DlTrack.BackgroundColor3 = DlTheme.BgRow
DlTrack.BorderSizePixel = 0
DlTrack.Parent = DlContent
Instance.new("UICorner", DlTrack).CornerRadius = UDim.new(1, 0)

local DlFill = Instance.new("Frame")
local initRel = (0.05 - 0.001) / (0.2 - 0.001)
DlFill.Size = UDim2.new(initRel, 0, 1, 0)
DlFill.BackgroundColor3 = DlTheme.AccentBright
DlFill.BorderSizePixel = 0
DlFill.Parent = DlTrack
Instance.new("UICorner", DlFill).CornerRadius = UDim.new(1, 0)

local dlDragging = false
local function UpdateSpeed(x)
    local rel = math.clamp((x - DlTrack.AbsolutePosition.X) / DlTrack.AbsoluteSize.X, 0, 1)
    local val = 0.001 + (0.2 - 0.001) * rel
    DlFill.Size = UDim2.new(rel, 0, 1, 0)
    SpeedLabel.Text = string.format("%.3f", val)
    DownloaderState.Options.SpeedDelay = val
end
DlTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dlDragging = true
        UpdateSpeed(input.Position.X)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dlDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        UpdateSpeed(input.Position.X)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dlDragging = false
    end
end)

-- ============ 下载器扫描逻辑 ============
local ScriptClasses = {
    ["Script"] = true, ["LocalScript"] = true, ["ModuleScript"] = true,
}
local RemoteClasses = {
    ["RemoteEvent"] = true, ["RemoteFunction"] = true,
    ["BindableEvent"] = true, ["BindableFunction"] = true,
    ["UnreliableRemoteEvent"] = true,
}

local function ShouldSkipDlInstance(inst)
    if not DownloaderState.Options.IncludeWorkspacePlayers then
        local cur = inst
        local guard = 0
        while cur and cur ~= game and guard < 30 do
            guard = guard + 1
            local ok, parent = pcall(function() return cur.Parent end)
            if not ok then break end
            if parent == workspace then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character == cur then return true end
                end
            end
            cur = parent
        end
    end
    return false
end

local function GetScriptHash(inst)
    if not XAC.Cap.getscripthash then return nil end
    local ok, h = pcall(getscripthash, inst)
    if ok and type(h) == "string" and #h > 0 then return h end
    return nil
end

local function TryDecompile(inst)
    if not XAC.Cap.decompile then return nil end
    local ok, src = pcall(decompile, inst)
    if ok and type(src) == "string" and #src > 0 then return src end
    return nil
end

local function TryBytecode(inst)
    if not XAC.Cap.getscriptbytecode then return nil end
    local ok, bc = pcall(getscriptbytecode, inst)
    if ok and bc then return bc end
    return nil
end

local function ProcessScript(inst)
    DownloaderState.Stats.ScriptsFound = DownloaderState.Stats.ScriptsFound + 1
    local path = GetInstancePath(inst)
    local fname = inst.ClassName .. "_" .. SafeName(inst.Name)
    local rel = path ~= "" and (path .. "/") or ""
    local hash = GetScriptHash(inst)
    if hash and DownloaderState.Options.SkipGet and DownloaderState.AlreadyGot[hash] then
        DownloaderState.Stats.Skipped = DownloaderState.Stats.Skipped + 1
        return
    end
    local saved = false
    if not DownloaderState.Options.SaveBytecode then
        local src = TryDecompile(inst)
        if src then
            local target = DownloaderState.Folders.Scripts .. "/" .. rel .. fname .. ".lua"
            if DownloaderState.Options.SkipExisting and XAC.Cap.isfile and isfile(target) then
                DownloaderState.Stats.Skipped = DownloaderState.Stats.Skipped + 1
                return
            end
            local ok = SafeWriteFile(target, "-- [[ " .. inst:GetFullName() .. " ]] --\n" .. src)
            if ok then
                DownloaderState.Stats.ScriptsSaved = DownloaderState.Stats.ScriptsSaved + 1
                saved = true
            else
                DownloaderState.Stats.Errors = DownloaderState.Stats.Errors + 1
            end
        end
    end
    if not saved then
        local bc = TryBytecode(inst)
        if bc then
            local target = DownloaderState.Folders.Bytecode .. "/" .. rel .. fname .. ".luac"
            if DownloaderState.Options.SkipExisting and XAC.Cap.isfile and isfile(target) then
                DownloaderState.Stats.Skipped = DownloaderState.Stats.Skipped + 1
                return
            end
            local ok = SafeWriteFile(target, bc)
            if ok then
                DownloaderState.Stats.ScriptsSaved = DownloaderState.Stats.ScriptsSaved + 1
                saved = true
            else
                DownloaderState.Stats.Errors = DownloaderState.Stats.Errors + 1
            end
        else
            DownloaderState.Stats.Errors = DownloaderState.Stats.Errors + 1
        end
    end
    if saved and hash then
        DownloaderState.AlreadyGot[hash] = true
        SaveDownloadHistory(hash)
    end
end

local function ProcessRemote(inst)
    DownloaderState.Stats.RemotesFound = DownloaderState.Stats.RemotesFound + 1
    local path = GetInstancePath(inst)
    local fname = inst.ClassName .. "_" .. SafeName(inst.Name)
    local rel = path ~= "" and (path .. "/") or ""
    local target = DownloaderState.Folders.Remotes .. "/" .. rel .. fname .. ".json"
    if DownloaderState.Options.SkipExisting and XAC.Cap.isfile and isfile(target) then
        DownloaderState.Stats.Skipped = DownloaderState.Stats.Skipped + 1
        return
    end
    local data = {
        Name = inst.Name, ClassName = inst.ClassName,
        FullName = inst:GetFullName(), Path = path,
    }
    local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
    if ok and json then
        local wrote = SafeWriteFile(target, json)
        if wrote then
            DownloaderState.Stats.RemotesSaved = DownloaderState.Stats.RemotesSaved + 1
        else
            DownloaderState.Stats.Errors = DownloaderState.Stats.Errors + 1
        end
    else
        DownloaderState.Stats.Errors = DownloaderState.Stats.Errors + 1
    end
end

local function UpdateDlUI()
    local s = DownloaderState.Stats
    StatusText.Text = string.format("状态：%s · 已保存 %d / %d",
        s.Current, s.ScriptsSaved + s.RemotesSaved, s.Total)
    StatusSub.Text = string.format("脚本：%d / %d · 远程：%d / %d · 跳过：%d · 错误：%d",
        s.ScriptsSaved, s.ScriptsFound, s.RemotesSaved, s.RemotesFound, s.Skipped, s.Errors)
    local rel = (s.Total > 0) and (s.Done / s.Total) or 0
    ProgressFill.Size = UDim2.new(math.clamp(rel, 0, 1), 0, 1, 0)
end

local function RunDlScan()
    if DownloaderState.Running then return end
    DownloaderState.Running = true
    DownloaderState.CancelRequested = false
    DownloaderState.Stats = {
        ScriptsFound = 0, ScriptsSaved = 0, RemotesFound = 0, RemotesSaved = 0,
        Errors = 0, Skipped = 0, Total = 0, Done = 0, Current = "扫描中",
    }
    MainBtn.Text = "扫描中...（点击取消）"
    MainBtn.BackgroundColor3 = DlTheme.Red
    MainBtnStroke.Color = DlTheme.Red
    UpdateDlUI()

    task.spawn(function()
        EnsureDownloadFolders()
        local targets = {}
        DownloaderState.Stats.Current = "枚举实例"
        UpdateDlUI()
        local ok, descendants = pcall(function() return game:GetDescendants() end)
        if ok and descendants then
            for _, obj in ipairs(descendants) do
                if DownloaderState.CancelRequested or not DownloaderState.Alive then break end
                local cn = obj.ClassName
                if DownloaderState.Targets.Scripts and ScriptClasses[cn] then
                    if not ShouldSkipDlInstance(obj) then
                        table.insert(targets, {obj = obj, kind = "script"})
                    end
                elseif DownloaderState.Targets.Remotes and RemoteClasses[cn] then
                    if not ShouldSkipDlInstance(obj) then
                        table.insert(targets, {obj = obj, kind = "remote"})
                    end
                end
            end
        end
        DownloaderState.Stats.Total = #targets
        DownloaderState.Stats.Done = 0
        DownloaderState.Stats.Current = "导出中"
        UpdateDlUI()
        for i, t in ipairs(targets) do
            if DownloaderState.CancelRequested or not DownloaderState.Alive then break end
            local obj = t.obj
            pcall(function()
                if t.kind == "script" then ProcessScript(obj) else ProcessRemote(obj) end
            end)
            DownloaderState.Stats.Done = i
            if i % 5 == 0 then UpdateDlUI() end
            task.wait(DownloaderState.Options.SpeedDelay)
        end
        DownloaderState.Stats.Current = DownloaderState.CancelRequested and "已取消" or "完成"
        DownloaderState.Running = false
        MainBtn.Text = "初始化扫描"
        MainBtn.BackgroundColor3 = DlTheme.Accent
        MainBtnStroke.Color = DlTheme.AccentBright
        UpdateDlUI()
    end)
end

MainBtn.MouseButton1Click:Connect(function()
    if DownloaderState.Running then
        DownloaderState.CancelRequested = true
        MainBtn.Text = "取消中..."
    else
        RunDlScan()
    end
end)

-- ============ 页面构建 ============
local function CreatePage(name)
    local Page = Instance.new("ScrollingFrame")
    Page.Name = name
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.BorderSizePixel = 0
    Page.ScrollBarThickness = 4
    Page.ScrollBarImageColor3 = Color3.fromRGB(180, 180, 180)
    Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.Visible = false
    Page.ZIndex = 5
    Page.Parent = ScrollFrame
    local Layout = Instance.new("UIListLayout", Page)
    Layout.Padding = UDim.new(0, 12)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Pages[name] = Page
    return Page
end

local P_aim = CreatePage("人物自瞄")
CreateSection(P_aim, "触摸瞄准")
CreateToggleRow(P_aim, "自瞄启用", "自瞄启用")
CreateToggleRow(P_aim, "忽略人机", "忽略人机")
CreateToggleRow(P_aim, "忽略倒地", "忽略倒地")
CreateSection(P_aim, "触摸位置")
CreateSliderRow(P_aim, "触摸框X", "触摸框 X", 0, 2000)
CreateSliderRow(P_aim, "触摸框Y", "触摸框 Y", 0, 2000)
CreateSliderRow(P_aim, "触摸框大小", "触摸框大小", 10, 500)
CreateSection(P_aim, "连点器")
CreateToggleRow(P_aim, "连点启用", "连点启用")
CreateToggleRow(P_aim, "极速模式", "极速模式")
CreateSliderRow(P_aim, "连点速度", "连点速度(毫秒)", 1, 500)
CreateSliderRow(P_aim, "连点框大小", "连点框大小", 10, 500)
CreateSliderRow(P_aim, "连点框X", "连点框 X", 0, 2000)
CreateSliderRow(P_aim, "连点框Y", "连点框 Y", 0, 2000)

local P_draw = CreatePage("人物绘制")
CreateSection(P_draw, "透视功能")
CreateToggleRow(P_draw, "ESP透视", "ESP透视", function(v) Fire("ESP透视", v) end)
CreateToggleRow(P_draw, "团队高亮", "团队高亮", function(v) Fire("团队高亮", v) end)
CreateToggleRow(P_draw, "敌对高亮", "敌对高亮", function(v) Fire("敌对高亮", v) end)
CreateToggleRow(P_draw, "全图点亮", "全图点亮", function(v) Fire("全图点亮", v) end)

local P_range = CreatePage("瞄准范围")
CreateSection(P_range, "范围调节")
CreateSliderRow(P_range, "视野", "视野(FOV)", 30, 120, function(v)
    local cam = workspace.CurrentCamera
    if cam then cam.FieldOfView = v end
end)
CreateSliderRow(P_range, "移动速度", "移动速度", 1, 500, function(v)
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed = v end
end)
CreateSliderRow(P_range, "跳跃高度", "跳跃高度", 1, 500, function(v)
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Humanoid") then c.Humanoid.JumpHeight = v end
end)
CreateSliderRow(P_range, "重力", "重力", 1, 500, function(v) workspace.Gravity = v end)

local P_move = CreatePage("移动功能")
CreateSection(P_move, "移动")
CreateToggleRow(P_move, "无限跳跃", "无限跳跃", function(v) Fire("无限跳跃", v) end)
CreateToggleRow(P_move, "穿墙", "穿墙", function(v) Fire("穿墙", v) end)
CreateToggleRow(P_move, "千倍速度", "千倍速度", function(v) Fire("千倍速度", v) end)
CreateToggleRow(P_move, "踏空", "踏空", function(v) Fire("踏空", v) end)
CreateToggleRow(P_move, "点击传送", "点击传送", function(v) Fire("点击传送", v) end)
CreateToggleRow(P_move, "加速", "加速", function(v) Fire("加速", v) end)

local P_fight = CreatePage("战斗功能")
CreateSection(P_fight, "战斗")
CreateToggleRow(P_fight, "自动攻击", "自动攻击", function(v) Fire("自动攻击", v) end)
CreateToggleRow(P_fight, "无敌", "无敌", function(v) Fire("无敌", v) end)
CreateToggleRow(P_fight, "防挂机", "防挂机", function(v) Fire("防挂机", v) end)
CreateToggleRow(P_fight, "自动连点", "自动连点", function(v) Fire("自动连点", v) end)

local P_vis = CreatePage("视觉功能")
CreateSection(P_vis, "视觉")
CreateToggleRow(P_vis, "夜视", "夜视", function(v) Fire("夜视", v) end)
CreateToggleRow(P_vis, "去雾", "去雾", function(v) Fire("去雾", v) end)
CreateToggleRow(P_vis, "隐身", "隐身", function(v) Fire("隐身", v) end)
CreateToggleRow(P_vis, "全屏特效", "全屏特效", function(v) Fire("全屏特效", v) end)
CreateToggleRow(P_vis, "显示FPS", "显示FPS")

local P_fun = CreatePage("娱乐功能")
CreateSection(P_fun, "娱乐")
CreateToggleRow(P_fun, "跳舞", "跳舞", function(v) Fire("跳舞", v) end)
CreateToggleRow(P_fun, "喷火", "喷火", function(v) Fire("喷火", v) end)
CreateToggleRow(P_fun, "光环", "光环", function(v) Fire("光环", v) end)
CreateToggleRow(P_fun, "倒立", "倒立", function(v) Fire("倒立", v) end)
CreateToggleRow(P_fun, "大头", "大头", function(v) Fire("大头", v) end)
CreateToggleRow(P_fun, "巨大化", "巨大化", function(v) Fire("巨大化", v) end)
CreateToggleRow(P_fun, "彩虹拖尾", "彩虹拖尾", function(v) Fire("彩虹拖尾", v) end)
CreateToggleRow(P_fun, "火焰拖尾", "火焰拖尾", function(v) Fire("火焰拖尾", v) end)
CreateToggleRow(P_fun, "冰霜拖尾", "冰霜拖尾", function(v) Fire("冰霜拖尾", v) end)
CreateToggleRow(P_fun, "彩虹名字", "彩虹名字", function(v) Fire("彩虹名字", v) end)
CreateToggleRow(P_fun, "客户端字幕", "客户端字幕", function(v) Fire("客户端字幕", v) end)

local P_anti = CreatePage("反检测")
CreateSection(P_anti, "XAC 状态")
local statusRefs = {}
local function AddStatus(label, getter)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 24)
    Row.BackgroundTransparency = 1
    Row.Parent = P_anti
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(0.5, 0, 1, 0)
    L.BackgroundTransparency = 1
    L.Text = label
    L.TextColor3 = Theme.TextMain
    L.TextSize = 12
    L.Font = Enum.Font.Gotham
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Parent = Row
    local V = Instance.new("TextLabel")
    V.Size = UDim2.new(0.5, 0, 1, 0)
    V.Position = UDim2.new(0.5, 0, 0, 0)
    V.BackgroundTransparency = 1
    V.Text = tostring(getter())
    V.TextColor3 = Theme.Accent
    V.TextSize = 12
    V.Font = Enum.Font.GothamBold
    V.TextXAlignment = Enum.TextXAlignment.Right
    V.Parent = Row
    table.insert(statusRefs, {val = V, getter = getter})
end
AddStatus("内核状态", function() return XAC.Alive and "运行中" or "已停止" end)
AddStatus("远程节流", function() return XAC.Config and XAC.Config.ThrottleRemotes and "已启用" or "已禁用" end)
AddStatus("反作弊清理", function() return XAC.Config and XAC.Config.KillAntiCheat and "已启用" or "已禁用" end)
AddStatus("踢出拦截", function() return XAC.Config and XAC.Config.BlockKick and "已启用" or "已禁用" end)
AddStatus("属性伪装", function() return XAC.Config and XAC.Config.SpoofProperties and "已启用" or "已禁用" end)
AddStatus("时间伪装", function() return XAC.Config and XAC.Config.SpoofTime and "已启用" or "已禁用" end)
AddStatus("执行器名称", function() return _real.identifyexecutor and _real.identifyexecutor() or "N/A" end)
AddStatus("Namecall Hook", function() return XAC.Hooks.__namecall and "已挂载" or "未挂载" end)
AddStatus("时间偏移", function() return string.format("%.2f", XAC.TimeOffset) end)
CreateSection(P_anti, "手动操作")
CreateButtonRow(P_anti, "🔄  立即清理反作弊脚本", function() pcall(XAC.KillAntiCheat) end)
CreateButtonRow(P_anti, "🧹  清理全局特征", function()
    pcall(function()
        local g = _real.getgenv and _real.getgenv() or _G
        for k in pairs(g) do
            if type(k) == "string" and (k:find("XAC") or k:find("Xixi")) and k ~= "XixiConfig" then
                g[k] = nil
            end
        end
    end)
end)
CreateButtonRow(P_anti, "⏱  重置时间偏移", function() XAC.ResetTime() end)

-- ============ 导航 ============
local NavList = {
    {"人物绘制", "人物绘制"},
    {"人物自瞄", "人物自瞄"},
    {"瞄准范围", "瞄准范围"},
    {"移动功能", "移动功能"},
    {"战斗功能", "战斗功能"},
    {"视觉功能", "视觉功能"},
    {"娱乐功能", "娱乐功能"},
    {"反检测", "反检测"},
}

for i, data in ipairs(NavList) do
    CreateNavButton(data[1], data[2], i)
end

-- 下载器独立按钮
local dlBtn = Instance.new("TextButton")
dlBtn.Size = UDim2.new(1, -16, 0, 40)
dlBtn.Position = UDim2.new(0, 8, 1, -52)
dlBtn.BackgroundColor3 = Theme.Accent
dlBtn.BackgroundTransparency = 0
dlBtn.BorderSizePixel = 0
dlBtn.Text = "📥  下载器"
dlBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dlBtn.TextSize = 13
dlBtn.Font = Enum.Font.GothamBold
dlBtn.ZIndex = 6
dlBtn.Parent = Sidebar
Instance.new("UICorner", dlBtn).CornerRadius = UDim.new(0, 10)
dlBtn.MouseButton1Click:Connect(function()
    DlMain.Visible = not DlMain.Visible
end)

SwitchPage("人物自瞄")

-- ============ 状态刷新 ============
task.spawn(function()
    while XAC.Alive and MainFrame.Parent do
        for _, ref in ipairs(statusRefs) do
            pcall(function() ref.val.Text = tostring(ref.getter()) end)
        end
        task.wait(0.5)
    end
end)

-- ============ FPS 刷新 ============
local frameCount = 0
local lastFpsTime = tick()
local currentFps = 0
TrackConn(RunService.RenderStepped:Connect(function()
    if not Config["显示FPS"] then
        FPSLabel.Visible = false
        return
    end
    FPSLabel.Visible = true
    frameCount = frameCount + 1
    local now = tick()
    if now - lastFpsTime >= 0.5 then
        currentFps = math.floor(frameCount / (now - lastFpsTime))
        frameCount = 0
        lastFpsTime = now
        local players = 0
        local bots = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if p.Name:lower():find("bot") then bots = bots + 1 else players = players + 1 end
            end
        end
        FPSLabel.Text = "真人 " .. players .. " / 人机 " .. bots .. "   " .. currentFps .. " FPS"
    end
end))

-- ============ 自瞄循环 ============
task.spawn(function()
    while XAC.Alive do
        task.wait(1/120)
        if Config["自瞄启用"] then
            local c = LocalPlayer.Character
            if c and c:FindFirstChild("HumanoidRootPart") then
                local myRoot = c.HumanoidRootPart
                local myTeam = LocalPlayer.Team
                local nearest, minDist = nil, math.huge
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChild("Humanoid")
                        if hrp and hum then
                            local skip = false
                            if Config["忽略倒地"] and hum.Health <= 0 then skip = true end
                            if not skip and (not myTeam or p.Team ~= myTeam) then
                                local d = (hrp.Position - myRoot.Position).Magnitude
                                if d < minDist then minDist = d nearest = hrp end
                            end
                        end
                    end
                end
                if nearest then
                    local cam = workspace.CurrentCamera
                    if cam then cam.CFrame = CFrame.new(cam.CFrame.Position, nearest.Position) end
                end
            end
        end
        if Config["连点启用"] then
            local vu = game:GetService("VirtualUser")
            local cam = workspace.CurrentCamera
            if cam then
                local s = cam.ViewportSize
                vu:Button1Down(Vector2.new(s.X/2, s.Y/2))
                vu:Button1Up(Vector2.new(s.X/2, s.Y/2))
            end
        end
    end
end)

print("========================================")
print("[海洋之星 XAC V5.0 + 下载器] 加载完成")
print("[+] 反作弊内核：已挂载")
print("[+] 下载器：点击侧边栏底部按钮打开")
print("========================================")

return XAC