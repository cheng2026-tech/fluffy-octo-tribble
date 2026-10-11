-- ============================================================
-- 兮兮 · 本地 UI 融合版 V8.0
-- 本地海洋之心 UI + Verdict 过检测 + XAC 反作弊 + 全远程加载
-- ============================================================

local _genv = (type(getgenv) == "function" and getgenv()) or _G

-- ============================================================
-- 第一部分：Verdict 过检测内核
-- ============================================================
local Verdict = {}
if _genv.__Verdict and _genv.__Verdict.Alive then pcall(_genv.__Verdict.Destroy) end
_genv.__Verdict = Verdict

Verdict.Alive = true
Verdict.Hooks = {}
Verdict.Conns = {}
Verdict.TimeOffset = 0

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
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local _real = {
    getgenv = getgenv, getrawmetatable = getrawmetatable, setreadonly = setreadonly,
    hookfunction = hookfunction, hookmetamethod = hookmetamethod,
    newcclosure = newcclosure or function(f) return f end,
    identifyexecutor = identifyexecutor, getconnections = getconnections,
    setscriptable = setscriptable, gethui = gethui,
    protect_gui = syn and syn.protect_gui,
    tick = tick, clock = os.clock,
    decompile = decompile, getscriptbytecode = getscriptbytecode,
    getscripthash = getscripthash, writefile = writefile,
    readfile = readfile, isfile = isfile,
    makefolder = makefolder, isfolder = isfolder,
}

local function NC(f) return _real.newcclosure(f) end
local function TC(c) if c and type(c.Disconnect) == "function" then table.insert(Verdict.Conns, c) end return c end
local Sandbox = _real.getgenv and _real.getgenv() or _G

-- 时间伪造
Verdict.Time = {Offset = 0, LastReal = _real.tick(), LastFake = _real.tick()}
local function InstallTimeForge()
    local oldTick = tick
    _G.tick = NC(function()
        local real = oldTick()
        local d = real - Verdict.Time.LastReal
        Verdict.Time.LastReal = real
        Verdict.Time.LastFake = Verdict.Time.LastFake + math.min(d, 0.05) + Verdict.Time.Offset
        Verdict.Time.Offset = 0
        return Verdict.Time.LastFake
    end)
    local oldClock = os.clock
    os.clock = NC(function() return oldClock() + (Verdict.Time.LastFake - Verdict.Time.LastReal) end)
    Verdict.Hooks.TimeForge = true
end
function Verdict.BumpTime(d) Verdict.Time.Offset = Verdict.Time.Offset + (d or 0); Verdict.TimeOffset = Verdict.TimeOffset + (d or 0) end
function Verdict.ResetTime() Verdict.Time.Offset = 0; Verdict.TimeOffset = 0 end

-- 属性影子
Verdict.Shadow = {WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, Gravity = 196.2, Hooked = setmetatable({}, {__mode = "k"})}
local function InstallHumanoidShadow(hum)
    if not hum or Verdict.Shadow.Hooked[hum] then return end
    Verdict.Shadow.Hooked[hum] = true
    pcall(function()
        local mt = _real.getrawmetatable(hum)
        if mt and mt.__index then
            local oi = mt.__index
            if _real.setreadonly then pcall(_real.setreadonly, mt, false) end
            mt.__index = NC(function(self, k)
                if self == hum then
                    if k == "WalkSpeed" then return Verdict.Shadow.WalkSpeed end
                    if k == "JumpPower" then return Verdict.Shadow.JumpPower end
                    if k == "JumpHeight" then return Verdict.Shadow.JumpHeight end
                end
                return oi(self, k)
            end)
        end
    end)
end
local function InstallWorkspaceShadow()
    pcall(function()
        local mt = _real.getrawmetatable(workspace)
        if mt and mt.__index then
            local oi = mt.__index
            if _real.setreadonly then pcall(_real.setreadonly, mt, false) end
            mt.__index = NC(function(self, k)
                if k == "Gravity" then return Verdict.Shadow.Gravity end
                return oi(self, k)
            end)
        end
    end)
end

-- Remote 清洗
Verdict.RemoteLog = {}
local function SanitizeArgs(remote, args)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local out, mod = {}, false
    for i, v in ipairs(args) do
        if type(v) == "Vector3" and hrp then
            local d = (v - hrp.Position).Magnitude
            if d > 500 then
                out[i] = hrp.Position + (v - hrp.Position).Unit * 50
                mod = true
                goto c
            end
        end
        if type(v) == "number" and (v ~= v or v == math.huge or v == -math.huge or math.abs(v) > 1e12) then
            out[i] = 0
            mod = true
            goto c
        end
        out[i] = v
        ::c::
    end
    if mod then
        table.insert(Verdict.RemoteLog, {time = _real.tick(), remote = remote:GetFullName()})
        if #Verdict.RemoteLog > 100 then table.remove(Verdict.RemoteLog, 1) end
    end
    return out, mod
end

-- 节奏器
Verdict.Pacer = {Last = {}, Min = {}, Default = 0.05}
function Verdict.Pacer.Check(k, m)
    local now = _real.tick()
    local last = Verdict.Pacer.Last[k] or 0
    local min = m or Verdict.Pacer.Min[k] or Verdict.Pacer.Default
    if now - last < min then return false end
    Verdict.Pacer.Last[k] = now
    return true
end

-- 位置流
Verdict.Flow = {Queue = {}, MaxStep = 8, Running = false}
function Verdict.Teleport(target)
    if typeof(target) == "Vector3" then target = CFrame.new(target) end
    if not target or typeof(target) ~= "CFrame" then return end
    table.insert(Verdict.Flow.Queue, target)
    if not Verdict.Flow.Running then
        Verdict.Flow.Running = true
        task.spawn(function()
            while #Verdict.Flow.Queue > 0 do
                local tgt = table.remove(Verdict.Flow.Queue, 1)
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local scf = hrp.CFrame
                    for i = 1, 20 do
                        if not hrp.Parent then break end
                        local t = i / 20
                        local e = t * t * (3 - 2 * t)
                        local d = scf:Lerp(tgt, e)
                        local step = (d.Position - hrp.Position).Magnitude
                        if step > Verdict.Flow.MaxStep then
                            hrp.CFrame = CFrame.new(hrp.Position + (d.Position - hrp.Position).Unit * Verdict.Flow.MaxStep) * d.Rotation
                        else
                            hrp.CFrame = d
                        end
                        task.wait(0.016)
                    end
                end
            end
            Verdict.Flow.Running = false
        end)
    end
end

-- 反作弊扫描
Verdict.ACFound = {}
local function ScanAC()
    for _, root in ipairs({ReplicatedStorage, ReplicatedFirst, LocalPlayer:FindFirstChild("PlayerScripts")}) do
        if root then
            for _, obj in ipairs(root:GetDescendants()) do
                local n = obj.Name:lower()
                if (obj:IsA("ModuleScript") or obj:IsA("LocalScript")) and
                   (n:find("anti") or n:find("guard") or n:find("detect") or n:find("security")) then
                    Verdict.ACFound[obj] = true
                end
            end
        end
    end
end

-- 环境伪装
local function NeutralizeEnvironment()
    for _, name in ipairs({"identifyexecutor","getexecutorname","getexploitname","is_sirhurt_closure","is_synapse_closure","isfunctionhash","checkcaller","getreg","getgc"}) do
        if Sandbox[name] then
            Sandbox[name] = NC(function()
                if name == "identifyexecutor" then return "Roblox", "" end
                if name == "checkcaller" then return true end
                if name == "isfunctionhash" then return false end
                return {}
            end)
        end
    end
end

-- 游戏指纹
Verdict.Profile = "default"
local PlaceProfile = {
    [2753915549] = "blox-fruits", [4442272183] = "blox-fruits-2",
    [6516141723] = "doors", [6839171747] = "doors-2",
    [8737899170] = "pet-sim", [1685866996] = "bee-swarm",
    [920587237] = "adopt-me", [142823291] = "mm2",
    [6872265039] = "bedwars", [6872274481] = "bedwars-2",
}
Verdict.Profile = PlaceProfile[game.PlaceId] or "default"

-- ============================================================
-- 第二部分：XAC 反反作弊
-- ============================================================
local XAC = {}
if _genv.__XAC and _genv.__XAC.Alive then pcall(_genv.__XAC.Destroy) end
_genv.__XAC = XAC
XAC.Alive = true
XAC.Hooks = {}
XAC.Conns = {}
XAC.Instances = {}

local function XTC(c) if c then table.insert(XAC.Conns, c) end return c end
local function XTI(i) if i then table.insert(XAC.Instances, i) end return i end

local ACKeys = {"anticheat","anti_cheat","ac_","guard","shield","sentinel","watchdog","detector","verifier","validator","byfron","hyperion","reportservice","logservice"}
local function IsACName(n)
    local low = n:lower()
    for _, kw in ipairs(ACKeys) do if low:find(kw, 1, true) then return true end end
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
    local stack, guard = {root}, 0
    while #stack > 0 and guard < 20000 do
        guard = guard + 1
        local node = table.remove(stack)
        if node then
            local ok, ch = pcall(function() return node:GetChildren() end)
            if ok then for _, c in ipairs(ch) do
                table.insert(stack, c)
                if IsACName(c.Name) then KillNode(c) end
            end end
        end
    end
end
function XAC.KillAC()
    pcall(SweepRoot, ReplicatedFirst)
    pcall(SweepRoot, ReplicatedStorage)
    pcall(SweepRoot, StarterPlayer)
    pcall(SweepRoot, LocalPlayer:FindFirstChild("PlayerScripts"))
    pcall(SweepRoot, LocalPlayer:FindFirstChild("PlayerGui"))
end

XAC.Cap = {
    hookmetamethod = type(_real.hookmetamethod) == "function",
    getrawmetatable = type(_real.getrawmetatable) == "function",
    setreadonly = type(_real.setreadonly) == "function",
    protect_gui = type(_real.protect_gui) == "function",
    gethui = type(_real.gethui) == "function",
    decompile = type(_real.decompile) == "function",
    getscriptbytecode = type(_real.getscriptbytecode) == "function",
    getscripthash = type(_real.getscripthash) == "function",
    writefile = type(_real.writefile) == "function",
    isfile = type(_real.isfile) == "function",
    makefolder = type(_real.makefolder) == "function",
    isfolder = type(_real.isfolder) == "function",
}

function XAC.NewProtectedGui(name)
    local gui = Instance.new("ScreenGui")
    gui.Name = name or "RobloxChatWindow"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if XAC.Cap.protect_gui then pcall(_real.protect_gui, gui) end
    if XAC.Cap.gethui then
        local ok, h = pcall(_real.gethui)
        gui.Parent = (ok and h) or CoreGui
    else
        gui.Parent = CoreGui
    end
    XTI(gui)
    return gui
end

-- 统一 namecall
local ReportKeys = {"flag","cheat","detect","report","kick","ban","exploit","hack","violation","anticheat","guard"}
local function ContainsReport(v, d)
    d = d or 0
    if d > 3 then return false end
    local t = type(v)
    if t == "string" then
        local low = v:lower()
        for _, kw in ipairs(ReportKeys) do if low:find(kw, 1, true) then return true end end
        return false
    elseif t == "table" then
        for k, vv in pairs(v) do
            if type(k) == "string" and ContainsReport(k, d + 1) then return true end
            if ContainsReport(vv, d + 1) then return true end
        end
    end
    return false
end

local function InstallNamecall()
    local handler = NC(function(self, ...)
        local method = getnamecallmethod and getnamecallmethod() or nil
        if method == "Kick" and self == LocalPlayer then return end
        if method == "Destroy" and (self == LocalPlayer or self == LocalPlayer.Character) then return end
        if method == "GetService" then
            local svc = (...)
            if type(svc) == "string" then
                local low = svc:lower()
                if low:find("anticheat") or low:find("ban") or low:find("report") then return nil end
            end
        end
        if method == "FireServer" or method == "InvokeServer" then
            local args = {...}
            for _, a in ipairs(args) do
                if ContainsReport(a) then return nil end
            end
            local sanitized, mod = SanitizeArgs(self, args)
            if not Verdict.Pacer.Check("remote") then return nil end
            if mod then
                if method == "FireServer" then return self:FireServer(table.unpack(sanitized))
                else return self:InvokeServer(table.unpack(sanitized)) end
            end
        end
        return nil
    end)
    if XAC.Cap.hookmetamethod then
        local old = _real.hookmetamethod(game, "__namecall", handler)
        XAC.Hooks.__namecall = true
        XAC._oldNamecall = old
    elseif XAC.Cap.getrawmetatable then
        local mt = _real.getrawmetatable(game)
        if mt and mt.__namecall then
            if _real.setreadonly then pcall(_real.setreadonly, mt, false) end
            XAC._oldNamecall = mt.__namecall
            mt.__namecall = handler
            XAC.Hooks.__namecall = true
        end
    end
end

local function InstallKickBlock()
    pcall(function()
        local mt = _real.getrawmetatable(LocalPlayer)
        if mt and mt.__index then
            local oi = mt.__index
            if _real.setreadonly then pcall(_real.setreadonly, mt, false) end
            mt.__index = NC(function(self, k)
                if k == "Kick" then return NC(function() end) end
                return oi(self, k)
            end)
        end
    end)
end

local function InstallDebugSpoof()
    if not debug then return end
    pcall(function()
        local og = debug.getinfo
        debug.getinfo = NC(function(...)
            local info = og(...)
            if type(info) == "table" then
                info.source = "=[C]"; info.short_src = "[C]"; info.what = "C"; info.currentline = -1
            end
            return info
        end)
    end)
end

local function InstallErrorSink()
    local oe, ow = error, warn
    _G.error = NC(function(m, l)
        if type(m) == "string" and ContainsReport(m) then return nil end
        return oe(m, l)
    end)
    _G.warn = NC(function(...)
        for _, a in ipairs({...}) do if ContainsReport(tostring(a)) then return end end
        return ow(...)
    end)
end

-- ============================================================
-- 第三部分：启动
-- ============================================================
InstallTimeForge()
InstallWorkspaceShadow()
InstallNamecall()
InstallKickBlock()
InstallDebugSpoof()
InstallErrorSink()
NeutralizeEnvironment()
ScanAC()
XAC.KillAC()

if LocalPlayer.Character then
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then InstallHumanoidShadow(hum) end
end
XTC(LocalPlayer.CharacterAdded:Connect(function(c)
    task.wait(0.1)
    local hum = c:FindFirstChildOfClass("Humanoid")
    if hum then InstallHumanoidShadow(hum) end
end))

task.spawn(function()
    while Verdict.Alive do
        task.wait(2)
        pcall(ScanAC)
        pcall(XAC.KillAC)
    end
end)

-- ============================================================
-- 第四部分：远程脚本加载器
-- ============================================================
local Loader = {}
Loader.Cache = {}

function Loader.Load(url, name)
    if type(url) ~= "string" or url == "" then return false, "URL 为空" end
    task.spawn(function()
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if not ok or type(src) ~= "string" or #src == 0 then
            warn("[兮兮] 远程拉取失败: " .. tostring(name) .. " | " .. tostring(src))
            return
        end
        local ldr = loadstring or load
        if type(ldr) ~= "function" then return end
        local okc, fn = pcall(ldr, src)
        if not okc or type(fn) ~= "function" then
            warn("[兮兮] 编译失败: " .. tostring(name))
            return
        end
        local oke, err = xpcall(fn, function(e) return debug and debug.traceback and debug.traceback(tostring(e)) or tostring(e) end)
        if not oke then warn("[兮兮] 执行失败: " .. tostring(name) .. " | " .. tostring(err)) end
    end)
    return true
end

-- ============================================================
-- 第五部分：本地 UI（海洋之心风格）
-- ============================================================
local Config = {
    ["自瞄启用"] = true, ["忽略人机"] = true, ["忽略倒地"] = true,
    ["触摸框X"] = 1460, ["触摸框Y"] = 1020, ["触摸框大小"] = 80,
    ["连点启用"] = false, ["连点速度"] = 50, ["连点框X"] = 1450, ["连点框Y"] = 1010,
    ["便捷开关"] = true, ["显示触摸框"] = false,
    ["显示FPS"] = true,
    ["移动速度"] = 16, ["跳跃高度"] = 50, ["重力"] = 196, ["视野"] = 70,
}
_genv.XixiConfig = Config

if CoreGui:FindFirstChild("Xixi_Final") then CoreGui.Xixi_Final:Destroy() end

local ScreenGui = XAC.NewProtectedGui("Xixi_Final")

local GlassStyle = {Rounding = 24, TintColor = Color3.fromRGB(245, 248, 252), Alpha = 0.85, GlowAlpha = 0.15, NoiseAlpha = 0.02}
local LiquidGlass = {}
function LiquidGlass.Apply(frame, isMain)
    if not frame then return end
    local glow = Instance.new("Frame")
    glow.Size = UDim2.new(1, 30, 1, 30); glow.Position = UDim2.new(0, -15, 0, -15)
    glow.BackgroundColor3 = Color3.fromRGB(180, 210, 240)
    glow.BackgroundTransparency = 1 - GlassStyle.GlowAlpha
    glow.BorderSizePixel = 0; glow.ZIndex = 0; glow.Parent = frame
    Instance.new("UICorner", glow).CornerRadius = UDim.new(0, GlassStyle.Rounding + 15)

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = GlassStyle.TintColor
    bg.BackgroundTransparency = 1 - GlassStyle.Alpha
    bg.BorderSizePixel = 0; bg.ZIndex = 1; bg.Parent = frame
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, GlassStyle.Rounding)

    local grad = Instance.new("UIGradient", bg)
    grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(225, 235, 245))
    grad.Rotation = 90
    grad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.3)})

    local noise = Instance.new("ImageLabel")
    noise.Size = UDim2.new(1, 0, 1, 0); noise.BackgroundTransparency = 1
    noise.Image = "rbxassetid://10183605738"
    noise.ImageTransparency = 1 - GlassStyle.NoiseAlpha
    noise.ImageColor3 = Color3.fromRGB(0, 0, 0)
    noise.ScaleType = Enum.ScaleType.Tile
    noise.TileSize = UDim2.new(0, 64, 0, 64)
    noise.ZIndex = 5; noise.Parent = frame
    Instance.new("UICorner", noise).CornerRadius = UDim.new(0, GlassStyle.Rounding)

    local border = Instance.new("Frame")
    border.Size = UDim2.new(1, -2, 1, -2); border.Position = UDim2.new(0, 1, 0, 1)
    border.BackgroundTransparency = 1; border.ZIndex = 6; border.Parent = frame
    Instance.new("UICorner", border).CornerRadius = UDim.new(0, GlassStyle.Rounding)

    local stroke = Instance.new("UIStroke", border)
    stroke.Thickness = 2; stroke.Color = Color3.fromRGB(150, 180, 210)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    if isMain then _genv.MainRainbowStroke = stroke end
end

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0.7, 0, 0.8, 0)
Main.Position = UDim2.new(0.5, 0, 0.5, 0)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundTransparency = 1
Main.Active = true; Main.Draggable = true; Main.ZIndex = 2
Main.Parent = ScreenGui
local MC = Instance.new("UISizeConstraint", Main)
MC.MinSize = Vector2.new(500, 380); MC.MaxSize = Vector2.new(800, 550)
LiquidGlass.Apply(Main, true)

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 150, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(235, 238, 242)
Sidebar.BackgroundTransparency = 0.3
Sidebar.BorderSizePixel = 0; Sidebar.ZIndex = 3; Sidebar.Parent = Main
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 24)

local TitleFrame = Instance.new("Frame")
TitleFrame.Size = UDim2.new(1, 0, 0, 65)
TitleFrame.BackgroundTransparency = 1; TitleFrame.ZIndex = 4; TitleFrame.Parent = Sidebar

local Avatar = Instance.new("ImageLabel")
Avatar.Size = UDim2.new(0, 36, 0, 36); Avatar.Position = UDim2.new(0, 12, 0, 14)
Avatar.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
Avatar.Image = "rbxassetid://0"; Avatar.ZIndex = 5; Avatar.Parent = TitleFrame
Instance.new("UICorner", Avatar).CornerRadius = UDim.new(0, 18)

local NameLabel = Instance.new("TextLabel")
NameLabel.Size = UDim2.new(1, -60, 0, 20); NameLabel.Position = UDim2.new(0, 56, 0, 10)
NameLabel.BackgroundTransparency = 1; NameLabel.Text = "兮兮"
NameLabel.TextColor3 = Color3.fromRGB(40, 40, 40); NameLabel.TextSize = 14
NameLabel.Font = Enum.Font.GothamBold; NameLabel.TextXAlignment = Enum.TextXAlignment.Left
NameLabel.ZIndex = 5; NameLabel.Parent = TitleFrame

local VersionLabel = Instance.new("TextLabel")
VersionLabel.Size = UDim2.new(1, -60, 0, 16); VersionLabel.Position = UDim2.new(0, 56, 0, 30)
VersionLabel.BackgroundTransparency = 1; VersionLabel.Text = "内核·8.0 全远程"
VersionLabel.TextColor3 = Color3.fromRGB(120, 120, 120); VersionLabel.TextSize = 11
VersionLabel.Font = Enum.Font.Gotham; VersionLabel.TextXAlignment = Enum.TextXAlignment.Left
VersionLabel.ZIndex = 5; VersionLabel.Parent = TitleFrame

local Pages, NavButtons = {}, {}
local currentTab = "公告"

local function SwitchPage(tabName)
    currentTab = tabName
    for name, page in pairs(Pages) do page.Visible = (name == tabName) end
    for name, btn in pairs(NavButtons) do
        local active = (name == tabName)
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(235, 238, 242),
            BackgroundTransparency = active and 0 or 0.6,
            TextColor3 = active and Color3.fromRGB(0, 122, 255) or Color3.fromRGB(80, 80, 80),
        }):Play()
        btn.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
    end
end

local Navs = {"公告", "通用", "战斗", "移动", "视觉", "娱乐", "服务器", "国内脚本", "设置"}
for i, n in ipairs(Navs) do
    local NB = Instance.new("TextButton")
    NB.Size = UDim2.new(1, -20, 0, 32)
    NB.Position = UDim2.new(0, 10, 0, 72 + (i-1)*36)
    NB.BackgroundColor3 = Color3.fromRGB(235, 238, 242)
    NB.BackgroundTransparency = 0.6
    NB.BorderSizePixel = 0; NB.Text = n
    NB.TextColor3 = Color3.fromRGB(80, 80, 80); NB.TextSize = 12
    NB.Font = Enum.Font.GothamMedium; NB.ZIndex = 4; NB.Parent = Sidebar
    Instance.new("UICorner", NB).CornerRadius = UDim.new(0, 8)
    NB.MouseButton1Click:Connect(function() SwitchPage(n) end)
    NavButtons[n] = NB
end

local Footer = Instance.new("TextLabel")
Footer.Size = UDim2.new(1, 0, 0, 20); Footer.Position = UDim2.new(0, 0, 1, -30)
Footer.BackgroundTransparency = 1; Footer.Text = "今天也要赢哦~"
Footer.TextColor3 = Color3.fromRGB(100, 100, 100); Footer.TextSize = 11
Footer.Font = Enum.Font.Gotham; Footer.TextXAlignment = Enum.TextXAlignment.Center
Footer.ZIndex = 5; Footer.Parent = Sidebar

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -150, 1, 0); ContentArea.Position = UDim2.new(0, 150, 0, 0)
ContentArea.BackgroundTransparency = 1; ContentArea.ZIndex = 4; ContentArea.Parent = Main

local ContentMask = Instance.new("Frame")
ContentMask.Size = UDim2.new(1, -20, 1, -20); ContentMask.Position = UDim2.new(0, 10, 0, 10)
ContentMask.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ContentMask.BackgroundTransparency = 0.5
ContentMask.BorderSizePixel = 0; ContentMask.ZIndex = 4; ContentMask.Parent = ContentArea
Instance.new("UICorner", ContentMask).CornerRadius = UDim.new(0, 24)

local function CreatePage(name)
    local P = Instance.new("ScrollingFrame")
    P.Name = name; P.Size = UDim2.new(1, 0, 1, 0)
    P.BackgroundTransparency = 1; P.BorderSizePixel = 0
    P.ScrollBarThickness = 2; P.CanvasSize = UDim2.new(0, 0, 0, 0)
    P.AutomaticCanvasSize = Enum.AutomaticSize.Y
    P.Visible = false; P.ZIndex = 5; P.Parent = ContentArea
    local pad = Instance.new("UIPadding", P)
    pad.PaddingTop = UDim.new(0, 12); pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12); pad.PaddingBottom = UDim.new(0, 12)
    local lay = Instance.new("UIListLayout", P)
    lay.Padding = UDim.new(0, 6); lay.SortOrder = Enum.SortOrder.LayoutOrder
    Pages[name] = P
    return P
end

local function CreateSection(parent, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 22); l.BackgroundTransparency = 1
    l.Text = text; l.TextColor3 = Color3.fromRGB(120, 130, 140)
    l.TextSize = 11; l.Font = Enum.Font.GothamMedium
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = parent
end

local function CreateToggle(parent, name)
    local F = Instance.new("Frame")
    F.Size = UDim2.new(1, 0, 0, 26); F.BackgroundTransparency = 1; F.Parent = parent
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(0.7, 0, 1, 0); L.BackgroundTransparency = 1
    L.Text = name; L.TextColor3 = Color3.fromRGB(60, 60, 60); L.TextSize = 12
    L.Font = Enum.Font.Gotham; L.TextXAlignment = Enum.TextXAlignment.Left; L.Parent = F
    local state = Config[name] or false
    local B = Instance.new("TextButton")
    B.Size = UDim2.new(0, 36, 0, 18); B.Position = UDim2.new(1, -36, 0.5, -9)
    B.BackgroundColor3 = state and Color3.fromRGB(0, 122, 255) or Color3.fromRGB(210, 210, 210)
    B.BorderSizePixel = 0; B.Text = ""; B.Parent = F
    Instance.new("UICorner", B).CornerRadius = UDim.new(0, 9)
    local C = Instance.new("Frame")
    C.Size = UDim2.new(0, 14, 0, 14)
    C.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    C.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    C.BorderSizePixel = 0; C.Parent = B
    Instance.new("UICorner", C).CornerRadius = UDim.new(0, 7)
    B.MouseButton1Click:Connect(function()
        state = not state
        Config[name] = state
        TweenService:Create(B, TweenInfo.new(0.2), {BackgroundColor3 = state and Color3.fromRGB(0, 122, 255) or Color3.fromRGB(210, 210, 210)}):Play()
        TweenService:Create(C, TweenInfo.new(0.2), {Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
        if _genv.XixiToggleCallbacks and _genv.XixiToggleCallbacks[name] then
            pcall(_genv.XixiToggleCallbacks[name], state)
        end
    end)
end

local function CreateSlider(parent, name, min, max, default, callback)
    local F = Instance.new("Frame")
    F.Size = UDim2.new(1, 0, 0, 32); F.BackgroundTransparency = 1; F.Parent = parent
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(0.6, 0, 0, 16); L.BackgroundTransparency = 1
    L.Text = name; L.TextColor3 = Color3.fromRGB(60, 60, 60); L.TextSize = 11
    L.Font = Enum.Font.Gotham; L.TextXAlignment = Enum.TextXAlignment.Left; L.Parent = F
    local VL = Instance.new("TextLabel")
    VL.Size = UDim2.new(0.4, 0, 0, 16); VL.Position = UDim2.new(0.6, 0, 0, 0)
    VL.BackgroundTransparency = 1; VL.Text = tostring(default or Config[name] or min)
    VL.TextColor3 = Color3.fromRGB(0, 122, 255); VL.TextSize = 11
    VL.Font = Enum.Font.GothamMedium; VL.TextXAlignment = Enum.TextXAlignment.Right; VL.Parent = F
    local BG = Instance.new("Frame")
    BG.Size = UDim2.new(1, 0, 0, 3); BG.Position = UDim2.new(0, 0, 0, 22)
    BG.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    BG.BackgroundTransparency = 0.2; BG.BorderSizePixel = 0; BG.Parent = F
    Instance.new("UICorner", BG).CornerRadius = UDim.new(0, 2)
    local Fill = Instance.new("Frame")
    local cur = Config[name] or default or min
    local rel = math.clamp((cur - min) / (max - min), 0, 1)
    Fill.Size = UDim2.new(rel, 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(0, 122, 255)
    Fill.BorderSizePixel = 0; Fill.Parent = BG
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(0, 2)
    local drag = false
    local function up(x)
        local r = math.clamp((x - BG.AbsolutePosition.X) / BG.AbsoluteSize.X, 0, 1)
        local v = math.floor(min + (max - min) * r)
        Fill.Size = UDim2.new(r, 0, 1, 0); VL.Text = tostring(v); Config[name] = v
        if callback then pcall(callback, v) end
    end
    BG.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = true; up(input.Position.X)
        end
    end)
    TC(UserInputService.InputChanged:Connect(function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            up(input.Position.X)
        end
    end))
    TC(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then drag = false end
    end))
end

local function CreateButton(parent, name, callback)
    local B = Instance.new("TextButton")
    B.Size = UDim2.new(1, 0, 0, 28)
    B.BackgroundColor3 = Color3.fromRGB(245, 248, 252)
    B.BorderSizePixel = 0; B.Text = name
    B.TextColor3 = Color3.fromRGB(60, 60, 60); B.TextSize = 12
    B.Font = Enum.Font.GothamMedium
    B.TextXAlignment = Enum.TextXAlignment.Left; B.Parent = parent
    Instance.new("UICorner", B).CornerRadius = UDim.new(0, 8)
    local pad = Instance.new("UIPadding", B); pad.PaddingLeft = UDim.new(0, 10)
    B.MouseButton1Click:Connect(function()
        if callback then pcall(callback) end
    end)
    return B
end

-- ============================================================
-- 第六部分：页面数据（远程 URL）
-- ============================================================
local ServerScripts = {
    {name="灾难之岛", url="https://raw.githubusercontent.com/hgvuyguyg/new/main/灾难之岛"},
    {name="巴掌检测", url="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/巴掌"},
    {name="汉堡包", url="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/汉堡"},
    {name="机器人滑膛枪", url="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/机器人"},
    {name="住宅大逃杀", url="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/住宅屠杀"},
    {name="降落或死亡", url="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/死亡"},
    {name="砧板鲶鱼", url="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/钓鱼"},
    {name="死铁轨", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/铁轨"},
    {name="柠檬大亨", url="https://rawscripts.net/raw/Sell-Lemons-Fluid-Orchard-Update-Read-Description-241132"},
    {name="键盘逃脱", url="https://raw.githubusercontent.com/ccdushii/zzzzzzzzz/refs/heads/main/ssssssssss"},
    {name="驾驶帝国", url="https://raw.githubusercontent.com/xiaopi77/xiaopi77/refs/heads/main/Roblox-Pi-Drivingempire-Script.lua"},
    {name="Doors", url="https://raw.githubusercontent.com/XxwanhexxX/doors-zh/refs/heads/main/Abysall.Hub"},
    {name="后巷", url="https://github.com/mryitang-sys/Ting-script/releases/download/nsjxjxhs/GE.2.6.lua"},
    {name="弹药师", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/%E5%BC%B9%E8%8D%AF"},
    {name="九十九夜", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/99"},
    {name="幸运方块", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/%E5%B9%B8%E8%BF%90%E6%96%B9%E5%9D%97"},
    {name="重型钓鱼", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/重型钓鱼"},
    {name="加脂肪", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/脂肪"},
    {name="动物医院", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/福瑞医院"},
    {name="关注者", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/关注"},
    {name="吃吃世界", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/吃吃世界"},
    {name="为城市供电", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/为你的城市供电"},
    {name="抛硬币", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/抛一枚硬币"},
    {name="Po大Po", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/拉大便"},
    {name="Blox Fruit", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/blox"},
    {name="餐厅大亨3", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/餐厅大亨"},
    {name="画滑雪板", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/画画"},
    {name="拥有咖啡馆", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/拥有咖啡馆"},
    {name="快躲起来", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/躲起来"},
    {name="钓鱼吧", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/调"},
    {name="清洗键盘", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/清洗键盘"},
    {name="装载卡车", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/装载卡车"},
    {name="Fisch", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/船鱼"},
    {name="种植花园2", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/种植菜园二"},
    {name="活了7天", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/活了7天"},
    {name="被遗弃", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/被遗弃"},
    {name="河北唐县", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/河北"},
    {name="末日生存", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/末日"},
    {name="零售大亨2", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/零售大亨"},
    {name="采矿大亨", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/采矿"},
    {name="启示录", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/启示录"},
    {name="战争大亨", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/战争"},
    {name="海上100天", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/海上100天"},
    {name="俄亥俄州", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/ohio"},
    {name="割草冒险", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/割草冒险"},
    {name="种植者", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/种植者"},
    {name="剑点击", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/剑1"},
    {name="超商生存", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/在超级商店生存"},
    {name="寒冷生存", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/在寒冷生存"},
    {name="训练鸡", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/训练鸡肉"},
    {name="长途旅行", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/长途旅行"},
    {name="最强战场", url="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/最强"},
    {name="获得球员", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/获得球员"},
    {name="伐木大亨2", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/伐木大亨"},
    {name="偷蛋", url="https://pastefy.app/4lHhgnhn/raw"},
    {name="变身升级", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/变身升级"},
    {name="肌肉墙壁", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/肌肉墙壁"},
    {name="踢球太空", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/踢球太空"},
    {name="魔法战利品", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/魔法战利品"},
    {name="夜幕降临", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/夜幕降临"},
    {name="恐龙生活", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/恐龙生活"},
    {name="双跳自行车", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/双跳车"},
    {name="谋杀之岛2", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/谋杀之岛"},
    {name="声名远播", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/抢劫"},
    {name="清理树叶", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/清理树叶"},
    {name="我的木材农场", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/我的木材农场"},
    {name="后空翻键盘", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/后空翻键盘"},
    {name="抽军队", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/抽军队"},
    {name="合并核弹", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/合并核弹"},
    {name="加速度进化", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/加速度进化"},
    {name="逃跑者", url="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/淘宝"},
    {name="击杀头目", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/击杀头目"},
    {name="Dit", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/dit"},
    {name="正在探矿", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/正在挖矿"},
    {name="蝗虫之屋", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/蝗虫之王"},
    {name="拯救猫咪", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/拯救猫"},
    {name="恐怖寿司", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/寿司"},
    {name="按一个键帽", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/按键帽"},
    {name="51区真相", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/51真相"},
    {name="每步减重", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/走路减重"},
    {name="矿井", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/矿井"},
    {name="神秘杀手", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/神秘的杀手"},
    {name="寻找菜鸟", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/寻找菜鸟"},
    {name="加一技能点", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/加一技能点"},
    {name="破碎之梦", url="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/破碎"},
    {name="烤或死", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/烤活死"},
    {name="挖掘逃出监狱", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/挖掘逃出监狱"},
    {name="飞行世界", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/飞行世界"},
    {name="空乘模拟", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/空乘模拟机"},
    {name="埃尔帕索", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/帕索角色扮演"},
    {name="无尽旅馆", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/k"},
    {name="力量传奇", url="https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/力量"},
    {name="路线06", url="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/路线"},
    {name="战斗大亨", url="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/战斗大亨"},
    {name="偷走巴掌", url="https://raw.githubusercontent.com/hgvuyguyg/sbqr/main/1巴掌"},
}

local CnScripts = {
    {name="小皮脚本", url="https://raw.githubusercontent.com/xiaopi77/xiaopi77/main/QQ1002100032-Roblox-Pi-script.lua"},
    {name="黑洞脚本", url="https://gitee.com/BS_script/script/raw/master/BS_Script.Luau"},
    {name="ROB脚本", url="https://raw.githubusercontent.com/idrobsc/rob_script/refs/heads/main/rob.v4"},
    {name="黄某脚本", url="https://rawscripts.net/raw/Universal-Script-HMscript-50384"},
    {name="Loader脚本", url="https://raw.githubusercontent.com/Jilxi/123/refs/heads/main/Loader.lua"},
    {name="落叶Pro Hub", url="https://raw.githubusercontent.com/SyndromeXph/Luoye-Pro-Hub/refs/heads/main/Script/Loader.lua"},
    {name="国内最强脚本中心", url="https://raw.githubusercontent.com/ggsq1741-debug/rj/refs/heads/main/pjie.lua"},
    {name="叶脚本主脚本", url="https://raw.githubusercontent.com/roblox-ye/QQ515966991/refs/heads/main/ROBLOX-CNVIP-XIAOYE.lua"},
    {name="ROB V2", url="https://raw.githubusercontent.com/Zyb150933/ROB/refs/heads/main/ROB.V2"},
    {name="ROB V4", url="https://raw.githubusercontent.com/idrobsc/rob_script/refs/heads/main/rob.v4"},
    {name="夜脚本", url="https://raw.githubusercontent.com/ylt410/roblox-Script/refs/heads/main/yejiaoben"},
    {name="恐脚本", url="https://raw.githubusercontent.com/kongbaNB/9178/refs/heads/main/恐脚本.NB"},
    {name="星脚本", url="https://raw.githubusercontent.com/zilinskaslandon/XingJiaoBen-2026-/refs/heads/main/%E6%98%9F%E8%84%9A%E6%9C%AC.lua"},
    {name="浅脚本", url="https://raw.githubusercontent.com/renlua/shallow/main/Script_Hub.lua"},
    {name="VOTR脚本", url="https://raw.githubusercontent.com/VOTR-HUB/MAIN/refs/heads/main/VOTR-MAIN"},
    {name="秋脚本", url="https://raw.githubusercontent.com/WS857960/-/main/秋·自制脚本新源码.txt"},
    {name="XION脚本", url="https://raw.githubusercontent.com/smalldesikon/wocaonima/main/qq984820669.txt"},
    {name="Sxingz脚本", url="https://raw.githubusercontent.com/ZiO9178/jb/refs/heads/main/ZiO.lua"},
    {name="祖国人飞行", url="https://raw.githubusercontent.com/giobolqv1/homelander-by-GioBolqv1-/main/homelander.lua"},
    {name="防甩飞", url="https://raw.githubusercontent.com/Linux6699/DaHubRevival/main/AntiFling.lua"},
}

-- ============================================================
-- 第七部分：构建所有页面
-- ============================================================
-- 公告页
local P_ann = CreatePage("公告")
local annLabel = Instance.new("TextLabel")
annLabel.Size = UDim2.new(1, 0, 1, 0); annLabel.BackgroundTransparency = 1
annLabel.TextColor3 = Color3.fromRGB(70, 70, 70); annLabel.TextSize = 11
annLabel.Font = Enum.Font.Gotham
annLabel.TextXAlignment = Enum.TextXAlignment.Left
annLabel.TextYAlignment = Enum.TextYAlignment.Top
annLabel.TextWrapped = true; annLabel.Parent = P_ann
task.spawn(function()
    while P_ann.Parent do
        local n = os.date("*t")
        pcall(function()
            annLabel.Text =
                "⏰ " .. n.year .. "年" .. n.month .. "月" .. n.day .. "日 " .. string.format("%02d:%02d:%02d", n.hour, n.min, n.sec) .. "\n\n" ..
                "👤 脚本：兮兮\n" ..
                "🛡 过检测：Verdict V8.0\n" ..
                "🎯 目标游戏：" .. Verdict.Profile .. "\n\n" ..
                "📊 反作弊模块：" .. tostring(#Verdict.ACFound) .. " 个\n" ..
                "📡 Remote 清洗：" .. tostring(#Verdict.RemoteLog) .. " 条\n" ..
                "⏱ 时间偏移：" .. string.format("%.2f", Verdict.TimeOffset) .. " 秒\n\n" ..
                "✨ 所有功能通过远程加载，脚本本身仅含 UI + 过检测"
        end)
        task.wait(1)
    end
end)

-- 通用页
local P_gen = CreatePage("通用")
CreateSection(P_gen, "移动")
CreateToggle(P_gen, "无限跳跃")
CreateToggle(P_gen, "穿墙")
CreateToggle(P_gen, "踏空")
CreateToggle(P_gen, "加速")
CreateToggle(P_gen, "隐身")
CreateSection(P_gen, "调节")
CreateSlider(P_gen, "移动速度", 1, 500, 16, function(v)
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed = v end
end)
CreateSlider(P_gen, "跳跃高度", 1, 500, 50, function(v)
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Humanoid") then c.Humanoid.JumpHeight = v end
end)
CreateSlider(P_gen, "重力", 1, 500, 196, function(v) workspace.Gravity = v end)
CreateSlider(P_gen, "视野", 30, 120, 70, function(v)
    local cam = workspace.CurrentCamera
    if cam then cam.FieldOfView = v end
end)
CreateSection(P_gen, "远程脚本")
CreateButton(P_gen, "🕊️  飞行模式", function() Loader.Load("https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/refs/heads/main/%E9%A3%9E%E9%A5%BC", "飞行") end)
CreateButton(P_gen, "📡  Remote Spy", function() Loader.Load("https://raw.githubusercontent.com/Klinac/scripts/main/utopia_spy.lua", "Remote") end)
CreateButton(P_gen, "💨  碰撞甩飞", function() Loader.Load("https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/帅飞", "帅飞") end)
CreateButton(P_gen, "🎯  FPS通用", function() Loader.Load("https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/%E8%87%AA%E7%9E%84", "自瞄") end)
CreateButton(P_gen, "🥚  NTv3.3", function() Loader.Load("https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/nt", "NT") end)
CreateButton(P_gen, "🌷  无限罗宝", function() Loader.Load("https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/锁机", "锁机") end)
CreateButton(P_gen, "⛽  Tx翻译", function() Loader.Load("https://raw.githubusercontent.com/JsYb666/Item/refs/heads/main/Auto-language", "翻译") end)

-- 战斗页
local P_fight = CreatePage("战斗")
CreateSection(P_fight, "战斗功能")
CreateToggle(P_fight, "团队高亮")
CreateToggle(P_fight, "敌对高亮")
CreateToggle(P_fight, "自动攻击")
CreateToggle(P_fight, "全图点亮")
CreateToggle(P_fight, "无敌")
CreateToggle(P_fight, "防挂机")
CreateToggle(P_fight, "自动连点")
CreateSection(P_fight, "远程脚本")
CreateButton(P_fight, "🦸  祖国人", function() Loader.Load("https://raw.githubusercontent.com/giobolqv1/homelander-by-GioBolqv1-/refs/heads/main/homelander.lua", "祖国人") end)
CreateButton(P_fight, "🤖  动作动画包", function() Loader.Load("https://rawscripts.net/raw/Universal-Script-7yd7-I-Emote-Script-48024", "动作") end)
CreateButton(P_fight, "🎉  播放器", function() Loader.Load("https://raw.githubusercontent.com/hgvuyguyg/jjjjjjjjj/main/播放", "播放") end)

-- 移动页
local P_move = CreatePage("移动")
CreateSection(P_move, "移动")
CreateToggle(P_move, "千倍速度")
CreateToggle(P_move, "点击传送")
CreateSection(P_move, "玩家交互")
CreateButton(P_move, "📬  传送玩家", function()
    local win = Instance.new("Frame")
    win.Size = UDim2.new(0, 220, 0, 320)
    win.Position = UDim2.new(0.5, -110, 0.5, -160)
    win.BackgroundColor3 = Color3.fromRGB(240, 245, 250)
    win.BorderSizePixel = 0; win.ZIndex = 200; win.Parent = ScreenGui
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 16)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -16, 1, -50); scroll.Position = UDim2.new(0, 8, 0, 42)
    scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ZIndex = 201; scroll.Parent = win
    local lay = Instance.new("UIListLayout", scroll)
    lay.Padding = UDim.new(0, 4); lay.SortOrder = Enum.SortOrder.LayoutOrder
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -50, 0, 30); title.Position = UDim2.new(0, 12, 0, 6)
    title.BackgroundTransparency = 1; title.Text = "选择玩家"
    title.TextColor3 = Color3.fromRGB(40, 40, 40); title.TextSize = 13
    title.Font = Enum.Font.GothamBold; title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 201; title.Parent = win
    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 24, 0, 24); close.Position = UDim2.new(1, -32, 0, 6)
    close.BackgroundColor3 = Color3.fromRGB(255, 90, 90); close.BorderSizePixel = 0
    close.Text = "×"; close.TextColor3 = Color3.fromRGB(255, 255, 255); close.TextSize = 16
    close.Font = Enum.Font.GothamBold; close.ZIndex = 201; close.Parent = win
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 12)
    close.MouseButton1Click:Connect(function() win:Destroy() end)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local pb = Instance.new("TextButton")
            pb.Size = UDim2.new(1, 0, 0, 30)
            pb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            pb.BorderSizePixel = 0; pb.Text = p.Name
            pb.TextColor3 = Color3.fromRGB(60, 60, 60); pb.TextSize = 12
            pb.Font = Enum.Font.Gotham; pb.ZIndex = 202; pb.Parent = scroll
            Instance.new("UICorner", pb).CornerRadius = UDim.new(0, 8)
            pb.MouseButton1Click:Connect(function()
                if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    Verdict.Teleport(p.Character.HumanoidRootPart.CFrame + Vector3.new(3, 0, 0))
                end
                win:Destroy()
            end)
        end
    end
end)
CreateButton(P_move, "🏠  快速回家", function()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        Verdict.Teleport(CFrame.new(0, 50, 0))
    end
end)

-- 视觉页
local P_vis = CreatePage("视觉")
CreateSection(P_vis, "视觉")
CreateToggle(P_vis, "夜视")
CreateToggle(P_vis, "去雾")
CreateToggle(P_vis, "全屏特效")
CreateToggle(P_vis, "彩虹拖尾")
CreateToggle(P_vis, "火焰拖尾")
CreateToggle(P_vis, "冰霜拖尾")
CreateToggle(P_vis, "彩虹名字")
CreateToggle(P_vis, "客户端字幕")
CreateToggle(P_vis, "显示FPS")

-- 娱乐页
local P_fun = CreatePage("娱乐")
CreateSection(P_fun, "娱乐")
CreateToggle(P_fun, "跳舞")
CreateToggle(P_fun, "喷火")
CreateToggle(P_fun, "光环")
CreateToggle(P_fun, "倒立")
CreateToggle(P_fun, "大头")
CreateToggle(P_fun, "巨大化")
CreateSection(P_fun, "下载器")
CreateButton(P_fun, "📥  打开下载器", function()
    if _genv.__XixiDownloaderGui and _genv.__XixiDownloaderGui.Parent then
        local main = _genv.__XixiDownloaderGui:FindFirstChild("DlMain")
        if main then main.Visible = not main.Visible end
    else
        warn("[兮兮] 下载器未加载")
    end
end)

-- 服务器页
local P_srv = CreatePage("服务器")
CreateSection(P_srv, "服务器专用脚本（" .. #ServerScripts .. " 个）")
for _, item in ipairs(ServerScripts) do
    CreateButton(P_srv, "🎍  " .. item.name, function()
        Loader.Load(item.url, item.name)
    end)
end

-- 国内脚本页
local P_cn = CreatePage("国内脚本")
CreateSection(P_cn, "国内脚本（" .. #CnScripts .. " 个）")
for _, item in ipairs(CnScripts) do
    CreateButton(P_cn, "🇨🇳  " .. item.name, function()
        Loader.Load(item.url, item.name)
    end)
end

-- 设置页
local P_set = CreatePage("设置")
CreateSection(P_set, "Verdict 过检测状态")
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 130); statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(70, 70, 70); statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Parent = P_set
task.spawn(function()
    while P_set.Parent do
        pcall(function()
            statusLabel.Text =
                "🎯 目标游戏：" .. Verdict.Profile .. "\n" ..
                "📍 PlaceId：" .. tostring(game.PlaceId) .. "\n" ..
                "🛡 Namecall Hook：" .. (Verdict.Hooks.__namecall and "✅ 已挂载" or "❌ 未挂载") .. "\n" ..
                "⏱ 时间伪造：" .. (Verdict.Hooks.TimeForge and "✅ 启用" or "❌ 禁用") .. "\n" ..
                "🔍 反作弊识别：" .. tostring(#Verdict.ACFound) .. " 个\n" ..
                "📡 Remote 清洗：" .. tostring(#Verdict.RemoteLog) .. " 条\n" ..
                "⏱ 时间偏移：" .. string.format("%.2f", Verdict.TimeOffset) .. " 秒"
        end)
        task.wait(1)
    end
end)
CreateSection(P_set, "手动操作")
CreateButton(P_set, "🔄  清理反作弊脚本", function() pcall(XAC.KillAC) end)
CreateButton(P_set, "🧹  清理全局特征", function()
    pcall(function()
        local g = _real.getgenv and _real.getgenv() or _G
        for k in pairs(g) do
            if type(k) == "string" and (k:find("Verdict") or k:find("Xixi")) and k ~= "XixiConfig" then
                g[k] = nil
            end
        end
    end)
end)
CreateButton(P_set, "⏱  重置时间偏移", function() Verdict.ResetTime() end)
CreateButton(P_set, "📊  打印过检测报告", function()
    print("=== Verdict 报告 ===")
    print("PlaceId:", game.PlaceId)
    print("Profile:", Verdict.Profile)
    print("Namecall Hook:", Verdict.Hooks.__namecall)
    print("TimeForge:", Verdict.Hooks.TimeForge)
    print("反作弊模块:", #Verdict.ACFound)
    print("Remote日志:", #Verdict.RemoteLog)
end)

-- 关闭按钮
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -35, 0, 15)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "×"; CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 18; CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.ZIndex = 10; CloseBtn.Parent = Main
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 12)
CloseBtn.MouseButton1Click:Connect(function() Main.Visible = false end)

SwitchPage("公告")

-- ============================================================
-- 第八部分：本地功能实现（连接 UI Toggle 到实际逻辑）
-- ============================================================
_genv.XixiToggleCallbacks = {}

-- 无限跳跃
_genv.XixiToggleCallbacks["无限跳跃"] = function(on)
    if on then
        if not _genv.__infJumpConn then
            _genv.__infJumpConn = UserInputService.JumpRequest:Connect(function()
                local c = LocalPlayer.Character
                if c and c:FindFirstChild("Humanoid") then
                    c.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
        end
    else
        if _genv.__infJumpConn then _genv.__infJumpConn:Disconnect(); _genv.__infJumpConn = nil end
    end
end

-- 穿墙
_genv.XixiToggleCallbacks["穿墙"] = function(on)
    if on then
        if not _genv.__noclipConn then
            _genv.__noclipConn = RunService.Stepped:Connect(function()
                local c = LocalPlayer.Character
                if c then
                    for _, p in ipairs(c:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                end
            end)
        end
    else
        if _genv.__noclipConn then _genv.__noclipConn:Disconnect(); _genv.__noclipConn = nil end
        local c = LocalPlayer.Character
        if c then for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end end
    end
end

-- 踏空
_genv.XixiToggleCallbacks["踏空"] = function(on)
    if on then
        if not _genv.__floatConn then
            local c = LocalPlayer.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if hrp then
                local y = hrp.Position.Y
                _genv.__floatConn = RunService.RenderStepped:Connect(function()
                    if hrp and hrp.Parent then
                        hrp.Velocity = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z)
                        hrp.CFrame = CFrame.new(hrp.Position.X, y, hrp.Position.Z)
                    end
                end)
            end
        end
    else
        if _genv.__floatConn then _genv.__floatConn:Disconnect(); _genv.__floatConn = nil end
    end
end

-- 加速
_genv.XixiToggleCallbacks["加速"] = function(on)
    if on then
        if not _genv.__speedConn then
            _genv.__speedConn = RunService.RenderStepped:Connect(function()
                for _, v in ipairs(workspace:GetDescendants()) do
                    if v:IsA("Animation") then v.Speed = 2 end
                end
            end)
        end
    else
        if _genv.__speedConn then _genv.__speedConn:Disconnect(); _genv.__speedConn = nil end
    end
end

-- 隐身
_genv.XixiToggleCallbacks["隐身"] = function(on)
    local c = LocalPlayer.Character
    if c then for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then v.Transparency = on and 0.8 or 0 end
    end end
end

-- 千倍速度
_genv.XixiToggleCallbacks["千倍速度"] = function(on)
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Humanoid") then
        c.Humanoid.WalkSpeed = on and 1000 or 16
    end
end

-- 无敌
_genv.XixiToggleCallbacks["无敌"] = function(on)
    if on then
        if not _genv.__godConn then
            _genv.__godConn = RunService.Heartbeat:Connect(function()
                local c = LocalPlayer.Character
                if c and c:FindFirstChild("Humanoid") then
                    c.Humanoid.MaxHealth = math.huge
                    c.Humanoid.Health = math.huge
                end
            end)
        end
    else
        if _genv.__godConn then _genv.__godConn:Disconnect(); _genv.__godConn = nil end
    end
end

-- 防挂机
_genv.XixiToggleCallbacks["防挂机"] = function(on)
    if on then
        if not _genv.__afkConn then
            _genv.__afkConn = LocalPlayer.Idled:Connect(function()
                local vu = game:GetService("VirtualUser")
                vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                task.wait(1)
                vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            end)
        end
    else
        if _genv.__afkConn then _genv.__afkConn:Disconnect(); _genv.__afkConn = nil end
    end
end

-- 自动连点
_genv.XixiToggleCallbacks["自动连点"] = function(on)
    if on then
        if not _genv.__autoClickConn then
            _genv.__autoClickConn = RunService.RenderStepped:Connect(function()
                local vu = game:GetService("VirtualUser")
                local cam = workspace.CurrentCamera
                if cam then
                    local s = cam.ViewportSize
                    vu:Button1Down(Vector2.new(s.X/2, s.Y/2))
                    vu:Button1Up(Vector2.new(s.X/2, s.Y/2))
                end
            end)
        end
    else
        if _genv.__autoClickConn then _genv.__autoClickConn:Disconnect(); _genv.__autoClickConn = nil end
    end
end

-- 点击传送
_genv.XixiToggleCallbacks["点击传送"] = function(on)
    if on then
        if not _genv.__clickTpConn then
            local mouse = LocalPlayer:GetMouse()
            _genv.__clickTpConn = mouse.Button1Down:Connect(function()
                if mouse.Hit then Verdict.Teleport(CFrame.new(mouse.Hit.p + Vector3.new(0, 3, 0))) end
            end)
        end
    else
        if _genv.__clickTpConn then _genv.__clickTpConn:Disconnect(); _genv.__clickTpConn = nil end
    end
end

-- 团队高亮
_genv.XixiToggleCallbacks["团队高亮"] = function(on)
    if on then
        if not _genv.__teamGlowConn then
            _genv.__teamGlowConn = RunService.RenderStepped:Connect(function()
                local myTeam = LocalPlayer.Team
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
            end)
        end
    else
        if _genv.__teamGlowConn then _genv.__teamGlowConn:Disconnect(); _genv.__teamGlowConn = nil end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local hl = p.Character:FindFirstChild("TeamGlow")
                if hl then hl:Destroy() end
            end
        end
    end
end

-- 敌对高亮
_genv.XixiToggleCallbacks["敌对高亮"] = function(on)
    if on then
        if not _genv.__enemyGlowConn then
            _genv.__enemyGlowConn = RunService.RenderStepped:Connect(function()
                local myTeam = LocalPlayer.Team
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
            end)
        end
    else
        if _genv.__enemyGlowConn then _genv.__enemyGlowConn:Disconnect(); _genv.__enemyGlowConn = nil end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local hl = p.Character:FindFirstChild("EnemyGlow")
                if hl then hl:Destroy() end
            end
        end
    end
end

-- 自动攻击
_genv.XixiToggleCallbacks["自动攻击"] = function(on)
    if on then
        if not _genv.__autoAtkConn then
            _genv.__autoAtkConn = RunService.RenderStepped:Connect(function()
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
                            if d < minDist then minDist = d; nearest = p.Character end
                        end
                    end
                end
                if nearest then
                    Verdict.Teleport(nearest.HumanoidRootPart.CFrame + Vector3.new(2, 0, 0))
                    local tool = c:FindFirstChildOfClass("Tool")
                    if tool and tool:FindFirstChild("Handle") then
                        firetouchinterest(tool.Handle, nearest, 0)
                        firetouchinterest(tool.Handle, nearest, 1)
                    end
                end
            end)
        end
    else
        if _genv.__autoAtkConn then _genv.__autoAtkConn:Disconnect(); _genv.__autoAtkConn = nil end
    end
end

-- 全图点亮
_genv.XixiToggleCallbacks["全图点亮"] = function(on)
    local L = game:GetService("Lighting")
    if on then
        L.Brightness = 5
        L.ClockTime = 14
        L.FogEnd = 100000
        L.GlobalShadows = false
        L.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
    else
        L.Brightness = 1
        L.GlobalShadows = true
    end
end

-- 夜视
_genv.XixiToggleCallbacks["夜视"] = function(on)
    local L = game:GetService("Lighting")
    if on then
        L.Brightness = 2
        L.ClockTime = 14
        L.FogEnd = 100000
        L.GlobalShadows = false
    else
        L.Brightness = 1
        L.GlobalShadows = true
    end
end

-- 去雾
_genv.XixiToggleCallbacks["去雾"] = function(on)
    local L = game:GetService("Lighting")
    if on then L.FogEnd = 100000; L.FogStart = 50000
    else L.FogEnd = 1000; L.FogStart = 0 end
end

-- 全屏特效
_genv.XixiToggleCallbacks["全屏特效"] = function(on)
    local L = game:GetService("Lighting")
    if on then
        if not L:FindFirstChild("ScreenFX") then
            local fx = Instance.new("ColorCorrectionEffect")
            fx.Name = "ScreenFX"
            fx.TintColor = Color3.fromRGB(255, 100, 200)
            fx.Parent = L
        end
    else
        local fx = L:FindFirstChild("ScreenFX")
        if fx then fx:Destroy() end
    end
end

-- 彩虹拖尾
_genv.XixiToggleCallbacks["彩虹拖尾"] = function(on)
    local c = LocalPlayer.Character
    if not c or not c:FindFirstChild("HumanoidRootPart") then return end
    local hrp = c.HumanoidRootPart
    if on then
        if not hrp:FindFirstChild("PlayerTrail") then
            local t = Instance.new("Trail"); t.Name = "PlayerTrail"
            local a0 = Instance.new("Attachment"); a0.Parent = hrp
            local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -2, 0); a1.Parent = hrp
            t.Attachment0 = a0; t.Attachment1 = a1
            t.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0), Color3.fromRGB(0, 0, 255))
            t.Lifetime = 0.5; t.Parent = hrp
        end
    else
        local t = hrp:FindFirstChild("PlayerTrail"); if t then t:Destroy() end
    end
end

-- 火焰拖尾
_genv.XixiToggleCallbacks["火焰拖尾"] = function(on)
    local c = LocalPlayer.Character
    if not c or not c:FindFirstChild("HumanoidRootPart") then return end
    local hrp = c.HumanoidRootPart
    if on then
        if not hrp:FindFirstChild("FireTrail") then
            local t = Instance.new("Trail"); t.Name = "FireTrail"
            local a0 = Instance.new("Attachment"); a0.Parent = hrp
            local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -2, 0); a1.Parent = hrp
            t.Attachment0 = a0; t.Attachment1 = a1
            t.Color = ColorSequence.new(Color3.fromRGB(255, 50, 0), Color3.fromRGB(255, 150, 0), Color3.fromRGB(255, 255, 0))
            t.Lifetime = 0.3; t.Parent = hrp
        end
    else
        local t = hrp:FindFirstChild("FireTrail"); if t then t:Destroy() end
    end
end

-- 冰霜拖尾
_genv.XixiToggleCallbacks["冰霜拖尾"] = function(on)
    local c = LocalPlayer.Character
    if not c or not c:FindFirstChild("HumanoidRootPart") then return end
    local hrp = c.HumanoidRootPart
    if on then
        if not hrp:FindFirstChild("IceTrail") then
            local t = Instance.new("Trail"); t.Name = "IceTrail"
            local a0 = Instance.new("Attachment"); a0.Parent = hrp
            local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -2, 0); a1.Parent = hrp
            t.Attachment0 = a0; t.Attachment1 = a1
            t.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255), Color3.fromRGB(200, 240, 255))
            t.Lifetime = 0.4; t.Parent = hrp
        end
    else
        local t = hrp:FindFirstChild("IceTrail"); if t then t:Destroy() end
    end
end

-- 彩虹名字
_genv.XixiToggleCallbacks["彩虹名字"] = function(on)
    local c = LocalPlayer.Character
    if not c or not c:FindFirstChild("Head") then return end
    if on then
        if not c.Head:FindFirstChild("XixiRainbow") then
            local bb = Instance.new("BillboardGui")
            bb.Name = "XixiRainbow"
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
            nl.TextStrokeTransparency = 0
            nl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            nl.Parent = bb
            if not _genv.__rainbowNameConn then
                local hue = 0
                _genv.__rainbowNameConn = RunService.RenderStepped:Connect(function(dt)
                    hue = (hue + dt * 0.5) % 1
                    nl.TextColor3 = Color3.fromHSV(hue, 1, 1)
                end)
            end
        end
    else
        local bb = c.Head:FindFirstChild("XixiRainbow")
        if bb then bb:Destroy() end
        if _genv.__rainbowNameConn then _genv.__rainbowNameConn:Disconnect(); _genv.__rainbowNameConn = nil end
    end
end

-- 客户端字幕
_genv.XixiToggleCallbacks["客户端字幕"] = function(on)
    if on then
        if not _genv.__subtitleGui then
            local gui = XAC.NewProtectedGui("XixiSubtitle")
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(0, 500, 0, 80)
            label.Position = UDim2.new(0.5, -250, 0, 10)
            label.Text = LocalPlayer.Name .. " 已入侵服务器"
            label.Font = Enum.Font.GothamBold
            label.TextSize = 24
            label.BackgroundTransparency = 1
            label.TextStrokeTransparency = 0
            label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            label.Parent = gui
            _genv.__subtitleGui = gui
        end
    else
        if _genv.__subtitleGui then _genv.__subtitleGui:Destroy(); _genv.__subtitleGui = nil end
    end
end

-- 显示FPS
_genv.XixiToggleCallbacks["显示FPS"] = function(on)
    if on then
        if not _genv.__fpsGui then
            local gui = XAC.NewProtectedGui("XixiFPS")
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(0, 180, 0, 28)
            label.Position = UDim2.new(0, 8, 0, 8)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamBold
            label.TextSize = 16
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.RichText = true
            label.Parent = gui
            _genv.__fpsGui = gui
            local fc, lt = 0, tick()
            _genv.__fpsConn = RunService.RenderStepped:Connect(function()
                fc = fc + 1
                if tick() - lt >= 0.5 then
                    local fps = math.floor(fc / (tick() - lt))
                    fc = 0; lt = tick()
                    local col = fps >= 30 and "255,80,80" or "255,255,0"
                    label.Text = '<font color="rgb(255,255,255)">FPS: </font><font color="rgb(' .. col .. ')">' .. fps .. '</font>'
                end
            end)
        end
    else
        if _genv.__fpsGui then _genv.__fpsGui:Destroy(); _genv.__fpsGui = nil end
        if _genv.__fpsConn then _genv.__fpsConn:Disconnect(); _genv.__fpsConn = nil end
    end
end

-- 跳舞
_genv.XixiToggleCallbacks["跳舞"] = function(on)
    local c = LocalPlayer.Character
    if not c or not c:FindFirstChild("Humanoid") then return end
    if on then
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://5918726674"
        local track = c.Humanoid:LoadAnimation(anim)
        track:Play()
        _genv.__danceTrack = track
    else
        if _genv.__danceTrack then _genv.__danceTrack:Stop(); _genv.__danceTrack = nil end
    end
end

-- 喷火
_genv.XixiToggleCallbacks["喷火"] = function(on)
    local c = LocalPlayer.Character
    if not c or not c:FindFirstChild("HumanoidRootPart") then return end
    if on then
        local f = Instance.new("ParticleEmitter")
        f.Name = "XixiFire"
        f.Texture = "rbxassetid://241876428"
        f.Color = ColorSequence.new(Color3.fromRGB(255, 100, 0))
        f.Rate = 30
        f.Speed = NumberRange.new(3, 6)
        f.Lifetime = NumberRange.new(0.5, 1)
        f.Parent = c.HumanoidRootPart
    else
        local f = c.HumanoidRootPart:FindFirstChild("XixiFire")
        if f then f:Destroy() end
    end
end

-- 光环
_genv.XixiToggleCallbacks["光环"] = function(on)
    local c = LocalPlayer.Character
    if not c then return end
    if on then
        if not c:FindFirstChild("XixiGlow") then
            local hl = Instance.new("Highlight")
            hl.Name = "XixiGlow"
            hl.FillColor = Color3.fromRGB(255, 255, 0)
            hl.OutlineColor = Color3.fromRGB(255, 200, 0)
            hl.FillTransparency = 0.3
            hl.Parent = c
        end
    else
        local hl = c:FindFirstChild("XixiGlow")
        if hl then hl:Destroy() end
    end
end

-- 倒立
_genv.XixiToggleCallbacks["倒立"] = function(on)
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        c.HumanoidRootPart.CFrame = c.HumanoidRootPart.CFrame * CFrame.Angles(0, 0, math.rad(180))
    end
end

-- 大头
_genv.XixiToggleCallbacks["大头"] = function(on)
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Head") then
        c.Head.Size = on and Vector3.new(4, 4, 4) or Vector3.new(2, 1, 1)
    end
end

-- 巨大化
_genv.XixiToggleCallbacks["巨大化"] = function(on)
    local c = LocalPlayer.Character
    if not c then return end
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Size = on and v.Size * 3 or v.Size / 3
        end
    end
end

-- ============================================================
-- 第九部分：灵动岛
-- ============================================================
local IslandCfg = {Collapsed = UDim2.new(0, 150, 0, 40), Expanded = UDim2.new(0, 320, 0, 130), PositionY = 8, Accent = Color3.fromRGB(0, 122, 255), Speed = 0.4}

local Island = Instance.new("Frame")
Island.Name = "Island"
Island.Size = IslandCfg.Collapsed
Island.Position = UDim2.new(0.5, 0, 0, IslandCfg.PositionY)
Island.AnchorPoint = Vector2.new(0.5, 0)
Island.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
Island.BorderSizePixel = 0; Island.ZIndex = 50; Island.Parent = ScreenGui
Instance.new("UICorner", Island).CornerRadius = UDim.new(0, 20)

local IslandStroke = Instance.new("UIStroke", Island)
IslandStroke.Color = Color3.fromRGB(50, 50, 55)
IslandStroke.Thickness = 2
IslandStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local Collapsed = Instance.new("Frame")
Collapsed.Size = UDim2.new(1, 0, 1, 0)
Collapsed.BackgroundTransparency = 1; Collapsed.ZIndex = 51; Collapsed.Parent = Island

local Dot = Instance.new("Frame")
Dot.Size = UDim2.new(0, 8, 0, 8); Dot.Position = UDim2.new(0, 16, 0.5, -4)
Dot.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
Dot.BorderSizePixel = 0; Dot.ZIndex = 52; Dot.Parent = Collapsed
Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)

local CTxt = Instance.new("TextLabel")
CTxt.Size = UDim2.new(0, 80, 1, 0); CTxt.Position = UDim2.new(0, 30, 0, 0)
CTxt.BackgroundTransparency = 1; CTxt.Text = "兮兮"
CTxt.TextColor3 = Color3.fromRGB(255, 255, 255); CTxt.TextSize = 13
CTxt.Font = Enum.Font.GothamBold; CTxt.TextXAlignment = Enum.TextXAlignment.Left
CTxt.ZIndex = 52; CTxt.Parent = Collapsed

local Clock = Instance.new("TextLabel")
Clock.Size = UDim2.new(0, 40, 1, 0); Clock.Position = UDim2.new(1, -45, 0, 0)
Clock.BackgroundTransparency = 1; Clock.Text = "00:00"
Clock.TextColor3 = Color3.fromRGB(180, 180, 200); Clock.TextSize = 11
Clock.Font = Enum.Font.Gotham; Clock.TextXAlignment = Enum.TextXAlignment.Right
Clock.ZIndex = 52; Clock.Parent = Collapsed

local Expanded = Instance.new("Frame")
Expanded.Size = UDim2.new(1, 0, 1, 0)
Expanded.BackgroundTransparency = 1; Expanded.ZIndex = 51
Expanded.Visible = false; Expanded.Parent = Island

local ETitle = Instance.new("TextLabel")
ETitle.Size = UDim2.new(1, -30, 0, 20); ETitle.Position = UDim2.new(0, 15, 0, 15)
ETitle.BackgroundTransparency = 1; ETitle.Text = "兮兮 · 运行中"
ETitle.TextColor3 = Color3.fromRGB(255, 255, 255); ETitle.TextSize = 14
ETitle.Font = Enum.Font.GothamBold; ETitle.TextXAlignment = Enum.TextXAlignment.Left
ETitle.ZIndex = 52; ETitle.Parent = Expanded

local InfoFrame = Instance.new("Frame")
InfoFrame.Size = UDim2.new(1, -30, 0, 30); InfoFrame.Position = UDim2.new(0, 15, 0, 40)
InfoFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
InfoFrame.BorderSizePixel = 0; InfoFrame.ZIndex = 52; InfoFrame.Parent = Expanded
Instance.new("UICorner", InfoFrame).CornerRadius = UDim.new(0, 10)

local FpsL = Instance.new("TextLabel")
FpsL.Size = UDim2.new(0.5, 0, 1, 0); FpsL.Position = UDim2.new(0, 10, 0, 0)
FpsL.BackgroundTransparency = 1; FpsL.Text = "FPS: --"
FpsL.TextColor3 = IslandCfg.Accent; FpsL.TextSize = 13
FpsL.Font = Enum.Font.GothamBold; FpsL.TextXAlignment = Enum.TextXAlignment.Left
FpsL.ZIndex = 53; FpsL.Parent = InfoFrame

local TimeL = Instance.new("TextLabel")
TimeL.Size = UDim2.new(0.5, -10, 1, 0); TimeL.Position = UDim2.new(0.5, 0, 0, 0)
TimeL.BackgroundTransparency = 1; TimeL.Text = "--:--"
TimeL.TextColor3 = Color3.fromRGB(180, 180, 200); TimeL.TextSize = 13
TimeL.Font = Enum.Font.Gotham; TimeL.TextXAlignment = Enum.TextXAlignment.Right
TimeL.ZIndex = 53; TimeL.Parent = InfoFrame

local BtnF = Instance.new("Frame")
BtnF.Size = UDim2.new(1, -30, 0, 32); BtnF.Position = UDim2.new(0, 15, 0, 80)
BtnF.BackgroundTransparency = 1; BtnF.ZIndex = 52; BtnF.Parent = Expanded

local TBtn = Instance.new("TextButton")
TBtn.Size = UDim2.new(1, 0, 1, 0)
TBtn.BackgroundColor3 = IslandCfg.Accent; TBtn.BorderSizePixel = 0
TBtn.Text = "隐藏主界面"; TBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TBtn.TextSize = 13; TBtn.Font = Enum.Font.GothamBold
TBtn.ZIndex = 53; TBtn.Parent = BtnF
Instance.new("UICorner", TBtn).CornerRadius = UDim.new(0, 10)
TBtn.MouseButton1Click:Connect(function()
    Main.Visible = not Main.Visible
    TBtn.Text = Main.Visible and "隐藏主界面" or "打开主界面"
end)

local isExp, isAnim = false, false
local function ToggleIsland()
    if isAnim then return end
    isAnim = true
    isExp = not isExp
    local targetSize = isExp and IslandCfg.Expanded or IslandCfg.Collapsed
    local targetY = isExp and (IslandCfg.PositionY + 5) or IslandCfg.PositionY
    local ti = TweenInfo.new(IslandCfg.Speed, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    TweenService:Create(Island, ti, {Size = targetSize, Position = UDim2.new(0.5, 0, 0, targetY)}):Play()
    if isExp then
        Collapsed.Visible = false
        Expanded.Visible = true
        for _, c in ipairs(Expanded:GetDescendants()) do
            if c:IsA("TextLabel") or c:IsA("TextButton") then
                c.TextTransparency = 1
                TweenService:Create(c, ti, {TextTransparency = 0}):Play()
            end
        end
    else
        Collapsed.Visible = true
        Expanded.Visible = false
    end
    task.delay(IslandCfg.Speed, function() isAnim = false end)
end
Island.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        ToggleIsland()
    end
end)

local fc, lt = 0, tick()
RunService.RenderStepped:Connect(function()
    local ot = os.date("*t")
    local ts = string.format("%02d:%02d", ot.hour, ot.min)
    Clock.Text = ts; TimeL.Text = ts
    fc = fc + 1
    if tick() - lt >= 1 then
        FpsL.Text = "FPS: " .. math.floor(fc / (tick() - lt))
        fc = 0; lt = tick()
    end
    local hue = (tick() % 4) / 4
    local rc = Color3.fromHSV(hue, 0.8, 1)
    if _genv.MainRainbowStroke then _genv.MainRainbowStroke.Color = rc end
    if IslandStroke then IslandStroke.Color = rc end
end)

print("========================================")
print("[兮兮 V8.0] 加载完成")
print("[+] 本地 UI：兮兮")
print("[+] 过检测：Verdict " .. Verdict.Profile)
print("[+] 所有脚本：远程加载")
print("========================================")

function Verdict.Destroy()
    Verdict.Alive = false
    for _, c in ipairs(Verdict.Conns) do pcall(function() c:Disconnect() end) end
    Verdict.Conns = {} Verdict.Hooks = {}
    if _genv.__Verdict == Verdict then _genv.__Verdict = nil end
end

function XAC.Destroy()
    XAC.Alive = false
    for _, c in ipairs(XAC.Conns) do pcall(function() c:Disconnect() end) end
    for _, i in ipairs(XAC.Instances) do pcall(function() i:Destroy() end) end
    XAC.Conns = {} XAC.Instances = {} XAC.Hooks = {}
    if _genv.__XAC == XAC then _genv.__XAC = nil end
end

return {Verdict = Verdict, XAC = XAC, Loader = Loader, Config = Config}
