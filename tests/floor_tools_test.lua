-- Run with: texlua tests/floor_tools_test.lua (or Lua 5.3+).
warn = warn or function() end
local Now = 0
os.clock = function() return Now end
table.clear = table.clear or function(t) for k in pairs(t) do t[k] = nil end end
local function Signal()
    local SignalObject = { List = {} }
    function SignalObject:Connect(fn)
        local Connection = { Connected = true }
        function Connection:Disconnect() self.Connected = false end
        table.insert(self.List, { Connection, fn })
        return Connection
    end
    function SignalObject:Fire(...)
        for _, Entry in ipairs(self.List) do if Entry[1].Connected then Entry[2](...) end end
    end
    return SignalObject
end
local Vector = {}
Vector.__index = Vector
function Vector.__sub(a, b) return setmetatable({ X = a.X - b.X, Magnitude = math.abs(a.X - b.X) }, Vector) end
Vector3 = { new = function(x) return setmetatable({ X = x or 0 }, Vector) end }
UDim2 = { fromOffset = function() return {} end, fromScale = function() return {} end }
Color3 = { fromRGB = function(...) return {...} end }
RaycastParams = { new = function() return {} end }
Enum = { RaycastFilterType = { Exclude = "Exclude" } }
local Instances = {}
local Methods = {}
function Methods:IsA(Class) return self.ClassName == Class end
function Methods:GetAttribute(Key) return self.Attributes[Key] end
function Methods:IsDescendantOf(Ancestor)
    local Parent = self.Parent
    while Parent do if Parent == Ancestor then return true end; Parent = Parent.Parent end
    return false
end
function Methods:GetDescendants()
    local Result = {}
    for _, Object in ipairs(Instances) do if Object:IsDescendantOf(self) then table.insert(Result, Object) end end
    return Result
end
function Methods:FindFirstChild(Name)
    for _, Object in ipairs(Instances) do if Object.Parent == self and Object.Name == Name then return Object end end
end
function Methods:FindFirstChildOfClass(Class)
    for _, Object in ipairs(Instances) do if Object.Parent == self and Object.ClassName == Class then return Object end end
end
function Methods:FindFirstChildWhichIsA(Class, Recursive)
    for _, Object in ipairs(Instances) do
        if Object.ClassName == Class and (Object.Parent == self or Recursive and Object:IsDescendantOf(self)) then return Object end
    end
end
function Methods:Destroy()
    local Children = self:GetDescendants()
    for _, Child in ipairs(Children) do Child.Parent = nil end
    self.Parent = nil
    self.Destroyed = true
end
Instance = { new = function(Class)
    local Object = setmetatable({ ClassName = Class, Name = Class, Attributes = {}, CanTouch = true }, { __index = Methods })
    table.insert(Instances, Object)
    return Object
end }
local function Object(Class, Name, Parent, Position)
    local Result = Instance.new(Class)
    Result.Name, Result.Parent, Result.Position = Name, Parent, Vector3.new(Position or 0)
    return Result
end
local Create = assert(loadfile("Games/Doors/FloorTools.luau"))()
local function Fixture(Floor, Capability)
    Instances = {}
    local Workspace = Object("Workspace", "Workspace")
    Workspace.DescendantAdded = Signal()
    function Workspace:Raycast() return self.Hit end
    local Heartbeat = Signal()
    local Character = Object("Model", "Player", Workspace)
    local Root = Object("BasePart", "HumanoidRootPart", Character, 0)
    local Humanoid = Object("Humanoid", "Humanoid", Character); Humanoid.Health = 100
    local Player = { Character = Character, GetAttribute = function() return true end }
    local Players = { LocalPlayer = Player, GetPlayers = function() return {Player} end }
    local Library = { Toggles = {}, Options = {} }
    local function Control(Value, Disabled)
        return { Value = Value, Disabled = Disabled, OnChanged = function(self, fn) self.Callback = fn end,
            SetValue = function(self, v) self.Value = v; if self.Callback then self.Callback(v) end end }
    end
    local Group = {}
    function Group:AddTab() return self end
    function Group:AddLeftTabbox() return self end
    function Group:AddRightGroupbox() return self end
    function Group:AddLabel() end
    function Group:AddToggle(Key, Spec) Library.Toggles[Key] = Control(Spec.Default, Spec.Disabled) end
    function Group:AddSlider(Key, Spec) Library.Options[Key] = Control(Spec.Default) end
    function Group:AddInput(Key, Spec) Library.Options[Key] = Control(Spec.Default) end
    for _, Key in ipairs({ "ObjectiveESPToggle", "ItemESPToggle", "DoorESPToggle", "EntityESPToggle", "NotifyEntities", "BypassLookman" }) do
        Library.Toggles[Key] = Control(false)
    end
    local Replicated = Object("Folder", "FloorReplicated")
    local Timer = Object("IntValue", "DigitalTimer", Replicated); Timer.Value = 50
    local Gui = Object("Folder", "Gui")
    local Alerts, Fired = {}, {}
    local SaveManager = { Ignore = {} }
    local Cleanup = Create({ Library = Library, Window = Group, SaveManager = SaveManager,
        Services = { Workspace = Workspace, RunService = { Heartbeat = Heartbeat }, Players = Players },
        Floor = Floor, FloorReplicated = Replicated, EntityNames = { GrumbleRig = { Alias = "Grumble" }, BackdoorRush = { Alias = "Blitz" } },
        GuiParent = Gui, CanFirePrompt = Capability ~= false,
        Notify = function(Alert) table.insert(Alerts, Alert) end,
        TriggerPrompt = function(Prompt) if Fired.Fail then error("incompatible prompt") end; table.insert(Fired, Prompt) end,
    })
    return { Workspace = Workspace, Toggles = Library.Toggles, Options = Library.Options, Alerts = Alerts, Fired = Fired,
        Timer = Timer, Root = Root, Humanoid = Humanoid, Gui = Gui, Save = SaveManager, Cleanup = Cleanup,
        Step = function(Delta) Now = Now + (Delta or 0.3); Heartbeat:Fire() end,
        Track = function(Obj) Workspace.DescendantAdded:Fire(Obj) end }
end
local F = Fixture("The Mines")
assert(not F.Toggles.FloorTools_Mines_EntityESPToggle.Disabled)
assert(F.Toggles.FloorTools_Archives_EntityESPToggle.Disabled)
F.Toggles.FloorTools_Mines_EntityESPToggle:SetValue(true)
assert(F.Toggles.EntityESPToggle.Value)
F.Toggles.EntityESPToggle:SetValue(false); F.Step()
assert(not F.Toggles.FloorTools_Mines_EntityESPToggle.Value)
assert(F.Save.Ignore.FloorTools_Mines_EntityESPToggle)
local Entity = Object("Model", "GrumbleRig", F.Workspace)
local Hitbox = Object("BasePart", "Hitbox", Entity, 15)
local AlreadyOff = Object("BasePart", "DamageHitbox", Entity, 15); AlreadyOff.CanTouch = false
local Decoration = Object("BasePart", "Decoration", Entity, 15)
Entity.PrimaryPart = Hitbox; F.Track(Entity)
F.Toggles.FloorToolsContact:SetValue(true)
F.Toggles.FloorToolsAlerts:SetValue(true)
F.Toggles.FloorToolsEntityESP:SetValue(true)
F.Step(); assert(not Hitbox.CanTouch and not AlreadyOff.CanTouch and Decoration.CanTouch)
assert(#F.Alerts == 1 and #F.Gui:GetDescendants() == 3)
F.Step(); assert(#F.Alerts == 1)
F.Step(11); assert(#F.Alerts == 2)
F.Toggles.FloorToolsContact:SetValue(false)
assert(Hitbox.CanTouch and not AlreadyOff.CanTouch)
F.Toggles.FloorToolsContact:SetValue(true); F.Step()
F.Humanoid.Health = 0; F.Step(); assert(Hitbox.CanTouch and #F.Gui:GetDescendants() == 1)
F.Humanoid.Health = 100; F.Step(); assert(not Hitbox.CanTouch)
F.Cleanup(); assert(Hitbox.CanTouch and not AlreadyOff.CanTouch and #F.Gui:GetDescendants() == 0)
F.Step(); assert(Hitbox.CanTouch)

F = Fixture("Backdoor")
F.Toggles.FloorToolsLowTime:SetValue(true)
F.Timer.Value = 20; F.Step(); assert(#F.Alerts == 1)
F.Step(); assert(#F.Alerts == 1)
F.Timer.Value = 40; F.Step(); F.Timer.Value = 10; F.Step(); assert(#F.Alerts == 2)
local Lever = Object("Model", "TimerLever", F.Workspace)
local Part = Object("BasePart", "Handle", Lever, 5)
local Prompt = Object("ProximityPrompt", "ActivateEventPrompt", Part)
Prompt.Enabled, Prompt.MaxActivationDistance, Prompt.RequiresLineOfSight = true, 8, false
Prompt.ObjectText, Prompt.ActionText = "Lever", "Pull"
F.Track(Prompt); F.Toggles.FloorToolsAutoObjectives:SetValue(true)
F.Step(); assert(#F.Fired == 1)
F.Step(); assert(#F.Fired == 1)
F.Step(1.1); assert(#F.Fired == 2)
Part.Position = Vector3.new(9); F.Step(1.1); assert(#F.Fired == 2)
Part.Position = Vector3.new(5); Prompt.Enabled = false; F.Step(1.1); assert(#F.Fired == 2)
Prompt.Enabled = true; Prompt.RequiresLineOfSight = true
F.Workspace.Hit = { Instance = Object("BasePart", "Wall", F.Workspace) }; F.Step(1.1); assert(#F.Fired == 2)
F.Workspace.Hit = nil; F.Step(1.1); assert(#F.Fired == 3)
Lever.Attributes.Activated = true; F.Step(1.1); assert(#F.Fired == 3)
Lever.Attributes.Activated = false; F.Fired.Fail = true
F.Step(1.1); assert(not F.Toggles.FloorToolsAutoObjectives.Value)
F.Cleanup()

F = Fixture("The Archives", false)
assert(not F.Toggles.FloorTools_Archives_EntityESPToggle.Disabled)
assert(F.Toggles.FloorToolsAutoObjectives.Disabled)
local Custom = Object("Model", "ArchiveMonster", F.Workspace)
local CustomHit = Object("BasePart", "Hitbox", Custom, 5); Custom.PrimaryPart = CustomHit
F.Track(Custom); F.Toggles.FloorToolsContact:SetValue(true); F.Step(); assert(CustomHit.CanTouch)
F.Options.FloorToolsCustomEntities:SetValue(" ArchiveMonster, ")
F.Step(); assert(not CustomHit.CanTouch)
F.Options.FloorToolsCustomEntities:SetValue(""); F.Step(); assert(CustomHit.CanTouch)
F.Cleanup()
for _, Pair in ipairs({ {"The Outdoors", "Garden"}, {"Stairwell", "Stairwell"}, {"the_archives", "Archives"} }) do
    F = Fixture(Pair[1]); assert(not F.Toggles["FloorTools_" .. Pair[2] .. "_EntityESPToggle"].Disabled); F.Cleanup()
end
print("PASS: floor detection, linked controls, ESP cleanup, proximity cooldown, contact restoration, death/unload, timer rearming, objective range/cooldown/LOS, custom entities, capability gating")
