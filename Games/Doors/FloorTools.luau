-- Shared floor tools. Unknown floors/entities require explicit names, not guessed remotes.
return function(Context)
    local Library, Window = Context.Library, Context.Window
    local Toggles, Options = Library.Toggles, Library.Options
    local Workspace, RunService = Context.Services.Workspace, Context.Services.RunService
    local Player = Context.Services.Players.LocalPlayer
    local Profiles = {
        { Id = "Garden", Name = "The Outdoors", Aliases = { "garden", "outdoors", "theoutdoors" },
            Shortcuts = { "ShowEyestalkPathToggle", "BypassSnare" },
            Objectives = { GardenGateButton = true, VineGuillotine = true, LeverForGate = true },
            Contact = { Groundskeeper = true, MonumentEntity = true, LiveEntityBramble = true } },
        { Id = "Backdoor", Name = "The Backdoor", Aliases = { "backdoor", "backdoors", "thebackdoor" },
            Shortcuts = { "BypassLookman", "BypassVacuum", "AutoClosetToggle", "NotifyHasteTime" },
            Objectives = { TimerLever = true }, Contact = {} },
        { Id = "Archives", Name = "The Archives", Aliases = { "archives", "thearchives" },
            Shortcuts = {}, Objectives = {}, Contact = {}, Experimental = true },
        { Id = "Stairwell", Name = "Stairwell", Aliases = { "stairwell", "thestairwell" },
            Shortcuts = {}, Objectives = {}, Contact = {}, Experimental = true },
        { Id = "Mines", Name = "The Mines", Aliases = { "mines", "themines" },
            Shortcuts = { "BypassGiggle", "BypassGloombatEggs", "BypassSeekObstructions", "AutoSolveAnchors", "AutoSteerMinecart", "ShowSeekPathToggle", "RemoveScreech" },
            Objectives = { MinesGateButton = true, LeverForGate = true, WaterPump = true },
            Contact = { GrumbleRig = true } },
    }
    local FloorName = tostring(Context.Floor):lower():gsub("[%s_%-]", "")
    local Active
    for _, Profile in ipairs(Profiles) do
        for _, Alias in ipairs(Profile.Aliases) do
            if FloorName == Alias then Active = Profile end
        end
    end
    local Tab = Window:AddTab("Map Tools", "map")
    local Maps = Tab:AddLeftTabbox("Maps")
    local Shortcuts = {}
    local Labels = {
        ObjectiveESPToggle = "Objectives / keys ESP", ItemESPToggle = "Items ESP",
        DoorESPToggle = "Doors ESP", EntityESPToggle = "Entities ESP",
        NotifyEntities = "Entity spawn alerts", AutoClosetToggle = "Auto hide (known entities)",
        ShowEyestalkPathToggle = "Eyestalk path", BypassSnare = "Anti Snare",
        BypassLookman = "Bypass Lookman", BypassVacuum = "Anti Vacuum",
        NotifyHasteTime = "Haste timer", BypassGiggle = "Anti Giggle",
        BypassGloombatEggs = "Anti Gloombat eggs", BypassSeekObstructions = "Bypass Seek obstacles",
        AutoSolveAnchors = "Auto solve anchors", AutoSteerMinecart = "Auto steer minecart",
        ShowSeekPathToggle = "Seek path", RemoveScreech = "Anti Screech",
    }
    for _, Profile in ipairs(Profiles) do
        local Group = Maps:AddTab(Profile.Name)
        local IsActive = Profile == Active
        Group:AddLabel(IsActive and "Current map" or "Available when this map is loaded", true)
        if Profile.Experimental then
            Group:AddLabel("Shared tools only. Map-specific entities and puzzles are not verified. Add exact object names below for custom detection.", true)
        end
        local Keys = { "ObjectiveESPToggle", "ItemESPToggle", "DoorESPToggle", "EntityESPToggle", "NotifyEntities" }
        for _, Key in ipairs(Profile.Shortcuts) do table.insert(Keys, Key) end
        for _, Key in ipairs(Keys) do
            local Source = Toggles[Key]
            if Source then
                local ProxyKey = "FloorTools_" .. Profile.Id .. "_" .. Key
                Group:AddToggle(ProxyKey, {
                    Text = Labels[Key] or Key, Default = Source.Value,
                    Disabled = not IsActive or Source.Disabled == true,
                    DisabledTooltip = not IsActive and "Load this map first." or "Required executor capability is unavailable.",
                    Tooltip = "Linked to the existing control; uses the same entity filters and settings.",
                })
                local Proxy = Toggles[ProxyKey]
                Proxy:OnChanged(function(Value)
                    if IsActive and not Source.Disabled and Source.Value ~= Value then Source:SetValue(Value) end
                end)
                table.insert(Shortcuts, { Source = Source, Proxy = Proxy })
                -- Proxy controls mirror the original saved toggle, never restore a second copy.
                if Context.SaveManager and Context.SaveManager.Ignore then Context.SaveManager.Ignore[ProxyKey] = true end
            end
        end
    end

    local Tools = Tab:AddRightGroupbox("Current map tools")
    Tools:AddLabel("Detected floor: " .. tostring(Context.Floor), true)
    Tools:AddLabel("Contact bypass is local and experimental; server-side damage may still apply.", true)
    Tools:AddToggle("FloorToolsEntityESP", { Text = "Detected entities ESP", Default = false })
    Tools:AddToggle("FloorToolsPromptESP", { Text = "Nearby interaction markers", Default = false })
    Tools:AddToggle("FloorToolsAlerts", { Text = "Nearby entity alerts", Default = false })
    Tools:AddSlider("FloorToolsRange", { Text = "Detection distance", Min = 10, Max = 300, Default = 80, Rounding = 0 })
    Tools:AddToggle("FloorToolsContact", { Text = "Disable entity hitbox touch (experimental)", Default = false,
        Tooltip = "Disables local touch on detected Hitbox / DamageHitbox parts for Grumble, Outdoors entities, and your custom entity names. Restores original values when turned off." })
    Tools:AddInput("FloorToolsCustomEntities", { Text = "Extra entity object names (comma separated)", Default = "", Finished = true })
    Tools:AddToggle("FloorToolsAutoObjectives", { Text = "Auto interact with nearby objectives", Default = false,
        Disabled = not Context.CanFirePrompt, DisabledTooltip = "fireproximityprompt is unavailable.",
        Tooltip = "Uses recognized objective prompts within their normal range. Does not solve unknown puzzles." })
    Tools:AddSlider("FloorToolsInteractRange", { Text = "Interaction distance", Min = 1, Max = 20, Default = 10, Rounding = 0 })
    Tools:AddInput("FloorToolsCustomObjectives", { Text = "Extra objective object names (comma separated)", Default = "", Finished = true })
    Tools:AddToggle("FloorToolsLowTime", { Text = "Backdoor low-time alert", Default = false, Disabled = not Active or Active.Id ~= "Backdoor" })
    Tools:AddSlider("FloorToolsLowTimeThreshold", { Text = "Low-time threshold (seconds)", Min = 5, Max = 60, Default = 20, Rounding = 0 })

    local Entities, Prompts, Markers = {}, {}, {}
    local SavedTouch, LastAlert, LastPrompt = {}, {}, {}
    local CustomEntities, CustomObjectives = {}, {}
    local Connections, Stopped = {}, false
    local Folder = Instance.new("Folder")
    Folder.Name = "AbysallFloorTools"
    Folder.Parent = Context.GuiParent
    local function ParseNames(Text)
        local Names = {}
        for Name in tostring(Text):gmatch("[^,]+") do
            Name = Name:match("^%s*(.-)%s*$")
            if Name ~= "" then Names[Name] = true end
        end
        return Names
    end
    local function IsPlayer(Object)
        for _, Other in ipairs(Context.Services.Players:GetPlayers()) do
            if Other.Character and (Object == Other.Character or Object:IsDescendantOf(Other.Character)) then return true end
        end
        return false
    end
    local function IsEntity(Object)
        return Object:IsA("Model") and not IsPlayer(Object)
            and (Context.EntityNames[Object.Name] ~= nil or CustomEntities[Object.Name]
                or Object:GetAttribute("Entity") == true)
    end
    local function Track(Object)
        if Object:IsA("ProximityPrompt") then Prompts[Object] = true end
        if IsEntity(Object) then Entities[Object] = true end
    end
    local function Scan()
        table.clear(Entities)
        for _, Object in ipairs(Workspace:GetDescendants()) do Track(Object) end
    end
    Options.FloorToolsCustomEntities:OnChanged(function(Value)
        CustomEntities = ParseNames(Value)
        Scan()
    end)
    Options.FloorToolsCustomObjectives:OnChanged(function(Value) CustomObjectives = ParseNames(Value) end)
    local function RestoreTouch()
        for Part, Original in pairs(SavedTouch) do
            if Part.Parent then Part.CanTouch = Original end
            SavedTouch[Part] = nil
        end
    end
    Toggles.FloorToolsContact:OnChanged(function(Value) if not Value then RestoreTouch() end end)
    local function PartFor(Object)
        if Object:IsA("BasePart") then return Object end
        if Object:IsA("Attachment") then return Object.Parent end
        if Object:IsA("Model") then return Object.PrimaryPart or Object:FindFirstChildWhichIsA("BasePart", true) end
        return nil
    end
    local function Marker(Object, Part, Text, Color, Wanted)
        Wanted[Object] = true
        local Entry = Markers[Object]
        if not Entry then
            local Billboard = Instance.new("BillboardGui")
            Billboard.Size = UDim2.fromOffset(220, 30)
            Billboard.AlwaysOnTop = true
            Billboard.StudsOffset = Vector3.new(0, 3, 0)
            Billboard.Parent = Folder
            local Label = Instance.new("TextLabel")
            Label.Size = UDim2.fromScale(1, 1)
            Label.BackgroundTransparency = 1
            Label.TextStrokeTransparency = 0
            Label.TextSize = 14
            Label.Parent = Billboard
            Entry = { Billboard = Billboard, Label = Label }
            Markers[Object] = Entry
        end
        Entry.Billboard.Adornee = Part
        Entry.Label.Text = Text
        Entry.Label.TextColor3 = Color
    end
    local function ObjectiveFor(Prompt)
        local Object = Prompt.Parent
        while Object and Object ~= Workspace do
            if CustomObjectives[Object.Name] or (Active and Active.Objectives[Object.Name]) then return Object end
            Object = Object.Parent
        end
        return nil
    end
    local function CanInteract(Prompt, Part, Root, Objective)
        if not Prompt.Enabled or Prompt:GetAttribute("AutoInteractIgnore") or Objective:GetAttribute("Activated")
            or Objective:GetAttribute("Abysall_Completed") or Prompt.ActionText == "Close" then return false end
        local Distance = (Part.Position - Root.Position).Magnitude
        if Distance > math.min(Options.FloorToolsInteractRange.Value, Prompt.MaxActivationDistance) then return false end
        if Prompt.RequiresLineOfSight then
            local Params = RaycastParams.new()
            Params.FilterType = Enum.RaycastFilterType.Exclude
            Params.FilterDescendantsInstances = { Player.Character }
            local Hit = Workspace:Raycast(Root.Position, Part.Position - Root.Position, Params)
            if Hit and Hit.Instance ~= Part and not Hit.Instance:IsDescendantOf(Objective) then return false end
        end
        return true
    end
    local LowTimeAlerted, LastStep = false, 0
    local function Step()
        if Stopped or os.clock() - LastStep < 0.25 then return end
        LastStep = os.clock()
        for _, Link in ipairs(Shortcuts) do
            if Link.Proxy.Value ~= Link.Source.Value then Link.Proxy:SetValue(Link.Source.Value) end
        end
        local Character = Player.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local Alive = Root and Humanoid and Humanoid.Health > 0 and Player:GetAttribute("Alive") ~= false
        local Wanted, TouchWanted = {}, {}
        for Entity in pairs(Entities) do
            if not Entity:IsDescendantOf(Workspace) or not IsEntity(Entity) then
                Entities[Entity], LastAlert[Entity] = nil, nil
            else
                local Part = PartFor(Entity)
                local Distance = Alive and Part and (Part.Position - Root.Position).Magnitude
                if Distance and Distance <= Options.FloorToolsRange.Value then
                    local Data = Context.EntityNames[Entity.Name]
                    local Name = type(Data) == "table" and Data.Alias or Entity.Name
                    if Toggles.FloorToolsEntityESP.Value then
                        Marker(Entity, Part, Name .. " [" .. math.floor(Distance) .. "]", Color3.fromRGB(255, 90, 90), Wanted)
                    end
                    if Toggles.FloorToolsAlerts.Value and LastStep - (LastAlert[Entity] or -math.huge) >= 10 then
                        LastAlert[Entity] = LastStep
                        Context.Notify({ Title = Name .. " nearby", Body = tostring(math.floor(Distance)) .. " studs away." })
                    end
                end
                if Alive and Toggles.FloorToolsContact.Value and (CustomEntities[Entity.Name] or (Active and Active.Contact[Entity.Name])) then
                    for _, Hitbox in ipairs(Entity:GetDescendants()) do
                        if Hitbox:IsA("BasePart") and (Hitbox.Name == "Hitbox" or Hitbox.Name == "DamageHitbox") then
                            TouchWanted[Hitbox] = true
                            if SavedTouch[Hitbox] == nil then SavedTouch[Hitbox] = Hitbox.CanTouch end
                            Hitbox.CanTouch = false
                        end
                    end
                end
            end
        end
        for Part, Original in pairs(SavedTouch) do
            if not TouchWanted[Part] then
                if Part.Parent then Part.CanTouch = Original end
                SavedTouch[Part] = nil
            end
        end
        local NextPrompt, Nearest = nil, math.huge
        for Prompt in pairs(Prompts) do
            if not Prompt:IsDescendantOf(Workspace) then
                Prompts[Prompt], LastPrompt[Prompt] = nil, nil
            elseif Alive then
                local Part = PartFor(Prompt.Parent)
                if Part and Prompt.Enabled then
                    local Distance = (Part.Position - Root.Position).Magnitude
                    if Toggles.FloorToolsPromptESP.Value and Distance <= Options.FloorToolsRange.Value then
                        local Name = Prompt.ObjectText ~= "" and Prompt.ObjectText or Prompt.Parent.Name
                        Marker(Prompt, Part, Name .. " [" .. math.floor(Distance) .. "]", Color3.fromRGB(100, 255, 170), Wanted)
                    end
                    if Context.CanFirePrompt and Toggles.FloorToolsAutoObjectives.Value then
                        local Objective = ObjectiveFor(Prompt)
                        if Objective and Distance < Nearest and LastStep - (LastPrompt[Prompt] or -math.huge) >= 1
                            and CanInteract(Prompt, Part, Root, Objective) then
                            NextPrompt, Nearest = Prompt, Distance
                        end
                    end
                end
            end
        end
        if NextPrompt then
            LastPrompt[NextPrompt] = LastStep
            -- Reuse the hub's inventory checks and prompt blacklist.
            local Success, Failure = pcall(Context.TriggerPrompt, NextPrompt)
            if not Success then
                Toggles.FloorToolsAutoObjectives:SetValue(false)
                Context.Notify({ Title = "Objective automation stopped", Body = "This prompt is incompatible with the current game version." })
                warn("Abysall objective prompt: " .. tostring(Failure))
            end
        end
        for Object, Entry in pairs(Markers) do
            if not Wanted[Object] then Entry.Billboard:Destroy(); Markers[Object] = nil end
        end
        local Timer = Context.FloorReplicated:FindFirstChild("DigitalTimer")
        local Time = Timer and tonumber(Timer.Value)
        if Active and Active.Id == "Backdoor" and Toggles.FloorToolsLowTime.Value and Time then
            if Time > Options.FloorToolsLowTimeThreshold.Value then
                LowTimeAlerted = false
            elseif not LowTimeAlerted then
                LowTimeAlerted = true
                Context.Notify({ Title = "Backdoor: low time", Body = tostring(math.max(0, math.floor(Time))) .. " seconds remaining. Find a time lever." })
            end
        else
            LowTimeAlerted = false
        end
    end
    Scan()
    table.insert(Connections, Workspace.DescendantAdded:Connect(Track))
    table.insert(Connections, RunService.Heartbeat:Connect(Step))
    return function()
        Stopped = true
        for _, Connection in ipairs(Connections) do Connection:Disconnect() end
        RestoreTouch()
        Folder:Destroy()
        table.clear(Entities)
        table.clear(Prompts)
        table.clear(Markers)
    end
end
