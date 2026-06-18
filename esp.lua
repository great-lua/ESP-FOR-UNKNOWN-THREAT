local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Drawings = {}
local Settings = {
    Enabled = false,
    PointESP = true,
    PointSize = 5,
    SkeletonESP = false,
    NameESP = false,
    MaxDistance = 400,
    TeamCheck = false,
    ShowTeam = false,
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
    Unknown = Color3.fromRGB(150, 150, 150),
}

local function GetPlayerRole(player)
    local roleAttr = player:GetAttribute("Role")
    if roleAttr then
        local role = tostring(roleAttr):upper()
        if role:find("SEEKER") then return "Seeker" end
        if role:find("KILLER") then return "Killer" end
        if role:find("HIDER") then return "Hider" end
        if role:find("INNOCENT") then return "Innocent" end
        if role:find("TRAITOR") then return "Traitor" end
        if role:find("POLICE") then return "Police" end
        if role:find("SWAT") then return "Swat" end
        if role:find("SHERIFF") then return "Sheriff" end
        if role:find("JUGGERNAUT") then return "Juggernaut" end
    end

    local deathRole = player:GetAttribute("DeathRole")
    if deathRole then
        local dr = tostring(deathRole):upper()
        if dr:find("SEEKER") then return "Seeker" end
        if dr:find("KILLER") then return "Killer" end
        if dr:find("HIDER") then return "Hider" end
    end

    local character = player.Character
    if character then
        local function normalize(val)
            if not val then return nil end
            local v = tostring(val):upper():gsub("%s+", "")
            if v:find("SEEKER") or v:find("KILLER") or v:find("MURDERER") then return "Seeker" end
            if v:find("HIDER") then return "Hider" end
            if v:find("INNOCENT") or v:find("CIVILIAN") then return "Innocent" end
            if v:find("TRAITOR") or v:find("TERRORIST") then return "Traitor" end
            if v:find("POLICE") then return "Police" end
            if v:find("SWAT") then return "Swat" end
            if v:find("SHERIFF") or v:find("DETECTIVE") then return "Sheriff" end
            if v:find("JUGGERNAUT") then return "Juggernaut" end
            return nil
        end

        local gui = player:FindFirstChild("PlayerGui")
        if gui then
            local timer = gui:FindFirstChild("TimerAndMore")
            if timer then
                local status = timer:FindFirstChild("StatusDisplay")
                if status then
                    local roleText = status:FindFirstChild("RoleText")
                    if roleText and roleText:IsA("TextLabel") then
                        local res = normalize(roleText.Text)
                        if res then return res end
                    end
                end
            end
        end

        local head = character:FindFirstChild("Head")
        if head then
            local nameTag = head:FindFirstChild("CustomNameTag")
            if nameTag then
                local roleLabel = nameTag:FindFirstChild("RoleLabel")
                if roleLabel then
                    local val = (roleLabel:IsA("TextLabel") and roleLabel.Text) or (roleLabel:IsA("StringValue") and roleLabel.Value) or nil
                    if val then
                        local res = normalize(val)
                        if res then return res end
                    end
                end
            end
        end
    end

    return "Unknown"
end

local function IsTeammate(player)
    local localRole = GetPlayerRole(LocalPlayer)
    local targetRole = GetPlayerRole(player)
    if localRole == "Unknown" or targetRole == "Unknown" then return false end

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

local function CreateESP(player)
    if player == LocalPlayer then return end

    local point = Drawing.new("Circle")
    local name = Drawing.new("Text")
    point.Visible = false
    point.Radius = Settings.PointSize
    point.Thickness = 1
    point.Filled = true
    point.NumSides = 20

    name.Visible = false
    name.Center = true
    name.Size = 14
    name.Font = 2
    name.Outline = true
    name.Color = Color3.fromRGB(255, 255, 255)

    local skeleton = {}
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
        line.Color = Color3.fromRGB(255, 255, 255)
        line.Thickness = 1.5
        skeleton[name] = line
    end

    Drawings[player] = {
        Point = point,
        Name = name,
        Skeleton = skeleton
    }
end

local function RemoveESP(player)
    local esp = Drawings[player]
    if esp then
        esp.Point:Remove()
        esp.Name:Remove()
        for _, line in pairs(esp.Skeleton) do
            line:Remove()
        end
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

local function UpdateESP(player)
    if not Settings.Enabled then return end

    local esp = Drawings[player]
    if not esp then return end

    local character = player.Character
    if not character then
        esp.Point.Visible = false
        esp.Name.Visible = false
        for _, line in pairs(esp.Skeleton) do line.Visible = false end
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        esp.Point.Visible = false
        esp.Name.Visible = false
        for _, line in pairs(esp.Skeleton) do line.Visible = false end
        return
    end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        esp.Point.Visible = false
        esp.Name.Visible = false
        for _, line in pairs(esp.Skeleton) do line.Visible = false end
        return
    end

    local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude

    if not onScreen or distance > Settings.MaxDistance then
        esp.Point.Visible = false
        esp.Name.Visible = false
        for _, line in pairs(esp.Skeleton) do line.Visible = false end
        return
    end

    if Settings.TeamCheck and IsTeammate(player) and not Settings.ShowTeam then
        esp.Point.Visible = false
        esp.Name.Visible = false
        for _, line in pairs(esp.Skeleton) do line.Visible = false end
        return
    end

    local role = GetPlayerRole(player)
    local color = Colors[role] or Colors.Unknown

    local head = character:FindFirstChild("Head")
    local headPos
    if head then
        headPos = Camera:WorldToViewportPoint(head.Position)
    else
        headPos = Camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 2, 0))
    end

    if Settings.PointESP then
        esp.Point.Position = Vector2.new(headPos.X, headPos.Y)
        esp.Point.Color = color
        esp.Point.Radius = Settings.PointSize
        esp.Point.Visible = true
    else
        esp.Point.Visible = false
    end

    if Settings.NameESP then
        esp.Name.Text = player.DisplayName
        esp.Name.Position = Vector2.new(headPos.X, headPos.Y - 20)
        esp.Name.Color = color
        esp.Name.Visible = true
    else
        esp.Name.Visible = false
    end

    if Settings.SkeletonESP then
        local bones = GetBonePositions(character)
        local function drawLine(fromPart, toPart, line)
            if not fromPart or not toPart then
                line.Visible = false
                return
            end
            local fromPos = Camera:WorldToViewportPoint((fromPart.CFrame * CFrame.new(0, 0, 0)).Position)
            local toPos = Camera:WorldToViewportPoint((toPart.CFrame * CFrame.new(0, 0, 0)).Position)
            if fromPos.Z < 0 or toPos.Z < 0 then
                line.Visible = false
                return
            end
            line.From = Vector2.new(fromPos.X, fromPos.Y)
            line.To = Vector2.new(toPos.X, toPos.Y)
            line.Color = color
            line.Thickness = 1.5
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
        for _, line in pairs(esp.Skeleton) do
            line.Visible = false
        end
    end
end

local function CleanupESP()
    for player, esp in pairs(Drawings) do
        esp.Point:Remove()
        esp.Name:Remove()
        for _, line in pairs(esp.Skeleton) do
            line:Remove()
        end
    end
    Drawings = {}
end

local Window = Fluent:CreateWindow({
    Title = "Unknown Threat ESP",
    SubTitle = "By Great | Discord: discord.gg/qR7ABr7f",
    TabWidth = 160,
    Size = UDim2.fromOffset(500, 500),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "eye" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
    Config = Window:AddTab({ Title = "Config", Icon = "save" })
}

do
    local mainSection = Tabs.Main:AddSection("ESP")

    local enabledToggle = mainSection:AddToggle("Enabled", {
        Title = "Enable ESP",
        Default = false
    })
    enabledToggle:OnChanged(function()
        Settings.Enabled = enabledToggle.Value
        if not Settings.Enabled then
            for _, esp in pairs(Drawings) do
                esp.Point.Visible = false
                esp.Name.Visible = false
                for _, line in pairs(esp.Skeleton) do line.Visible = false end
            end
        end
    end)

    local pointToggle = mainSection:AddToggle("PointESP", {
        Title = "Role Points",
        Default = true
    })
    pointToggle:OnChanged(function()
        Settings.PointESP = pointToggle.Value
    end)

    local skeletonToggle = mainSection:AddToggle("SkeletonESP", {
        Title = "Skeleton ESP",
        Default = false
    })
    skeletonToggle:OnChanged(function()
        Settings.SkeletonESP = skeletonToggle.Value
    end)

    local nameToggle = mainSection:AddToggle("NameESP", {
        Title = "Name ESP",
        Default = false
    })
    nameToggle:OnChanged(function()
        Settings.NameESP = nameToggle.Value
    end)

    local teamCheckToggle = mainSection:AddToggle("TeamCheck", {
        Title = "Team Check",
        Default = false
    })
    teamCheckToggle:OnChanged(function()
        Settings.TeamCheck = teamCheckToggle.Value
    end)

    local showTeamToggle = mainSection:AddToggle("ShowTeam", {
        Title = "Show Team",
        Default = false
    })
    showTeamToggle:OnChanged(function()
        Settings.ShowTeam = showTeamToggle.Value
    end)
end

do
    local settingsSection = Tabs.Settings:AddSection("Visuals")

    local pointSize = settingsSection:AddSlider("PointSize", {
        Title = "Point Size",
        Default = 5,
        Min = 2,
        Max = 15,
        Rounding = 0
    })
    pointSize:OnChanged(function(value)
        Settings.PointSize = value
        for _, esp in pairs(Drawings) do
            esp.Point.Radius = value
        end
    end)

    local maxDistance = settingsSection:AddSlider("MaxDistance", {
        Title = "Max Distance",
        Default = 400,
        Min = 50,
        Max = 1000,
        Rounding = 0
    })
    maxDistance:OnChanged(function(value)
        Settings.MaxDistance = value
    end)

    local colorsSection = Tabs.Settings:AddSection("Role Colors")

    local seekerColor = colorsSection:AddColorpicker("SeekerColor", {
        Title = "Seeker / Killer",
        Default = Colors.Seeker
    })
    seekerColor:OnChanged(function(value)
        Colors.Seeker = value
        Colors.Killer = value
    end)

    local hiderColor = colorsSection:AddColorpicker("HiderColor", {
        Title = "Hider",
        Default = Colors.Hider
    })
    hiderColor:OnChanged(function(value)
        Colors.Hider = value
    end)

    local innocentColor = colorsSection:AddColorpicker("InnocentColor", {
        Title = "Innocent",
        Default = Colors.Innocent
    })
    innocentColor:OnChanged(function(value)
        Colors.Innocent = value
    end)

    local policeColor = colorsSection:AddColorpicker("PoliceColor", {
        Title = "Police / SWAT / Sheriff",
        Default = Colors.Police
    })
    policeColor:OnChanged(function(value)
        Colors.Police = value
        Colors.Swat = value
        Colors.Sheriff = value
    end)

    local traitorColor = colorsSection:AddColorpicker("TraitorColor", {
        Title = "Traitor",
        Default = Colors.Traitor
    })
    traitorColor:OnChanged(function(value)
        Colors.Traitor = value
    end)

    local juggernautColor = colorsSection:AddColorpicker("JuggernautColor", {
        Title = "Juggernaut",
        Default = Colors.Juggernaut
    })
    juggernautColor:OnChanged(function(value)
        Colors.Juggernaut = value
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

RunService.RenderStepped:Connect(function()
    if not Settings.Enabled then
        for _, esp in pairs(Drawings) do
            esp.Point.Visible = false
            esp.Name.Visible = false
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
    Content = "Loaded! Join our Discord: discord.gg/qR7ABr7f",
    Duration = 5
})
