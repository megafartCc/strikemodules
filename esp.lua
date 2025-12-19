local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local camera = game:GetService("Workspace").CurrentCamera
local player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local THEME = {
    panel = Color3.fromRGB(16, 18, 24),
    panel2 = Color3.fromRGB(22, 24, 30),
    text = Color3.fromRGB(230, 235, 240),
    textDim = Color3.fromRGB(170, 176, 186),
    accentA = Color3.fromRGB(64, 156, 255),
    accentB = Color3.fromRGB(0, 204, 204),
    gold = Color3.fromRGB(255, 215, 0),
}

local BlissfulSettings = {
    Box_Color = Color3.fromRGB(255, 255, 255),
    Tracer_Color = Color3.fromRGB(255, 255, 255),
    Tracer_Thickness = 1,
    Box_Thickness = 1,
    Tracer_Origin = "Bottom",
    Tracer_FollowMouse = false,
}
local hotbarDisplaySet = {}

local boxEspEnabled = false
local healthEspEnabled = false
local tracersEnabled = false
local teamCheckEnabled = false
local teamColorEnabled = true
local nameEspEnabled = false
local hotbarEspEnabled = false
local skeletonEspEnabled = false

local trackedPlayers = {}
local black = Color3.fromRGB(0, 0, 0)
local mouse = player:GetMouse()

local hasDrawing = (typeof(Drawing) == "table" or typeof(Drawing) == "userdata")
    and typeof(Drawing.new) == "function"
local hasTaskCancel = (type(task) == "table" or type(task) == "userdata")
    and type(task.cancel) == "function"

local TEAM_COLOR_MAP = {
    ["Terrorists"] = Color3.fromRGB(255, 85, 85),
    ["Counter-Terrorists"] = Color3.fromRGB(85, 170, 255),
}

local function getTeamName(plr)
    if not plr then
        return nil
    end
    local attr = plr:GetAttribute("Team")
    if attr and attr ~= "" then
        return attr
    end
    local teamObj = plr.Team
    if teamObj and teamObj.Name ~= "" then
        return teamObj.Name
    end
    return nil
end

local function isSameTeam(plr)
    local myTeam = getTeamName(player)
    local theirTeam = getTeamName(plr)
    if not myTeam or not theirTeam then
        return false
    end
    if myTeam == "Spectators" or theirTeam == "Spectators" then
        return false
    end
    return myTeam == theirTeam
end

local function resolveTeamColor(teamObj, teamName)
    if teamObj and teamObj.TeamColor then
        return teamObj.TeamColor.Color
    end
    return TEAM_COLOR_MAP[teamName]
end

local autoDigEnabled = false
local autoDigThread = nil
local autoDigManualEnabled = false
local autoSprinklerEnabled = false
local autoBuffItemsState = { false }
local autoBuffItemsThread = { nil }


local function safeFire(event, ...)
    if not event then return end
    local args = { ... }
    pcall(function()
        if #args == 0 then
            event:FireServer()
        else
            event:FireServer(table.unpack(args))
        end
    end)
end
local function getPlayerActivesCommand()
    local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
    or ReplicatedStorage:WaitForChild("Events", 1)
    return eventsFolder and eventsFolder:FindFirstChild("PlayerActivesCommand")
end
local function firePlayerActives(name)
    local ev = getPlayerActivesCommand()
    if not ev then return end
    safeFire(ev, { Name = tostring(name) })
end
local function startAutoLoop(stateRef, threadRef, interval, callback)
    if threadRef[1] then return end
    stateRef[1] = true
    threadRef[1] = task.spawn(function()
        while stateRef[1] do
            callback()
            task.wait(interval)
        end
        threadRef[1] = nil
    end)
end
local function stopAutoLoop(stateRef, threadRef)
    stateRef[1] = false
    if threadRef[1] then
        if hasTaskCancel then
            pcall(function()
                task.cancel(threadRef[1])
            end)
        end
        threadRef[1] = nil
    end
end
local function startAutoDig()
    if autoDigThread then
        return
    end
    autoDigEnabled = true
    autoDigThread = task.spawn(function()
        local args = {}
        while autoDigEnabled do
            local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
            or ReplicatedStorage:WaitForChild("Events", 1)
            local toolCollectRemote = eventsFolder and eventsFolder:FindFirstChild("ToolCollect")
            if toolCollectRemote then
                pcall(function()
                    toolCollectRemote:FireServer(table.unpack(args))
                end)
            end
            task.wait(0.1)
        end
        autoDigThread = nil
    end)
end
local function stopAutoDig()
    autoDigEnabled = false
    if autoDigThread then
        if hasTaskCancel then
            pcall(function()
                task.cancel(autoDigThread)
            end)
        end
        autoDigThread = nil
    end
end
local function refreshAutoDig(isAutoFarmEnabled)
    local shouldRun = isAutoFarmEnabled or autoDigManualEnabled
    if shouldRun and not autoDigEnabled then
        startAutoDig()
    elseif not shouldRun and autoDigEnabled then
        stopAutoDig()
    end
end
local function releaseBuffs()
    local buffs = {
        "Blue Extract",
        "Red Extract",
        "Oil",
        "Enzymes",
        "Glue",
        "Glitter",
        "Tropical Drink",
    }
    for _, name in ipairs(buffs) do
        firePlayerActives(name)
        task.wait(0.1)
    end
end

local function getHudRoot()
    local ok, ui = pcall(function()
        return gethui and gethui()
    end)
    if ok and ui then
        return ui
    end
    return game:GetService("CoreGui")
end

local function safeDisconnectConn(conn)
    if conn and typeof(conn) == "RBXScriptConnection" then
        pcall(function()
            conn:Disconnect()
        end)
    end
end

local function NewQuad(thickness, color)
    if hasDrawing then
        local quad = Drawing.new("Quad")
        quad.Visible = false
        quad.PointA = Vector2.new(0, 0)
        quad.PointB = Vector2.new(0, 0)
        quad.PointC = Vector2.new(0, 0)
        quad.PointD = Vector2.new(0, 0)
        quad.Color = color
        quad.Filled = false
        quad.Thickness = thickness
        quad.Transparency = 1
        return quad
    end
    local quad = {
        Visible = false,
        PointA = Vector2.new(0, 0),
        PointB = Vector2.new(0, 0),
        PointC = Vector2.new(0, 0),
        PointD = Vector2.new(0, 0),
        Color = color,
        Filled = false,
        Thickness = thickness,
        Transparency = 1,
    }
    function quad:Remove() end
    return quad
end

local function NewLine(thickness, color)
    if hasDrawing then
        local line = Drawing.new("Line")
        line.Visible = false
        line.From = Vector2.new(0, 0)
        line.To = Vector2.new(0, 0)
        line.Color = color
        line.Thickness = thickness
        line.Transparency = 1
        return line
    end

    local line = {
        Visible = false,
        From = Vector2.new(0, 0),
        To = Vector2.new(0, 0),
        Color = color,
        Thickness = thickness,
        Transparency = 1,
    }
    function line:Remove() end
    return line
end

local function ESP(plr)
    local data = trackedPlayers[plr]
    if not data then
        data = {}
        trackedPlayers[plr] = data
    end

    local library = {
        blacktracer = NewLine(BlissfulSettings.Tracer_Thickness * 2, black),
        tracer = NewLine(BlissfulSettings.Tracer_Thickness, BlissfulSettings.Tracer_Color),
        black = NewQuad(BlissfulSettings.Box_Thickness * 2, black),
        box = NewQuad(BlissfulSettings.Box_Thickness, BlissfulSettings.Box_Color),
        healthbar = NewLine(5, black),
        greenhealth = NewLine(3, black),
        nametext = nil,
        hotbartext = nil,
        teamtext = nil,
    }

    local hotbarGui = nil
    local hotbarFrame = nil
    local hotbarViewport = nil
    local hotbarCam = nil
    local lastToolName = nil
    local hotbarGuiName = "HotbarBillboard_" .. plr.Name

    local function ensureHotbarGui(anchorPart)
        if hotbarGui and hotbarGui.Parent == nil then
            hotbarGui = nil
        end
        if hotbarGui then
            return
        end
        local hudRoot = getHudRoot()
        local BillboardGui = hudRoot:FindFirstChild(hotbarGuiName)
        if BillboardGui then
            hotbarGui = BillboardGui
        else
            hotbarGui = Instance.new("BillboardGui")
            hotbarGui.Name = hotbarGuiName
            hotbarGui.AlwaysOnTop = true
            hotbarGui.Size = UDim2.fromOffset(64, 64)
            hotbarGui.StudsOffset = Vector3.new(0, -3.8, 0)
            hotbarGui.MaxDistance = 500
            hotbarGui.Adornee = anchorPart
            hotbarGui.Parent = hudRoot
        end

        hotbarFrame = hotbarGui:FindFirstChild("HotbarFrame")
        if not hotbarFrame then
            hotbarFrame = Instance.new("Frame")
            hotbarFrame.Name = "HotbarFrame"
            hotbarFrame.Size = UDim2.fromScale(1, 1)
            hotbarFrame.BackgroundColor3 = THEME.panel
            hotbarFrame.BackgroundTransparency = 0.35
            hotbarFrame.BorderSizePixel = 0
            hotbarFrame.Parent = hotbarGui
            local corner = Instance.new("UICorner", hotbarFrame)
            corner.CornerRadius = UDim.new(0, 10)
        end
        hotbarViewport = hotbarFrame:FindFirstChild("HotbarViewport")
        if not hotbarViewport then
            hotbarViewport = Instance.new("ViewportFrame")
            hotbarViewport.Name = "HotbarViewport"
            hotbarViewport.AnchorPoint = Vector2.new(0.5, 0.5)
            hotbarViewport.Position = UDim2.fromScale(0.5, 0.5)
            hotbarViewport.Size = UDim2.fromScale(0.9, 0.9)
            hotbarViewport.BackgroundTransparency = 1
            hotbarViewport.Ambient = Color3.fromRGB(200, 200, 200)
            hotbarViewport.LightColor = Color3.fromRGB(255, 255, 255)
            hotbarViewport.LightDirection = Vector3.new(0, -1, -1)
            hotbarViewport.Parent = hotbarFrame
            local cam = Instance.new("Camera")
            cam.Name = "HotbarCam"
            cam.FieldOfView = 40
            cam.Parent = hotbarViewport
            hotbarCam = cam
            hotbarViewport.CurrentCamera = hotbarCam
        else
            hotbarCam = hotbarViewport:FindFirstChild("HotbarCam")
            if not hotbarCam then
                local cam = Instance.new("Camera")
                cam.Name = "HotbarCam"
                cam.FieldOfView = 40
                cam.Parent = hotbarViewport
                hotbarCam = cam
                hotbarViewport.CurrentCamera = hotbarCam
            end
        end
    end
    
    local function clearViewport()
        if hotbarViewport then
            for _, ch in ipairs(hotbarViewport:GetChildren()) do
                if ch:IsA("Model") or ch:IsA("BasePart") or ch:IsA("Camera") then
                    if ch.Name ~= "HotbarCam" then
                        ch:Destroy()
                    end
                end
            end
        end
    end
    
    local function setViewportToTool(tool)
        if not tool then
            return
        end
        clearViewport()
        local model = Instance.new("Model")
        model.Name = "ToolPreview"
        model.Parent = hotbarViewport
        
        local function cloneParts(instance)
            for _, d in ipairs(instance:GetDescendants()) do
                if d:IsA("BasePart") then
                    local cp = d:Clone()
                    cp.Anchored = true
                    cp.CanCollide = false
                    cp.Parent = model
                end
            end
        end
        
        pcall(cloneParts, tool)
        local handle = tool:FindFirstChild("Handle")
        if handle and #model:GetChildren() == 0 then
            local h = handle:Clone()
            h.Anchored = true
            h.CanCollide = false
            h.Parent = model
        end
        
        local cf, size = model:GetBoundingBox()
        local center = cf.Position
        local maxDim = math.max(size.X, size.Y, size.Z)
        local distance = (maxDim == 0 and 2) or (maxDim * 2.2)
        local viewPos = (cf * CFrame.new(0, 0, distance)).Position
        if hotbarCam then
            hotbarCam.CFrame = CFrame.new(viewPos, center)
        end
    end
    
    local function destroyHotbarGui()
        if hotbarGui then
            pcall(function()
                hotbarGui:Destroy()
            end)
        end
        hotbarGui, hotbarFrame, hotbarViewport, hotbarCam = nil, nil, nil, nil
        lastToolName = nil
    end
    data.destroyHotbarGui = destroyHotbarGui

    local function Updater()
        local connection
        connection = RunService.RenderStepped
            :Connect(function()
                if
                    plr.Character ~= nil
                    and plr.Character:FindFirstChild("Humanoid") ~= nil
                    and plr.Character:FindFirstChild("HumanoidRootPart") ~= nil
                    and plr.Character.Humanoid.Health > 0
                    and plr.Character:FindFirstChild("Head") ~= nil
                then
                    local gamemode = workspace:GetAttribute("Gamemode")
                    if teamCheckEnabled and gamemode ~= "Deathmatch" and isSameTeam(plr) then
                        for _, drawing in pairs(library) do
                            if drawing and drawing.Visible then
                                drawing.Visible = false
                            end
                        end
                        destroyHotbarGui()
                        return
                    end
                    local humanoid = plr.Character.Humanoid
                    local hrp = plr.Character.HumanoidRootPart
                    local shakeOffset = humanoid.CameraOffset
                    local stable_hrp_pos_3d = hrp.Position - shakeOffset
                    local HumPos, OnScreen =
                        camera:WorldToViewportPoint(stable_hrp_pos_3d)
                    if OnScreen then
                        local box_top_3d = stable_hrp_pos_3d + Vector3.new(0, 3, 0)
                        local box_bottom_3d = stable_hrp_pos_3d + Vector3.new(0, -3, 0)
                        local box_top_2d = camera:WorldToViewportPoint(box_top_3d)
                        local box_bottom_2d = camera:WorldToViewportPoint(box_bottom_3d)
                        
                        local proj_height = box_bottom_2d.Y - box_top_2d.Y
                        local half_height = proj_height / 2
                        local half_width = half_height / 2
                        half_height = math.clamp(half_height, 2, math.huge)
                        half_width = math.clamp(half_width, 1, math.huge)
                        
                        local center_x = HumPos.X
                        local center_y = HumPos.Y
                        local yTop = center_y - half_height
                        local scale = math.clamp(half_height, 8, 220)
                        local nameSize = math.floor(math.clamp(scale * 0.30, 10, 18))
                        local hotbarSize = math.floor(math.clamp(scale * 0.28, 9, 16))
                        local teamSize = math.floor(math.clamp(scale * 0.22, 8, 13))
                        local margin = math.floor(math.clamp(scale * 0.10, 5, 12))

                        if nameEspEnabled then
                            if not library.nametext then
                                if hasDrawing then
                                    local t = Drawing.new("Text")
                                    t.Visible = false
                                    t.Center = true
                                    t.Outline = true
                                    t.Size = nameSize
                                    t.Color = Color3.fromRGB(255, 255, 255)
                                    library.nametext = t
                                end
                            end
                            if library.nametext then
                                local t = library.nametext
                                t.Size = nameSize
                                t.Text = plr.DisplayName or plr.Name
                                t.Position = Vector2.new(
                                    center_x,
                                    yTop - (margin + math.floor(nameSize * 0.60))
                                )
                                t.Color = Color3.fromRGB(255, 255, 255)
                                t.Visible = true
                            end
                        elseif library.nametext then
                            library.nametext.Visible = false
                        end

                        if boxEspEnabled then
                            local function Size(item)
                                item.PointA = Vector2.new(center_x + half_width, center_y - half_height)
                                item.PointB = Vector2.new(center_x - half_width, center_y - half_height)
                                item.PointC = Vector2.new(center_x - half_width, center_y + half_height)
                                item.PointD = Vector2.new(center_x + half_width, center_y + half_height)
                            end
                            Size(library.box)
                            Size(library.black)
                            library.box.Color = BlissfulSettings.Box_Color
                            library.box.Visible = true
                            library.black.Visible = true
                        else
                            library.box.Visible = false
                            library.black.Visible = false
                        end

                        if tracersEnabled then
                            if BlissfulSettings.Tracer_Origin == "Middle" then
                                library.tracer.From = camera.ViewportSize * 0.5
                                library.blacktracer.From = camera.ViewportSize * 0.5
                            elseif BlissfulSettings.Tracer_Origin == "Bottom" then
                                library.tracer.From = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y)
                                library.blacktracer.From = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y)
                            end
                            if BlissfulSettings.Tracer_FollowMouse then
                                library.tracer.From = Vector2.new(mouse.X, mouse.Y + 36)
                                library.blacktracer.From = Vector2.new(mouse.X, mouse.Y + 36)
                            end
                            library.tracer.To = Vector2.new(center_x, center_y + half_height)
                            library.blacktracer.To = Vector2.new(center_x, center_y + half_height)
                            library.tracer.Color = BlissfulSettings.Tracer_Color
                            library.tracer.Visible = true
                            library.blacktracer.Visible = true
                        else
                            library.tracer.Visible = false
                            library.blacktracer.Visible = false
                        end

                        if healthEspEnabled then
                            local d = 2 * half_height
                            local healthoffset = plr.Character.Humanoid.Health / plr.Character.Humanoid.MaxHealth * d
                            local healthbar_x = center_x - half_width - 4
                            local healthbar_top_y = center_y - half_height
                            local healthbar_bottom_y = center_y + half_height
                            
                            library.greenhealth.From = Vector2.new(healthbar_x, healthbar_bottom_y)
                            library.greenhealth.To = Vector2.new(healthbar_x, healthbar_bottom_y - healthoffset)
                            library.healthbar.From = Vector2.new(healthbar_x, healthbar_bottom_y)
                            library.healthbar.To = Vector2.new(healthbar_x, healthbar_top_y)
                            
                            local green = Color3.fromRGB(0, 255, 0)
                            local red = Color3.fromRGB(255, 0, 0)
                            library.greenhealth.Color = red:lerp(green, plr.Character.Humanoid.Health / plr.Character.Humanoid.MaxHealth)
                            library.healthbar.Visible = true
                            library.greenhealth.Visible = true
                        else
                            library.healthbar.Visible = false
                            library.greenhealth.Visible = false
                        end

                        local tool = nil
                        pcall(function()
                            tool = plr.Character:FindFirstChildOfClass("Tool")
                        end)
                        
                        if hotbarEspEnabled and hotbarDisplaySet.Text then
                            if not library.hotbartext then
                                if hasDrawing then
                                    local ht = Drawing.new("Text")
                                    ht.Visible = false
                                    ht.Center = true
                                    ht.Outline = true
                                    ht.Size = hotbarSize
                                    ht.Color = Color3.fromRGB(200, 200, 200)
                                    library.hotbartext = ht
                                end
                            end
                            if library.hotbartext then
                                local ht = library.hotbartext
                                ht.Size = hotbarSize
                                local label = (tool and tool.Name) or ""
                                ht.Text = label
                                local yBottom = center_y + half_height
                                local y = yBottom + math.max(1, margin - math.floor(hotbarSize * 0.35))
                                ht.Position = Vector2.new(center_x, y)
                                ht.Visible = (label ~= "")
                            end
                        elseif library.hotbartext then
                            library.hotbartext.Visible = false
                        end
                        
                        if hotbarEspEnabled and hotbarDisplaySet.Image and tool then
                            ensureHotbarGui(plr.Character.HumanoidRootPart)
                            if hotbarGui then
                                local px = math.floor(math.clamp(half_width * 1.2, 26, 84))
                                hotbarGui.Size = UDim2.fromOffset(px, px)
                                local currName = tool.Name
                                if currName ~= lastToolName then
                                    lastToolName = currName
                                    setViewportToTool(tool)
                                end
                            end
                        else
                            destroyHotbarGui()
                        end

                        local teamLabel = nil
                        local teamObj = plr.Team
                        local teamName = getTeamName(plr)
                        if teamCheckEnabled and teamName then
                            teamLabel = teamName
                        end
                        
                        if teamLabel and teamCheckEnabled then
                            if not library.teamtext then
                                if hasDrawing then
                                    local tt = Drawing.new("Text")
                                    tt.Visible = false
                                    tt.Center = false
                                    tt.Outline = true
                                    tt.Size = teamSize
                                    tt.Color = (teamColorEnabled and (resolveTeamColor(teamObj, teamName) or Color3.fromRGB(255, 255, 255))) or Color3.fromRGB(255, 255, 255)
                                    library.teamtext = tt
                                end
                            end
                            if library.teamtext then
                                local tt = library.teamtext
                                tt.Size = teamSize
                                tt.Text = teamLabel
                                tt.Position = Vector2.new(
                                    center_x + half_width + 4,
                                    yTop + math.max(2, math.floor(teamSize * 0.3))
                                )
                                tt.Color = (teamColorEnabled and (resolveTeamColor(teamObj, teamName) or Color3.fromRGB(255, 255, 255))) or Color3.fromRGB(255, 255, 255)
                                tt.Visible = true
                            end
                        elseif library.teamtext then
                            library.teamtext.Visible = false
                        end

                    else
                        for _, drawing in pairs(library) do
                            if drawing and drawing.Visible then
                                drawing.Visible = false
                            end
                        end
                        destroyHotbarGui()
                    end
                else
                    for _, drawing in pairs(library) do
                        if drawing and drawing.Visible then
                            drawing.Visible = false
                        end
                    end
                    destroyHotbarGui()
                    if Players:FindFirstChild(plr.Name) == nil then
                        connection:Disconnect()
                        for _, drawing in pairs(library) do
                            pcall(function()
                                if drawing and drawing.Remove then
                                    drawing:Remove()
                                end
                            end)
                        end
                        library = nil
                        if trackedPlayers[plr] then
                            if trackedPlayers[plr].SkeletonConnection then
                                safeDisconnectConn(trackedPlayers[plr].SkeletonConnection)
                            end
                            if trackedPlayers[plr].SkeletonLimbs then
                                for _, line in pairs(trackedPlayers[plr].SkeletonLimbs) do
                                    pcall(function()
                                        line:Remove()
                                    end)
                                end
                            end
                            trackedPlayers[plr] = nil
                        end
                    end
                end
            end)
    end
    coroutine.wrap(Updater)()
end

local function DrawSkeletonESP(plr)
    local data = trackedPlayers[plr]
    if not data then
        return
    end

    local function DrawLine()
        if hasDrawing then
            local l = Drawing.new("Line")
            l.Visible = false
            l.From = Vector2.new(0, 0)
            l.To = Vector2.new(1, 1)
            l.Color = Color3.fromRGB(255, 255, 255)
            l.Thickness = 1
            l.Transparency = 1
            return l
        end
        local l = {
            Visible = false,
            From = Vector2.new(0, 0),
            To = Vector2.new(0, 0),
            Color = Color3.fromRGB(255, 255, 255),
            Thickness = 1,
            Transparency = 1,
        }
        function l:Remove() end
        return l
    end

    repeat task.wait() until plr.Character ~= nil and plr.Character:FindFirstChildOfClass("Humanoid") ~= nil

    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local isR15 = hum and hum.RigType == Enum.HumanoidRigType.R15

    local limbs
    if isR15 then
        limbs = {
            Head_UpperTorso = DrawLine(),
            UpperTorso_LowerTorso = DrawLine(),
            UpperTorso_LeftUpperArm = DrawLine(),
            LeftUpperArm_LeftLowerArm = DrawLine(),
            LeftLowerArm_LeftHand = DrawLine(),
            UpperTorso_RightUpperArm = DrawLine(),
            RightUpperArm_RightLowerArm = DrawLine(),
            RightLowerArm_RightHand = DrawLine(),
            LowerTorso_LeftUpperLeg = DrawLine(),
            LeftUpperLeg_LeftLowerLeg = DrawLine(),
            LeftLowerLeg_LeftFoot = DrawLine(),
            LowerTorso_RightUpperLeg = DrawLine(),
            RightUpperLeg_RightLowerLeg = DrawLine(),
            RightLowerLeg_RightFoot = DrawLine(),
        }
    else
        limbs = {
            Head_Torso = DrawLine(),
            Torso_LeftArm = DrawLine(),
            Torso_RightArm = DrawLine(),
            Torso_LeftLeg = DrawLine(),
            Torso_RightLeg = DrawLine(),
        }
    end

    local sampleLimb
    for _, line in pairs(limbs) do
        sampleLimb = line
        break
    end

    local function SetVisible(state)
        for _, v in pairs(limbs) do
            v.Visible = state and skeletonEspEnabled or false
        end
    end

    local function anyVisible()
        for _, v in pairs(limbs) do
            if v.Visible then
                return true
            end
        end
        return false
    end

    local function viewport(pos)
        local res, onScreen = camera:WorldToViewportPoint(pos)
        return Vector2.new(res.X, res.Y), onScreen
    end

    local function setLine(key, partA, partB)
        local line = limbs[key]
        if not line then
            return false
        end
        if not partA or not partB then
            line.Visible = false
            return false
        end
        local from2d, onScreenA = viewport(partA.Position)
        local to2d, onScreenB = viewport(partB.Position)
        if not (onScreenA and onScreenB) then
            line.Visible = false
            return false
        end
        line.From = from2d
        line.To = to2d
        return true
    end

    data.SkeletonVisibilityFunc = SetVisible
    data.SkeletonLimbs = limbs

    local function UpdateR15Skeleton(char)
        local parts = {
            Head = char:FindFirstChild("Head"),
            UpperTorso = char:FindFirstChild("UpperTorso"),
            LowerTorso = char:FindFirstChild("LowerTorso"),
            LeftUpperArm = char:FindFirstChild("LeftUpperArm"),
            LeftLowerArm = char:FindFirstChild("LeftLowerArm"),
            LeftHand = char:FindFirstChild("LeftHand"),
            RightUpperArm = char:FindFirstChild("RightUpperArm"),
            RightLowerArm = char:FindFirstChild("RightLowerArm"),
            RightHand = char:FindFirstChild("RightHand"),
            LeftUpperLeg = char:FindFirstChild("LeftUpperLeg"),
            LeftLowerLeg = char:FindFirstChild("LeftLowerLeg"),
            LeftFoot = char:FindFirstChild("LeftFoot"),
            RightUpperLeg = char:FindFirstChild("RightUpperLeg"),
            RightLowerLeg = char:FindFirstChild("RightLowerLeg"),
            RightFoot = char:FindFirstChild("RightFoot"),
        }

        if not parts.Head or not parts.UpperTorso then
            SetVisible(false)
            return false
        end

        local visible = false
        if setLine("Head_UpperTorso", parts.Head, parts.UpperTorso) then visible = true end
        if setLine("UpperTorso_LowerTorso", parts.UpperTorso, parts.LowerTorso) then visible = true end
        if setLine("UpperTorso_LeftUpperArm", parts.UpperTorso, parts.LeftUpperArm) then visible = true end
        if setLine("LeftUpperArm_LeftLowerArm", parts.LeftUpperArm, parts.LeftLowerArm) then visible = true end
        if setLine("LeftLowerArm_LeftHand", parts.LeftLowerArm, parts.LeftHand) then visible = true end
        if setLine("UpperTorso_RightUpperArm", parts.UpperTorso, parts.RightUpperArm) then visible = true end
        if setLine("RightUpperArm_RightLowerArm", parts.RightUpperArm, parts.RightLowerArm) then visible = true end
        if setLine("RightLowerArm_RightHand", parts.RightLowerArm, parts.RightHand) then visible = true end
        if setLine("LowerTorso_LeftUpperLeg", parts.LowerTorso, parts.LeftUpperLeg) then visible = true end
        if setLine("LeftUpperLeg_LeftLowerLeg", parts.LeftUpperLeg, parts.LeftLowerLeg) then visible = true end
        if setLine("LeftLowerLeg_LeftFoot", parts.LeftLowerLeg, parts.LeftFoot) then visible = true end
        if setLine("LowerTorso_RightUpperLeg", parts.LowerTorso, parts.RightUpperLeg) then visible = true end
        if setLine("RightUpperLeg_RightLowerLeg", parts.RightUpperLeg, parts.RightLowerLeg) then visible = true end
        if setLine("RightLowerLeg_RightFoot", parts.RightLowerLeg, parts.RightFoot) then visible = true end

        return visible
    end

    local function UpdateR6Skeleton(char)
        local parts = {
            Head = char:FindFirstChild("Head"),
            Torso = char:FindFirstChild("Torso"),
            LeftArm = char:FindFirstChild("Left Arm"),
            RightArm = char:FindFirstChild("Right Arm"),
            LeftLeg = char:FindFirstChild("Left Leg"),
            RightLeg = char:FindFirstChild("Right Leg"),
        }

        if not parts.Head or not parts.Torso then
            SetVisible(false)
            return false
        end

        local visible = false
        if setLine("Head_Torso", parts.Head, parts.Torso) then visible = true end
        if setLine("Torso_LeftArm", parts.Torso, parts.LeftArm) then visible = true end
        if setLine("Torso_RightArm", parts.Torso, parts.RightArm) then visible = true end
        if setLine("Torso_LeftLeg", parts.Torso, parts.LeftLeg) then visible = true end
        if setLine("Torso_RightLeg", parts.Torso, parts.RightLeg) then visible = true end

        return visible
    end

    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not skeletonEspEnabled then
            SetVisible(false)
            return
        end

        if not camera then
            camera = workspace.CurrentCamera
        end

        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health <= 0 then
            SetVisible(false)
            return
        end

        local visible
        if hum.RigType == Enum.HumanoidRigType.R15 then
            visible = UpdateR15Skeleton(char)
        else
            visible = UpdateR6Skeleton(char)
        end

        if visible then
            if not anyVisible() then
                SetVisible(true)
            end
        else
            if anyVisible() then
                SetVisible(false)
            end
        end

        if not Players:FindFirstChild(plr.Name) then
            safeDisconnectConn(connection)
        end
    end)

    data.SkeletonConnection = connection
end

local function trackPlayer(newplr)
    if newplr.Name ~= player.Name then
        trackedPlayers[newplr] = trackedPlayers[newplr] or {}
        coroutine.wrap(ESP)(newplr)
        task.spawn(DrawSkeletonESP, newplr)
    end
end

local function onPlayerRemoving(rem)
    local data = trackedPlayers[rem]
    if data then
        if data.destroyHotbarGui then
            data.destroyHotbarGui()
        end
        if data.SkeletonConnection then
            safeDisconnectConn(data.SkeletonConnection)
        end
        if data.SkeletonLimbs then
            for _, line in pairs(data.SkeletonLimbs) do
                pcall(function()
                    line:Remove()
                end)
            end
        end
        trackedPlayers[rem] = nil
    end
end

local PlayerESP = {
    refreshAutoDig = refreshAutoDig
}

function PlayerESP:Init()
    for _, v in pairs(Players:GetPlayers()) do
        trackPlayer(v)
    end
    Players.PlayerAdded:Connect(trackPlayer)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function PlayerESP:InitAutomation()
    local savedState = false
    if savedState then
        self:SetAutoItemBuffs(true)
    end
end

function PlayerESP:SetBoxEsp(state)
    boxEspEnabled = state
end
function PlayerESP:SetHealthEsp(state)
    healthEspEnabled = state
end
function PlayerESP:SetTracers(state)
    tracersEnabled = state
end
function PlayerESP:SetTeamCheck(state)
    teamCheckEnabled = state
end
function PlayerESP:SetTeamColor(state)
    teamColorEnabled = state
end
function PlayerESP:SetSkeletonEsp(state)
    skeletonEspEnabled = state
    if not state then
        for _, data in pairs(trackedPlayers) do
            if data.SkeletonVisibilityFunc then
                data.SkeletonVisibilityFunc(false)
            end
        end
    end
end
function PlayerESP:SetNameEsp(state)
    nameEspEnabled = state
end
function PlayerESP:SetHotbarEsp(state)
    hotbarEspEnabled = state
    if not state then
        for _, data in pairs(trackedPlayers) do
            if data.destroyHotbarGui then
                data.destroyHotbarGui()
            end
        end
    end
end
function PlayerESP:SetHotbarDisplay(list)
    local set = {}
    if type(list) == "table" then
        if #list > 0 then
            for _, name in ipairs(list) do
                set[tostring(name)] = true
            end
        else
            for name, flag in pairs(list) do
                if flag then
                    set[tostring(name)] = true
                end
            end
        end
    end
    if next(set) == nil then
        set.Text = true
    end
    hotbarDisplaySet = set
end

function PlayerESP:SetAutoDigManual(state, isAutoFarmEnabled)
    autoDigManualEnabled = state
    refreshAutoDig(isAutoFarmEnabled)
end

function PlayerESP:SetAutoSprinkler(state)
    autoSprinklerEnabled = state
end

function PlayerESP:SetAutoActive(enabled, interval, activeName)
    local state = { enabled }
    local threadRef = { nil }
    
    local function getAutoLoopState(name)
        if not PlayerESP.ActiveStates then PlayerESP.ActiveStates = {} end
        if not PlayerESP.ActiveStates[name] then
            PlayerESP.ActiveStates[name] = { state = state, thread = threadRef }
        end
        return PlayerESP.ActiveStates[name]
    end

    local tracker = getAutoLoopState(activeName)

    if enabled then
        startAutoLoop(tracker.state, tracker.thread, interval, function()
            firePlayerActives(activeName)
        end)
    else
        stopAutoLoop(tracker.state, tracker.thread)
    end
end

function PlayerESP:SetAutoItemBuffs(enabled)
    autoBuffItemsState[1] = enabled
    if enabled then
        startAutoLoop(autoBuffItemsState, autoBuffItemsThread, 600, releaseBuffs)
    else
        stopAutoLoop(autoBuffItemsState, autoBuffItemsThread)
    end
end

function PlayerESP:FireActive(activeName)
    firePlayerActives(activeName)
end

return PlayerESP
