local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Drawings = {}
local Settings = {
    Enabled = true,
    BoxESP = false,
    BoxStyle = "Corner",
    BoxThickness = 1,
    SkeletonESP = false,
    SkeletonThickness = 1.5,
    NameESP = false,
    HealthESP = false,
    HealthBarWidth = 4,
    ShowHealthText = false,
    TracerESP = false,
    TracerOrigin = "Bottom",
    TracerThickness = 1,
    PointESP = false,
    PointSize = 5,
    MaxDistance = 400,
    TeamCheck = false,
    RainbowEnabled = false,
    RainbowSpeed = 1,
}

local Colors = {
    Seeker = Color3.fromRGB(255, 0, 0),
    Killer = Color3.fromRGB(255, 0, 0),
    Hider = Color3.fromRGB(255, 200, 0),
    Innocent = Color3.fromRGB(0, 255, 0),
    Traitor = Color3.fromRGB(255, 0, 255),
    Police = Color3.fromRGB(0, 100, 255),
    Swat = Color3.fromRGB(0, 80, 200),
    Sheriff = Color3.fromRGB(0, 150, 255),
    Juggernaut = Color3.fromRGB(255, 165, 0),
    NoRole = Color3.fromRGB(255, 255, 255),
    Unknown = Color3.fromRGB(150, 150, 150),
    Rainbow = nil,
}

local function GetWorkspaceSettingsFolder()
    local folder = workspace:FindFirstChild("ESP_Settings")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "ESP_Settings"
        folder.Parent = workspace
    end
    return folder
end

local function SaveWorkspaceSetting(key, value)
    local folder = GetWorkspaceSettingsFolder()
    local obj = folder:FindFirstChild(key)
    local typeVal = type(value)
    if typeVal == "boolean" then
        if not obj or not obj:IsA("BoolValue") then
            if obj then obj:Destroy() end
            obj = Instance.new("BoolValue")
            obj.Name = key
            obj.Parent = folder
        end
        obj.Value = value
    elseif typeVal == "number" then
        if not obj or not obj:IsA("NumberValue") then
            if obj then obj:Destroy() end
            obj = Instance.new("NumberValue")
            obj.Name = key
            obj.Parent = folder
        end
        obj.Value = value
    elseif typeVal == "string" then
        if not obj or not obj:IsA("StringValue") then
            if obj then obj:Destroy() end
            obj = Instance.new("StringValue")
            obj.Name = key
            obj.Parent = folder
        end
        obj.Value = value
    elseif typeVal == "Color3" then
        if not obj or not obj:IsA("Color3Value") then
            if obj then obj:Destroy() end
            obj = Instance.new("Color3Value")
            obj.Name = key
            obj.Parent = folder
        end
        obj.Value = value
    end
end

local function LoadSettingsFromWorkspace()
    local folder = GetWorkspaceSettingsFolder()
    for _, child in ipairs(folder:GetChildren()) do
        local key = child.Name
        if Settings[key] ~= nil then
            if child:IsA("BoolValue") then
                Settings[key] = child.Value
            elseif child:IsA("NumberValue") then
                Settings[key] = child.Value
            elseif child:IsA("StringValue") then
                Settings[key] = child.Value
            elseif child:IsA("Color3Value") then
                if Colors[key] ~= nil then
                    Colors[key] = child.Value
                else
                    Settings[key] = child.Value
                end
            end
        elseif Colors[key] ~= nil then
            if child:IsA("Color3Value") then
                Colors[key] = child.Value
            end
        end
    end
end

LoadSettingsFromWorkspace()

local function GetPlayerRole(player)
    local character = player.Character
    if not character then return "NoRole" end
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return "NoRole" end
    local roleAttr = player:GetAttribute("Role")
    local deathRole = player:GetAttribute("DeathRole")
    local roleStr = nil
    if roleAttr ~= nil and roleAttr ~= "" and tostring(roleAttr) ~= "nil" then
        roleStr = tostring(roleAttr):upper()
    end
    if not roleStr and deathRole ~= nil and deathRole ~= "" and tostring(deathRole) ~= "nil" then
        roleStr = tostring(deathRole):upper()
    end
    if not roleStr then
        return "NoRole"
    end
    if roleStr:find("SEEKER") then return "Seeker" end
    if roleStr:find("KILLER") then return "Killer" end
    if roleStr:find("HIDER") then return "Hider" end
    if roleStr:find("INNOCENT") then return "Innocent" end
    if roleStr:find("TRAITOR") then return "Traitor" end
    if roleStr:find("POLICE") then return "Police" end
    if roleStr:find("SWAT") then return "Swat" end
    if roleStr:find("SHERIFF") then return "Sheriff" end
    if roleStr:find("JUGGERNAUT") then return "Juggernaut" end
    return "Unknown"
end

local function IsTeammate(player)
    local localRole = GetPlayerRole(LocalPlayer)
    local targetRole = GetPlayerRole(player)
    if localRole == "Unknown" or targetRole == "Unknown" then return false end
    if localRole == "NoRole" or targetRole == "NoRole" then return false end
    local function isGood(role)
        return role == "Hider" or role == "Innocent" or role == "Police" or role == "Swat" or role == "Sheriff" or role == "Juggernaut"
    end
    local function isBad(role)
        return role == "Seeker" or role == "Killer" or role == "Traitor"
    end
    if isGood(localRole) and isGood(targetRole) then return true end
    if isBad(localRole) and isBad(targetRole) then return true end
    return false
end

local function GetPlayerColor(player)
    if Settings.RainbowEnabled then
        return Colors.Rainbow
    end
    local role = GetPlayerRole(player)
    return Colors[role] or Colors.Unknown
end

local function CreateESP(player)
    if player == LocalPlayer then return end
    local esp = {
        Box = {
            Left = Drawing.new("Line"),
            Right = Drawing.new("Line"),
            Top = Drawing.new("Line"),
            Bottom = Drawing.new("Line"),
            TL = Drawing.new("Line"),
            TR = Drawing.new("Line"),
            BL = Drawing.new("Line"),
            BR = Drawing.new("Line"),
        },
        Name = Drawing.new("Text"),
        Health = {
            Outline = Drawing.new("Square"),
            Fill = Drawing.new("Square"),
            Text = Drawing.new("Text"),
        },
        Tracer = Drawing.new("Line"),
        Point = Drawing.new("Circle"),
        Skeleton = {},
    }
    for _, line in pairs(esp.Box) do
        line.Visible = false
        line.Color = Color3.fromRGB(255,255,255)
        line.Thickness = Settings.BoxThickness
    end
    esp.Name.Visible = false
    esp.Name.Center = true
    esp.Name.Size = 14
    esp.Name.Font = 2
    esp.Name.Outline = true
    esp.Name.Color = Color3.fromRGB(255,255,255)
    for _, obj in pairs(esp.Health) do
        obj.Visible = false
        if obj == esp.Health.Fill then
            obj.Filled = true
        elseif obj == esp.Health.Text then
            obj.Center = true
            obj.Size = 12
            obj.Font = 2
            obj.Outline = true
        end
    end
    esp.Tracer.Visible = false
    esp.Tracer.Color = Color3.fromRGB(255,255,255)
    esp.Tracer.Thickness = Settings.TracerThickness
    esp.Point.Visible = false
    esp.Point.Radius = Settings.PointSize
    esp.Point.Thickness = 1
    esp.Point.Filled = true
    esp.Point.NumSides = 20
    local boneNames = {
        "Head", "UpperTorso", "LowerTorso",
        "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "RightUpperLeg", "RightLowerLeg", "RightFoot"
    }
    for _, name in ipairs(boneNames) do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = Color3.fromRGB(255,255,255)
        line.Thickness = Settings.SkeletonThickness
        esp.Skeleton[name] = line
    end
    Drawings[player] = esp
end

local function RemoveESP(player)
    local esp = Drawings[player]
    if esp then
        for _, line in pairs(esp.Box) do line:Remove() end
        esp.Name:Remove()
        for _, obj in pairs(esp.Health) do obj:Remove() end
        esp.Tracer:Remove()
        esp.Point:Remove()
        for _, line in pairs(esp.Skeleton) do line:Remove() end
        Drawings[player] = nil
    end
end

local function GetBonePositions(character)
    local bones = {}
    local function getPart(name, alt)
        local part = character:FindFirstChild(name)
        if not part and alt then part = character:FindFirstChild(alt) end
        return part
    end
    bones.Head = getPart("Head")
    bones.UpperTorso = getPart("UpperTorso", "Torso")
    bones.LowerTorso = getPart("LowerTorso", "Torso")
    bones.LeftUpperArm = getPart("LeftUpperArm", "Left Arm")
    bones.LeftLowerArm = getPart("LeftLowerArm", "Left Arm")
    bones.LeftHand = getPart("LeftHand", "Left Arm")
    bones.RightUpperArm = getPart("RightUpperArm", "Right Arm")
    bones.RightLowerArm = getPart("RightLowerArm", "Right Arm")
    bones.RightHand = getPart("RightHand", "Right Arm")
    bones.LeftUpperLeg = getPart("LeftUpperLeg", "Left Leg")
    bones.LeftLowerLeg = getPart("LeftLowerLeg", "Left Leg")
    bones.LeftFoot = getPart("LeftFoot", "Left Leg")
    bones.RightUpperLeg = getPart("RightUpperLeg", "Right Leg")
    bones.RightLowerLeg = getPart("RightLowerLeg", "Right Leg")
    bones.RightFoot = getPart("RightFoot", "Right Leg")
    return bones
end

local function GetTracerOrigin()
    local origin = Settings.TracerOrigin
    if origin == "Bottom" then
        return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
    elseif origin == "Top" then
        return Vector2.new(Camera.ViewportSize.X/2, 0)
    elseif origin == "Mouse" then
        return UserInputService:GetMouseLocation()
    else
        return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    end
end

local function UpdateESP(player)
    if not Settings.Enabled then return end
    local esp = Drawings[player]
    if not esp then return end

    local character = player.Character
    if not character then
        for _, line in pairs(esp.Box) do line.Visible = false end
        esp.Name.Visible = false
        for _, obj in pairs(esp.Health) do obj.Visible = false end
        esp.Tracer.Visible = false
        esp.Point.Visible = false
        for _, line in pairs(esp.Skeleton) do line.Visible = false end
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        for _, line in pairs(esp.Box) do line.Visible = false end
        esp.Name.Visible = false
        for _, obj in pairs(esp.Health) do obj.Visible = false end
        esp.Tracer.Visible = false
        esp.Point.Visible = false
        for _, line in pairs(esp.Skeleton) do line.Visible = false end
        return
    end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        for _, line in pairs(esp.Box) do line.Visible = false end
        esp.Name.Visible = false
        for _, obj in pairs(esp.Health) do obj.Visible = false end
        esp.Tracer.Visible = false
        esp.Point.Visible = false
        for _, line in pairs(esp.Skeleton) do line.Visible = false end
        return
    end

    local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude

    if not onScreen or distance > Settings.MaxDistance then
        for _, line in pairs(esp.Box) do line.Visible = false end
        esp.Name.Visible = false
        for _, obj in pairs(esp.Health) do obj.Visible = false end
        esp.Tracer.Visible = false
        esp.Point.Visible = false
        for _, line in pairs(esp.Skeleton) do line.Visible = false end
        return
    end

    if Settings.TeamCheck and IsTeammate(player) then
        for _, line in pairs(esp.Box) do line.Visible = false end
        esp.Name.Visible = false
        for _, obj in pairs(esp.Health) do obj.Visible = false end
        esp.Tracer.Visible = false
        esp.Point.Visible = false
        for _, line in pairs(esp.Skeleton) do line.Visible = false end
        return
    end

    local color = GetPlayerColor(player)

    local size = character:GetExtentsSize()
    local cf = rootPart.CFrame
    local top = Camera:WorldToViewportPoint((cf * CFrame.new(0, size.Y/2, 0)).Position)
    local bottom = Camera:WorldToViewportPoint((cf * CFrame.new(0, -size.Y/2, 0)).Position)

    if top.Z < 0 or bottom.Z < 0 then
        for _, line in pairs(esp.Box) do line.Visible = false end
        return
    end

    local screenSize = bottom.Y - top.Y
    local boxWidth = screenSize * 0.65
    local boxPos = Vector2.new(top.X - boxWidth/2, top.Y)
    local boxSize = Vector2.new(boxWidth, screenSize)

    if Settings.BoxESP then
        local b = esp.Box
        if Settings.BoxStyle == "Corner" then
            local cornerSize = boxWidth * 0.2
            b.TL.From = boxPos
            b.TL.To = boxPos + Vector2.new(cornerSize, 0)
            b.TL.Visible = true
            b.TR.From = boxPos + Vector2.new(boxSize.X, 0)
            b.TR.To = boxPos + Vector2.new(boxSize.X - cornerSize, 0)
            b.TR.Visible = true
            b.BL.From = boxPos + Vector2.new(0, boxSize.Y)
            b.BL.To = boxPos + Vector2.new(cornerSize, boxSize.Y)
            b.BL.Visible = true
            b.BR.From = boxPos + Vector2.new(boxSize.X, boxSize.Y)
            b.BR.To = boxPos + Vector2.new(boxSize.X - cornerSize, boxSize.Y)
            b.BR.Visible = true
            b.Left.From = boxPos
            b.Left.To = boxPos + Vector2.new(0, cornerSize)
            b.Left.Visible = true
            b.Right.From = boxPos + Vector2.new(boxSize.X, 0)
            b.Right.To = boxPos + Vector2.new(boxSize.X, cornerSize)
            b.Right.Visible = true
            b.Top.From = boxPos + Vector2.new(0, boxSize.Y)
            b.Top.To = boxPos + Vector2.new(0, boxSize.Y - cornerSize)
            b.Top.Visible = true
            b.Bottom.From = boxPos + Vector2.new(boxSize.X, boxSize.Y)
            b.Bottom.To = boxPos + Vector2.new(boxSize.X, boxSize.Y - cornerSize)
            b.Bottom.Visible = true
        else
            b.Left.From = boxPos
            b.Left.To = boxPos + Vector2.new(0, boxSize.Y)
            b.Left.Visible = true
            b.Right.From = boxPos + Vector2.new(boxSize.X, 0)
            b.Right.To = boxPos + Vector2.new(boxSize.X, boxSize.Y)
            b.Right.Visible = true
            b.Top.From = boxPos
            b.Top.To = boxPos + Vector2.new(boxSize.X, 0)
            b.Top.Visible = true
            b.Bottom.From = boxPos + Vector2.new(0, boxSize.Y)
            b.Bottom.To = boxPos + Vector2.new(boxSize.X, boxSize.Y)
            b.Bottom.Visible = true
            b.TL.Visible = false
            b.TR.Visible = false
            b.BL.Visible = false
            b.BR.Visible = false
        end
        for _, line in pairs(esp.Box) do
            if line.Visible then
                line.Color = color
                line.Thickness = Settings.BoxThickness
            end
        end
    else
        for _, line in pairs(esp.Box) do line.Visible = false end
    end

    if Settings.NameESP then
        esp.Name.Text = player.DisplayName
        esp.Name.Position = Vector2.new(top.X, top.Y - 20)
        esp.Name.Color = color
        esp.Name.Visible = true
    else
        esp.Name.Visible = false
    end

    if Settings.HealthESP then
        local health = humanoid.Health
        local maxHealth = humanoid.MaxHealth
        local healthPercent = health / maxHealth
        local barHeight = screenSize * 0.8
        local barWidth = Settings.HealthBarWidth
        local barPos = Vector2.new(boxPos.X - barWidth - 2, boxPos.Y + (screenSize - barHeight)/2)

        esp.Health.Outline.Size = Vector2.new(barWidth, barHeight)
        esp.Health.Outline.Position = barPos
        esp.Health.Outline.Visible = true

        esp.Health.Fill.Size = Vector2.new(barWidth - 2, barHeight * healthPercent)
        esp.Health.Fill.Position = Vector2.new(barPos.X + 1, barPos.Y + barHeight * (1 - healthPercent))
        esp.Health.Fill.Color = Color3.fromRGB(255 - (255 * healthPercent), 255 * healthPercent, 0)
        esp.Health.Fill.Visible = true

        if Settings.ShowHealthText then
            esp.Health.Text.Text = math.floor(health)
            esp.Health.Text.Position = Vector2.new(barPos.X + barWidth + 2, barPos.Y + barHeight/2)
            esp.Health.Text.Visible = true
        else
            esp.Health.Text.Visible = false
        end
    else
        for _, obj in pairs(esp.Health) do obj.Visible = false end
    end

    if Settings.TracerESP then
        esp.Tracer.From = GetTracerOrigin()
        esp.Tracer.To = Vector2.new(pos.X, pos.Y)
        esp.Tracer.Color = color
        esp.Tracer.Visible = true
    else
        esp.Tracer.Visible = false
    end

    if Settings.PointESP then
        local head = character:FindFirstChild("Head")
        local headPos
        if head then
            headPos = Camera:WorldToViewportPoint(head.Position)
        else
            headPos = Camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 2, 0))
        end
        esp.Point.Position = Vector2.new(headPos.X, headPos.Y)
        esp.Point.Color = color
        esp.Point.Radius = Settings.PointSize
        esp.Point.Visible = true
    else
        esp.Point.Visible = false
    end

    if Settings.SkeletonESP then
        local bones = GetBonePositions(character)
        local function drawLine(fromPart, toPart, line)
            if not fromPart or not toPart then
                line.Visible = false
                return
            end
            local fromPos = Camera:WorldToViewportPoint((fromPart.CFrame * CFrame.new(0,0,0)).Position)
            local toPos = Camera:WorldToViewportPoint((toPart.CFrame * CFrame.new(0,0,0)).Position)
            if fromPos.Z < 0 or toPos.Z < 0 then
                line.Visible = false
                return
            end
            line.From = Vector2.new(fromPos.X, fromPos.Y)
            line.To = Vector2.new(toPos.X, toPos.Y)
            line.Color = color
            line.Thickness = Settings.SkeletonThickness
            line.Visible = true
        end

        local skel = esp.Skeleton
        drawLine(bones.Head, bones.UpperTorso, skel.Head)
        drawLine(bones.UpperTorso, bones.LowerTorso, skel.UpperTorso)
        drawLine(bones.UpperTorso, bones.LeftUpperArm, skel.LeftUpperArm)
        drawLine(bones.LeftUpperArm, bones.LeftLowerArm, skel.LeftLowerArm)
        drawLine(bones.LeftLowerArm, bones.LeftHand, skel.LeftHand)
        drawLine(bones.UpperTorso, bones.RightUpperArm, skel.RightUpperArm)
        drawLine(bones.RightUpperArm, bones.RightLowerArm, skel.RightLowerArm)
        drawLine(bones.RightLowerArm, bones.RightHand, skel.RightHand)
        drawLine(bones.LowerTorso, bones.LeftUpperLeg, skel.LeftUpperLeg)
        drawLine(bones.LeftUpperLeg, bones.LeftLowerLeg, skel.LeftLowerLeg)
        drawLine(bones.LeftLowerLeg, bones.LeftFoot, skel.LeftFoot)
        drawLine(bones.LowerTorso, bones.RightUpperLeg, skel.RightUpperLeg)
        drawLine(bones.RightUpperLeg, bones.RightLowerLeg, skel.RightLowerLeg)
        drawLine(bones.RightLowerLeg, bones.RightFoot, skel.RightFoot)
    else
        for _, line in pairs(esp.Skeleton) do line.Visible = false end
    end
end

local function CleanupESP()
    for player, esp in pairs(Drawings) do
        for _, line in pairs(esp.Box) do line:Remove() end
        esp.Name:Remove()
        for _, obj in pairs(esp.Health) do obj:Remove() end
        esp.Tracer:Remove()
        esp.Point:Remove()
        for _, line in pairs(esp.Skeleton) do line:Remove() end
    end
    Drawings = {}
end

local Window = Fluent:CreateWindow({
    Title = "Unknown Threat ESP",
    SubTitle = "by Great | discord.gg/nTMYauyf59",
    TabWidth = 160,
    Size = UDim2.fromOffset(500, 600),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "eye" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "palette" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
    Config = Window:AddTab({ Title = "Config", Icon = "save" })
}

do
    local mainSection = Tabs.Main:AddSection("ESP Toggles")

    local enabledToggle = mainSection:AddToggle("Enabled", {
        Title = "Enable ESP",
        Default = Settings.Enabled
    })
    enabledToggle:OnChanged(function()
        Settings.Enabled = enabledToggle.Value
        SaveWorkspaceSetting("Enabled", Settings.Enabled)
        if not Settings.Enabled then
            for _, esp in pairs(Drawings) do
                for _, line in pairs(esp.Box) do line.Visible = false end
                esp.Name.Visible = false
                for _, obj in pairs(esp.Health) do obj.Visible = false end
                esp.Tracer.Visible = false
                esp.Point.Visible = false
                for _, line in pairs(esp.Skeleton) do line.Visible = false end
            end
        end
    end)

    local boxToggle = mainSection:AddToggle("BoxESP", {
        Title = "Box ESP",
        Default = Settings.BoxESP
    })
    boxToggle:OnChanged(function()
        Settings.BoxESP = boxToggle.Value
        SaveWorkspaceSetting("BoxESP", Settings.BoxESP)
    end)

    local skeletonToggle = mainSection:AddToggle("SkeletonESP", {
        Title = "Skeleton ESP",
        Default = Settings.SkeletonESP
    })
    skeletonToggle:OnChanged(function()
        Settings.SkeletonESP = skeletonToggle.Value
        SaveWorkspaceSetting("SkeletonESP", Settings.SkeletonESP)
    end)

    local nameToggle = mainSection:AddToggle("NameESP", {
        Title = "Name ESP",
        Default = Settings.NameESP
    })
    nameToggle:OnChanged(function()
        Settings.NameESP = nameToggle.Value
        SaveWorkspaceSetting("NameESP", Settings.NameESP)
    end)

    local healthToggle = mainSection:AddToggle("HealthESP", {
        Title = "Health Bar",
        Default = Settings.HealthESP
    })
    healthToggle:OnChanged(function()
        Settings.HealthESP = healthToggle.Value
        SaveWorkspaceSetting("HealthESP", Settings.HealthESP)
    end)

    local tracerToggle = mainSection:AddToggle("TracerESP", {
        Title = "Tracer ESP",
        Default = Settings.TracerESP
    })
    tracerToggle:OnChanged(function()
        Settings.TracerESP = tracerToggle.Value
        SaveWorkspaceSetting("TracerESP", Settings.TracerESP)
    end)

    local pointToggle = mainSection:AddToggle("PointESP", {
        Title = "Head Point",
        Default = Settings.PointESP
    })
    pointToggle:OnChanged(function()
        Settings.PointESP = pointToggle.Value
        SaveWorkspaceSetting("PointESP", Settings.PointESP)
    end)

    local teamCheckToggle = mainSection:AddToggle("TeamCheck", {
        Title = "Team Check",
        Default = Settings.TeamCheck
    })
    teamCheckToggle:OnChanged(function()
        Settings.TeamCheck = teamCheckToggle.Value
        SaveWorkspaceSetting("TeamCheck", Settings.TeamCheck)
    end)
end

do
    local visualSection = Tabs.Visuals:AddSection("Box Settings")

    local boxStyle = visualSection:AddDropdown("BoxStyle", {
        Title = "Box Style",
        Values = {"Corner", "Full"},
        Default = Settings.BoxStyle
    })
    boxStyle:OnChanged(function(v)
        Settings.BoxStyle = v
        SaveWorkspaceSetting("BoxStyle", Settings.BoxStyle)
    end)

    local boxThickness = visualSection:AddSlider("BoxThickness", {
        Title = "Box Thickness",
        Default = Settings.BoxThickness,
        Min = 1,
        Max = 3,
        Rounding = 0
    })
    boxThickness:OnChanged(function(v)
        Settings.BoxThickness = v
        SaveWorkspaceSetting("BoxThickness", Settings.BoxThickness)
        for _, esp in pairs(Drawings) do
            for _, line in pairs(esp.Box) do
                line.Thickness = v
            end
        end
    end)

    local tracerSection = Tabs.Visuals:AddSection("Tracer Settings")

    local tracerOrigin = tracerSection:AddDropdown("TracerOrigin", {
        Title = "Tracer Origin",
        Values = {"Bottom", "Top", "Mouse", "Center"},
        Default = Settings.TracerOrigin
    })
    tracerOrigin:OnChanged(function(v)
        Settings.TracerOrigin = v
        SaveWorkspaceSetting("TracerOrigin", Settings.TracerOrigin)
    end)

    local tracerThickness = tracerSection:AddSlider("TracerThickness", {
        Title = "Tracer Thickness",
        Default = Settings.TracerThickness,
        Min = 1,
        Max = 3,
        Rounding = 0
    })
    tracerThickness:OnChanged(function(v)
        Settings.TracerThickness = v
        SaveWorkspaceSetting("TracerThickness", Settings.TracerThickness)
        for _, esp in pairs(Drawings) do
            esp.Tracer.Thickness = v
        end
    end)

    local healthSection = Tabs.Visuals:AddSection("Health Settings")

    local healthWidth = healthSection:AddSlider("HealthBarWidth", {
        Title = "Health Bar Width",
        Default = Settings.HealthBarWidth,
        Min = 2,
        Max = 10,
        Rounding = 0
    })
    healthWidth:OnChanged(function(v)
        Settings.HealthBarWidth = v
        SaveWorkspaceSetting("HealthBarWidth", Settings.HealthBarWidth)
    end)

    local showHealthText = healthSection:AddToggle("ShowHealthText", {
        Title = "Show Health Number",
        Default = Settings.ShowHealthText
    })
    showHealthText:OnChanged(function()
        Settings.ShowHealthText = showHealthText.Value
        SaveWorkspaceSetting("ShowHealthText", Settings.ShowHealthText)
    end)

    local pointSection = Tabs.Visuals:AddSection("Point Settings")

    local pointSize = pointSection:AddSlider("PointSize", {
        Title = "Point Size",
        Default = Settings.PointSize,
        Min = 2,
        Max = 15,
        Rounding = 0
    })
    pointSize:OnChanged(function(v)
        Settings.PointSize = v
        SaveWorkspaceSetting("PointSize", Settings.PointSize)
        for _, esp in pairs(Drawings) do
            esp.Point.Radius = v
        end
    end)

    local skeletonSection = Tabs.Visuals:AddSection("Skeleton Settings")

    local skelThickness = skeletonSection:AddSlider("SkeletonThickness", {
        Title = "Skeleton Thickness",
        Default = Settings.SkeletonThickness,
        Min = 1,
        Max = 3,
        Rounding = 1
    })
    skelThickness:OnChanged(function(v)
        Settings.SkeletonThickness = v
        SaveWorkspaceSetting("SkeletonThickness", Settings.SkeletonThickness)
        for _, esp in pairs(Drawings) do
            for _, line in pairs(esp.Skeleton) do
                line.Thickness = v
            end
        end
    end)
end

do
    local settingsSection = Tabs.Settings:AddSection("General")

    local maxDistance = settingsSection:AddSlider("MaxDistance", {
        Title = "Max Distance",
        Default = Settings.MaxDistance,
        Min = 50,
        Max = 2000,
        Rounding = 0
    })
    maxDistance:OnChanged(function(v)
        Settings.MaxDistance = v
        SaveWorkspaceSetting("MaxDistance", Settings.MaxDistance)
    end)

    local rainbowToggle = settingsSection:AddToggle("RainbowEnabled", {
        Title = "Rainbow Mode",
        Default = Settings.RainbowEnabled
    })
    rainbowToggle:OnChanged(function()
        Settings.RainbowEnabled = rainbowToggle.Value
        SaveWorkspaceSetting("RainbowEnabled", Settings.RainbowEnabled)
    end)

    local rainbowSpeed = settingsSection:AddSlider("RainbowSpeed", {
        Title = "Rainbow Speed",
        Default = Settings.RainbowSpeed,
        Min = 0.1,
        Max = 5,
        Rounding = 1
    })
    rainbowSpeed:OnChanged(function(v)
        Settings.RainbowSpeed = v
        SaveWorkspaceSetting("RainbowSpeed", Settings.RainbowSpeed)
    end)

    local colorsSection = Tabs.Settings:AddSection("Role Colors")

    local noRoleColor = colorsSection:AddColorpicker("NoRoleColor", {
        Title = "No Role (Spawn)",
        Default = Colors.NoRole
    })
    noRoleColor:OnChanged(function(v)
        Colors.NoRole = v
        SaveWorkspaceSetting("NoRoleColor", Colors.NoRole)
    end)

    local seekerColor = colorsSection:AddColorpicker("SeekerColor", {
        Title = "Seeker / Killer",
        Default = Colors.Seeker
    })
    seekerColor:OnChanged(function(v)
        Colors.Seeker = v
        Colors.Killer = v
        SaveWorkspaceSetting("SeekerColor", Colors.Seeker)
        SaveWorkspaceSetting("Killer", Colors.Killer)
    end)

    local hiderColor = colorsSection:AddColorpicker("HiderColor", {
        Title = "Hider",
        Default = Colors.Hider
    })
    hiderColor:OnChanged(function(v)
        Colors.Hider = v
        SaveWorkspaceSetting("HiderColor", Colors.Hider)
    end)

    local innocentColor = colorsSection:AddColorpicker("InnocentColor", {
        Title = "Innocent",
        Default = Colors.Innocent
    })
    innocentColor:OnChanged(function(v)
        Colors.Innocent = v
        SaveWorkspaceSetting("InnocentColor", Colors.Innocent)
    end)

    local policeColor = colorsSection:AddColorpicker("PoliceColor", {
        Title = "Police / SWAT / Sheriff",
        Default = Colors.Police
    })
    policeColor:OnChanged(function(v)
        Colors.Police = v
        Colors.Swat = v
        Colors.Sheriff = v
        SaveWorkspaceSetting("PoliceColor", Colors.Police)
        SaveWorkspaceSetting("Swat", Colors.Swat)
        SaveWorkspaceSetting("Sheriff", Colors.Sheriff)
    end)

    local traitorColor = colorsSection:AddColorpicker("TraitorColor", {
        Title = "Traitor",
        Default = Colors.Traitor
    })
    traitorColor:OnChanged(function(v)
        Colors.Traitor = v
        SaveWorkspaceSetting("TraitorColor", Colors.Traitor)
    end)

    local juggernautColor = colorsSection:AddColorpicker("JuggernautColor", {
        Title = "Juggernaut",
        Default = Colors.Juggernaut
    })
    juggernautColor:OnChanged(function(v)
        Colors.Juggernaut = v
        SaveWorkspaceSetting("JuggernautColor", Colors.Juggernaut)
    end)

    local unknownColor = colorsSection:AddColorpicker("UnknownColor", {
        Title = "Unknown (fallback)",
        Default = Colors.Unknown
    })
    unknownColor:OnChanged(function(v)
        Colors.Unknown = v
        SaveWorkspaceSetting("UnknownColor", Colors.Unknown)
    end)
end

do
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    InterfaceManager:SetFolder("UnknownThreatESP")
    SaveManager:SetFolder("UnknownThreatESP/configs")

    InterfaceManager:BuildInterfaceSection(Tabs.Config)
    SaveManager:BuildConfigSection(Tabs.Config)

    local unloadSection = Tabs.Config:AddSection("Unload")
    local unloadButton = unloadSection:AddButton({
        Title = "Unload ESP",
        Description = "Completely remove the ESP",
        Callback = function()
            CleanupESP()
            pcall(function()
                for _, connection in pairs(getconnections(RunService.RenderStepped)) do
                    connection:Disable()
                end
            end)
            Window:Destroy()
            Drawings = nil
            Settings = nil
        end
    })
end

task.spawn(function()
    while task.wait(0.05) do
        Colors.Rainbow = Color3.fromHSV(tick() * Settings.RainbowSpeed % 1, 1, 1)
    end
end)

RunService.RenderStepped:Connect(function()
    if not Settings.Enabled then
        for _, esp in pairs(Drawings) do
            for _, line in pairs(esp.Box) do line.Visible = false end
            esp.Name.Visible = false
            for _, obj in pairs(esp.Health) do obj.Visible = false end
            esp.Tracer.Visible = false
            esp.Point.Visible = false
            for _, line in pairs(esp.Skeleton) do line.Visible = false end
        end
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not Drawings[player] then
                CreateESP(player)
            end
            UpdateESP(player)
        end
    end
end)

Players.PlayerAdded:Connect(CreateESP)
Players.PlayerRemoving:Connect(RemoveESP)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end

Window:SelectTab(1)

Fluent:Notify({
    Title = "Unknown Threat ESP",
    Content = "Loaded! Settings saved in workspace. Join discord.gg/nTMYauyf59",
    Duration = 4
})
