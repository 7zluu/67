local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

WindUI:Notify({
    Title = "4EVR",
    Content = "Interfaz cargada",
    Duration = 3
})

local Window = WindUI:CreateWindow({
    Title = "4EVR",
    Icon = "moon",
    Author = "4EVR",
    Folder = "4EVR",
    Size = UDim2.fromOffset(800, 700),
    MinSize = Vector2.new(560, 350),
    MaxSize = Vector2.new(1000, 1000),
    Transparent = true,
    Theme = "Dark",
    Resizable = true,
    Background = "rbxassetid://80687556099311",
    SideBarWidth = 200,
    BackgroundImageTransparency = 0.3,
    HideSearchBar = true,
    ScrollBarEnabled = false,
})

Window:SetToggleKey(Enum.KeyCode.K)

Window:EditOpenButton({
    Title = "4EVR",
    Icon = "moon",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Color = ColorSequence.new(
        Color3.fromHex("1e40ff"),
        Color3.fromHex("60a5fa")
    ),
    OnlyMobile = false,
    Enabled = true,
    Draggable = true,
})

-- ==================== TABS ====================
local Main = Window:Tab({ Title = "Main", Locked = false })
local Movement = Window:Tab({ Title = "Movement", Locked = false })
local PlayerTab = Window:Tab({ Title = "Player", Locked = false })
local Visuals = Window:Tab({ Title = "Visuals", Locked = false })
local AimbotTab = Window:Tab({ Title = "Aimbot", Locked = false })
local Utility = Window:Tab({ Title = "Utility", Locked = false })
local Others = Window:Tab({ Title = "Others", Locked = false })

Main:Select()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==================== MOVEMENT ====================
local SpeedEnabled = false
local SpeedValue = 30

local function SetSpeed(value)
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = value end
    end
end

Movement:Toggle({
    Title = "Speed Hack",
    Value = false,
    Callback = function(state)
        SpeedEnabled = state
        SetSpeed(state and SpeedValue or 16)
    end
})

Movement:Slider({
    Title = "Velocidad",
    Step = 1,
    Value = { Min = 16, Max = 200, Default = 30 },
    Callback = function(value)
        SpeedValue = value
        if SpeedEnabled then SetSpeed(value) end
    end
})

local Flying = false
local FlySpeed = 50
local FlyConnection

local function StartFly()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    hum.PlatformStand = true
    local bodyGyro = Instance.new("BodyGyro", hrp)
    bodyGyro.P = 9e4
    bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bodyGyro.CFrame = hrp.CFrame
    local bodyVel = Instance.new("BodyVelocity", hrp)
    bodyVel.Velocity = Vector3.zero
    bodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    FlyConnection = RunService.RenderStepped:Connect(function()
        local camCF = Camera.CFrame
        local direction = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then direction -= Vector3.new(0,1,0) end
        bodyVel.Velocity = direction.Magnitude > 0 and direction.Unit * FlySpeed or Vector3.zero
        bodyGyro.CFrame = camCF
    end)
end

local function StopFly()
    if FlyConnection then FlyConnection:Disconnect() end
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hrp then
            for _, v in pairs(hrp:GetChildren()) do
                if v:IsA("BodyGyro") or v:IsA("BodyVelocity") then v:Destroy() end
            end
        end
        if hum then hum.PlatformStand = false end
    end
end

Movement:Toggle({
    Title = "Fly",
    Value = false,
    Callback = function(state)
        Flying = state
        if state then StartFly() else StopFly() end
    end
})

Movement:Slider({
    Title = "Fly Speed",
    Step = 1,
    Value = { Min = 20, Max = 300, Default = 50 },
    Callback = function(v) FlySpeed = v end
})

local JumpPowerEnabled = false
local JumpPowerValue = 50

Movement:Toggle({
    Title = "Jump Power",
    Value = false,
    Callback = function(state)
        JumpPowerEnabled = state
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower = state and JumpPowerValue or 50
            end
        end
    end
})

Movement:Slider({
    Title = "Jump Power Value",
    Step = 1,
    Value = { Min = 50, Max = 300, Default = 50 },
    Callback = function(v)
        JumpPowerValue = v
        if JumpPowerEnabled then
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.JumpPower = v end
            end
        end
    end
})

local InfJump = false
Movement:Toggle({
    Title = "Infinite Jump",
    Value = false,
    Callback = function(state) InfJump = state end
})

UserInputService.JumpRequest:Connect(function()
    if InfJump then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end
end)

local Noclip = false
Movement:Toggle({
    Title = "Noclip",
    Value = false,
    Callback = function(state) Noclip = state end
})

RunService.Stepped:Connect(function()
    if Noclip and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

-- ==================== PLAYER ====================
PlayerTab:Toggle({
    Title = "God Mode",
    Value = false,
    Callback = function(state)
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                if state then
                    hum.MaxHealth = math.huge
                    hum.Health = math.huge
                else
                    hum.MaxHealth = 100
                    hum.Health = 100
                end
            end
        end
    end
})

PlayerTab:Button({
    Title = "Reset Character",
    Callback = function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health = 0 end
        end
    end
})

PlayerTab:Button({
    Title = "Respawn",
    Callback = function()
        LocalPlayer:LoadCharacter()
    end
})

-- ==================== AIMBOT (MEJORADO) ====================
local AimbotEnabled = false
local SilentAimEnabled = false
local AimPart = "Head"
local FOV = 150
local ShowFOV = true
local Smoothness = 0.22
local Prediction = 0.13
local TeamCheck = true
local VisibleCheck = true

local HoldingClick = false -- Nuevo: detecta click/touch

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.6
FOVCircle.NumSides = 64
FOVCircle.Filled = false
FOVCircle.Color = Color3.fromRGB(0, 255, 140)
FOVCircle.Visible = false

-- Detectar click o touch en cualquier parte de la pantalla
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        HoldingClick = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        HoldingClick = false
    end
end)

local function IsVisible(part)
    if not VisibleCheck then return true end
    local origin = Camera.CFrame.Position
    local direction = (part.Position - origin)
    local ray = Ray.new(origin, direction.Unit * direction.Magnitude)
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, Camera})
    return hit == nil or hit:IsDescendantOf(part.Parent)
end

local function GetClosest()
    local closest, shortest = nil, FOV
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            if TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then continue end

            local part = player.Character:FindFirstChild(AimPart) or player.Character:FindFirstChild("HumanoidRootPart")
            if part then
                local screen, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                    if dist < shortest and IsVisible(part) then
                        shortest = dist
                        closest = part
                    end
                end
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    FOVCircle.Position = center
    FOVCircle.Radius = FOV
    FOVCircle.Visible = ShowFOV and (AimbotEnabled or SilentAimEnabled)

    if AimbotEnabled or SilentAimEnabled then
        local target = GetClosest()
        if target then
            local velocity = target.AssemblyLinearVelocity or Vector3.zero
            local predicted = target.Position + (velocity * Prediction)
            local newCF = CFrame.new(Camera.CFrame.Position, predicted)

            -- Camera Aimbot normal
            if AimbotEnabled then
                Camera.CFrame = Camera.CFrame:Lerp(newCF, Smoothness)
            end

            -- Silent Aim mejorado: cuando haces click/touch se pone mucho más fuerte
            if SilentAimEnabled then
                if HoldingClick then
                    -- Al hacer click → apunta casi instantáneamente al enemigo
                    Camera.CFrame = Camera.CFrame:Lerp(newCF, 0.92)
                else
                    -- Sin click → silent más suave
                    Camera.CFrame = Camera.CFrame:Lerp(newCF, 0.35)
                end
            end
        end
    end
end)

AimbotTab:Toggle({
    Title = "Camera Aimbot",
    Value = false,
    Callback = function(v) AimbotEnabled = v end
})

AimbotTab:Toggle({
    Title = "Silent Aim (Click = Fuerte)",
    Value = false,
    Callback = function(v) SilentAimEnabled = v end
})

AimbotTab:Dropdown({
    Title = "Aim Part",
    Values = {"Head", "HumanoidRootPart", "UpperTorso"},
    Value = "Head",
    Callback = function(v) AimPart = v end
})

AimbotTab:Toggle({
    Title = "Show FOV Circle",
    Value = true,
    Callback = function(v) ShowFOV = v end
})

AimbotTab:Slider({
    Title = "FOV Size",
    Step = 1,
    Value = { Min = 40, Max = 400, Default = 150 },
    Callback = function(v) FOV = v end
})

AimbotTab:Slider({
    Title = "Smoothness (Camera)",
    Step = 0.01,
    Value = { Min = 0.05, Max = 1, Default = 0.22 },
    Callback = function(v) Smoothness = v end
})

AimbotTab:Slider({
    Title = "Prediction",
    Step = 0.01,
    Value = { Min = 0, Max = 0.4, Default = 0.13 },
    Callback = function(v) Prediction = v end
})

AimbotTab:Toggle({
    Title = "Team Check",
    Value = true,
    Callback = function(v) TeamCheck = v end
})

AimbotTab:Toggle({
    Title = "Visible Check",
    Value = true,
    Callback = function(v) VisibleCheck = v end
})

-- ==================== VISUALS (ESP Completo) ====================
local ESPEnabled = false
local TracersEnabled = false
local BoxEnabled = false
local HealthBarEnabled = false
local ChamsEnabled = false
local SkeletonEnabled = false

local ESPColor = Color3.fromRGB(255, 255, 255)
local TracerColor = Color3.fromRGB(0, 255, 140)
local BoxColor = Color3.fromRGB(0, 255, 140)
local SkeletonColor = Color3.fromRGB(0, 255, 140)
local TextSize = 14
local TracerThickness = 1.5

local ESPObjects = {}

local function CreateESP(player)
    if player == LocalPlayer then return end
    if ESPObjects[player] then return end

    local d = {
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
        Box = Drawing.new("Square"),
        HealthBg = Drawing.new("Square"),
        Health = Drawing.new("Square"),
        Highlight = nil,
        Skeleton = {}
    }

    d.Name.Size = TextSize
    d.Name.Center = true
    d.Name.Outline = true
    d.Name.Color = ESPColor

    d.Distance.Size = TextSize - 1
    d.Distance.Center = true
    d.Distance.Outline = true
    d.Distance.Color = ESPColor

    d.Tracer.Thickness = TracerThickness
    d.Tracer.Color = TracerColor

    d.Box.Thickness = 1.5
    d.Box.Filled = false
    d.Box.Color = BoxColor

    d.HealthBg.Filled = true
    d.HealthBg.Color = Color3.fromRGB(30,30,30)
    d.Health.Filled = true

    for i = 1, 12 do
        local line = Drawing.new("Line")
        line.Thickness = 1.4
        line.Color = SkeletonColor
        d.Skeleton[i] = line
    end

    ESPObjects[player] = d
end

local function RemoveESP(player)
    if ESPObjects[player] then
        for _, v in pairs(ESPObjects[player]) do
            if typeof(v) == "table" then
                for _, line in pairs(v) do pcall(function() line:Remove() end) end
            elseif typeof(v) == "Instance" and v:IsA("Highlight") then
                v:Destroy()
            else
                pcall(function() v:Remove() end)
            end
        end
        ESPObjects[player] = nil
    end
end

for _, plr in pairs(Players:GetPlayers()) do CreateESP(plr) end
Players.PlayerAdded:Connect(CreateESP)
Players.PlayerRemoving:Connect(RemoveESP)

local function GetBonePos(char, name)
    local part = char:FindFirstChild(name)
    return part and part.Position
end

RunService.RenderStepped:Connect(function()
    for player, d in pairs(ESPObjects) do
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then
            d.Name.Visible = false
            d.Distance.Visible = false
            d.Tracer.Visible = false
            d.Box.Visible = false
            d.HealthBg.Visible = false
            d.Health.Visible = false
            if d.Highlight then d.Highlight.Enabled = false end
            for _, line in pairs(d.Skeleton) do line.Visible = false end
            continue
        end

        local hrp = char.HumanoidRootPart
        local hum = char.Humanoid
        local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)

        if ChamsEnabled then
            if not d.Highlight or not d.Highlight.Parent then
                local hl = Instance.new("Highlight")
                hl.FillColor = BoxColor
                hl.OutlineColor = Color3.new(1,1,1)
                hl.FillTransparency = 0.5
                hl.Parent = char
                d.Highlight = hl
            end
            d.Highlight.Enabled = true
            d.Highlight.FillColor = BoxColor
        else
            if d.Highlight then d.Highlight.Enabled = false end
        end

        if onScreen then
            local top = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2.5, 0))
            local bottom = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
            local sizeY = math.abs(top.Y - bottom.Y) / 2
            local boxSize = Vector2.new(sizeY * 1.5, sizeY * 2.2)
            local boxPos = Vector2.new(pos.X - boxSize.X/2, pos.Y - boxSize.Y/2)

            if ESPEnabled then
                d.Name.Text = player.Name
                d.Name.Size = TextSize
                d.Name.Position = Vector2.new(pos.X, boxPos.Y - 18)
                d.Name.Color = ESPColor
                d.Name.Visible = true

                local dist = math.floor((hrp.Position - Camera.CFrame.Position).Magnitude)
                d.Distance.Text = dist .. "m"
                d.Distance.Size = TextSize - 1
                d.Distance.Position = Vector2.new(pos.X, boxPos.Y + boxSize.Y + 4)
                d.Distance.Color = ESPColor
                d.Distance.Visible = true
            else
                d.Name.Visible = false
                d.Distance.Visible = false
            end

            if TracersEnabled then
                d.Tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                d.Tracer.To = Vector2.new(pos.X, pos.Y)
                d.Tracer.Thickness = TracerThickness
                d.Tracer.Color = TracerColor
                d.Tracer.Visible = true
            else
                d.Tracer.Visible = false
            end

            if BoxEnabled then
                d.Box.Size = boxSize
                d.Box.Position = boxPos
                d.Box.Color = BoxColor
                d.Box.Visible = true
            else
                d.Box.Visible = false
            end

            if HealthBarEnabled then
                local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                d.HealthBg.Size = Vector2.new(3, boxSize.Y)
                d.HealthBg.Position = Vector2.new(boxPos.X - 7, boxPos.Y)
                d.HealthBg.Visible = true
                d.Health.Size = Vector2.new(3, boxSize.Y * hp)
                d.Health.Position = Vector2.new(boxPos.X - 7, boxPos.Y + boxSize.Y * (1-hp))
                d.Health.Color = Color3.fromRGB(255*(1-hp), 255*hp, 40)
                d.Health.Visible = true
            else
                d.HealthBg.Visible = false
                d.Health.Visible = false
            end

            if SkeletonEnabled then
                local function scr(p)
                    if not p then return nil end
                    local s, on = Camera:WorldToViewportPoint(p)
                    return on and Vector2.new(s.X, s.Y) or nil
                end

                local head = GetBonePos(char, "Head")
                local torso = GetBonePos(char, "UpperTorso") or GetBonePos(char, "Torso")
                local larm = GetBonePos(char, "LeftUpperArm") or GetBonePos(char, "Left Arm")
                local rarm = GetBonePos(char, "RightUpperArm") or GetBonePos(char, "Right Arm")
                local lleg = GetBonePos(char, "LeftUpperLeg") or GetBonePos(char, "Left Leg")
                local rleg = GetBonePos(char, "RightUpperLeg") or GetBonePos(char, "Right Leg")
                local lhand = GetBonePos(char, "LeftHand") or larm
                local rhand = GetBonePos(char, "RightHand") or rarm
                local lfoot = GetBonePos(char, "LeftFoot") or lleg
                local rfoot = GetBonePos(char, "RightFoot") or rleg

                local connections = {
                    {head, torso}, {torso, larm}, {torso, rarm},
                    {larm, lhand}, {rarm, rhand},
                    {torso, lleg}, {torso, rleg},
                    {lleg, lfoot}, {rleg, rfoot}
                }

                for i, conn in ipairs(connections) do
                    local from = scr(conn[1])
                    local to = scr(conn[2])
                    if from and to and d.Skeleton[i] then
                        d.Skeleton[i].From = from
                        d.Skeleton[i].To = to
                        d.Skeleton[i].Color = SkeletonColor
                        d.Skeleton[i].Visible = true
                    elseif d.Skeleton[i] then
                        d.Skeleton[i].Visible = false
                    end
                end
            else
                for _, line in pairs(d.Skeleton) do line.Visible = false end
            end
        else
            d.Name.Visible = false
            d.Distance.Visible = false
            d.Tracer.Visible = false
            d.Box.Visible = false
            d.HealthBg.Visible = false
            d.Health.Visible = false
            for _, line in pairs(d.Skeleton) do line.Visible = false end
        end
    end
end)

Visuals:Toggle({ Title = "ESP (Nombre + Distancia)", Value = false, Callback = function(v) ESPEnabled = v end })
Visuals:Toggle({ Title = "ESP Tracers", Value = false, Callback = function(v) TracersEnabled = v end })
Visuals:Toggle({ Title = "Box ESP", Value = false, Callback = function(v) BoxEnabled = v end })
Visuals:Toggle({ Title = "Health Bar ESP", Value = false, Callback = function(v) HealthBarEnabled = v end })
Visuals:Toggle({ Title = "Chams / Highlight", Value = false, Callback = function(v) ChamsEnabled = v end })
Visuals:Toggle({ Title = "Skeleton ESP", Value = false, Callback = function(v) SkeletonEnabled = v end })

Visuals:Colorpicker({ Title = "Color ESP (Texto)", Default = Color3.fromRGB(255,255,255), Callback = function(c) ESPColor = c end })
Visuals:Colorpicker({ Title = "Color Tracers", Default = Color3.fromRGB(0,255,140), Callback = function(c) TracerColor = c end })
Visuals:Colorpicker({ Title = "Color Box / Chams", Default = Color3.fromRGB(0,255,140), Callback = function(c) BoxColor = c end })
Visuals:Colorpicker({ Title = "Color Skeleton", Default = Color3.fromRGB(0,255,140), Callback = function(c) SkeletonColor = c end })

Visuals:Slider({
    Title = "Tamaño del Texto ESP",
    Step = 1,
    Value = { Min = 10, Max = 22, Default = 14 },
    Callback = function(v) TextSize = v end
})

Visuals:Slider({
    Title = "Grosor de Tracers",
    Step = 0.1,
    Value = { Min = 0.5, Max = 4, Default = 1.5 },
    Callback = function(v) TracerThickness = v end
})

Visuals:Toggle({
    Title = "X-Ray",
    Value = false,
    Callback = function(state)
        for _, part in pairs(workspace:GetDescendants()) do
            if part:IsA("BasePart") and not part:IsDescendantOf(LocalPlayer.Character) then
                part.LocalTransparencyModifier = state and 0.65 or 0
            end
        end
    end
})

Visuals:Button({
    Title = "Remove Textures",
    Callback = function()
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
                obj:Destroy()
            elseif obj:IsA("MeshPart") then
                obj.TextureID = ""
            end
        end
    end
})

-- ==================== UTILITY & OTHERS ====================
Utility:Button({ Title = "Rejoin", Callback = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end })
Utility:Button({
    Title = "Server Hop",
    Callback = function()
        local success, result = pcall(function()
            return game:GetService("HttpService"):JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"))
        end)
        if success and result and result.data then
            for _, server in pairs(result.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id)
                    break
                end
            end
        end
    end
})

Others:Toggle({
    Title = "Anti AFK",
    Value = false,
    Callback = function(state)
        if state then
            local vu = game:GetService("VirtualUser")
            LocalPlayer.Idled:Connect(function()
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end)
        end
    end
})

Others:Button({
    Title = "FPS Booster",
    Callback = function()
        settings().Rendering.QualityLevel = 1
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
    end
})

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.6)
    if SpeedEnabled then SetSpeed(SpeedValue) end
    if JumpPowerEnabled then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = JumpPowerValue
        end
    end
end)

print("4EVR | Silent Aim mejorado (Click = Fuerte)")
