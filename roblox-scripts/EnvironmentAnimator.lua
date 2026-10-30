--[[
    ============================================================================
    ENVIRONMENT & OBBY DYNAMIC ANIMATOR (PART.C5CA FULL SUITE)
    ============================================================================
    Animates ALL elements in workspace.Model["Part.c5ca"]:
    1. Palm Trees (20 models): Multi-sine harmonic wind breeze swaying leaf crowns.
    2. Duck Floaties (2 models): Water wave bobbing and gentle rocking.
    3. Inflatable Water Obstacles / Floating Modular Rubber Platforms (90 MeshParts):
       Gentle aquatic wave floatation with spatial offsets across the water surface.
    4. Bounce House & Trampoline Pillars (Balloons & Pillars):
       Breathing inflation pulse and gentle sway.
    5. Inflatable Arches, Tunnels & Castle Walls:
       Subtle wind-responsive flex and bounce.
    Runs on Client (RenderStepped) for 60+ FPS zero server physics load.
]]

local RunService = game:GetService("RunService")

local folder = workspace:WaitForChild("Model", 30):WaitForChild("Part.c5ca", 30)

-- 1. Palm Trees
local palmTrees = {}
-- 2. Duck Floaties
local duckFloaties = {}
-- 3. Floating Modular Rubber Tiles / Obstacle Pads (the 90 MeshParts)
local waterTiles = {}
-- 4. Bounce House & Towers
local bounceStructures = {}
-- 5. Floating Tunnels, Arches & Ramps
local inflatableObstacles = {}
-- 6. Castle Tower Wind-Flapping Banners / Flags (Beams)
local castleFlags = {}

-- Function to safely index and register a flag beam
local function registerFlag(beam)
    if not (beam and beam.Attachment0 and beam.Attachment1) then return end
    for _, f in ipairs(castleFlags) do
        if f.beam == beam then return end
    end

    local a0 = beam.Attachment0
    local a1 = beam.Attachment1
    local tipAtt = (math.abs(a1.Position.Z) > math.abs(a0.Position.Z)) and a1 or a0
    local baseAtt = (tipAtt == a1) and a0 or a1

    table.insert(castleFlags, {
        beam = beam,
        baseCurve = beam.CurveSize0,
        tipAtt = tipAtt,
        baseAtt = baseAtt,
        origTipPos = tipAtt.Position,
        phase = (tipAtt.WorldPosition.X * 0.12 + tipAtt.WorldPosition.Z * 0.12),
        windSpeed = 6.0 + math.random() * 2.0,
        flutterFreq = 14.0 + math.random() * 4.0
    })
end

local targetFlagNames = {
    ["Part.3445"] = true,
    ["Object.e663"] = true,
    ["Part.b8c2"] = true,
    ["Object.be9a"] = true,
    ["Object.2e91"] = true
}

local function scanForFlags()
    for _, desc in ipairs(folder:GetDescendants()) do
        if targetFlagNames[desc.Name] then
            local beam = desc:IsA("Beam") and desc or desc:FindFirstChildWhichIsA("Beam")
            if beam then
                registerFlag(beam)
            end
        end
    end
end

-- Scan immediately and also listen for newly loaded instances (streaming support)
scanForFlags()
folder.DescendantAdded:Connect(function(desc)
    if targetFlagNames[desc.Name] then
        task.defer(function()
            local beam = desc:IsA("Beam") and desc or desc:FindFirstChildWhichIsA("Beam")
            if beam then
                registerFlag(beam)
            end
        end)
    end
end)

for _, child in ipairs(folder:GetChildren()) do
    local name = child.Name

    if name == "Palm Tree" and child:IsA("Model") then
        local parts = child:GetChildren()
        if #parts >= 2 then
            local p1, p2 = parts[1], parts[2]
            local topPart = (p1.Position.Y > p2.Position.Y) and p1 or p2
            local basePart = (topPart == p1) and p2 or p1
            table.insert(palmTrees, {
                top = topPart,
                origCFrame = topPart.CFrame,
                basePos = basePart.Position,
                phase = math.random() * math.pi * 2,
                speed = 0.85 + math.random() * 0.45,
                angleStrength = math.rad(2.2 + math.random() * 1.5)
            })
        end

    elseif name == "Duck Floatie" and child:IsA("Model") then
        table.insert(duckFloaties, {
            model = child,
            origCFrame = child:GetPivot(),
            phase = math.random() * math.pi * 2,
            waveSpeed = 1.35 + math.random() * 0.35,
            bobHeight = 0.7 + math.random() * 0.3,
            rockStrength = math.rad(3.5 + math.random() * 2.0)
        })

    elseif name == "Bounce House" and child:IsA("Model") then
        table.insert(bounceStructures, {
            model = child,
            origCFrame = child:GetPivot(),
            phase = math.random() * math.pi * 2,
            speed = 1.8,
            bounceHeight = 0.45,
            tiltStrength = math.rad(1.5)
        })

    elseif (name == "Tunnel" or name == "Arches" or name == "Ramp" or name == "Castle Wall" or name == "Walls") and child:IsA("Model") then
        local pivot = child:GetPivot()
        table.insert(inflatableObstacles, {
            model = child,
            origCFrame = pivot,
            phase = (pivot.Position.X * 0.05 + pivot.Position.Z * 0.05),
            waveSpeed = 1.1 + math.random() * 0.25,
            bobHeight = 0.35 + math.random() * 0.15,
            rockStrength = math.rad(1.2 + math.random() * 0.8)
        })

    elseif name == "Model" and child:IsA("Model") then
        -- Tall corner inflatable balloon towers / spires
        local pivot = child:GetPivot()
        table.insert(bounceStructures, {
            model = child,
            origCFrame = pivot,
            phase = math.random() * math.pi * 2,
            speed = 1.4,
            bounceHeight = 0.4,
            tiltStrength = math.rad(2.0)
        })

    elseif child:IsA("MeshPart") then
        -- Inflatable floating obstacle tiles on the water surface (Y around 56.7)
        local origCF = child.CFrame
        local x = origCF.Position.X
        local z = origCF.Position.Z
        -- Spatial wave equation: tiles ripple according to position across the water surface
        table.insert(waterTiles, {
            part = child,
            origCFrame = origCF,
            spatialPhase = (x * 0.038 + z * 0.038),
            speed = 1.25,
            waveHeight = 0.38,
            rockAngle = math.rad(1.2)
        })
    end
end

-- Continuous frame-by-frame ambient simulation
RunService.RenderStepped:Connect(function()
    local now = os.clock()

    -- 1. Palm Trees wind sway
    for _, tree in ipairs(palmTrees) do
        if tree.top and tree.top.Parent then
            local t = now * tree.speed + tree.phase
            local windRoll = math.sin(t) * tree.angleStrength + math.sin(t * 1.7) * (tree.angleStrength * 0.35)
            local windPitch = math.cos(t * 0.8) * (tree.angleStrength * 0.6)

            local offsetFromBase = tree.origCFrame.Position - tree.basePos
            local rotatedOffset = (CFrame.Angles(windPitch, 0, windRoll) * CFrame.new(offsetFromBase)).Position

            tree.top.CFrame = CFrame.new(tree.basePos + rotatedOffset) * (tree.origCFrame - tree.origCFrame.Position) * CFrame.Angles(windPitch, 0, windRoll)
        end
    end

    -- 2. Duck Floaties bobbing and rocking
    for _, floatie in ipairs(duckFloaties) do
        if floatie.model and floatie.model.Parent then
            local t = now * floatie.waveSpeed + floatie.phase
            local waveY = math.sin(t) * floatie.bobHeight
            local rockPitch = math.sin(t * 0.9) * floatie.rockStrength
            local rockRoll = math.cos(t * 1.1) * (floatie.rockStrength * 0.85)

            local currentPos = floatie.origCFrame.Position + Vector3.new(0, waveY, 0)
            floatie.model:PivotTo(CFrame.new(currentPos) * (floatie.origCFrame.Rotation) * CFrame.Angles(rockPitch, 0, rockRoll))
        end
    end

    -- 3. Inflatable Floating Water Tiles (Smooth wave propagation)
    for _, tile in ipairs(waterTiles) do
        if tile.part and tile.part.Parent then
            local t = now * tile.speed + tile.spatialPhase
            local dy = math.sin(t) * tile.waveHeight
            local tilt = math.cos(t) * tile.rockAngle

            local pos = tile.origCFrame.Position + Vector3.new(0, dy, 0)
            tile.part.CFrame = CFrame.new(pos) * tile.origCFrame.Rotation * CFrame.Angles(tilt, 0, tilt * 0.6)
        end
    end

    -- 4. Bounce Houses & Balloon Spires
    for _, b in ipairs(bounceStructures) do
        if b.model and b.model.Parent then
            local t = now * b.speed + b.phase
            local dy = math.abs(math.sin(t)) * b.bounceHeight
            local tilt = math.sin(t * 0.7) * b.tiltStrength

            local pos = b.origCFrame.Position + Vector3.new(0, dy, 0)
            b.model:PivotTo(CFrame.new(pos) * b.origCFrame.Rotation * CFrame.Angles(tilt, 0, 0))
        end
    end

    -- 5. Inflatable Obstacles (Tunnels, Arches, Ramps, Castle Walls)
    for _, o in ipairs(inflatableObstacles) do
        if o.model and o.model.Parent then
            local t = now * o.waveSpeed + o.phase
            local dy = math.sin(t) * o.bobHeight
            local rock = math.sin(t * 0.8) * o.rockStrength

            local pos = o.origCFrame.Position + Vector3.new(0, dy, 0)
            o.model:PivotTo(CFrame.new(pos) * o.origCFrame.Rotation * CFrame.Angles(rock, 0, rock * 0.5))
        end
    end

    -- 6. Castle Tower Flags flapping in the wind
    for _, f in ipairs(castleFlags) do
        if f.beam and f.beam.Parent and f.tipAtt and f.tipAtt.Parent then
            local tMain = now * f.windSpeed + f.phase
            local tFlutter = now * f.flutterFreq + f.phase

            -- Multi-frequency wind wave
            local wave = math.sin(tMain) * 0.75 + math.sin(tFlutter) * 0.35 + math.cos(tMain * 2.1) * 0.2
            local curveDynamic = f.baseCurve + (wave * 0.85)
            f.beam.CurveSize0 = curveDynamic
            f.beam.CurveSize1 = curveDynamic * 0.9

            -- Jitter the free flapping tip of the flag in 3D
            local tipDriftX = math.sin(tMain * 1.3) * 0.45 + math.sin(tFlutter) * 0.25
            local tipDriftY = math.cos(tMain) * 0.35 + math.sin(tFlutter * 1.4) * 0.2
            local tipDriftZ = math.sin(tFlutter * 0.8) * 0.2

            f.tipAtt.Position = f.origTipPos + Vector3.new(tipDriftX, tipDriftY, tipDriftZ)
        end
    end
end)

print(string.format(
    "🌊 Part.c5ca Full Animation Activated: %d Trees, %d Floaties, %d Water Tiles, %d Bounce Structures, %d Obstacles, %d Flapping Flags!",
    #palmTrees, #duckFloaties, #waterTiles, #bounceStructures, #inflatableObstacles, #castleFlags
))
