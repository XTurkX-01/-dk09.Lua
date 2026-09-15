# -dk09.Lua
-- ====================================================================
-- 🚀 X MENU | CAR FLING V52 - ESP + AUTO-FLING EDITION
-- ✅ ESP Sistemi (Highlight + Box + Name + Distance + Health + Team Check)
-- ✅ Auto-Fling (Kuyruk + Seçili Oyuncular + İptal + Anti-Fling Bypass)
-- ✅ Multi-Instance Compatibility
-- ✅ Movement (Frontflip + LayDown + Goon)
-- ✅ Tracer Lines Düzeltildi
-- ✅ Renkli Menü (Her Sekme Farklı Renk)
-- ✅ Password 1234 (1 kere)
-- ✅ Fling + Auto-Pilot + Remote + AI + Waypoint + Killcam + Garage + Stats
-- ❌ Bot iptal
-- ====================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then warn("[X52] No LocalPlayer") return end

local CreateFlingEffect
local PlayFlingSound

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

-- ====================================================================
-- 📦 SETTINGS
-- ====================================================================
local Settings = {
    FlingPower = 3500,
    MinFlingPower = 100,
    MaxFlingPower = 50000,
    MaxSpinSpeed = 600,
    FlingCooldown = 1.0,
    FlingRange = 60,
    FlingDamage = 50,
    FlySpeed = 90,
    WaypointSpeed = 100,
    WaypointFlingCooldown = 0.5,
    NoclipActive = false,
    IsFlying = false,
    ClickFlingActive = false,
    IsFlingEveryone = false,
    IsNormalFling = false,
    RespawnProtection = false,
    IsWaypointRunning = false,
    WaypointDirection = 1,
    UseBanSafe = false,
    AntiDetection = false,
    FlingDelayMin = 5,
    FlingDelayMax = 15,
    MaxTargetsPerFrame = 5,
    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
    FPSUnlocker = false,
    Fullbright = false,
    AntiAFK = false,
    AutoRejoin = false,
    ShowFPSCounter = true,
    AntiFling = false,
    -- V52 YENİ
    ESP_Enabled = false,
    ESP_Highlight = true,
    ESP_Box = true,
    ESP_Name = true,
    ESP_Distance = true,
    ESP_Health = true,
    ESP_TeamCheck = true,
    ESP_Color = Color3.fromRGB(0, 255, 0), -- Yeşil
    ESP_SelectedColor = Color3.fromRGB(255, 255, 0), -- Sarı
    TracerLines = false,
    TracerColor = Color3.fromRGB(255, 50, 50),
    AutoFlingActive = false,
    AntiFlingBypass = false,
    Password = "1234",
    IsUnlocked = false,
}

-- ====================================================================
-- 📦 DATA
-- ====================================================================
local VehicleData = {
    Current=nil, MainPart=nil, SavedCFrame=nil, IsAnchored=false,
    LastVehicleCheck=0, VehicleCheckInterval=0.5, LastNoclipVehicle=nil,
    AlignOrientation=nil, StabilizerAttachment=nil, AlignPosition=nil,
    LastKnownVehicle=nil, LastSeatTime=0, RemoteMode=false,
}

local WaypointData = {Point1=nil, Point2=nil}

local State = {
    lastFlingTime=0, isFollowingPlayer=false, targetPlayer=nil,
    targetPosition=nil, isSelectingTarget=false, lastStatusUpdate=0,
    isRespawning=false, lastSoundTime=0, lastEffectTime=0,
    isShuttingDown=false, killCount=0, lastRespawnCheck=0,
    lastPatrolFlingTime=0, lastWaypointFlingTime=0, lastAIMode=nil,
    lastNoclipState=nil, isSelectingPlayer=false, deathCount=0,
    currentStreak=0, bestStreak=0, sessionKills=0, sessionDeaths=0,
    lastAntiAFKTime=0, currentFPS=60, lastFPSUpdate=0,
    framesThisSecond=0, currentMenuScale=1,
    antiFlingConn=nil, lastSafePosition=nil, lastSafeTime=0,
    ESP_LastUpdate=0,
}

local MoveDirection = Vector3.new(0,0,0)
local ActiveKeys = {}
local FlingQueue = {}
local SelectedPlayers = {}
local isAutoPilotActive = false
local currentQueueIndex = 1
local RemoteControlActive = false
local ESPObjects = {} -- player -> {highlight, box, nameLabel, distLabel, healthBar}

local AIData = {
    Enabled=false, Mode="auto", Target=nil, LastTargetSwitch=0,
    TargetSwitchCooldown=2, ThreatRadius=80, AttackRadius=35,
    RetreatHP=30, PatrolPoints={}, MaxPatrolPoints=20,
    CurrentPatrolIndex=1, ScanInterval=0.3, LastScan=0,
    Personality=math.random(),
}

local KillcamBuffer = {}
local KillcamRecording = false
local KILLCAM_MAX = 60

local TracerData = {}
local OriginalLightingSettings = {}

-- ====================================================================
-- 📦 TASK MANAGER
-- ====================================================================
local Connections = {}
local Timers = {}

local function AddConnection(conn)
    table.insert(Connections, conn)
    return conn
end

local function AddTimer()
    local token = {cancelled=false}
    table.insert(Timers, token)
    return token
end

local function TrackTimer(token)
    if not token then return end
    local idx = table.find(Timers, token)
    if idx then table.remove(Timers, idx) end
end

local function CleanupConnections()
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Connections = {}
    for _, token in ipairs(Timers) do
        pcall(function() token.cancelled = true end)
    end
    Timers = {}
end

-- ====================================================================
-- 📦 HELPERS
-- ====================================================================
local function SafeCall(func, ...)
    local ok, result = pcall(func, ...)
    if not ok then warn("[X52] " .. tostring(result)) return nil end
    return result
end

local function RandomInt(min, max)
    return math.random(math.floor(min), math.floor(max))
end

local function GetMainPart(vehicle)
    if not vehicle then return nil end
    return vehicle:FindFirstChild("VehicleSeat")
        or vehicle.PrimaryPart
        or vehicle:FindFirstChildWhichIsA("BasePart")
end

local StatusLabel, KillLabel, StatsLabel, FPSLabel
local function SetStatus(text, color)
    if State.isShuttingDown then return end
    if not StatusLabel or not StatusLabel.Parent then return end
    local now = os.clock()
    if text == StatusLabel.Text and now - State.lastStatusUpdate < 0.1 then return end
    State.lastStatusUpdate = now
    StatusLabel.Text = text
    StatusLabel.TextColor3 = color or Color3.fromRGB(0, 255, 100)
end

-- ====================================================================
-- 👁️ ESP SİSTEMİ (YENİ)
-- ====================================================================
local function IsPlayerSelected(player)
    return SelectedPlayers[player] == true
end

local function GetESPColor(player)
    if IsPlayerSelected(player) then
        return Settings.ESP_SelectedColor
    end
    return Settings.ESP_Color
end

local function CreateESPForPlayer(player)
    if not player or player == LocalPlayer then return end
    if ESPObjects[player] then return end

    local char = player.Character
    if not char then return end

    local espData = {}

    -- Highlight ESP
    local highlight = Instance.new("Highlight")
    highlight.Name = "XESP_Highlight"
    highlight.FillColor = GetESPColor(player)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = char
    highlight.Parent = char
    espData.highlight = highlight

    ESPObjects[player] = espData
end

local function UpdateESPColors()
    for player, data in pairs(ESPObjects) do
        if data.highlight and data.highlight.Parent then
            data.highlight.FillColor = GetESPColor(player)
        end
    end
end

local function RemoveESPForPlayer(player)
    if ESPObjects[player] then
        for _, obj in pairs(ESPObjects[player]) do
            if obj and obj.Parent then
                pcall(function() obj:Destroy() end)
            end
        end
        ESPObjects[player] = nil
    end
end

local function UpdateESPVisibility()
    for player, data in pairs(ESPObjects) do
        if data.highlight then
            data.highlight.Enabled = Settings.ESP_Enabled and Settings.ESP_Highlight
        end
    end
end

local function RefreshAllESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if Settings.ESP_Enabled then
                CreateESPForPlayer(player)
            else
                RemoveESPForPlayer(player)
            end
        end
    end
    UpdateESPVisibility()
    UpdateESPColors()
end

-- ====================================================================
-- 🛡️ ANTI-FLING
-- ====================================================================
local ANTI_FLING_VELOCITY_THRESHOLD = 200
local ANTI_FLING_ANGULAR_THRESHOLD = 80

local function UpdateSafePosition(hrp)
    if not hrp or not hrp.Parent then return end
    local now = os.clock()
    if now - State.lastSafeTime > 0.3 then
        State.lastSafePosition = hrp.CFrame
        State.lastSafeTime = now
    end
end

local function StartAntiFling()
    if State.antiFlingConn then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    State.lastSafePosition = hrp.CFrame
    State.lastSafeTime = os.clock()

    State.antiFlingConn = AddConnection(RunService.Heartbeat:Connect(function()
        if not Settings.AntiFling then return end
        if not hrp or not hrp.Parent then return end

        local linearSpeed = hrp.AssemblyLinearVelocity.Magnitude
        local angularSpeed = hrp.AssemblyAngularVelocity.Magnitude

        local anomaly = linearSpeed > ANTI_FLING_VELOCITY_THRESHOLD
                     or angularSpeed > ANTI_FLING_ANGULAR_THRESHOLD

        if anomaly then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if State.lastSafePosition then
                hrp.CFrame = State.lastSafePosition
            end
            SetStatus("🛡️ Anti-Fling: Engel!", Color3.fromRGB(255, 100, 100))
        else
            UpdateSafePosition(hrp)
        end
    end))
end

local function StopAntiFling()
    if State.antiFlingConn then
        pcall(function() State.antiFlingConn:Disconnect() end)
        State.antiFlingConn = nil
    end
end

-- ====================================================================
-- 🛡️ ANTI-FLING BYPASS (YENİ)
-- ====================================================================
local function BypassAntiFling(target)
    if not target then return false end
    SafeCall(function()
        -- 1) NetworkOwnership al
        pcall(function() target:SetNetworkOwner(LocalPlayer) end)
        -- 2) Anchored kaldır
        if target.Anchored then target.Anchored = false end
        -- 3) Constraint'leri sil
        for _, child in ipairs(target:GetChildren()) do
            if child:IsA("BodyGyro") or child:IsA("BodyVelocity") 
               or child:IsA("AlignOrientation") or child:IsA("AlignPosition")
               or child:IsA("LinearVelocity") or child:IsA("BodyPosition") then
                pcall(function() child:Destroy() end)
            end
        end
    end)
    return true
end

-- ====================================================================
-- 💥 FLING
-- ====================================================================
local function ApplyFling(targetRoot, power, spinSpeed)
    if not targetRoot or not targetRoot.Parent then return false end
    if not targetRoot:IsA("BasePart") then return false end

    power = math.floor(power or Settings.FlingPower)
    spinSpeed = math.floor(spinSpeed or Settings.MaxSpinSpeed)

    if Settings.AntiFlingBypass then
        BypassAntiFling(targetRoot)
    end

    pcall(function() targetRoot:SetNetworkOwner(LocalPlayer) end)

    local mass = targetRoot.AssemblyMass
    if mass < 1 then mass = 1 end

    local direction = Vector3.new(
        math.random() * 2 - 1,
        0.7 + math.random() * 0.8,
        math.random() * 2 - 1
    ).Unit

    local impulse = direction * power * mass * 0.5
    pcall(function() targetRoot:ApplyImpulse(impulse) end)

    targetRoot.AssemblyAngularVelocity = Vector3.new(
        RandomInt(-spinSpeed, spinSpeed),
        RandomInt(-spinSpeed, spinSpeed),
        RandomInt(-spinSpeed, spinSpeed)
    )

    task.delay(0.02, function()
        if targetRoot and targetRoot.Parent then
            pcall(function()
                targetRoot.AssemblyLinearVelocity = Vector3.new(
                    RandomInt(-power, power),
                    RandomInt(math.floor(power * 0.7), math.floor(power * 1.3)),
                    RandomInt(-power, power)
                )
            end)
        end
    end)

    return true
end

local function ScheduleFlingWithDelay(root, power, spinSpeed)
    if not root or not root.Parent then return end
    if Settings.AntiDetection then
        local delay = math.random(Settings.FlingDelayMin, Settings.FlingDelayMax) / 1000
        task.delay(delay, function()
            ApplyFling(root, power, spinSpeed)
        end)
    else
        ApplyFling(root, power, spinSpeed)
    end
end

-- ====================================================================
-- 📦 RAYCAST
-- ====================================================================
local CachedRayParams = RaycastParams.new()
CachedRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function UpdateRayFilter()
    local list = {}
    if LocalPlayer.Character then table.insert(list, LocalPlayer.Character) end
    if VehicleData.Current and VehicleData.Current.Parent then table.insert(list, VehicleData.Current) end
    CachedRayParams.FilterDescendantsInstances = list
end

-- ====================================================================
-- 📦 KILL TRACKER
-- ====================================================================
local KillTracker = {}
local playerKills = {}
local playerDeaths = {}
local playerStreaks = {}
local playerBestStreaks = {}
local recentKillTimestamps = {}

function KillTracker.RegisterKill(killer, victim)
    if killer then
        playerKills[killer] = (playerKills[killer] or 0) + 1
        playerStreaks[killer] = (playerStreaks[killer] or 0) + 1
        playerBestStreaks[killer] = math.max(playerBestStreaks[killer] or 0, playerStreaks[killer])
        if not recentKillTimestamps[killer] then recentKillTimestamps[killer] = {} end
        table.insert(recentKillTimestamps[killer], os.clock())

        local streak = playerStreaks[killer]
        for _, threshold in ipairs({3, 5, 10, 15, 20}) do
            if streak == threshold then
                SetStatus("🔥 " .. killer.Name .. " " .. threshold .. " KILL STREAK!", Color3.fromRGB(255, 200, 0))
            end
        end

        if killer == LocalPlayer then
            State.sessionKills = State.sessionKills + 1
            State.currentStreak = State.currentStreak + 1
            State.bestStreak = math.max(State.bestStreak, State.currentStreak)
            State.killCount = State.killCount + 1
            if KillLabel and KillLabel.Parent then
                KillLabel.Text = "Kills: " .. State.killCount .. " | Streak: " .. State.currentStreak
            end
        end
    end
    if victim then
        playerDeaths[victim] = (playerDeaths[victim] or 0) + 1
        playerStreaks[victim] = 0
        if victim == LocalPlayer then
            State.sessionDeaths = State.sessionDeaths + 1
            State.deathCount = State.deathCount + 1
            State.currentStreak = 0
        end
    end
    KillTracker.UpdateStats()
end

function KillTracker.GetKD(player)
    local k = playerKills[player] or 0
    local d = math.max(playerDeaths[player] or 0, 1)
    return k / d
end

function KillTracker.GetRecentKills(player, window)
    window = window or 15
    local now = os.clock()
    local count = 0
    if recentKillTimestamps[player] then
        for _, t in ipairs(recentKillTimestamps[player]) do
            if now - t <= window then count = count + 1 end
        end
    end
    return count
end

function KillTracker.GetAllStats()
    local result = {}
    for _, p in ipairs(Players:GetPlayers()) do
        result[p] = {
            killsInWindow = KillTracker.GetRecentKills(p, 15),
            currentStreak = playerStreaks[p] or 0,
            kd = KillTracker.GetKD(p),
        }
    end
    return result
end

function KillTracker.UpdateStats()
    if not StatsLabel or not StatsLabel.Parent then return end
    local kd = State.sessionDeaths > 0 and (State.sessionKills / State.sessionDeaths) or State.sessionKills
    StatsLabel.Text = string.format("K: %d | D: %d | K/D: %.2f | Streak: %d | Best: %d",
        State.sessionKills, State.sessionDeaths, kd, State.currentStreak, State.bestStreak)
end

function KillTracker.CalculateMVP()
    local best, bestScore = nil, -math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        local kills = playerKills[p] or 0
        local deaths = playerDeaths[p] or 0
        local bestStreak = playerBestStreaks[p] or 0
        if kills > 0 then
            local score = math.max(0, (kills * 2) - deaths + (bestStreak * 1.5))
            if score > bestScore then
                bestScore = score
                best = p
            end
        end
    end
    return best, bestScore
end

local KillTrackerConnections = {}

local function AttachPlayerKillTracking(player)
    if not player or player == LocalPlayer then return end
    if KillTrackerConnections[player] then return end

    local data = {humConn = nil, charConn = nil}
    KillTrackerConnections[player] = data

    local function attachToHumanoid(humanoid)
        if not humanoid then return end
        if data.humConn then
            pcall(function() data.humConn:Disconnect() end)
            data.humConn = nil
        end
        data.humConn = AddConnection(humanoid.Died:Connect(function()
            if State.isShuttingDown then return end
            local killer = nil
            pcall(function()
                local creator = humanoid:FindFirstChild("creator")
                if not creator and player.Character then
                    creator = player.Character:FindFirstChild("creator")
                end
                if creator and creator.Value then
                    if creator.Value:IsA("Player") then
                        killer = creator.Value
                    else
                        killer = Players:GetPlayerFromCharacter(creator.Value.Parent)
                    end
                end
            end)
            KillTracker.RegisterKill(killer, player)
        end))
    end

    if player.Character then
        local h = player.Character:FindFirstChildOfClass("Humanoid")
        if h then attachToHumanoid(h) end
    end

    data.charConn = AddConnection(player.CharacterAdded:Connect(function(newChar)
        if State.isShuttingDown then return end
        task.delay(0.3, function()
            if State.isShuttingDown then return end
            local h = newChar:FindFirstChildOfClass("Humanoid")
            if h then attachToHumanoid(h) end
        end)
    end))
end

-- ====================================================================
-- 📦 VEHICLE
-- ====================================================================
local function UnanchorVehicle()
    return SafeCall(function()
        if VehicleData.MainPart and VehicleData.MainPart.Parent then
            for _, name in ipairs({"VehicleAlignOrientation", "StabilizerAttachment", "XAlignPos", "XMoveAtt", "XMoveLV", "FlingGyro"}) do
                local obj = VehicleData.MainPart:FindFirstChild(name)
                if obj then obj:Destroy() end
            end
        end
        VehicleData.IsAnchored = false
        VehicleData.SavedCFrame = nil
        VehicleData.AlignOrientation = nil
        VehicleData.StabilizerAttachment = nil
        VehicleData.AlignPosition = nil
    end)
end

local function GetVehicle(forceRefresh)
    local now = os.clock()
    local char = LocalPlayer.Character

    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.SeatPart and hum.SeatPart.Parent then
            local vehicleModel = hum.SeatPart:FindFirstAncestorOfClass("Model") or hum.SeatPart.Parent
            if VehicleData.Current ~= vehicleModel then
                VehicleData.Current = vehicleModel
                VehicleData.LastKnownVehicle = vehicleModel
                VehicleData.LastSeatTime = now
                VehicleData.RemoteMode = false
            end
            return VehicleData.Current
        end
    end

    if RemoteControlActive and VehicleData.LastKnownVehicle and VehicleData.LastKnownVehicle.Parent then
        if now - VehicleData.LastSeatTime < 300 then
            VehicleData.Current = VehicleData.LastKnownVehicle
            VehicleData.RemoteMode = true
            return VehicleData.Current
        end
    end

    if not RemoteControlActive and VehicleData.Current then
        VehicleData.Current = nil
        VehicleData.MainPart = nil
    end
    return nil
end

local function ResetVehicleData()
    UnanchorVehicle()
    VehicleData.Current = nil
    VehicleData.MainPart = nil
    VehicleData.LastVehicleCheck = 0
    VehicleData.LastNoclipVehicle = nil
    State.lastNoclipState = nil
end

local function StabilizeWithAlign(mainPart)
    if not mainPart then return nil end
    local attach = mainPart:FindFirstChild("StabilizerAttachment")
    if not attach then
        attach = Instance.new("Attachment")
        attach.Name = "StabilizerAttachment"
        attach.Parent = mainPart
    end
    local align = mainPart:FindFirstChild("VehicleAlignOrientation")
    if not align then
        align = Instance.new("AlignOrientation")
        align.Name = "VehicleAlignOrientation"
        align.Attachment0 = attach
        align.Mode = Enum.OrientationAlignmentMode.OneAttachment
        align.MaxTorque = math.huge
        align.Responsiveness = 25
        align.RigidityEnabled = false
        local look = mainPart.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude > 0.01 then
            align.CFrame = CFrame.lookAt(mainPart.Position, mainPart.Position + flat.Unit)
        else
            align.CFrame = CFrame.new()
        end
        align.Parent = mainPart
    end
    VehicleData.AlignOrientation = align
    VehicleData.StabilizerAttachment = attach
    return align
end

-- ====================================================================
-- 🚀 REMOTE CONTROL
-- ====================================================================
local function SetRemoteControl(enabled)
    RemoteControlActive = enabled
    if enabled then
        if VehicleData.LastKnownVehicle and VehicleData.LastKnownVehicle.Parent then
            SetStatus("📡 UZAKTAN KONTROL: AKTİF", Color3.fromRGB(0, 255, 200))
        else
            SetStatus("⚠️ Önce bir gemiye bin!", Color3.fromRGB(255, 100, 0))
        end
    else
        SetStatus("📡 Uzaktan kontrol kapalı", Color3.fromRGB(200, 200, 200))
    end
end

AddConnection(LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    AddConnection(hum.Seated:Connect(function(active, seat)
        if active and seat then
            local veh = seat:FindFirstAncestorOfClass("Model") or seat.Parent
            VehicleData.LastKnownVehicle = veh
            VehicleData.LastSeatTime = os.clock()
            SetStatus("🚗 Gemi kaydedildi (uzaktan hazır)", Color3.fromRGB(0, 255, 0))
        end
    end))
end))

-- ====================================================================
-- 🚀 MOVE VEHICLE
-- ====================================================================
local function MoveVehicle(direction, speed)
    local vehicle = GetVehicle()
    if not vehicle then return false end
    local mainPart = GetMainPart(vehicle)
    if not mainPart then return false end

    if mainPart.Anchored then
        for _, part in ipairs(vehicle:GetDescendants()) do
            if part:IsA("BasePart") then part.Anchored = false end
        end
    end

    pcall(function() mainPart:SetNetworkOwner(LocalPlayer) end)

    if direction.Magnitude > 0.01 then
        local att = mainPart:FindFirstChild("XAlignAtt")
        if not att then
            att = Instance.new("Attachment")
            att.Name = "XAlignAtt"
            att.Parent = mainPart
        end

        local ap = mainPart:FindFirstChild("XAlignPos")
        if not ap then
            ap = Instance.new("AlignPosition")
            ap.Name = "XAlignPos"
            ap.Attachment0 = att
            ap.MaxForce = math.huge
            ap.MaxVelocity = speed
            ap.Responsiveness = 25
            ap.RigidityEnabled = false
            ap.Parent = mainPart
        end

        ap.Position = mainPart.Position + direction.Unit * 10
        ap.MaxVelocity = speed

        local lv = mainPart:FindFirstChild("XMoveLV")
        if not lv then
            lv = Instance.new("LinearVelocity")
            lv.Name = "XMoveLV"
            lv.Attachment0 = att
            lv.MaxForce = math.huge
            lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
            lv.Parent = mainPart
        end
        lv.VectorVelocity = direction.Unit * speed
    else
        local lv = mainPart:FindFirstChild("XMoveLV")
        if lv then lv.VectorVelocity = Vector3.new(0,0,0) end
        local ap = mainPart:FindFirstChild("XAlignPos")
        if ap then ap:Destroy() end
    end
    return true
end

local function StopVehicle()
    local vehicle = GetVehicle()
    if not vehicle then return end
    local mainPart = GetMainPart(vehicle)
    if not mainPart then return end
    local lv = mainPart:FindFirstChild("XMoveLV")
    if lv then lv.VectorVelocity = Vector3.new(0,0,0) end
    local ap = mainPart:FindFirstChild("XAlignPos")
    if ap then ap:Destroy() end
    pcall(function()
        mainPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
        mainPart.AssemblyAngularVelocity = Vector3.new(0,0,0)
    end)
end

-- ====================================================================
-- 🎯 EFFECTS
-- ====================================================================
function CreateFlingEffect(position)
    if State.isShuttingDown then return end
    local now = os.clock()
    if now - State.lastEffectTime < 0.1 then return end
    State.lastEffectTime = now
    SafeCall(function()
        for i = 1, 3 do
            local part = Instance.new("Part")
            part.Position = position + Vector3.new(RandomInt(-5,5), RandomInt(-5,5), RandomInt(-5,5))
            part.Size = Vector3.new(1,1,1)
            part.Shape = Enum.PartType.Ball
            part.Material = Enum.Material.Neon
            part.BrickColor = BrickColor.new("Bright red")
            part.Anchored = true
            part.CanCollide = false
            part.CastShadow = false
            part.Transparency = 0.1
            part.Parent = Workspace
            TweenService:Create(part, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {
                Size=Vector3.new(8,8,8), Transparency=1
            }):Play()
            Debris:AddItem(part, 0.8)
        end
    end)
end

function PlayFlingSound(position)
    if State.isShuttingDown then return end
    local now = os.clock()
    if now - State.lastSoundTime < 0.3 then return end
    State.lastSoundTime = now
    SafeCall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://138091579"
        sound.Volume = 0.4
        sound.Parent = Workspace
        sound.Position = position
        sound:Play()
        Debris:AddItem(sound, 5)
    end)
end

-- ====================================================================
-- 💥 FLING ACTION
-- ====================================================================
local function DoFlingAction(multiplier, forceFar)
    if State.isShuttingDown then return end
    return SafeCall(function()
        local vehicle = GetVehicle()
        if not vehicle then SetStatus("❌ GEMİ YOK!", Color3.fromRGB(255,0,0)) return end
        local mainPart = GetMainPart(vehicle)
        if not mainPart then return end

        local range = forceFar and 99999 or Settings.FlingRange
        local hitCount = 0

        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                local hum = player.Character:FindFirstChild("Humanoid")
                if root and hum and hum.Health > 0 then
                    local dist = (root.Position - mainPart.Position).Magnitude
                    if dist <= range then
                        local power = Settings.FlingPower * (multiplier or 1)
                        ApplyFling(root, power, Settings.MaxSpinSpeed)
                        if not Settings.UseBanSafe then
                            hum.Health = math.max(0, hum.Health - Settings.FlingDamage)
                        end
                        CreateFlingEffect(root.Position)
                        PlayFlingSound(root.Position)
                        hitCount = hitCount + 1
                    end
                end
            end
        end

        if hitCount > 0 then
            SetStatus("🔥 " .. hitCount .. " kişi uçuruldu!", Color3.fromRGB(255,200,0))
        end
    end)
end

-- ====================================================================
-- 🎯 AUTO-FLING (YENİ)
-- ====================================================================
local function StartAutoFling()
    if next(SelectedPlayers) == nil then
        SetStatus("❌ Hiç oyuncu seçilmedi!", Color3.fromRGB(255, 0, 0))
        return
    end

    if Settings.AutoFlingActive then
        Settings.AutoFlingActive = false
        SetStatus("⏹️ AUTO-FLING DURDU", Color3.fromRGB(255, 200, 0))
        return
    end

    Settings.AutoFlingActive = true
    SetStatus("🎯 AUTO-FLING BAŞLADI!", Color3.fromRGB(0, 255, 0))

    task.spawn(function()
        while Settings.AutoFlingActive and not State.isShuttingDown do
            for player, _ in pairs(SelectedPlayers) do
                if not Settings.AutoFlingActive then break end
                if not player.Parent or not player.Character then
                    SelectedPlayers[player] = nil
                    continue
                end

                local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
                local targetHum = player.Character:FindFirstChild("Humanoid")
                if targetRoot and targetHum and targetHum.Health > 0 then
                    SetStatus("🎯 Hedefe gidiliyor: " .. player.Name, Color3.fromRGB(0, 200, 255))
                    local vehicle = GetVehicle()
                    if vehicle then
                        local mainPart = GetMainPart(vehicle)
                        if mainPart then
                            local targetPos = targetRoot.Position + Vector3.new(0, 3, 0)
                            local timeout = 5
                            local startT = os.clock()
                            while os.clock() - startT < timeout do
                                if not Settings.AutoFlingActive then break end
                                local diff = targetPos - mainPart.Position
                                if diff.Magnitude < 5 then break end
                                MoveVehicle(diff, Settings.FlySpeed)
                                task.wait(0.1)
                            end
                            StopVehicle()
                            task.wait(0.2)

                            -- Fling (bypass ile)
                            ApplyFling(targetRoot, Settings.FlingPower, Settings.MaxSpinSpeed)
                            if not Settings.UseBanSafe then
                                targetHum.Health = math.max(0, targetHum.Health - Settings.FlingDamage)
                            end
                            CreateFlingEffect(targetRoot.Position)
                            PlayFlingSound(targetRoot.Position)
                            SetStatus("💥 " .. player.Name .. " uçuruldu!", Color3.fromRGB(255, 100, 0))
                            task.wait(0.5)
                        end
                    else
                        SetStatus("❌ Araç yok!", Color3.fromRGB(255, 0, 0))
                        Settings.AutoFlingActive = false
                        return
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

-- ====================================================================
-- 🏃 MOVEMENT (YENİ)
-- ====================================================================
local function DoFrontflip()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, -30)
    SetStatus("🤸 Frontflip!", Color3.fromRGB(0, 200, 255))
end

local function DoLayDown()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(math.rad(-90), 0, 0)
    SetStatus("🛌 LayDown!", Color3.fromRGB(200, 200, 0))
end

local function DoGoon()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://5918726674" -- goon animation
        local track = hum.Animator:LoadAnimation(anim)
        track:Play()
    end)
    SetStatus("🕺 Goon!", Color3.fromRGB(255, 100, 255))
end

-- ====================================================================
-- 📏 TRACER LINES (Düzeltildi)
-- ====================================================================
local TracerGui = Instance.new("Frame")
TracerGui.Name = "TracerLayer"
TracerGui.Size = UDim2.new(1, 0, 1, 0)
TracerGui.BackgroundTransparency = 1
TracerGui.ZIndex = 1

local function CreateTracerFor(player)
    if TracerData[player] then return end
    local line = Instance.new("Frame")
    line.Name = "Tracer_" .. player.Name
    line.BackgroundColor3 = Settings.TracerColor
    line.BorderSizePixel = 0
    line.Size = UDim2.new(0, 2, 0, 0)
    line.Visible = false
    line.ZIndex = 1
    line.Parent = TracerGui
    TracerData[player] = line
end

local function RemoveTracerFor(player)
    if TracerData[player] then
        TracerData[player]:Destroy()
        TracerData[player] = nil
    end
end

local function UpdateTracers()
    if not Settings.TracerLines then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

    local viewportSize = camera.ViewportSize

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local head = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
            if head then
                if not TracerData[player] then CreateTracerFor(player) end
                local line = TracerData[player]
                if line then
                    local screenPos, onScreen = camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        line.Visible = true
                        -- Ekranın ALT ORTASINDAN çizgi
                        local startX = viewportSize.X / 2
                        local startY = viewportSize.Y
                        local endX = screenPos.X
                        local endY = screenPos.Y

                        local midX = (startX + endX) / 2
                        local midY = (startY + endY) / 2
                        local length = math.sqrt((endX - startX)^2 + (endY - startY)^2)
                        local angle = math.deg(math.atan2(endY - startY, endX - startX))

                        line.Size = UDim2.new(0, length, 0, 2)
                        line.Position = UDim2.new(0, midX - length/2, 0, midY)
                        line.Rotation = angle
                        line.BackgroundColor3 = Settings.TracerColor
                    else
                        line.Visible = false
                    end
                end
            end
        end
    end
end

-- ====================================================================
-- 🤖 AI
-- ====================================================================
local function GetPredictedPosition(targetRoot, leadTime)
    leadTime = leadTime or 1.2
    return targetRoot.Position + (targetRoot.AssemblyLinearVelocity * leadTime)
end

local function SelectBestTarget()
    local vehicle = GetVehicle()
    if not vehicle then return nil end
    local mainPart = GetMainPart(vehicle)
    if not mainPart then return nil end

    local bestTarget, bestScore = nil, -math.huge
    local myPos = mainPart.Position
    local playerStats = KillTracker.GetAllStats()

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChild("Humanoid")
            if root and hum and hum.Health > 0 then
                local distance = (root.Position - myPos).Magnitude
                if distance <= AIData.ThreatRadius then
                    local baseScore = (AIData.ThreatRadius - distance) * 1.5
                    if hum.Health < 30 then baseScore = baseScore + 40 end
                    local myLook = mainPart.CFrame.LookVector
                    local toTarget = (root.Position - myPos).Unit
                    if myLook:Dot(toTarget) < 0 then baseScore = baseScore + 25 end

                    local predictedPos = GetPredictedPosition(root)
                    local predDist = (myPos - predictedPos).Magnitude
                    local leadBonus = math.clamp(distance - predDist, 0, 15)
                    local hysteresis = (player == AIData.Target) and 20 or 0

                    local stats = playerStats[player]
                    local threatScore = 0
                    if stats then
                        threatScore = (stats.killsInWindow + stats.currentStreak) * 8
                    end

                    local aggression = 0.7 + (AIData.Personality * 0.6)
                    local finalScore = (baseScore * aggression) + leadBonus + hysteresis + (threatScore * aggression)
                    if finalScore > bestScore then
                        bestScore = finalScore
                        bestTarget = player
                    end
                end
            end
        end
    end
    return bestTarget
end

local function FindNearestThreat()
    local vehicle = GetVehicle()
    if not vehicle then return nil, nil end
    local mainPart = GetMainPart(vehicle)
    if not mainPart then return nil, nil end

    local nearest, nearestDist = nil, math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (root.Position - mainPart.Position).Magnitude
                if dist < nearestDist and dist < AIData.ThreatRadius then
                    nearestDist = dist
                    nearest = player
                end
            end
        end
    end
    return nearest, nearestDist
end

local function UpdateAI()
    if State.isShuttingDown or not AIData.Enabled then return end
    local now = os.clock()
    if now - AIData.LastScan < AIData.ScanInterval then return end
    AIData.LastScan = now

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end

    local vehicle = GetVehicle()
    if not vehicle then return end
    local mainPart = GetMainPart(vehicle)
    if not mainPart then return end

    local mode = AIData.Mode
    if mode == "auto" then
        mode = (hum.Health / hum.MaxHealth < AIData.RetreatHP / 100) and "defensive" or "aggressive"
    end

    if mode == "defensive" then
        local threat, dist = FindNearestThreat()
        if threat and dist then
            local threatRoot = threat.Character and threat.Character:FindFirstChild("HumanoidRootPart")
            if threatRoot then
                local awayDir = (mainPart.Position - threatRoot.Position).Unit
                MoveVehicle(awayDir, Settings.FlySpeed * 1.5)
                SetStatus("🛡️ KAÇIYOR: " .. threat.Name, Color3.fromRGB(255,100,100))
                if dist < Settings.FlingRange and now - State.lastFlingTime > Settings.FlingCooldown then
                    State.lastFlingTime = now
                    DoFlingAction(1.2, false)
                end
            end
        end
        return
    end

    if mode == "aggressive" then
        if now - AIData.LastTargetSwitch > AIData.TargetSwitchCooldown or not AIData.Target then
            local newTarget = SelectBestTarget()
            if newTarget and newTarget ~= AIData.Target then
                AIData.Target = newTarget
                AIData.LastTargetSwitch = now
                SetStatus("🎯 HEDEF: " .. newTarget.Name, Color3.fromRGB(255,200,0))
            elseif not newTarget then
                AIData.LastTargetSwitch = now
            end
        end

        local target = AIData.Target
        if not target or not target.Character then return end
        local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
        local targetHum = target.Character:FindFirstChild("Humanoid")
        if not targetRoot or not targetHum or targetHum.Health <= 0 then
            AIData.Target = nil
            return
        end

        local dist = (targetRoot.Position - mainPart.Position).Magnitude
        if dist > AIData.AttackRadius then
            local dir = (targetRoot.Position - mainPart.Position)
            MoveVehicle(dir, Settings.FlySpeed)
            SetStatus("🏃 KOVALIYOR: " .. target.Name, Color3.fromRGB(255,150,0))
        else
            if now - State.lastFlingTime > Settings.FlingCooldown then
                State.lastFlingTime = now
                DoFlingAction(1.5, false)
                SetStatus("💥 VURULDU: " .. target.Name, Color3.fromRGB(255,50,50))
            end
        end
    end

    if mode == "patrol" and #AIData.PatrolPoints > 0 then
        local targetCF = AIData.PatrolPoints[AIData.CurrentPatrolIndex]
        if targetCF then
            local targetPos = targetCF.Position + Vector3.new(0, 3, 0)
            local dist = (targetPos - mainPart.Position).Magnitude
            if dist < 6 then
                AIData.CurrentPatrolIndex = AIData.CurrentPatrolIndex % #AIData.PatrolPoints + 1
            else
                MoveVehicle(targetPos - mainPart.Position, Settings.WaypointSpeed)
            end

            if now - State.lastPatrolFlingTime > Settings.FlingCooldown then
                State.lastPatrolFlingTime = now
                DoFlingAction(1, false)
            end
        end
    end
end

-- ====================================================================
-- 🛤️ WAYPOINT
-- ====================================================================
local WaypointState = {transitioning = false}

local function WaypointLoop()
    if State.isShuttingDown or not Settings.IsWaypointRunning then return end
    if not WaypointData.Point1 or not WaypointData.Point2 then return end
    if WaypointState.transitioning then return end

    local vehicle = GetVehicle()
    if not vehicle then return end
    local mainPart = GetMainPart(vehicle)
    if not mainPart then return end

    local targetCF = Settings.WaypointDirection == 1 and WaypointData.Point1 or WaypointData.Point2
    if not targetCF then return end

    local targetPos = targetCF.Position + Vector3.new(0, 3, 0)
    local diff = targetPos - mainPart.Position
    local distance = diff.Magnitude

    if distance > 5 then
        MoveVehicle(diff, Settings.WaypointSpeed)
        local now = os.clock()
        if now - State.lastWaypointFlingTime > Settings.WaypointFlingCooldown then
            State.lastWaypointFlingTime = now
            DoFlingAction(1.2, false)
        end
        SetStatus("🛤️ WAYPOINT + FLING", Color3.fromRGB(255,200,0))
    else
        WaypointState.transitioning = true
        StopVehicle()
        SetStatus("✅ Noktaya varıldı", Color3.fromRGB(0,255,0))
        task.wait(0.5)
        Settings.WaypointDirection = Settings.WaypointDirection * -1
        WaypointState.transitioning = false
    end
end

local function GoToPoint(pointCF)
    if not pointCF then return end
    local vehicle = GetVehicle()
    if not vehicle then SetStatus("❌ GEMİ YOK!", Color3.fromRGB(255,0,0)) return end
    local mainPart = GetMainPart(vehicle)
    if not mainPart then return end

    task.spawn(function()
        local targetPos = pointCF.Position + Vector3.new(0, 3, 0)
        while true do
            if State.isShuttingDown then break end
            local diff = targetPos - mainPart.Position
            if diff.Magnitude < 5 then
                StopVehicle()
                SetStatus("✅ Hedefe varıldı!", Color3.fromRGB(0,255,0))
                break
            end
            MoveVehicle(diff, Settings.WaypointSpeed)
            task.wait(0.1)
        end
    end)
end

-- ====================================================================
-- 📦 KILLCAM
-- ====================================================================
local function StartKillcamRecording()
    if KillcamRecording then return end
    KillcamRecording = true
    task.spawn(function()
        while KillcamRecording and not State.isShuttingDown do
            task.wait(0.05)
            local vehicle = GetVehicle()
            if vehicle then
                local mainPart = GetMainPart(vehicle)
                if mainPart then
                    table.insert(KillcamBuffer, {cframe = mainPart.CFrame, timestamp = os.clock()})
                    if #KillcamBuffer > KILLCAM_MAX then
                        table.remove(KillcamBuffer, 1)
                    end
                end
            end
        end
    end)
end

local function StopKillcamRecording()
    KillcamRecording = false
end

local function PlayKillcam(replayPart)
    if #KillcamBuffer == 0 then return end
    task.spawn(function()
        local startTime = os.clock()
        local firstTs = KillcamBuffer[1].timestamp
        for _, sample in ipairs(KillcamBuffer) do
            local elapsed = sample.timestamp - firstTs
            local waitTime = (startTime + elapsed) - os.clock()
            if waitTime > 0 then task.wait(waitTime) end
            if replayPart and replayPart.Parent then
                replayPart.CFrame = sample.cframe
            end
        end
    end)
end

-- ====================================================================
-- 📱 SCREEN GUI
-- ====================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "XMenuV52_" .. tostring(math.random(1000, 9999))
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999

local parented = pcall(function()
    ScreenGui.Parent = game:GetService("CoreGui")
end)
if not parented then
    if PlayerGui then ScreenGui.Parent = PlayerGui end
end

TracerGui.Parent = ScreenGui

-- ====================================================================
-- 🔐 PASSWORD GUI
-- ====================================================================
local PasswordGui = Instance.new("Frame")
PasswordGui.Size = UDim2.new(0, 300, 0, 180)
PasswordGui.Position = UDim2.new(0.5, -150, 0.5, -90)
PasswordGui.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
PasswordGui.BorderSizePixel = 0
PasswordGui.Active = true
PasswordGui.Visible = true
PasswordGui.ZIndex = 9999999
PasswordGui.Parent = ScreenGui
Instance.new("UICorner", PasswordGui).CornerRadius = UDim.new(0, 12)

local PwdStroke = Instance.new("UIStroke")
PwdStroke.Color = Color3.fromRGB(0, 255, 0)
PwdStroke.Thickness = 3
PwdStroke.Parent = PasswordGui

local PwdTitle = Instance.new("TextLabel")
PwdTitle.Text = "🔒 X MENU V52 ŞİFRE"
PwdTitle.Size = UDim2.new(1, 0, 0, 30)
PwdTitle.Position = UDim2.new(0, 0, 0, 10)
PwdTitle.BackgroundTransparency = 1
PwdTitle.TextColor3 = Color3.fromRGB(0, 255, 100)
PwdTitle.Font = Enum.Font.GothamBold
PwdTitle.TextSize = 16
PwdTitle.Parent = PasswordGui

local PwdDesc = TextLabel = Instance.new("TextLabel")
PwdDesc.Text = "Şifre: 1234"
PwdDesc.Size = UDim2.new(1, 0, 0, 18)
PwdDesc.Position = UDim2.new(0, 0, 0, 40)
PwdDesc.BackgroundTransparency = 1
PwdDesc.TextColor3 = Color3.fromRGB(150, 150, 150)
PwdDesc.Font = Enum.Font.Gotham
PwdDesc.TextSize = 11
PwdDesc.Parent = PasswordGui

local PwdInput = Instance.new("TextBox")
PwdInput.PlaceholderText = "Şifre"
PwdInput.Size = UDim2.new(1, -40, 0, 36)
PwdInput.Position = UDim2.new(0, 20, 0, 65)
PwdInput.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
PwdInput.TextColor3 = Color3.fromRGB(255, 255, 255)
PwdInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
PwdInput.Font = Enum.Font.Gotham
PwdInput.TextSize = 14
PwdInput.Parent = PasswordGui
Instance.new("UICorner", PwdInput).CornerRadius = UDim.new(0, 6)

local PwdBtn = Instance.new("TextButton")
PwdBtn.Text = "🔓 GİRİŞ"
PwdBtn.Size = UDim2.new(1, -40, 0, 34)
PwdBtn.Position = UDim2.new(0, 20, 0, 110)
PwdBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
PwdBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PwdBtn.Font = Enum.Font.GothamBold
PwdBtn.TextSize = 14
PwdBtn.Parent = PasswordGui
Instance.new("UICorner", PwdBtn).CornerRadius = UDim.new(0, 6)

local PwdError = Instance.new("TextLabel")
PwdError.Text = ""
PwdError.Size = UDim2.new(1, 0, 0, 16)
PwdError.Position = UDim2.new(0, 0, 1, -22)
PwdError.BackgroundTransparency = 1
PwdError.TextColor3 = Color3.fromRGB(255, 50, 50)
PwdError.Font = Enum.Font.Gotham
PwdError.TextSize = 11
PwdError.Parent = PasswordGui

local function TryUnlock()
    if PwdInput.Text == Settings.Password then
        Settings.IsUnlocked = true
        PasswordGui.Visible = false
        SetStatus("✅ Şifre doğru! Menü hazır", Color3.fromRGB(0, 255, 100))
    else
        PwdError.Text = "❌ Yanlış şifre!"
        PwdInput.Text = ""
    end
end

AddConnection(PwdBtn.MouseButton1Click:Connect(TryUnlock))
AddConnection(PwdInput.FocusLost:Connect(function(enter)
    if enter then TryUnlock() end
end))

-- ====================================================================
-- 📱 UI HELPERS
-- ====================================================================
local function MakeDraggable(frame, dragBar)
    dragBar = dragBar or frame
    local dragging, dragStart, startPos = false, nil, nil
    local DRAG_THRESHOLD = 10

    AddConnection(dragBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end))

    AddConnection(dragBar.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > DRAG_THRESHOLD or input.UserInputType == Enum.UserInputType.MouseMovement then
                frame.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end
    end))

    AddConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

-- ====================================================================
-- 📱 MAIN MENU
-- ====================================================================
local ORIGINAL_WIDTH = 500
local ORIGINAL_HEIGHT = 400
local MIN_WIDTH, MIN_HEIGHT = 300, 250
local MAX_WIDTH, MAX_HEIGHT = 750, 600

local XMenu = Instance.new("Frame")
XMenu.Name = "XMenu"
XMenu.Size = UDim2.new(0, ORIGINAL_WIDTH, 0, ORIGINAL_HEIGHT)
XMenu.Position = UDim2.new(0.5, -ORIGINAL_WIDTH/2, 0.5, -ORIGINAL_HEIGHT/2)
XMenu.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
XMenu.BackgroundTransparency = 0.15
XMenu.BorderSizePixel = 0
XMenu.Active = true
XMenu.Visible = false
XMenu.Parent = ScreenGui
Instance.new("UICorner", XMenu).CornerRadius = UDim.new(0, 12)

local XMenuStroke = Instance.new("UIStroke")
XMenuStroke.Color = Color3.fromRGB(200, 0, 0)
XMenuStroke.Thickness = 3
XMenuStroke.Transparency = 0.1
XMenuStroke.Parent = XMenu

local pulseInfo = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
TweenService:Create(XMenuStroke, pulseInfo, {Color = Color3.fromRGB(80, 0, 0)}):Play()

local innerGlow = Instance.new("Frame")
innerGlow.Size = UDim2.new(1, -6, 1, -6)
innerGlow.Position = UDim2.new(0, 3, 0, 3)
innerGlow.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
innerGlow.BackgroundTransparency = 0.97
innerGlow.BorderSizePixel = 0
innerGlow.ZIndex = 0
innerGlow.Parent = XMenu
Instance.new("UICorner", innerGlow).CornerRadius = UDim.new(0, 10)

local menuUIScale = Instance.new("UIScale")
menuUIScale.Scale = 1
menuUIScale.Parent = XMenu

-- ====================================================================
-- TITLE BAR
-- ====================================================================
local XTitleBar = Instance.new("Frame")
XTitleBar.Size = UDim2.new(1, 0, 0, 34)
XTitleBar.BackgroundColor3 = Color3.fromRGB(5, 35, 5)
XTitleBar.BackgroundTransparency = 0.1
XTitleBar.Parent = XMenu
Instance.new("UICorner", XTitleBar).CornerRadius = UDim.new(0, 12)

local XTitleText = Instance.new("TextLabel")
XTitleText.Text = "⚡ X MENU | V52"
XTitleText.Size = UDim2.new(1, -130, 1, 0)
XTitleText.Position = UDim2.new(0, 12, 0, 0)
XTitleText.BackgroundTransparency = 1
XTitleText.TextColor3 = Color3.fromRGB(0, 255, 100)
XTitleText.Font = Enum.Font.GothamBold
XTitleText.TextSize = 14
XTitleText.TextXAlignment = Enum.TextXAlignment.Left
XTitleText.Parent = XTitleBar

local XResizeMinusBtn = Instance.new("TextButton")
XResizeMinusBtn.Text = "-"
XResizeMinusBtn.Size = UDim2.new(0, 24, 0, 26)
XResizeMinusBtn.Position = UDim2.new(1, -118, 0, 4)
XResizeMinusBtn.BackgroundColor3 = Color3.fromRGB(0, 60, 60)
XResizeMinusBtn.TextColor3 = Color3.fromRGB(255,255,255)
XResizeMinusBtn.Font = Enum.Font.GothamBold
XResizeMinusBtn.TextSize = 16
XResizeMinusBtn.Parent = XTitleBar
Instance.new("UICorner", XResizeMinusBtn).CornerRadius = UDim.new(0, 6)

local XResizePlusBtn = Instance.new("TextButton")
XResizePlusBtn.Text = "+"
XResizePlusBtn.Size = UDim2.new(0, 24, 0, 26)
XResizePlusBtn.Position = UDim2.new(1, -92, 0, 4)
XResizePlusBtn.BackgroundColor3 = Color3.fromRGB(0, 60, 60)
XResizePlusBtn.TextColor3 = Color3.fromRGB(255,255,255)
XResizePlusBtn.Font = Enum.Font.GothamBold
XResizePlusBtn.TextSize = 16
XResizePlusBtn.Parent = XTitleBar
Instance.new("UICorner", XResizePlusBtn).CornerRadius = UDim.new(0, 6)

local XResizeResetBtn = Instance.new("TextButton")
XResizeResetBtn.Text = "R"
XResizeResetBtn.Size = UDim2.new(0, 24, 0, 26)
XResizeResetBtn.Position = UDim2.new(1, -66, 0, 4)
XResizeResetBtn.BackgroundColor3 = Color3.fromRGB(0, 60, 60)
XResizeResetBtn.TextColor3 = Color3.fromRGB(255,255,255)
XResizeResetBtn.Font = Enum.Font.GothamBold
XResizeResetBtn.TextSize = 14
XResizeResetBtn.Parent = XTitleBar
Instance.new("UICorner", XResizeResetBtn).CornerRadius = UDim.new(0, 6)

local XMinBtn = Instance.new("TextButton")
XMinBtn.Text = "−"
XMinBtn.Size = UDim2.new(0, 24, 0, 26)
XMinBtn.Position = UDim2.new(1, -40, 0, 4)
XMinBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
XMinBtn.TextColor3 = Color3.fromRGB(255,255,255)
XMinBtn.Font = Enum.Font.GothamBold
XMinBtn.TextSize = 16
XMinBtn.Parent = XTitleBar
Instance.new("UICorner", XMinBtn).CornerRadius = UDim.new(0, 6)

local XCloseBtn = Instance.new("TextButton")
XCloseBtn.Text = "✕"
XCloseBtn.Size = UDim2.new(0, 24, 0, 26)
XCloseBtn.Position = UDim2.new(1, -14, 0, 4)
XCloseBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
XCloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
XCloseBtn.Font = Enum.Font.GothamBold
XCloseBtn.TextSize = 14
XCloseBtn.Parent = XTitleBar
Instance.new("UICorner", XCloseBtn).CornerRadius = UDim.new(0, 6)

MakeDraggable(XMenu, XTitleBar)

local function ApplyMenuResize(scale)
    scale = math.clamp(scale, 0.6, 1.5)
    local newW = math.clamp(ORIGINAL_WIDTH * scale, MIN_WIDTH, MAX_WIDTH)
    local newH = math.clamp(ORIGINAL_HEIGHT * scale, MIN_HEIGHT, MAX_HEIGHT)
    local realScale = newW / ORIGINAL_WIDTH
    State.currentMenuScale = realScale

    local ti = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
    TweenService:Create(XMenu, ti, {Size = UDim2.new(0, newW, 0, newH)}):Play()
    TweenService:Create(menuUIScale, ti, {Scale = 1}):Play()
end

AddConnection(XResizeMinusBtn.MouseButton1Click:Connect(function()
    ApplyMenuResize(State.currentMenuScale * 0.85)
end))

AddConnection(XResizePlusBtn.MouseButton1Click:Connect(function()
    ApplyMenuResize(State.currentMenuScale * 1.15)
end))

AddConnection(XResizeResetBtn.MouseButton1Click:Connect(function()
    ApplyMenuResize(1)
end))

-- ====================================================================
-- LEFT TAB BAR (Renkli)
-- ====================================================================
local XLeftMenu = Instance.new("ScrollingFrame")
XLeftMenu.Size = UDim2.new(0, 125, 1, -34)
XLeftMenu.Position = UDim2.new(0, 0, 0, 34)
XLeftMenu.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
XLeftMenu.BackgroundTransparency = 0.2
XLeftMenu.BorderSizePixel = 0
XLeftMenu.ScrollBarThickness = 3
XLeftMenu.CanvasSize = UDim2.new(0, 0, 0, 0)
XLeftMenu.Parent = XMenu

local LeftLayout = Instance.new("UIListLayout")
LeftLayout.Padding = UDim.new(0, 3)
LeftLayout.Parent = XLeftMenu

LeftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    XLeftMenu.CanvasSize = UDim2.new(0, 0, 0, LeftLayout.AbsoluteContentSize.Y + 10)
end)

local function CreateTabBtn(text, accentColor)
    local btn = Instance.new("TextButton")
    btn.Text = text
    btn.Size = UDim2.new(1, -8, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = XLeftMenu
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    local c = Instance.new("UITextSizeConstraint")
    c.MinTextSize = 9
    c.MaxTextSize = 12
    c.Parent = btn

    btn:SetAttribute("AccentColor", accentColor)
    return btn
end

-- Renkli sekmeler (her biri farklı)
local Tabs = {
    Fling = CreateTabBtn("💥 FLING", Color3.fromRGB(0, 255, 100)),        -- Zümrüt Yeşili
    ESP = CreateTabBtn("👁️ ESP", Color3.fromRGB(0, 255, 0)),               -- Parlak Yeşil
    AutoFling = CreateTabBtn("🎯 AUTO-FLING", Color3.fromRGB(255, 200, 0)), -- Altın Sarısı
    Remote = CreateTabBtn("📡 REMOTE", Color3.fromRGB(0, 200, 255)),       -- Elmas Mavisi
    AI = CreateTabBtn("🤖 AI", Color3.fromRGB(180, 80, 255)),               -- Mor
    Fly = CreateTabBtn("🛫 FLY", Color3.fromRGB(80, 150, 255)),             -- Gök Mavisi
    Waypoint = CreateTabBtn("🛤️ PATH", Color3.fromRGB(255, 150, 50)),       -- Turuncu
    Track = CreateTabBtn("🎯 TRACK", Color3.fromRGB(100, 255, 200)),        -- Mint Yeşili
    Movement = CreateTabBtn("🏃 MOVEMENT", Color3.fromRGB(255, 100, 200)),  -- Pembe
    Utility = CreateTabBtn("🛠️ UTILITY", Color3.fromRGB(255, 80, 80)),      -- Kırmızı
    Players = CreateTabBtn("👥 PLAYERS", Color3.fromRGB(200, 100, 255)),    -- Lila
    Settings = CreateTabBtn("⚙️ SETTINGS", Color3.fromRGB(180, 180, 180)),  -- Gri
    Garage = CreateTabBtn("🏎️ GARAGE", Color3.fromRGB(200, 200, 0)),        -- Hardal
    Killcam = CreateTabBtn("🎬 KILLCAM", Color3.fromRGB(200, 50, 50)),      -- Bordo
    Stats = CreateTabBtn("📊 STATS", Color3.fromRGB(100, 200, 255)),        -- Açık Mavi
}

local XMidPanel = Instance.new("Frame")
XMidPanel.Size = UDim2.new(1, -125, 1, -34)
XMidPanel.Position = UDim2.new(0, 125, 0, 34)
XMidPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
XMidPanel.BackgroundTransparency = 1
XMidPanel.Parent = XMenu

local function CreatePage()
    local p = Instance.new("ScrollingFrame")
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 3
    p.CanvasSize = UDim2.new(0, 0, 0, 0)
    p.Visible = false
    p.Parent = XMidPanel
    return p
end

local Pages = {
    Fling = CreatePage(), ESP = CreatePage(), AutoFling = CreatePage(),
    Remote = CreatePage(), AI = CreatePage(), Fly = CreatePage(),
    Waypoint = CreatePage(), Track = CreatePage(), Movement = CreatePage(),
    Utility = CreatePage(), Players = CreatePage(), Settings = CreatePage(),
    Garage = CreatePage(), Killcam = CreatePage(), Stats = CreatePage(),
}

local AllPages, AllTabs = {}, {}
for k, v in pairs(Pages) do table.insert(AllPages, v) end
for k, v in pairs(Tabs) do table.insert(AllTabs, v) end

local function SwitchTab(activePage, activeBtn)
    for _, p in ipairs(AllPages) do p.Visible = false end
    for _, b in ipairs(AllTabs) do
        b.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
        b.TextColor3 = Color3.fromRGB(200, 200, 200)
    end
    activePage.Visible = true
    local accent = activeBtn:GetAttribute("AccentColor") or Color3.fromRGB(180, 0, 0)
    activeBtn.BackgroundColor3 = accent
    activeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
end

for tabName, tab in pairs(Tabs) do
    if Pages[tabName] then
        tab.MouseButton1Click:Connect(function()
            SwitchTab(Pages[tabName], tab)
        end)
    end
end

for _, page in ipairs(AllPages) do
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 15)
    end)
end

local function CreateBtn(parent, text, color, order)
    local btn = Instance.new("TextButton")
    btn.Text = text
    btn.Size = UDim2.new(1, -16, 0, 32)
    btn.BackgroundColor3 = color
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.LayoutOrder = order or 0
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    local c = Instance.new("UITextSizeConstraint")
    c.MinTextSize = 10
    c.MaxTextSize = 13
    c.Parent = btn
    return btn
end

local function CreateInput(parent, placeholder, order)
    local box = Instance.new("TextBox")
    box.PlaceholderText = placeholder
    box.Size = UDim2.new(1, -16, 0, 28)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    box.TextColor3 = Color3.fromRGB(255,255,255)
    box.PlaceholderColor3 = Color3.fromRGB(150,150,150)
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.LayoutOrder = order or 0
    box.Parent = parent
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 5)
    return box
end

local function CreateLabel(parent, text, color, order)
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(1, -16, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = color or Color3.fromRGB(200,200,200)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order or 0
    lbl.Parent = parent
    return lbl
end

-- ═══════════════════════════════════════════════════════════════
-- 💥 FLING PAGE
-- ═══════════════════════════════════════════════════════════════
CreateLabel(Pages.Fling, "💥 FLING CONTROLS", Color3.fromRGB(0, 255, 100), 1)
local FlingBtn = CreateBtn(Pages.Fling, "💥 FLING ALL (nearby)", Color3.fromRGB(200, 0, 0), 2)
local FlingFarBtn = CreateBtn(Pages.Fling, "🌍 FLING EVERYONE (far)", Color3.fromRGB(140, 0, 80), 3)
local NormalFlingBtn = CreateBtn(Pages.Fling, "🌀 FLING ON (continuous)", Color3.fromRGB(0, 80, 80), 4)
local ClickBtn = CreateBtn(Pages.Fling, "👆 CLICK FLING: OFF", Color3.fromRGB(120, 20, 20), 5)
CreateLabel(Pages.Fling, "Fling Power:", nil, 6)
local PowerInput = CreateInput(Pages.Fling, "3500", 7)
local PowerSetBtn = CreateBtn(Pages.Fling, "✅ SET POWER", Color3.fromRGB(20, 80, 20), 8)
CreateLabel(Pages.Fling, "Range (stud):", nil, 9)
local RangeInput = CreateInput(Pages.Fling, "60", 10)
local RangeSetBtn = CreateBtn(Pages.Fling, "✅ SET RANGE", Color3.fromRGB(20, 80, 20), 11)
local CancelBtn = CreateBtn(Pages.Fling, "❌ CANCEL ALL", Color3.fromRGB(80, 20, 20), 12)

-- ═══════════════════════════════════════════════════════════════
-- 👁️ ESP PAGE (YENİ)
-- ═══════════════════════════════════════════════════════════════
CreateLabel(Pages.ESP, "👁️ ESP SİSTEMİ", Color3.fromRGB(0, 255, 0), 1)
local ESPToggleBtn = CreateBtn(Pages.ESP, "👁️ ESP: OFF", Color3.fromRGB(0, 100, 0), 2)
local ESPHighlightBtn = CreateBtn(Pages.ESP, "🔴 Highlight: ON", Color3.fromRGB(0, 150, 0), 3)
local ESPBoxBtn = CreateBtn(Pages.ESP, "📦 Box: ON", Color3.fromRGB(0, 150, 0), 4)
local ESPNameBtn = CreateBtn(Pages.ESP, "📝 Name: ON", Color3.fromRGB(0, 150, 0), 5)
local ESPDistanceBtn = CreateBtn(Pages.ESP, "📏 Distance: ON", Color3.fromRGB(0, 150, 0), 6)
local ESPHealthBtn = CreateBtn(Pages.ESP, "❤️ Health Bar: ON", Color3.fromRGB(0, 150, 0), 7)
local ESPTeamBtn = CreateBtn(Pages.ESP, "👥 Team Check: ON", Color3.fromRGB(0, 150, 0), 8)
CreateLabel(Pages.ESP, "ESP kapatınca araç durur", Color3.fromRGB(200, 200, 100), 9)

-- ═══════════════════════════════════════════════════════════════
-- 🎯 AUTO-FLING PAGE (YENİ)
-- ═══════════════════════════════════════════════════════════════
CreateLabel(Pages.AutoFling, "🎯 AUTO-FLING SİSTEMİ", Color3.fromRGB(255, 200, 0), 1)

local AutoFlingScroll = Instance.new("ScrollingFrame")
AutoFlingScroll.Size = UDim2.new(1, -16, 0, 180)
AutoFlingScroll.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
AutoFlingScroll.BorderSizePixel = 0
AutoFlingScroll.ScrollBarThickness = 3
AutoFlingScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
AutoFlingScroll.LayoutOrder = 2
AutoFlingScroll.Parent = Pages.AutoFling
Instance.new("UICorner", AutoFlingScroll).CornerRadius = UDim.new(0, 6)

local AutoFlingLayout = Instance.new("UIListLayout")
AutoFlingLayout.Padding = UDim.new(0, 3)
AutoFlingLayout.Parent = AutoFlingScroll

local AutoFlingStartBtn = CreateBtn(Pages.AutoFling, "▶️ START AUTO-FLING", Color3.fromRGB(0, 150, 0), 3)
local AutoFlingCancelBtn = CreateBtn(Pages.AutoFling, "❌ CANCEL", Color3.fromRGB(180, 0, 0), 4)
local AutoFlingBypassBtn = CreateBtn(Pages.AutoFling, "🛡️ ANTI-FLING BYPASS: OFF", Color3.fromRGB(100, 100, 0), 5)

-- ═══════════════════════════════════════════════════════════════
-- 📡 REMOTE PAGE
-- ═══════════════════════════════════════════════════════════════
CreateLabel(Pages.Remote, "📡 REMOTE CONTROL", Color3.fromRGB(0, 200, 255), 1)
local RemoteToggleBtn = CreateBtn(Pages.Remote, "📡 REMOTE: OFF", Color3.fromRGB(60, 60, 60), 2)
CreateLabel(Pages.Remote, "1) Get in vehicle (saves it)", Color3.fromRGB(150, 200, 150), 3)
CreateLabel(Pages.Remote, "2) Enable remote control", Color3.fromRGB(150, 200, 150), 4)
CreateLabel(Pages.Remote, "3) Vehicle drives itself, you stay", Color3.fromRGB(150, 200, 150), 5)

-- ═══════════════════════════════════════════════════════════════
-- 🤖 AI PAGE
-- ═══════════════════════════════════════════════════════════════
CreateLabel(Pages.AI, "🤖 AI SYSTEM", Color3.fromRGB(200, 100, 255), 1)
local AIBtn = CreateBtn(Pages.AI, "🤖 AI: OFF", Color3.fromRGB(80, 0, 120), 2)
local AIModeBtn = CreateBtn(Pages.AI, "🎯 MODE: AUTO", Color3.fromRGB(60, 0, 80), 3)
local PatrolAddBtn = CreateBtn(Pages.AI, "📍 ADD PATROL POINT", Color3.fromRGB(40, 40, 100), 4)

-- ═══════════════════════════════════════════════════════════════
-- 🛫 FLY PAGE
-- ═══════════════════════════════════════════════════════════════
CreateLabel(Pages.Fly, "🛫 FLIGHT CONTROLS", Color3.fromRGB(100, 200, 255), 1)
local FlyBtn = CreateBtn(Pages.Fly, "🛫 FLY: OFF", Color3.fromRGB(120, 20, 20), 2)
local FlyButtonsBtn = CreateBtn(Pages.Fly, "🎮 SHOW BUTTONS: OFF", Color3.fromRGB(50, 50, 100), 3)
local NoclipBtn = CreateBtn(Pages.Fly, "🚫 NOCLIP: OFF", Color3.fromRGB(80, 30, 30), 4)

-- ═══════════════════════════════════════════════════════════════
-- 🛤️ WAYPOINT PAGE
-- ═══════════════════════════════════════════════════════════════
CreateLabel(Pages.Waypoint, "🛤️ WAYPOINTS", Color3.fromRGB(255, 200, 100), 1)
local Point1Btn = CreateBtn(Pages.Waypoint, "📍 SAVE POINT 1", Color3.fromRGB(30, 60, 30), 2)
local Point2Btn = CreateBtn(Pages.Waypoint, "📍 SAVE POINT 2", Color3.fromRGB(30, 60, 30), 3)
local GoPoint1Btn = CreateBtn(Pages.Waypoint, "🚀 GO TO POINT 1", Color3.fromRGB(20, 120, 20), 4)
local GoPoint2Btn = CreateBtn(Pages.Waypoint, "🚀 GO TO POINT 2", Color3.fromRGB(120, 50, 20), 5)
local WaypointLoopBtn = CreateBtn(Pages.Waypoint, "🔄 LOOP: OFF", Color3.fromRGB(60, 60, 20), 6)

-- ═══════════════════════════════════════════════════════════════
-- 🎯 TRACK PAGE
-- ═══════════════════════════════════════════════════════════════
CreateLabel(Pages.Track, "🎯 TRACK / TARGET", Color3.fromRGB(100, 255, 200), 1)
local TargetBtn = CreateBtn(Pages.Track, "📍 SET TARGET", Color3.fromRGB(30, 30, 80), 2)
local SelectPlayerBtn = CreateBtn(Pages.Track, "👤 SELECT PLAYER", Color3.fromRGB(30, 80, 30), 3)
local FollowBtn = CreateBtn(Pages.Track, "🚀 FOLLOW: OFF", Color3.fromRGB(70, 30, 70), 4)
local GotoBtn = CreateBtn(Pages.Track, "📍 BRING VEHICLE", Color3.fromRGB(0, 80, 80), 5)

-- ═══════════════════════════════════════════════════════════════
-- 🏃 MOVEMENT PAGE (YENİ)
-- ═══════════════════════════════════════════════════════════════
CreateLabel(Pages.Movement, "🏃 MOVEMENT", Color3.fromRGB(255, 100, 200), 1)
local FrontflipBtn = CreateBtn(Pages.Movement, "🤸 FRONTFLIP (F)", Color3.fromRGB(0, 150, 200), 2)
local LayDownBtn = CreateBtn(Pages.Movement, "🛌 LAYDOWN (G)", Color3.fromRGB(200, 200, 0), 3)
local GoonBtn = CreateBtn(Pages.Movement, "🕺 GOON (H)", Color3.fromRGB(200, 0, 200), 4)

-- ═══════════════════════════════════════════════════════════════
-- 🛠️ UTILITY PAGE
-- ═══════════════════════════════════════════════════════════════
CreateLabel(Pages.Utility, "🛠️ UTILITY TOOLS", Color3.fromRGB(255, 80, 80), 1)
local MultiInstanceBtn = CreateBtn(Pages.Utility, "🖥️ Multi-Instance: OFF", Color3.fromRGB(60, 60, 100), 2)
local ServerHopBtn = CreateBtn(Pages.Utility, "🌐 Server Hop", Color3.fromRGB(0, 100, 200), 3)
local AntiAFKBtn = CreateBtn(Pages.Utility, "💤 Anti-AFK: OFF", Color3.fromRGB(60, 60, 100), 4)
local FullbrightBtn = CreateBtn(Pages.Utility, "☀️ Fullbright: OFF", Color3.fromRGB(60, 60, 100), 5)
local FPSUnlockBtn = CreateBtn(Pages.Utility, "⚡ FPS Unlocker: OFF", Color3.fromRGB(60, 60, 100), 6)
local AntiFlingBtn = CreateBtn(Pages.Utility, "🛡️ Anti-Fling: OFF", Color3.fromRGB(60, 100, 100), 7)

-- ═══════════════════════════════════════════════════════════════
-- 👥 PLAYERS PAGE
-- ═══════════════════════════════════════════════════════════════
CreateLabel(Pages.Players, "👥 PLAYER LIST", Color3.fromRGB(200, 100, 255), 1)
local PlayerScroll = Instance.new("ScrollingFrame")
PlayerScroll.Size = UDim2.new(1, -16, 0, 260)
PlayerScroll.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
PlayerScroll.BorderSizePixel = 0
PlayerScroll.ScrollBarThickness = 3
PlayerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
PlayerScroll.LayoutOrder = 2
PlayerScroll.Parent = Pages.Players
Instance.new("UICorner", PlayerScroll).CornerRadius = UDim.new(0, 6)

local PlayerLayout = Instance.new("UIListLayout")
PlayerLayout.Padding = UDim.new(0, 3)
PlayerLayout.Parent = PlayerScroll

local function RefreshPlayerList()
    for _, child in ipairs(PlayerScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, child in ipairs(AutoFlingScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local count = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            count = count + 1
            local kd = KillTracker.GetKD(player)

            -- Players sekmesi
            local btn = Instance.new("TextButton")
            btn.Text = "👤 " .. player.Name .. "  [K/D: " .. string.format("%.2f", kd) .. "]"
            btn.Size = UDim2.new(1, 0, 0, 28)
            btn.BackgroundColor3 = Color3.fromRGB(35, 35, 60)
            btn.TextColor3 = Color3.fromRGB(255,255,255)
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 11
            btn.Parent = PlayerScroll
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
            btn.MouseButton1Click:Connect(function()
                SelectedPlayers[player] = not SelectedPlayers[player]
                UpdateESPColors()
                RefreshPlayerList()
                if SelectedPlayers[player] then
                    SetStatus("✅ " .. player.Name .. " seçildi", Color3.fromRGB(0, 255, 0))
                else
                    SetStatus("🗑️ " .. player.Name .. " çıkarıldı", Color3.fromRGB(255, 100, 0))
                end
            end)

            -- Auto-Fling listesi
            local afBtn = Instance.new("TextButton")
            local selected = SelectedPlayers[player] and " ✅" or ""
            afBtn.Text = "🎯 " .. player.Name .. selected
            afBtn.Size = UDim2.new(1, 0, 0, 26)
            afBtn.BackgroundColor3 = SelectedPlayers[player] and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(35, 60, 60)
            afBtn.TextColor3 = Color3.fromRGB(255,255,255)
            afBtn.Font = Enum.Font.Gotham
            afBtn.TextSize = 11
            afBtn.Parent = AutoFlingScroll
            Instance.new("UICorner", afBtn).CornerRadius = UDim.new(0, 5)
            afBtn.MouseButton1Click:Connect(function()
                SelectedPlayers[player] = not SelectedPlayers[player]
                UpdateESPColors()
                RefreshPlayerList()
            end)
        end
    end
    PlayerScroll.CanvasSize = UDim2.new(0, 0, 0, count * 32)
    AutoFlingScroll.CanvasSize = UDim2.new(0, 0, 0, count * 30)
end

AddConnection(Players.PlayerAdded:Connect(function() task.wait(0.5) RefreshPlayerList() end))
AddConnection(Players.PlayerRemoving:Connect(function() task.wait(0.5) RefreshPlayerList() end))

-- ═══════════════════════════════════════════════════════════════
-- ⚙️ SETTINGS PAGE
-- ═══════════════════════════════════════════════════════════════
CreateLabel(Pages.Settings, "⚙️ ADVANCED", Color3.fromRGB(180, 180, 180), 1)
local AntiDetectBtn = CreateBtn(Pages.Settings, "🛡️ Anti-Detection: OFF", Color3.fromRGB(60, 0, 60), 2)
local BanSafeBtn = CreateBtn(Pages.Settings, "🚫 Ban-Safe: OFF", Color3.fromRGB(60, 0, 60), 3)
local TracerToggleBtn = CreateBtn(Pages.Settings, "📏 Tracer Lines: OFF", Color3.fromRGB(60, 0, 60), 4)
local FPSCounterBtn = CreateBtn(Pages.Settings, "📊 FPS Counter: ON", Color3.fromRGB(40, 100, 40), 5)

-- ═══════════════════════════════════════════════════════════════
-- 🏎️ GARAGE PAGE
-- ═══════════════════════════════════════════════════════════════
CreateLabel(Pages.Garage, "🏎️ VEHICLE GARAGE", Color3.fromRGB(255, 150, 50), 1)
local ColorRedBtn = CreateBtn(Pages.Garage, "🔴 Red", Color3.fromRGB(200, 0, 0), 2)
local ColorBlueBtn = CreateBtn(Pages.Garage, "🔵 Blue", Color3.fromRGB(0, 50, 200), 3)
local ColorGreenBtn = CreateBtn(Pages.Garage, "🟢 Green", Color3.fromRGB(0, 150, 0), 4)
local ColorRandomBtn = CreateBtn(Pages.Garage, "🎨 Random", Color3.fromRGB(100, 50, 150), 5)

-- ═══════════════════════════════════════════════════════════════
-- 🎬 KILLCAM PAGE
-- ═══════════════════════════════════════════════════════════════
CreateLabel(Pages.Killcam, "🎬 KILLCAM / REPLAY", Color3.fromRGB(200, 100, 100), 1)
local StartRecordBtn = CreateBtn(Pages.Killcam, "⏺️ START RECORDING", Color3.fromRGB(150, 0, 0), 2)
local StopRecordBtn = CreateBtn(Pages.Killcam, "⏹️ STOP RECORDING", Color3.fromRGB(80, 80, 80), 3)
local PlayRecordBtn = CreateBtn(Pages.Killcam, "▶️ PLAY (3s)", Color3.fromRGB(0, 120, 0), 4)

-- ═══════════════════════════════════════════════════════════════
-- 📊 STATS PAGE
-- ═══════════════════════════════════════════════════════════════
CreateLabel(Pages.Stats, "📊 SESSION STATS", Color3.fromRGB(100, 255, 200), 1)
local StatsInfoLabel = CreateLabel(Pages.Stats, "K: 0 | D: 0 | K/D: 0.00", Color3.fromRGB(255, 255, 255), 2)
local MVPBtn = CreateBtn(Pages.Stats, "🏆 CALCULATE MVP", Color3.fromRGB(200, 150, 0), 3)
local ResetStatsBtn = CreateBtn(Pages.Stats, "🔄 RESET STATS", Color3.fromRGB(100, 50, 50), 4)

-- ====================================================================
-- BUTTON HANDLERS
-- ====================================================================
AddConnection(PowerSetBtn.MouseButton1Click:Connect(function()
    local val = tonumber(PowerInput.Text)
    if val and val >= Settings.MinFlingPower and val <= Settings.MaxFlingPower then
        Settings.FlingPower = val
        SetStatus("Power: " .. val, Color3.fromRGB(0,255,0))
        PowerInput.Text = ""
    end
end))

AddConnection(RangeSetBtn.MouseButton1Click:Connect(function()
    local val = tonumber(RangeInput.Text)
    if val and val >= 1 then
        Settings.FlingRange = val
        SetStatus("Range: " .. val, Color3.fromRGB(0,255,0))
        RangeInput.Text = ""
    end
end))

AddConnection(FlingBtn.MouseButton1Click:Connect(function()
    DoFlingAction(1.2, false)
end))

AddConnection(FlingFarBtn.MouseButton1Click:Connect(function()
    DoFlingAction(1.5, true)
end))

AddConnection(NormalFlingBtn.MouseButton1Click:Connect(function()
    Settings.IsNormalFling = not Settings.IsNormalFling
    NormalFlingBtn.Text = Settings.IsNormalFling and "🌀 FLING: ON!" or "🌀 FLING ON (continuous)"
    NormalFlingBtn.BackgroundColor3 = Settings.IsNormalFling and Color3.fromRGB(0,200,200) or Color3.fromRGB(0,80,80)
end))

AddConnection(ClickBtn.MouseButton1Click:Connect(function()
    Settings.ClickFlingActive = not Settings.ClickFlingActive
    ClickBtn.Text = Settings.ClickFlingActive and "👆 CLICK: ON" or "👆 CLICK FLING: OFF"
    ClickBtn.BackgroundColor3 = Settings.ClickFlingActive and Color3.fromRGB(20,150,20) or Color3.fromRGB(120,20,20)
end))

-- ESP BUTTONS
AddConnection(ESPToggleBtn.MouseButton1Click:Connect(function()
    Settings.ESP_Enabled = not Settings.ESP_Enabled
    ESPToggleBtn.Text = Settings.ESP_Enabled and "👁️ ESP: ON" or "👁️ ESP: OFF"
    ESPToggleBtn.BackgroundColor3 = Settings.ESP_Enabled and Color3.fromRGB(0,200,0) or Color3.fromRGB(0,100,0)
    RefreshAllESP()
    if not Settings.ESP_Enabled and Settings.AutoFlingActive then
        Settings.AutoFlingActive = false
        SetStatus("⏹️ ESP kapandı, Auto-Fling durdu", Color3.fromRGB(255, 200, 0))
    end
end))

AddConnection(ESPHighlightBtn.MouseButton1Click:Connect(function()
    Settings.ESP_Highlight = not Settings.ESP_Highlight
    ESPHighlightBtn.Text = Settings.ESP_Highlight and "🔴 Highlight: ON" or "🔴 Highlight: OFF"
    ESPHighlightBtn.BackgroundColor3 = Settings.ESP_Highlight and Color3.fromRGB(0,150,0) or Color3.fromRGB(80,30,30)
    UpdateESPVisibility()
end))

AddConnection(ESPBoxBtn.MouseButton1Click:Connect(function()
    Settings.ESP_Box = not Settings.ESP_Box
    ESPBoxBtn.Text = Settings.ESP_Box and "📦 Box: ON" or "📦 Box: OFF"
    ESPBoxBtn.BackgroundColor3 = Settings.ESP_Box and Color3.fromRGB(0,150,0) or Color3.fromRGB(80,30,30)
end))

AddConnection(ESPNameBtn.MouseButton1Click:Connect(function()
    Settings.ESP_Name = not Settings.ESP_Name
    ESPNameBtn.Text = Settings.ESP_Name and "📝 Name: ON" or "📝 Name: OFF"
    ESPNameBtn.BackgroundColor3 = Settings.ESP_Name and Color3.fromRGB(0,150,0) or Color3.fromRGB(80,30,30)
end))

AddConnection(ESPDistanceBtn.MouseButton1Click:Connect(function()
    Settings.ESP_Distance = not Settings.ESP_Distance
    ESPDistanceBtn.Text = Settings.ESP_Distance and "📏 Distance: ON" or "📏 Distance: OFF"
    ESPDistanceBtn.BackgroundColor3 = Settings.ESP_Distance and Color3.fromRGB(0,150,0) or Color3.fromRGB(80,30,30)
end))

AddConnection(ESPHealthBtn.MouseButton1Click:Connect(function()
    Settings.ESP_Health = not Settings.ESP_Health
    ESPHealthBtn.Text = Settings.ESP_Health and "❤️ Health Bar: ON" or "❤️ Health Bar: OFF"
    ESPHealthBtn.BackgroundColor3 = Settings.ESP_Health and Color3.fromRGB(0,150,0) or Color3.fromRGB(80,30,30)
end))

AddConnection(ESPTeamBtn.MouseButton1Click:Connect(function()
    Settings.ESP_TeamCheck = not Settings.ESP_TeamCheck
    ESPTeamBtn.Text = Settings.ESP_TeamCheck and "👥 Team Check: ON" or "👥 Team Check: OFF"
    ESPTeamBtn.BackgroundColor3 = Settings.ESP_TeamCheck and Color3.fromRGB(0,150,0) or Color3.fromRGB(80,30,30)
end))

-- AUTO-FLING
AddConnection(AutoFlingStartBtn.MouseButton1Click:Connect(StartAutoFling))

AddConnection(AutoFlingCancelBtn.MouseButton1Click:Connect(function()
    Settings.AutoFlingActive = false
    SetStatus("❌ AUTO-FLING İPTAL", Color3.fromRGB(255, 0, 0))
end))

AddConnection(AutoFlingBypassBtn.MouseButton1Click:Connect(function()
    Settings.AntiFlingBypass = not Settings.AntiFlingBypass
    AutoFlingBypassBtn.Text = Settings.AntiFlingBypass and "🛡️ ANTI-FLING BYPASS: ON" or "🛡️ ANTI-FLING BYPASS: OFF"
    AutoFlingBypassBtn.BackgroundColor3 = Settings.AntiFlingBypass and Color3.fromRGB(200,200,0) or Color3.fromRGB(100,100,0)
    SetStatus(Settings.AntiFlingBypass and "🛡️ Bypass AÇIK" or "🛡️ Bypass KAPALI",
        Settings.AntiFlingBypass and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(150, 150, 150))
end))

-- MOVEMENT
AddConnection(FrontflipBtn.MouseButton1Click:Connect(DoFrontflip))
AddConnection(LayDownBtn.MouseButton1Click:Connect(DoLayDown))
AddConnection(GoonBtn.MouseButton1Click:Connect(DoGoon))

-- Diğer butonlar (kısaltıldı)
AddConnection(RemoteToggleBtn.MouseButton1Click:Connect(function()
    local enabled = not RemoteControlActive
    SetRemoteControl(enabled)
    RemoteToggleBtn.Text = enabled and "📡 REMOTE: ON" or "📡 REMOTE: OFF"
    RemoteToggleBtn.BackgroundColor3 = enabled and Color3.fromRGB(0,180,180) or Color3.fromRGB(60,60,60)
end))

AddConnection(FlyBtn.MouseButton1Click:Connect(function()
    Settings.IsFlying = not Settings.IsFlying
    FlyBtn.Text = Settings.IsFlying and "🛫 FLY: ON" or "🛫 FLY: OFF"
    FlyBtn.BackgroundColor3 = Settings.IsFlying and Color3.fromRGB(20,150,20) or Color3.fromRGB(120,20,20)
end))

AddConnection(NoclipBtn.MouseButton1Click:Connect(function()
    Settings.NoclipActive = not Settings.NoclipActive
    NoclipBtn.Text = Settings.NoclipActive and "🚫 NOCLIP: ON" or "🚫 NOCLIP: OFF"
    NoclipBtn.BackgroundColor3 = Settings.NoclipActive and Color3.fromRGB(20,150,20) or Color3.fromRGB(80,30,30)
end))

AddConnection(AIBtn.MouseButton1Click:Connect(function()
    AIData.Enabled = not AIData.Enabled
    AIBtn.Text = AIData.Enabled and "🤖 AI: ON" or "🤖 AI: OFF"
    AIBtn.BackgroundColor3 = AIData.Enabled and Color3.fromRGB(150,0,200) or Color3.fromRGB(80,0,120)
end))

AddConnection(AntiFlingBtn.MouseButton1Click:Connect(function()
    Settings.AntiFling = not Settings.AntiFling
    AntiFlingBtn.Text = Settings.AntiFling and "🛡️ Anti-Fling: ON" or "🛡️ Anti-Fling: OFF"
    AntiFlingBtn.BackgroundColor3 = Settings.AntiFling and Color3.fromRGB(0,200,180) or Color3.fromRGB(60,100,100)
    if Settings.AntiFling then StartAntiFling() else StopAntiFling() end
end))

AddConnection(TracerToggleBtn.MouseButton1Click:Connect(function()
    Settings.TracerLines = not Settings.TracerLines
    TracerToggleBtn.Text = Settings.TracerLines and "📏 Tracer Lines: ON" or "📏 Tracer Lines: OFF"
    TracerToggleBtn.BackgroundColor3 = Settings.TracerLines and Color3.fromRGB(0,150,150) or Color3.fromRGB(60,0,60)
end))

AddConnection(MultiInstanceBtn.MouseButton1Click:Connect(function()
    MultiInstanceBtn.Text = "🖥️ Multi-Instance: ON"
    MultiInstanceBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 150)
    SetStatus("🖥️ Multi-Instance uyumlu!", Color3.fromRGB(0, 255, 200))
end))

AddConnection(ServerHopBtn.MouseButton1Click:Connect(function()
    SetStatus("🌐 Server Hop yakında!", Color3.fromRGB(0, 200, 255))
end))

AddConnection(CancelBtn.MouseButton1Click:Connect(function()
    Settings.IsFlingEveryone = false
    Settings.IsNormalFling = false
    Settings.IsWaypointRunning = false
    Settings.IsFlying = false
    Settings.ClickFlingActive = false
    Settings.AutoFlingActive = false
    isAutoPilotActive = false
    FlingQueue = {}
    UpdateQueueUI()
    UnanchorVehicle()
    StopVehicle()
    SetStatus("✅ HER ŞEY İPTAL", Color3.fromRGB(0,255,0))
end))

-- ====================================================================
-- 🖱️ INPUT HANDLER
-- ====================================================================
AddConnection(UserInputService.InputBegan:Connect(function(input, gp)
    if gp or State.isShuttingDown then return end
    if input.KeyCode == Enum.KeyCode.F then DoFrontflip() end
    if input.KeyCode == Enum.KeyCode.G then DoLayDown() end
    if input.KeyCode == Enum.KeyCode.H then DoGoon() end
end))

-- ====================================================================
-- 🔄 MAIN LOOP
-- ====================================================================
local function MainLoop()
    if State.isShuttingDown then return end
    local now = os.clock()
    local vehicle = GetVehicle()

    UpdateTracers()

    if vehicle and Settings.NoclipActive then
        for _, part in pairs(vehicle:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end

    if vehicle and Settings.IsWaypointRunning then WaypointLoop()
    elseif vehicle and AIData.Enabled then UpdateAI()
    end

    if Settings.IsNormalFling and now - State.lastFlingTime > Settings.FlingCooldown then
        DoFlingAction(1, false)
        State.lastFlingTime = os.clock()
    end
end

AddConnection(RunService.Heartbeat:Connect(MainLoop))

AddConnection(LocalPlayer.CharacterAdded:Connect(function()
    task.delay(0.5, function()
        if State.isShuttingDown then return end
        ResetVehicleData()
        State.isRespawning = false
        RefreshAllESP()
    end)
end))

for _, player in pairs(Players:GetPlayers()) do AttachPlayerKillTracking(player) end
AddConnection(Players.PlayerAdded:Connect(function(p)
    AttachPlayerKillTracking(p)
    task.wait(0.5)
    RefreshPlayerList()
    if Settings.ESP_Enabled then CreateESPForPlayer(p) end
end))
AddConnection(Players.PlayerRemoving:Connect(function(p)
    KillTrackerConnections[p] = nil
    RemoveESPForPlayer(p)
    SelectedPlayers[p] = nil
end))

-- ====================================================================
-- 📊 FPS COUNTER
-- ====================================================================
FPSLabel = Instance.new("TextLabel")
FPSLabel.Text = "FPS: 60"
FPSLabel.Size = UDim2.new(0, 80, 0, 22)
FPSLabel.Position = UDim2.new(1, -90, 0, 10)
FPSLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
FPSLabel.BackgroundTransparency = 0.4
FPSLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
FPSLabel.Font = Enum.Font.GothamBold
FPSLabel.TextSize = 12
FPSLabel.ZIndex = 10
FPSLabel.Parent = ScreenGui
Instance.new("UICorner", FPSLabel).CornerRadius = UDim.new(0, 6)

task.spawn(function()
    local frames = 0
    local lastTime = os.clock()
    while not State.isShuttingDown do
        frames = frames + 1
        local now = os.clock()
        if now - lastTime >= 1 then
            local fps = frames
            frames = 0
            lastTime = now
            if Settings.ShowFPSCounter and FPSLabel and FPSLabel.Parent then
                FPSLabel.Text = "FPS: " .. fps
                if fps >= 55 then FPSLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
                elseif fps >= 30 then FPSLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
                else FPSLabel.TextColor3 = Color3.fromRGB(255, 50, 50) end
            end
        end
        RunService.RenderStepped:Wait()
    end
end)

-- ====================================================================
-- 🎯 TOGGLE BUTONU
-- ====================================================================
local XToggleBtn = Instance.new("TextButton")
XToggleBtn.Size = UDim2.new(0, 70, 0, 70)
XToggleBtn.Position = UDim2.new(0, 20, 0.35, 0)
XToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
XToggleBtn.Text = "X"
XToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
XToggleBtn.Font = Enum.Font.GothamBold
XToggleBtn.TextSize = 26
XToggleBtn.Parent = ScreenGui
Instance.new("UICorner", XToggleBtn).CornerRadius = UDim.new(1, 0)

local XToggleStroke = Instance.new("UIStroke")
XToggleStroke.Color = Color3.fromRGB(100, 255, 100)
XToggleStroke.Thickness = 3
XToggleStroke.Parent = XToggleBtn

task.spawn(function()
    while XToggleBtn.Parent and not State.isShuttingDown do
        local t1 = TweenService:Create(XToggleStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {
            Color=Color3.fromRGB(0,255,0), Thickness=6
        })
        t1:Play() t1.Completed:Wait()
        if not XToggleBtn.Parent then break end
        local t2 = TweenService:Create(XToggleStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {
            Color=Color3.fromRGB(0,80,0), Thickness=2
        })
        t2:Play() t2.Completed:Wait()
    end
end)

MakeDraggable(XToggleBtn)

AddConnection(XToggleBtn.MouseButton1Click:Connect(function()
    if not Settings.IsUnlocked then
        PasswordGui.Visible = true
        return
    end
    XMenu.Visible = not XMenu.Visible
end))

AddConnection(XCloseBtn.MouseButton1Click:Connect(function() XMenu.Visible = false end))

-- ====================================================================
-- 📊 STATUS LABELS
-- ====================================================================
StatusLabel = Instance.new("TextLabel")
StatusLabel.Text = "🔒 Şifre gir: 1234"
StatusLabel.Size = UDim2.new(0, 320, 0, 22)
StatusLabel.Position = UDim2.new(0.5, -160, 0.94, 0)
StatusLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
StatusLabel.BackgroundTransparency = 0.3
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 11
StatusLabel.ZIndex = 5
StatusLabel.Parent = ScreenGui
Instance.new("UICorner", StatusLabel).CornerRadius = UDim.new(0, 6)

KillLabel = Instance.new("TextLabel")
KillLabel.Text = "Kills: 0 | Streak: 0"
KillLabel.Size = UDim2.new(0, 200, 0, 22)
KillLabel.Position = UDim2.new(0.5, 160, 0.94, 0)
KillLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
KillLabel.BackgroundTransparency = 0.3
KillLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
KillLabel.Font = Enum.Font.GothamBold
KillLabel.TextSize = 11
KillLabel.ZIndex = 5
KillLabel.Parent = ScreenGui
Instance.new("UICorner", KillLabel).CornerRadius = UDim.new(0, 6)

StatsLabel = Instance.new("TextLabel")
StatsLabel.Text = "K: 0 | D: 0 | K/D: 0.00"
StatsLabel.Size = UDim2.new(0, 320, 0, 22)
StatsLabel.Position = UDim2.new(0.5, -160, 0.97, 0)
StatsLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
StatsLabel.BackgroundTransparency = 0.3
StatsLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
StatsLabel.Font = Enum.Font.GothamBold
StatsLabel.TextSize = 11
StatsLabel.ZIndex = 5
StatsLabel.Parent = ScreenGui
Instance.new("UICorner", StatsLabel).CornerRadius = UDim.new(0, 6)

-- ====================================================================
-- 🧹 CLEANUP
-- ====================================================================
local function Cleanup()
    if State.isShuttingDown then return end
    State.isShuttingDown = true
    StopKillcamRecording()
    StopAntiFling()
    CleanupConnections()
    SafeCall(UnanchorVehicle)
    SafeCall(StopVehicle)
    for player, _ in pairs(ESPObjects) do
        RemoveESPForPlayer(player)
    end
    for _, line in pairs(TracerData) do pcall(function() line:Destroy() end) end
    TracerData = {}
end

AddConnection(ScreenGui.Destroying:Connect(Cleanup))

-- ====================================================================
-- ✅ STARTUP
-- ====================================================================
SafeCall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "X MENU V52 - ESP + AUTO-FLING",
        Text = "Şifre: 1234 | ESP + Auto-Fling + Movement",
        Duration = 6
    })
end)

SetStatus("🔒 Şifre gir: 1234", Color3.fromRGB(0, 255, 100))
UpdateQueueUI()
KillTracker.UpdateStats()
task.spawn(function() task.wait(1) RefreshPlayerList() end)

print("[X MENU V52] Loaded!")
print("NEW: ESP System, Auto-Fling, Anti-Fling Bypass, Movement, Multi-Instance")
