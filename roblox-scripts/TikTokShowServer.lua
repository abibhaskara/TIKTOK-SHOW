--[[
    ============================================================================
    TIKTOK LIVE -> ROBLOX AVATAR SHOW (SERVER SCRIPT)
    ============================================================================
    HOW TO USE IN ROBLOX STUDIO:
    1. Open Roblox Studio -> Game Settings -> Security -> Enable "Allow HTTP Requests".
    2. Create a new Script inside `ServerScriptService` named `TikTokShowServer`.
    3. Paste this entire file into `TikTokShowServer`.
    4. Create a LocalScript inside `StarterPlayer -> StarterPlayerScripts` named `TikTokShowClient`
       and paste `TikTokShowClient.lua` into it.
    5. Make sure the Node.js bridge server is running (`npm start` in `bridge-server/`),
       then press Play in Roblox Studio!
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

-- Smooth Lighting Transition Helper (Daytime <-> Spotlight Night)
local function setStageLightingMode(isNightSpotlight)
    local targetClock = isNightSpotlight and 3.2 or 8.6
    local targetOutdoor = isNightSpotlight and Color3.fromRGB(45, 50, 70) or Color3.fromRGB(128, 128, 128)
    local targetBrightness = isNightSpotlight and 1.2 or 2.0

    TweenService:Create(
        Lighting,
        TweenInfo.new(0.65, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {
            ClockTime = targetClock,
            OutdoorAmbient = targetOutdoor,
            Brightness = targetBrightness
        }
    ):Play()

    local stageFX = workspace:FindFirstChild("StageLightingFX")
    if stageFX then
        for _, obj in ipairs(stageFX:GetDescendants()) do
            if obj:IsA("SpotLight") then
                obj.Enabled = isNightSpotlight
            elseif obj:IsA("ParticleEmitter") then
                obj.Enabled = isNightSpotlight
            end
        end
    end
end

-- ============================================================================
-- RGB Fireworks on the 4 Corners of the Arena
-- Size: (78.479, 22, 84), Center Position: (50.239, 66.903, -106)
-- ============================================================================
local FIREWORK_CENTER = Vector3.new(50.239, 66.903, -106)
local FIREWORK_SIZE = Vector3.new(78.479, 22, 84)
local halfX = FIREWORK_SIZE.X / 2 -- ~39.24
local halfZ = FIREWORK_SIZE.Z / 2 -- ~42.00
local groundY = FIREWORK_CENTER.Y - (FIREWORK_SIZE.Y / 2) -- ~55.9

local FIREWORK_CORNERS = {
    FIREWORK_CENTER + Vector3.new(-halfX, -(FIREWORK_SIZE.Y / 2), -halfZ), -- Corner 1
    FIREWORK_CENTER + Vector3.new( halfX, -(FIREWORK_SIZE.Y / 2), -halfZ), -- Corner 2
    FIREWORK_CENTER + Vector3.new(-halfX, -(FIREWORK_SIZE.Y / 2),  halfZ), -- Corner 3
    FIREWORK_CENTER + Vector3.new( halfX, -(FIREWORK_SIZE.Y / 2),  halfZ), -- Corner 4
}

local function triggerRGBFireworks(duration)
    duration = duration or 4.5
    local fwFolder = workspace:FindFirstChild("LiveFireworksFX")
    if not fwFolder then
        fwFolder = Instance.new("Folder")
        fwFolder.Name = "LiveFireworksFX"
        fwFolder.Parent = workspace
    end

    local emitters = {}

    for i, cornerPos in ipairs(FIREWORK_CORNERS) do
        local anchorPart = Instance.new("Part")
        anchorPart.Name = "FireworkLauncher_" .. i
        anchorPart.Anchored = true
        anchorPart.CanCollide = false
        anchorPart.Transparency = 1
        anchorPart.Size = Vector3.new(1, 1, 1)
        anchorPart.Position = cornerPos
        anchorPart.Parent = fwFolder

        -- 1. Rocket Trail Emitter
        local trail = Instance.new("ParticleEmitter")
        trail.Name = "RocketTrail"
        trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        trail.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),   -- R
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 255, 50)), -- G
            ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 100, 255))  -- B
        })
        trail.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(0.5, 1.2),
            NumberSequenceKeypoint.new(1, 0)
        })
        trail.Rate = 22
        trail.Speed = NumberRange.new(28, 42)
        trail.SpreadAngle = Vector2.new(15, 15)
        trail.EmissionDirection = Enum.NormalId.Top
        trail.Lifetime = NumberRange.new(1.1, 1.8)
        trail.Acceleration = Vector3.new(0, -12, 0)
        trail.LightEmission = 0.95
        trail.Parent = anchorPart

        -- 2. RGB Burst Explosion Emitter (High Air Burst)
        local burst = Instance.new("ParticleEmitter")
        burst.Name = "RGBBurst"
        burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        burst.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 80)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 120)),
            ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 150, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 230, 0))
        })
        burst.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(0.4, 2.2),
            NumberSequenceKeypoint.new(1, 0)
        })
        burst.Rate = 35
        burst.Speed = NumberRange.new(14, 28)
        burst.SpreadAngle = Vector2.new(180, 180)
        burst.Lifetime = NumberRange.new(1.2, 2.0)
        burst.Drag = 3.5
        burst.LightEmission = 1
        burst.Parent = anchorPart

        -- 3. Dynamic Colorful PointLight at the launcher
        local light = Instance.new("PointLight")
        light.Brightness = 4.0
        light.Range = 28
        light.Color = (i % 3 == 1 and Color3.fromRGB(255, 60, 60))
            or (i % 3 == 2 and Color3.fromRGB(60, 255, 60))
            or Color3.fromRGB(60, 140, 255)
        light.Parent = anchorPart

        table.insert(emitters, anchorPart)
    end

    -- Automatically extinguish and clean up after duration
    task.delay(duration, function()
        for _, part in ipairs(emitters) do
            if part and part.Parent then
                for _, child in ipairs(part:GetChildren()) do
                    if child:IsA("ParticleEmitter") then
                        child.Enabled = false
                    elseif child:IsA("PointLight") then
                        child.Enabled = false
                    end
                end
                Debris:AddItem(part, 2.5)
            end
        end
    end)
end

-- Ensure default lighting starts at Daytime
setStageLightingMode(false)

-- ============================================================================
-- 3 Dragons Flight Event (Topi Penyihir Gift)
-- Area Center: (50.239, 66.903, -106), Size: (78.479, 22, 84)
-- Timeline:
--   0s - 1s: 3 dragons fly in from far apart toward orbit, fade transparency 1 -> 0
--   3s - 7s: Lighting changes smoothly from day (8.6) to dark (3.2)
--   5s: Rotating / orbiting the area
--   9s: Spreading flame breath & atmosphere
--   17s - 20s: Dragons break orbit, fly far apart, fade transparency 0 -> 1, cleaned up
-- ============================================================================
local DRAGON_AREA_CENTER = Vector3.new(50.239, 66.903, -106)
local DRAGON_AREA_SIZE = Vector3.new(78.479, 22, 84)
local DRAGON_RADIUS_X = DRAGON_AREA_SIZE.X * 0.52 -- ~40.8 studs radius
local DRAGON_RADIUS_Z = DRAGON_AREA_SIZE.Z * 0.52 -- ~43.6 studs radius
local DRAGON_BASE_Y = DRAGON_AREA_CENTER.Y + 8     -- ~74.9 studs high flight path

local isDragonEventActive = false

local function setModelTransparency(model, transparency)
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") and desc.Name ~= "DragonRoot" and desc.Name ~= "MouthFlamePart" then
            desc.Transparency = transparency
        elseif desc:IsA("Decal") then
            desc.Transparency = transparency
        end
    end
end

local function setDragonFlameState(dragon, enabled)
    local flamePart = dragon:FindFirstChild("MouthFlamePart")
    if flamePart then
        for _, ch in ipairs(flamePart:GetChildren()) do
            if ch:IsA("ParticleEmitter") or ch:IsA("Light") then
                ch.Enabled = enabled
            end
        end
    end
end

local function triggerWitchHatDragons(giftData)
    if isDragonEventActive then
        print("⚠️ Dragon event is already currently running!")
        return
    end
    isDragonEventActive = true
    print("🐉 [DRAGON EVENT] Spawning 3 Dragons for Topi Penyihir gift from @" .. tostring(giftData and giftData.tiktokUniqueId or "viewer"))

    local template = ReplicatedStorage:FindFirstChild("DragonModel")
    if not template then
        warn("❌ DragonModel not found in ReplicatedStorage! Searching for fallback...")
        template = ReplicatedStorage:FindFirstChild("DragonTemplate")
    end

    if not template then
        warn("❌ Could not find dragon template in ReplicatedStorage!")
        isDragonEventActive = false
        return
    end

    -- Create 3 dragon instances
    local dragons = {}
    local anglesOffset = { 0, (2 * math.pi / 3), (4 * math.pi / 3) } -- 0, 120, 240 degrees

    for i = 1, 3 do
        local dragon = template:Clone()
        dragon.Name = "EventDragon_" .. i
        
        -- Start fully transparent
        setModelTransparency(dragon, 1)
        setDragonFlameState(dragon, false)

        -- Initial spawn position: Far apart outside (3x orbit radius)
        local startAngle = anglesOffset[i]
        local farDist = 3.2
        local startX = DRAGON_AREA_CENTER.X + math.cos(startAngle) * (DRAGON_RADIUS_X * farDist)
        local startZ = DRAGON_AREA_CENTER.Z + math.sin(startAngle) * (DRAGON_RADIUS_Z * farDist)
        local startY = DRAGON_BASE_Y + 35

        -- Target orbit entry position (at radius)
        local orbitX = DRAGON_AREA_CENTER.X + math.cos(startAngle) * DRAGON_RADIUS_X
        local orbitZ = DRAGON_AREA_CENTER.Z + math.sin(startAngle) * DRAGON_RADIUS_Z

        local initialLook = CFrame.lookAt(Vector3.new(startX, startY, startZ), Vector3.new(orbitX, DRAGON_BASE_Y, orbitZ))
        dragon:PivotTo(initialLook)
        dragon.Parent = Workspace

        -- Cache wing submodels for animated flapping
        local wingsFolder = dragon:FindFirstChild("Wings") or dragon:FindFirstChild("Wings Model")
        local leftWing = wingsFolder and wingsFolder:FindFirstChild("LeftWing")
        local rightWing = wingsFolder and wingsFolder:FindFirstChild("RightWing")

        table.insert(dragons, {
            model = dragon,
            leftWing = leftWing,
            rightWing = rightWing
        })
    end

    -- Run 20-second cinematic event timeline
    task.spawn(function()
        local startTime = os.clock()
        local TOTAL_DURATION = 20.0
        local orbitSpeed = 0.85 -- Radians per second for orbiting

        -- Atmospheric fog & dark transition helper
        local initialClockTime = Lighting.ClockTime
        local dayClock = 8.6
        local nightClock = 3.2

        local heartbeatConn
        heartbeatConn = RunService.Heartbeat:Connect(function()
            local elapsed = os.clock() - startTime
            if elapsed >= TOTAL_DURATION then
                heartbeatConn:Disconnect()
                return
            end

            -- ================================================================
            -- 1. Lighting Control (3s to 7s: transition from day 8.6 to night 3.2)
            --    (After 17s to 20s: transition smoothly back to day 8.6)
            -- ================================================================
            if elapsed >= 3 and elapsed <= 7 then
                local alpha = (elapsed - 3) / 4.0
                Lighting.ClockTime = dayClock + (nightClock - dayClock) * alpha
                Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 130):Lerp(Color3.fromRGB(20, 20, 35), alpha)
            elseif elapsed > 7 and elapsed < 17 then
                Lighting.ClockTime = nightClock
                Lighting.OutdoorAmbient = Color3.fromRGB(20, 20, 35)
            elseif elapsed >= 17 then
                local alpha = math.clamp((elapsed - 17) / 3.0, 0, 1)
                Lighting.ClockTime = nightClock + (dayClock - nightClock) * alpha
                Lighting.OutdoorAmbient = Color3.fromRGB(20, 20, 35):Lerp(Color3.fromRGB(130, 130, 130), alpha)
            end

            -- Wing Flapping Parameters (Realistic biological wing beat: fast downstroke, graceful upstroke)
            local flapFreq = (elapsed >= 9.0 and elapsed < 17.0) and 8.0 or 6.0
            local flapSine = math.sin(elapsed * flapFreq)
            local leftWingAngle = flapSine * 0.38
            local rightWingAngle = -flapSine * 0.38

            local LEFT_WING_REST_CF = CFrame.new(
                -9.6159, -1.7762, -1.7248,
                -0.08635, -0.99093, -0.10295,
                0.004186, -0.10370, 0.99460,
                -0.99626, 0.08545, 0.01310
            )

            local RIGHT_WING_REST_CF = CFrame.new(
                0.7588, 0.1627, -2.6368,
                -0.08218, 0.98726, 0.13624,
                -0.02258, 0.13482, -0.99061,
                -0.99636, -0.08448, 0.01121
            )

            -- ================================================================
            -- 2. Movement & Realistic Rotation Physics Calculations
            -- ================================================================
            for i, data in ipairs(dragons) do
                local dragon = data.model
                if dragon and dragon.Parent then
                    local baseAngle = anglesOffset[i]

                    if elapsed < 1.0 then
                        -- PHASE 1: 0s - 1s (Fly in from far apart, fade transparency 1 -> 0)
                        local alpha = math.clamp(elapsed / 1.0, 0, 1)
                        setModelTransparency(dragon, 1 - alpha)

                        local curDist = 3.2 - (2.2 * alpha) -- 3.2 down to 1.0
                        local x = DRAGON_AREA_CENTER.X + math.cos(baseAngle) * (DRAGON_RADIUS_X * curDist)
                        local z = DRAGON_AREA_CENTER.Z + math.sin(baseAngle) * (DRAGON_RADIUS_Z * curDist)
                        local y = DRAGON_BASE_Y + (35 * (1 - alpha))

                        -- Look toward next inward step with swoop pitch
                        local nextDist = curDist - 0.15
                        local nextX = DRAGON_AREA_CENTER.X + math.cos(baseAngle) * (DRAGON_RADIUS_X * nextDist)
                        local nextZ = DRAGON_AREA_CENTER.Z + math.sin(baseAngle) * (DRAGON_RADIUS_Z * nextDist)
                        local nextY = DRAGON_BASE_Y + (35 * (1 - math.min(alpha + 0.05, 1)))

                        local lookDir = (Vector3.new(nextX, nextY, nextZ) - Vector3.new(x, y, z)).Unit
                        local targetCf = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z) + lookDir)
                        dragon:PivotTo(targetCf)

                    elseif elapsed >= 1.0 and elapsed < 5.0 then
                        -- PHASE 2: 1s - 5s (Hovering / swooping into orbit positioning)
                        setModelTransparency(dragon, 0)
                        local progress = (elapsed - 1.0) / 4.0
                        local currentAngle = baseAngle + (progress * 0.5)
                        local waveY = DRAGON_BASE_Y + math.sin(elapsed * 2.5 + i) * 3.5
                        local x = DRAGON_AREA_CENTER.X + math.cos(currentAngle) * DRAGON_RADIUS_X
                        local z = DRAGON_AREA_CENTER.Z + math.sin(currentAngle) * DRAGON_RADIUS_Z

                        -- Tangent forward direction
                        local tangentAngle = currentAngle + 0.15
                        local tx = DRAGON_AREA_CENTER.X + math.cos(tangentAngle) * DRAGON_RADIUS_X
                        local tz = DRAGON_AREA_CENTER.Z + math.sin(tangentAngle) * DRAGON_RADIUS_Z
                        local tangentDir = (Vector3.new(tx, waveY, tz) - Vector3.new(x, waveY, z)).Unit
                        local baseLook = CFrame.lookAt(Vector3.new(x, waveY, z), Vector3.new(x, waveY, z) + tangentDir)

                        -- Subtle aerodynamic roll and pitch
                        local pitch = math.rad(math.cos(elapsed * 2.5 + i) * 6)
                        local roll = -math.rad(15 * progress) -- bank into turn
                        dragon:PivotTo(baseLook * CFrame.Angles(pitch, 0, roll))

                    elseif elapsed >= 5.0 and elapsed < 17.0 then
                        -- PHASE 3: 5s - 17s (Active Orbit Rotation)
                        if elapsed >= 9.0 then
                            setDragonFlameState(dragon, true)
                        else
                            setDragonFlameState(dragon, false)
                        end
                        setModelTransparency(dragon, 0)

                        local orbitElapsed = elapsed - 5.0
                        local currentAngle = baseAngle + (orbitElapsed * orbitSpeed)
                        local waveY = DRAGON_BASE_Y + math.sin(elapsed * 2.8 + (i * 2.0)) * 4.5
                        local x = DRAGON_AREA_CENTER.X + math.cos(currentAngle) * DRAGON_RADIUS_X
                        local z = DRAGON_AREA_CENTER.Z + math.sin(currentAngle) * DRAGON_RADIUS_Z

                        -- Tangent forward direction for precise flight path
                        local nextAngle = currentAngle + 0.12
                        local nx = DRAGON_AREA_CENTER.X + math.cos(nextAngle) * DRAGON_RADIUS_X
                        local nz = DRAGON_AREA_CENTER.Z + math.sin(nextAngle) * DRAGON_RADIUS_Z
                        local forwardDir = (Vector3.new(nx, waveY, nz) - Vector3.new(x, waveY, z)).Unit

                        local baseLook = CFrame.lookAt(Vector3.new(x, waveY, z), Vector3.new(x, waveY, z) + forwardDir)
                        
                        -- Aerodynamic Banking (Roll into the center circle) & Pitch wave
                        local bankRoll = -math.rad(26) -- 26 degrees banked turn
                        local pitchBob = math.rad(math.cos(elapsed * 2.8 + (i * 2.0)) * 7)
                        local yawSway = math.rad(math.sin(elapsed * 1.5 + i) * 3)

                        local animatedCf = baseLook * CFrame.Angles(pitchBob, yawSway, bankRoll)
                        dragon:PivotTo(animatedCf)

                    elseif elapsed >= 17.0 then
                        -- PHASE 4: 17s - 20s (Extinguish fire, fly apart away from arena, fade 0 -> 1)
                        setDragonFlameState(dragon, false)
                        local exitAlpha = math.clamp((elapsed - 17.0) / 3.0, 0, 1)
                        setModelTransparency(dragon, exitAlpha)

                        -- Fly outward away from center & ascend dramatically
                        local exitAngle = baseAngle + (12.0 * orbitSpeed) + (exitAlpha * 0.4)
                        local exitDist = 1.0 + (exitAlpha * 3.8) -- 1.0 -> 4.8x away
                        local x = DRAGON_AREA_CENTER.X + math.cos(exitAngle) * (DRAGON_RADIUS_X * exitDist)
                        local z = DRAGON_AREA_CENTER.Z + math.sin(exitAngle) * (DRAGON_RADIUS_Z * exitDist)
                        local y = DRAGON_BASE_Y + (exitAlpha * 55)

                        local forwardAngle = exitAngle + 0.15
                        local nx = DRAGON_AREA_CENTER.X + math.cos(forwardAngle) * (DRAGON_RADIUS_X * (exitDist + 0.3))
                        local nz = DRAGON_AREA_CENTER.Z + math.sin(forwardAngle) * (DRAGON_RADIUS_Z * (exitDist + 0.3))
                        local ny = y + 8

                        local flyDir = (Vector3.new(nx, ny, nz) - Vector3.new(x, y, z)).Unit
                        local baseLook = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z) + flyDir)
                        local climbPitch = math.rad(18)
                        dragon:PivotTo(baseLook * CFrame.Angles(climbPitch, 0, 0))
                    end

                    -- Animate Wings flapping relative to dragon body
                    if data.leftWing and data.leftWing.PrimaryPart then
                        data.leftWing:PivotTo(dragon.PrimaryPart.CFrame * LEFT_WING_REST_CF * CFrame.Angles(leftWingAngle, 0, 0))
                    end
                    if data.rightWing and data.rightWing.PrimaryPart then
                        data.rightWing:PivotTo(dragon.PrimaryPart.CFrame * RIGHT_WING_REST_CF * CFrame.Angles(rightWingAngle, 0, 0))
                    end
                end
            end
        end)

        -- After 20 seconds, safely clean up dragons and reset state
        task.wait(TOTAL_DURATION + 0.2)
        if heartbeatConn and heartbeatConn.Connected then
            heartbeatConn:Disconnect()
        end

        for _, data in ipairs(dragons) do
            local dragon = data.model
            if dragon and dragon.Parent then
                dragon:Destroy()
            end
        end

        Lighting.ClockTime = dayClock
        Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 130)
        isDragonEventActive = false
        print("🐉 [DRAGON EVENT] Finished & Cleaned up successfully!")
    end)
end

-- ============================================================================
-- 5 Leaping Dolphins Event (Finger Heart Gift)
-- 5 dolphins leaping from below water surface (Y ~ 52.8) in an arc with water splash
-- Duration: 15 seconds, rotating in a circle around the water surrounding the stage
-- ============================================================================
local WATER_SURFACE_Y = 52.8
local DOLPHIN_CENTER = Vector3.new(50.239, WATER_SURFACE_Y, -106)
local DOLPHIN_RADIUS_X = 46.0
local DOLPHIN_RADIUS_Z = 48.0
local isDolphinEventActive = false

-- Helper to create water splash particle burst at entry / exit points on water surface
local function spawnWaterSplash(position)
    local splashPart = Instance.new("Part")
    splashPart.Name = "WaterSplashFX"
    splashPart.Size = Vector3.new(1, 1, 1)
    splashPart.CFrame = CFrame.new(position.X, WATER_SURFACE_Y + 0.5, position.Z)
    splashPart.Transparency = 1
    splashPart.CanCollide = false
    splashPart.CanTouch = false
    splashPart.Anchored = true
    splashPart.Parent = Workspace

    -- Upward water fountain droplets
    local splash = Instance.new("ParticleEmitter")
    splash.Name = "Droplets"
    splash.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    splash.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 240, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 220, 255))
    })
    splash.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.2),
        NumberSequenceKeypoint.new(0.4, 3.0),
        NumberSequenceKeypoint.new(1, 0)
    })
    splash.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.8, 0.3),
        NumberSequenceKeypoint.new(1, 1)
    })
    splash.Rate = 0 -- one-shot burst
    splash.Speed = NumberRange.new(18, 32)
    splash.SpreadAngle = Vector2.new(45, 45)
    splash.EmissionDirection = Enum.NormalId.Top
    splash.Acceleration = Vector3.new(0, -42, 0) -- gravity pulls water back down
    splash.Lifetime = NumberRange.new(0.8, 1.4)
    splash.LightEmission = 0.5
    splash.Parent = splashPart

    -- Foam / mist ring
    local foam = Instance.new("ParticleEmitter")
    foam.Name = "FoamRing"
    foam.Color = ColorSequence.new(Color3.fromRGB(230, 250, 255))
    foam.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 2.0),
        NumberSequenceKeypoint.new(0.5, 6.5),
        NumberSequenceKeypoint.new(1, 9.0)
    })
    foam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1.0)
    })
    foam.Rate = 0
    foam.Speed = NumberRange.new(5, 12)
    foam.SpreadAngle = Vector2.new(80, 80)
    foam.EmissionDirection = Enum.NormalId.Top
    foam.Lifetime = NumberRange.new(0.6, 1.1)
    foam.Parent = splashPart

    -- Fire burst
    splash:Emit(45)
    foam:Emit(25)

    Debris:AddItem(splashPart, 2.0)
end

local function triggerFingerHeartDolphins(giftData)
    if isDolphinEventActive then
        print("⚠️ Dolphin event is already running!")
        return
    end
    isDolphinEventActive = true
    print("🐬 [DOLPHIN EVENT] Spawning 5 Leaping Dolphins for Finger Heart gift from @" .. tostring(giftData and giftData.tiktokUniqueId or "viewer"))

    local template = ReplicatedStorage:FindFirstChild("DolphinTemplate")
    if not template then
        local inWs = Workspace:FindFirstChild("dolphin")
        if inWs then
            template = inWs:Clone()
            template.Name = "DolphinTemplate"
            template.Parent = ReplicatedStorage
        end
    end

    if not template then
        warn("❌ Could not find dolphin model/template in Workspace or ReplicatedStorage!")
        isDolphinEventActive = false
        return
    end

    -- Create 5 dolphins
    local dolphins = {}
    local anglesOffset = {
        0,
        (2 * math.pi / 5),
        (4 * math.pi / 5),
        (6 * math.pi / 5),
        (8 * math.pi / 5)
    }

    for i = 1, 5 do
        local dolphin = template:Clone()
        dolphin.Name = "EventDolphin_" .. i
        dolphin.Anchored = true
        dolphin.CanCollide = false
        dolphin.CanTouch = false
        dolphin.CanQuery = false
        
        -- Start hidden under the water
        local startAngle = anglesOffset[i]
        local x = DOLPHIN_CENTER.X + math.cos(startAngle) * DOLPHIN_RADIUS_X
        local z = DOLPHIN_CENTER.Z + math.sin(startAngle) * DOLPHIN_RADIUS_Z
        dolphin.CFrame = CFrame.new(x, WATER_SURFACE_Y - 14, z)
        dolphin.Parent = Workspace
        table.insert(dolphins, {
            model = dolphin,
            lastWasAbove = false,
            phaseOffset = (i - 1) * (2 * math.pi / 5)
        })
    end

    -- Run 15-second leaping & rotating animation
    task.spawn(function()
        local startTime = os.clock()
        local TOTAL_DURATION = 15.0
        local orbitSpeed = -0.95 -- Radians per second circling the stage in the opposite direction
        local leapFreq = 2.4    -- Leap frequency (leaping out of water every ~2.6 seconds)
        local leapHeight = 16.5 -- Height studs above water at peak of leap

        local conn
        conn = RunService.Heartbeat:Connect(function()
            local elapsed = os.clock() - startTime
            if elapsed >= TOTAL_DURATION then
                conn:Disconnect()
                return
            end

            for i, d in ipairs(dolphins) do
                local dolphin = d.model
                if dolphin and dolphin.Parent then
                    -- Circle rotation around water around the stage (opposite direction)
                    local currentAngle = anglesOffset[i] + (elapsed * orbitSpeed)
                    local x = DOLPHIN_CENTER.X + math.cos(currentAngle) * DOLPHIN_RADIUS_X
                    local z = DOLPHIN_CENTER.Z + math.sin(currentAngle) * DOLPHIN_RADIUS_Z

                    -- Leap vertical arc equation:
                    -- Sinusoidal curve where top half (> 0) emerges into the air, and bottom dips underwater
                    local leapCycle = math.sin((elapsed * leapFreq) + d.phaseOffset)
                    local y = WATER_SURFACE_Y + (leapCycle * leapHeight)

                    -- Calculate velocity vector (direction of movement in 3D for perfect realistic facing & pitch)
                    local dt = 0.05
                    local nextAngle = currentAngle + (dt * orbitSpeed)
                    local nx = DOLPHIN_CENTER.X + math.cos(nextAngle) * DOLPHIN_RADIUS_X
                    local nz = DOLPHIN_CENTER.Z + math.sin(nextAngle) * DOLPHIN_RADIUS_Z
                    local nextLeapCycle = math.sin(((elapsed + dt) * leapFreq) + d.phaseOffset)
                    local ny = WATER_SURFACE_Y + (nextLeapCycle * leapHeight)

                    local moveDir = (Vector3.new(nx, ny, nz) - Vector3.new(x, y, z)).Unit

                    -- Water splash detection on entry and exit
                    local isAbove = (y >= (WATER_SURFACE_Y - 1.0))
                    if isAbove ~= d.lastWasAbove then
                        d.lastWasAbove = isAbove
                        -- Trigger water splash particles at the surface crossing point!
                        spawnWaterSplash(Vector3.new(x, WATER_SURFACE_Y, z))
                    end

                    -- Direct basis matrix:
                    -- Snout (+Z) points exactly in moveDir (pitch up on jump, pitch down on dive)
                    -- Dorsal fin (+Y) points upright towards the sky
                    local vZ = moveDir
                    local up = Vector3.new(0, 1, 0)
                    local vX = up:Cross(vZ).Unit
                    local vY = vZ:Cross(vX).Unit
                    local baseCF = CFrame.fromMatrix(Vector3.new(x, y, z), vX, vY, vZ)
                    
                    -- Slight playful barrel roll twist while leaping in the air
                    local roll = 0
                    if y > WATER_SURFACE_Y then
                        local airProgress = (y - WATER_SURFACE_Y) / leapHeight
                        roll = math.sin(airProgress * math.pi) * math.rad(25)
                    end

                    dolphin.CFrame = baseCF * CFrame.Angles(0, 0, roll)
                end
            end
        end)

        task.wait(TOTAL_DURATION + 0.1)
        if conn and conn.Connected then
            conn:Disconnect()
        end

        for _, d in ipairs(dolphins) do
            if d.model and d.model.Parent then
                d.model:Destroy()
            end
        end

        isDolphinEventActive = false
        print("🐬 [DOLPHIN EVENT] Finished & Cleaned up successfully!")
    end)
end

-- ============================================================================
-- Configuration
-- ============================================================================
local BRIDGE_URL = "http://localhost:3000/api/events"
local POLL_INTERVAL = 0.5            -- Seconds between checking the Node.js bridge queue
local STAGE_DANCE_DURATION = 4.5     -- Seconds an avatar dances on the Main Stage before walking to crowd
local ROSE_POV_DURATION = 4.5        -- Seconds the Camera POV focuses on an avatar when they send a Rose
local MAX_CROWD_AVATARS = 12         -- Delete oldest character if total avatars exceed 12

-- Default Avatar Scale (1.45x larger by default for stream visibility)
local DEFAULT_AVATAR_SCALE = 1.45
local currentAvatarScale = DEFAULT_AVATAR_SCALE

-- Your Custom Stage Position in Workspace
local STAGE_POSITION = Vector3.new(49.665, 58.798, -68.576)

-- Built-in Roblox R15 Dance & Emote Animation IDs
local STAGE_DANCE_ANIMS = {
    "rbxassetid://507771019", -- Dance 1
    "rbxassetid://507776043", -- Dance 2
    "rbxassetid://507777268", -- Dance 3
    "rbxassetid://3333499508", -- Cheer / Pose
}

local CROWD_DANCE_ANIMS = {
    "rbxassetid://507771019",
    "rbxassetid://507776043",
    "rbxassetid://507777268",
}

local VIP_ROSE_DANCE_ANIMS = {
    "rbxassetid://507776043", -- Energetic Dance
    "rbxassetid://507777268", -- VIP Dance 3
    "rbxassetid://507770677", -- Celebrate / Wave
}

-- ============================================================================
-- Setup RemoteEvent & Spawned Avatars Folder
-- ============================================================================
local remoteEvent = ReplicatedStorage:FindFirstChild("TikTokShowEvents")
if not remoteEvent then
    remoteEvent = Instance.new("RemoteEvent")
    remoteEvent.Name = "TikTokShowEvents"
    remoteEvent.Parent = ReplicatedStorage
end

local avatarsFolder = workspace:FindFirstChild("SpawnedTikTokAvatars")
if not avatarsFolder then
    avatarsFolder = Instance.new("Folder")
    avatarsFolder.Name = "SpawnedTikTokAvatars"
    avatarsFolder.Parent = workspace
end

-- Hide the host's own character so it doesn't block the stage camera
local function hideHostCharacter(character)
    task.wait(0.2)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(STAGE_POSITION + Vector3.new(0, -50, 100))
        hrp.Anchored = true
    end
end

local function onHostPlayerAdded(player)
    if player.Character then
        task.spawn(hideHostCharacter, player.Character)
    end
    player.CharacterAdded:Connect(hideHostCharacter)
end

for _, player in ipairs(Players:GetPlayers()) do
    onHostPlayerAdded(player)
end
Players.PlayerAdded:Connect(onHostPlayerAdded)

-- ============================================================================
-- Crowd Slot Management & Avatar Registry (Relative to Custom Boundary Area)
-- ============================================================================
local activeAvatarsByTikTok = {} -- lowercase tiktokUniqueId -> character Model
local crowdQueue = {}            -- Ordered list of character Models in the crowd
local currentServerTrackedAvatar = nil
local isServerRoseVIP = false
local serverRoseStartTime = 0
local serverStagePoseFinishTime = 0

local function enforceMaxAvatars()
    -- Filter out any already-destroyed models from crowdQueue
    local validQueue = {}
    for _, model in ipairs(crowdQueue) do
        if model and model.Parent then
            table.insert(validQueue, model)
        end
    end
    crowdQueue = validQueue

    -- Delete oldest character(s) if count exceeds MAX_CROWD_AVATARS (12)
    while #crowdQueue > MAX_CROWD_AVATARS do
        local oldest = table.remove(crowdQueue, 1)
        if oldest and oldest.Parent then
            oldest:Destroy()
        end
    end
end

-- Also update workspace.CurrentCamera on the Server (for Studio "Server" / "Run" viewport mode!)
if RunService:IsStudio() then
    local MAIN_CAMERA_CFRAME = CFrame.lookAt(
        STAGE_POSITION + Vector3.new(0, 10, 22),
        STAGE_POSITION + Vector3.new(0, 3.0, 0)
    )

    local DRONE_CENTER = Vector3.new(47, 78.929, -115.5)
    local DRONE_AREA_SIZE = Vector3.new(288, 33.907, 233)
    local DRONE_RADIUS_X = (DRONE_AREA_SIZE.X / 2) * 0.72
    local DRONE_RADIUS_Z = (DRONE_AREA_SIZE.Z / 2) * 0.72
    local DRONE_SPEED = 0.12

    RunService.Heartbeat:Connect(function(dt)
        local cam = workspace.CurrentCamera
        if not cam then return end
        cam.CameraType = Enum.CameraType.Scriptable

        if not currentServerTrackedAvatar or not currentServerTrackedAvatar.Parent then
            currentServerTrackedAvatar = crowdQueue[#crowdQueue]
        end

        if isServerRoseVIP and currentServerTrackedAvatar and currentServerTrackedAvatar.Parent then
            local hrp = currentServerTrackedAvatar:FindFirstChild("HumanoidRootPart") or currentServerTrackedAvatar.PrimaryPart
            if hrp then
                local targetLookAt = hrp.Position + Vector3.new(0, 1.8, 0)
                local elapsed = os.clock() - serverRoseStartTime
                local orbitAngle = math.sin(elapsed * 1.8) * 0.55
                local frontVec = (hrp.CFrame * CFrame.Angles(0, orbitAngle, 0)).LookVector
                local camPos = targetLookAt + (frontVec * 10.5) + Vector3.new(0, 2.4, 0)
                local desiredCFrame = CFrame.lookAt(camPos, targetLookAt)
                cam.CFrame = cam.CFrame:Lerp(desiredCFrame, math.clamp(dt * 8, 0, 1))
                return
            end
        end

        -- Follow during stage posing
        if isStageBusy and currentServerTrackedAvatar and currentServerTrackedAvatar.Parent then
            local hrp = currentServerTrackedAvatar:FindFirstChild("HumanoidRootPart") or currentServerTrackedAvatar.PrimaryPart
            if hrp then
                local targetLookAt = hrp.Position + Vector3.new(0, 1.8, 0)
                local frontVec = hrp.CFrame.LookVector
                local camPos = targetLookAt + (frontVec * 15.0) + Vector3.new(0, 3.8, 0)
                local desiredCFrame = CFrame.lookAt(camPos, targetLookAt)
                cam.CFrame = cam.CFrame:Lerp(desiredCFrame, math.clamp(dt * 8, 0, 1))
                return
            end
        end

        -- Within 5 seconds after posing finished
        local timeSincePoseEnd = (serverStagePoseFinishTime > 0) and (os.clock() - serverStagePoseFinishTime) or 999
        if timeSincePoseEnd < 5.0 and currentServerTrackedAvatar and currentServerTrackedAvatar.Parent then
            local hrp = currentServerTrackedAvatar:FindFirstChild("HumanoidRootPart") or currentServerTrackedAvatar.PrimaryPart
            if hrp then
                local targetLookAt = hrp.Position + Vector3.new(0, 1.8, 0)
                local frontVec = hrp.CFrame.LookVector
                local camPos = targetLookAt + (frontVec * 15.0) + Vector3.new(0, 3.8, 0)
                local desiredCFrame = CFrame.lookAt(camPos, targetLookAt)
                cam.CFrame = cam.CFrame:Lerp(desiredCFrame, math.clamp(dt * 7, 0, 1))
                return
            end
        end

        -- Drone view when no avatar has spawned on stage for 5 seconds after posing
        local t = os.clock() * DRONE_SPEED
        local droneX = DRONE_CENTER.X + math.cos(t) * DRONE_RADIUS_X
        local droneZ = DRONE_CENTER.Z + math.sin(t) * DRONE_RADIUS_Z
        local droneY = DRONE_CENTER.Y + (DRONE_AREA_SIZE.Y * 0.25) + (math.sin(t * 1.5) * 6)

        local lookTarget = DRONE_CENTER + Vector3.new(
            math.cos(t + 0.6) * 18,
            -(DRONE_AREA_SIZE.Y * 0.35),
            math.sin(t + 0.6) * 18
        )
        local droneCFrame = CFrame.lookAt(Vector3.new(droneX, droneY, droneZ), lookTarget)
        cam.CFrame = cam.CFrame:Lerp(droneCFrame, math.clamp(dt * 3.5, 0, 1))
    end)
end

-- Custom Walking & Roaming Waypoints
local TRANSITION_WAYPOINT = Vector3.new(50, 59.248, -105.44)
local ROAM_AREA = {
    minX = 37,
    maxX = 62,
    minY = 59.198,
    maxY = 59.248,
    minZ = -124.44,
    maxZ = -105.44
}

local function getRandomRoamPosition()
    local x = math.random() * (ROAM_AREA.maxX - ROAM_AREA.minX) + ROAM_AREA.minX
    local y = math.random() * (ROAM_AREA.maxY - ROAM_AREA.minY) + ROAM_AREA.minY
    local z = math.random() * (ROAM_AREA.maxZ - ROAM_AREA.minZ) + ROAM_AREA.minZ
    return Vector3.new(x, y, z)
end

-- ============================================================================
-- Helper: Create Overhead BillboardGui (TikTok @username + Roblox username)
-- ============================================================================
local function attachNametag(character, tiktokUniqueId, robloxUsername, isRoseVIP)
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not head then return end

    local existing = head:FindFirstChild("TikTokNametag")
    if existing then existing:Destroy() end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "TikTokNametag"
    billboard.Adornee = head
    -- Using Studs (Scale) sizing so the nametag maintains realistic 3D world dimensions
    -- and stops growing on screen as the camera pulls further away:
    billboard.Size = UDim2.new(5.5, 0, 1.5, 0)
    billboard.StudsOffset = Vector3.new(0, 3.8, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 140
    billboard.DistanceLowerLimit = 10
    billboard.Parent = head

    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundColor3 = Color3.fromRGB(15, 17, 25)
    container.BackgroundTransparency = 0.2
    container.BorderSizePixel = 0
    container.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = container

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = isRoseVIP and Color3.fromRGB(254, 44, 85) or Color3.fromRGB(37, 244, 238)
    stroke.Parent = container

    -- Line 1: TikTok Username
    local tiktokLabel = Instance.new("TextLabel")
    tiktokLabel.Name = "TikTokLabel"
    tiktokLabel.Size = UDim2.new(1, -12, 0.5, 0)
    tiktokLabel.Position = UDim2.new(0, 6, 0, 2)
    tiktokLabel.BackgroundTransparency = 1
    tiktokLabel.Font = Enum.Font.GothamBold
    tiktokLabel.TextSize = 16
    tiktokLabel.TextColor3 = Color3.fromRGB(37, 244, 238)
    tiktokLabel.TextStrokeTransparency = 0.3
    tiktokLabel.Text = (isRoseVIP and "🌹 @" or "🎵 @") .. tostring(tiktokUniqueId)
    tiktokLabel.TextScaled = true
    tiktokLabel.Parent = container

    -- Line 2: Roblox Username
    local robloxLabel = Instance.new("TextLabel")
    robloxLabel.Name = "RobloxLabel"
    robloxLabel.Size = UDim2.new(1, -12, 0.45, 0)
    robloxLabel.Position = UDim2.new(0, 6, 0.5, 0)
    robloxLabel.BackgroundTransparency = 1
    robloxLabel.Font = Enum.Font.GothamSemibold
    robloxLabel.TextSize = 14
    robloxLabel.TextColor3 = isRoseVIP and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(240, 244, 255)
    robloxLabel.TextStrokeTransparency = 0.4
    robloxLabel.Text = "🎮 Roblox: " .. tostring(robloxUsername)
    robloxLabel.TextScaled = true
    robloxLabel.Parent = container
end

-- ============================================================================
-- Helper: Resolve Animation ID (Supports both direct Animation IDs and Catalog Emotes)
-- ============================================================================
local InsertService = game:GetService("InsertService")
local resolvedAnimationCache = {}

local function resolvePlayableAnimationId(rawId)
    if not rawId then return nil end
    local numId = string.match(tostring(rawId), "%d+")
    if not numId then return nil end

    if resolvedAnimationCache[numId] then
        return resolvedAnimationCache[numId]
    end

    -- First try InsertService:LoadAsset in case it is a Catalog Emote (AssetTypeId 61)
    local ok, assetModel = pcall(function()
        return InsertService:LoadAsset(tonumber(numId))
    end)

    if ok and assetModel then
        local foundAnim = assetModel:FindFirstChildWhichIsA("Animation", true)
        if foundAnim and foundAnim.AnimationId and foundAnim.AnimationId ~= "" then
            local resolved = foundAnim.AnimationId
            resolvedAnimationCache[numId] = resolved
            print("[TikTokShow] 🎯 Resolved Emote Asset " .. numId .. " -> Real Animation ID: " .. resolved)
            pcall(function() assetModel:Destroy() end)
            return resolved
        end
        pcall(function() assetModel:Destroy() end)
    end

    -- Fallback: assume it is directly an Animation asset
    local directId = "rbxassetid://" .. numId
    resolvedAnimationCache[numId] = directId
    return directId
end

-- ============================================================================
-- Helper: Play Animation on Avatar Humanoid
-- ============================================================================
local function playAvatarAnimation(character, animIdList)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end

    -- Stop existing playing tracks
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        track:Stop(0.05)
    end

    local chosenId = nil
    if type(animIdList) == "string" then
        chosenId = animIdList
    elseif type(animIdList) == "table" and #animIdList > 0 then
        chosenId = animIdList[math.random(1, #animIdList)]
    end

    if not chosenId then return nil end

    -- Automatically resolve catalog emote IDs to their real playable animation ID!
    local playableId = resolvePlayableAnimationId(chosenId)
    if not playableId then return nil end

    local anim = Instance.new("Animation")
    anim.AnimationId = playableId

    local ok, track = pcall(function()
        return animator:LoadAnimation(anim)
    end)

    if ok and track then
        track.Priority = Enum.AnimationPriority.Action
        track.Looped = true
        track:Play(0.05)
        return track
    else
        warn("[TikTokShow] Failed to load animation:", chosenId, "Resolved as:", playableId, "Error:", track)
    end
    return nil
end

-- ============================================================================
-- Helper: Attach Rose Gift Particle Burst & VIP Glow
-- ============================================================================
local function applyRoseGiftEffects(character, duration)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Highlight Outline
    local highlight = Instance.new("Highlight")
    highlight.Name = "RoseHighlight"
    highlight.FillColor = Color3.fromRGB(254, 44, 85)
    highlight.FillTransparency = 0.65
    highlight.OutlineColor = Color3.fromRGB(255, 215, 0)
    highlight.OutlineTransparency = 0
    highlight.Parent = character
    Debris:AddItem(highlight, duration)

    -- Pink/Gold Glow Light
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(254, 80, 120)
    light.Brightness = 3.5
    light.Range = 16
    light.Parent = hrp
    Debris:AddItem(light, duration)

    -- Rose / Heart Particle Emitter
    local roseParticles = Instance.new("ParticleEmitter")
    roseParticles.Name = "RoseParticles"
    roseParticles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    roseParticles.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(254, 44, 85)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 105, 180)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0)),
    })
    roseParticles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(0.5, 1.1),
        NumberSequenceKeypoint.new(1, 0),
    })
    roseParticles.Rate = 45
    roseParticles.Lifetime = NumberRange.new(1.2, 2.2)
    roseParticles.Speed = NumberRange.new(4, 9)
    roseParticles.SpreadAngle = Vector2.new(180, 180)
    roseParticles.Parent = hrp
    Debris:AddItem(roseParticles, duration)
end

-- ============================================================================
-- Spawn Verified Follower Avatar on Main Stage -> Walk to Background Crowd
-- ============================================================================
local isStageBusy = false

local function spawnVerifiedFollowerAvatar(event)
    local tiktokUniqueId = event.tiktokUniqueId or "viewer"
    local robloxUserId = tonumber(event.robloxUserId)
    local robloxUsername = event.robloxUsername or "Player"
    if not robloxUserId then return end

    local key = string.lower(tiktokUniqueId)

    -- If this viewer already has an avatar in the crowd, remove the old one before spawning fresh on stage
    local existingModel = activeAvatarsByTikTok[key]
    if existingModel and existingModel.Parent then
        existingModel:Destroy()
        activeAvatarsByTikTok[key] = nil
    end

    -- Create the 3D Humanoid Model from Roblox UserId
    local success, character = pcall(function()
        return Players:CreateHumanoidModelFromUserId(robloxUserId)
    end)

    if not success or not character then
        warn("[TikTokShow] Could not load Roblox avatar for userId:", robloxUserId)
        return
    end

    character.Name = robloxUsername
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end

    -- Scale avatar larger by default for prominent visibility!
    pcall(function()
        character:ScaleTo(currentAvatarScale)
    end)

    -- Wait briefly if another avatar is mid-spotlight on the center pedestal
    local waitCount = 0
    while isStageBusy and waitCount < 8 do
        task.wait(0.5)
        waitCount += 1
    end
    isStageBusy = true

    -- Place avatar on your Stage Position facing +Z
    local stagePos = STAGE_POSITION + Vector3.new(0, 3.5, 0)
    character:PivotTo(CFrame.lookAt(stagePos, stagePos + Vector3.new(0, 0, 20)))
    character.Parent = avatarsFolder

    -- Attach overhead nametag showing BOTH TikTok @username and Roblox username
    attachNametag(character, tiktokUniqueId, robloxUsername, false)

    -- Register in lookup table
    activeAvatarsByTikTok[key] = character
    table.insert(crowdQueue, character)
    currentServerTrackedAvatar = character

    -- Trim oldest crowd avatar if over MAX_CROWD_AVATARS (12)
    enforceMaxAvatars()

    -- Notify Client HUD & Tell Camera to Follow This Avatar!
    remoteEvent:FireAllClients("ShowBannerAlert", {
        alertType = "spawn",
        targetModel = character,
        tiktokUniqueId = tiktokUniqueId,
        robloxUsername = robloxUsername,
        justFollowed = event.justFollowed
    })

    -- Switch lighting to Dramatic Night + Spotlight on avatar!
    setStageLightingMode(true)

    -- Launch celebratory RGB Fireworks on the 4 corners of the arena!
    triggerRGBFireworks(STAGE_DANCE_DURATION)

    -- Play Main Stage Dance Animation for STAGE_DANCE_DURATION seconds
    local danceTrack = playAvatarAnimation(character, STAGE_DANCE_ANIMS)
    task.wait(STAGE_DANCE_DURATION)
    isStageBusy = false
    serverStagePoseFinishTime = os.clock()

    -- Posing finished: Smoothly return lighting back to Daytime!
    setStageLightingMode(false)

    -- Notify client that stage posing is finished (start 5s drone timer if no next avatar spawns)
    remoteEvent:FireAllClients("AvatarStagePoseFinished", {
        targetModel = character
    })

    -- Stop stage dance so the avatar can walk into the background crowd
    if danceTrack then
        danceTrack:Stop(0.25)
    end

    if not character or not character.Parent then return end

    -- 1. Walk directly to the transition point (50, 59.248, -105.44)
    if humanoid then
        humanoid.WalkSpeed = 14
        humanoid:MoveTo(TRANSITION_WAYPOINT)
        humanoid.MoveToFinished:Wait()
    end

    if not character or not character.Parent then return end

    -- 2. Once reached, pick a spot inside the custom boundary area:
    --    X: [37, 62], Y: [59.198, 59.248], Z: [-124.44, -105.44]
    local targetRoamSpot = getRandomRoamPosition()
    character:SetAttribute("CrowdSpot", targetRoamSpot)

    if humanoid then
        humanoid:MoveTo(targetRoamSpot)
        humanoid.MoveToFinished:Wait()
    end

    -- Face forward and dance
    if character and character.Parent then
        local standPos = targetRoamSpot
        character:PivotTo(CFrame.lookAt(standPos, standPos + Vector3.new(0, 0, 20)))
        playAvatarAnimation(character, CROWD_DANCE_ANIMS)

        -- Periodically roam between spots within the boundary area
        task.spawn(function()
            while character and character.Parent and humanoid and humanoid.Parent do
                task.wait(math.random(6, 11))
                if not character or not character.Parent then break end

                -- Stop dancing briefly to walk to a new spot in the roam area
                local animator = humanoid:FindFirstChildOfClass("Animator")
                if animator then
                    for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
                        tr:Stop(0.2)
                    end
                end

                local newSpot = getRandomRoamPosition()
                humanoid:MoveTo(newSpot)
                humanoid.MoveToFinished:Wait()

                if character and character.Parent then
                    local currentPos = character:GetPivot().Position
                    character:PivotTo(CFrame.lookAt(currentPos, currentPos + Vector3.new(0, 0, 20)))
                    playAvatarAnimation(character, CROWD_DANCE_ANIMS)
                end
            end
        end)
    end
end

-- ============================================================================
-- Handle Rose Gift: Particle Effect + VIP Dance + Camera POV Zoom to Avatar!
-- ============================================================================
local function triggerRoseGiftEffect(event)
    local tiktokUniqueId = event.tiktokUniqueId or "gifter"
    local robloxUserId = tonumber(event.robloxUserId)
    local robloxUsername = event.robloxUsername or tiktokUniqueId
    local giftName = event.giftName or "Rose"
    local key = string.lower(tiktokUniqueId)

    local targetCharacter = activeAvatarsByTikTok[key]

    -- If their avatar isn't currently spawned, spawn it right now if we have their robloxUserId!
    if (not targetCharacter or not targetCharacter.Parent) and robloxUserId then
        local ok, newChar = pcall(function()
            return Players:CreateHumanoidModelFromUserId(robloxUserId)
        end)
        if ok and newChar then
            newChar.Name = robloxUsername
            local hum = newChar:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            end
            local standPos = getRandomRoamPosition()
            newChar:PivotTo(CFrame.lookAt(standPos, standPos + Vector3.new(0, 0, 20)))
            newChar.Parent = avatarsFolder
            activeAvatarsByTikTok[key] = newChar
            table.insert(crowdQueue, newChar)
            enforceMaxAvatars()
            targetCharacter = newChar
        end
    end

    -- Fallback: If gifter hasn't linked a Roblox account yet, pick the newest avatar on stage/crowd
    if (not targetCharacter or not targetCharacter.Parent) and #crowdQueue > 0 then
        targetCharacter = crowdQueue[#crowdQueue]
    end

    if not targetCharacter or not targetCharacter.Parent then
        -- Still show the Rose notification banner even if no avatar is on stage yet
        remoteEvent:FireAllClients("ShowBannerAlert", {
            alertType = "rose",
            tiktokUniqueId = tiktokUniqueId,
            robloxUsername = robloxUsername,
            giftName = giftName
        })
        return
    end

    -- Upgrade overhead tag to Rose VIP style
    attachNametag(targetCharacter, tiktokUniqueId, targetCharacter.Name, true)

    -- Apply Rose Particle Emitters + Glow Highlight
    applyRoseGiftEffects(targetCharacter, ROSE_POV_DURATION + 1.0)

    -- Play energetic VIP Rose Dance + celebratory jumps
    playAvatarAnimation(targetCharacter, VIP_ROSE_DANCE_ANIMS)
    local hum = targetCharacter:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Jump = true
    end

    -- Tell Client Camera to smoothly zoom POV directly to this avatar for ROSE_POV_DURATION seconds!
    currentServerTrackedAvatar = targetCharacter
    isServerRoseVIP = true
    serverRoseStartTime = os.clock()
    task.delay(ROSE_POV_DURATION, function()
        isServerRoseVIP = false
    end)

    remoteEvent:FireAllClients("FocusAvatarPOV", {
        targetModel = targetCharacter,
        tiktokUniqueId = tiktokUniqueId,
        robloxUsername = targetCharacter.Name,
        giftName = giftName,
        duration = ROSE_POV_DURATION
    })
end

-- ============================================================================
-- Poll Node.js Local Bridge Server (http://localhost:3000/api/events)
-- ============================================================================
print("================================================================")
print("🎬 TikTok Show Server Started! Polling " .. BRIDGE_URL)
print("================================================================")

task.spawn(function()
    while true do
        local ok, responseBody = pcall(function()
            return HttpService:GetAsync(BRIDGE_URL, true)
        end)

        if ok and responseBody then
            local decodeOk, payload = pcall(function()
                return HttpService:JSONDecode(responseBody)
            end)

            if decodeOk and payload and payload.ok and type(payload.events) == "table" then
                for _, event in ipairs(payload.events) do
                    if event.type == "spawn_avatar" then
                        task.spawn(function()
                            spawnVerifiedFollowerAvatar(event)
                        end)
                    elseif event.type == "rose_gift" then
                        task.spawn(function()
                            triggerRoseGiftEffect(event)
                        end)
                    elseif event.type == "not_following" then
                        remoteEvent:FireAllClients("ShowBannerAlert", {
                            alertType = "not_following",
                            tiktokUniqueId = event.tiktokUniqueId,
                            robloxUsername = event.robloxUsername
                        })
                    elseif event.type == "new_follower" then
                        remoteEvent:FireAllClients("ShowBannerAlert", {
                            alertType = "new_follower",
                            tiktokUniqueId = event.tiktokUniqueId
                        })
                    elseif event.type == "member_join" then
                        triggerRGBFireworks(3.5)
                        remoteEvent:FireAllClients("ShowBannerAlert", {
                            alertType = "member_join",
                            tiktokUniqueId = event.tiktokUniqueId
                        })
                    elseif event.type == "witch_hat_dragon" then
                        task.spawn(function()
                            triggerWitchHatDragons(event)
                        end)
                        remoteEvent:FireAllClients("ShowBannerAlert", {
                            alertType = "witch_hat_dragon",
                            tiktokUniqueId = event.tiktokUniqueId,
                            giftName = event.giftName or "Topi Penyihir"
                        })
                    elseif event.type == "finger_heart_dolphin" then
                        task.spawn(function()
                            triggerFingerHeartDolphins(event)
                        end)
                        remoteEvent:FireAllClients("ShowBannerAlert", {
                            alertType = "finger_heart_dolphin",
                            tiktokUniqueId = event.tiktokUniqueId,
                            giftName = event.giftName or "Finger Heart"
                        })
                    elseif event.type == "update_dance_config" then
                        print("[TikTokShow] 💃 Received update_dance_config from web controller!")
                        if event.avatarScale and tonumber(event.avatarScale) then
                            currentAvatarScale = tonumber(event.avatarScale)
                            print("[TikTokShow] 📏 Updated avatar scale to: " .. currentAvatarScale .. "x")
                            local spawnedFolder = workspace:FindFirstChild("SpawnedTikTokAvatars")
                            if spawnedFolder then
                                for _, char in ipairs(spawnedFolder:GetChildren()) do
                                    if char:IsA("Model") then
                                        pcall(function()
                                            char:ScaleTo(currentAvatarScale)
                                        end)
                                    end
                                end
                            end
                        end
                        if type(event.stageDances) == "table" and #event.stageDances > 0 then
                            local resolved = {}
                            for _, id in ipairs(event.stageDances) do
                                table.insert(resolved, resolvePlayableAnimationId(id))
                            end
                            STAGE_DANCE_ANIMS = resolved
                            print("[TikTokShow] Updated STAGE_DANCE_ANIMS (" .. #STAGE_DANCE_ANIMS .. " dances)")
                        end
                        if type(event.crowdDances) == "table" and #event.crowdDances > 0 then
                            local resolved = {}
                            for _, id in ipairs(event.crowdDances) do
                                table.insert(resolved, resolvePlayableAnimationId(id))
                            end
                            CROWD_DANCE_ANIMS = resolved
                            print("[TikTokShow] Updated CROWD_DANCE_ANIMS (" .. #CROWD_DANCE_ANIMS .. " dances)")
                        end
                        if type(event.vipDances) == "table" and #event.vipDances > 0 then
                            local resolved = {}
                            for _, id in ipairs(event.vipDances) do
                                table.insert(resolved, resolvePlayableAnimationId(id))
                            end
                            VIP_ROSE_DANCE_ANIMS = resolved
                            print("[TikTokShow] Updated VIP_ROSE_DANCE_ANIMS (" .. #VIP_ROSE_DANCE_ANIMS .. " dances)")
                        end

                        if event.forceDanceId and tostring(event.forceDanceId) ~= "" then
                            local forceId = tostring(event.forceDanceId)
                            print("[TikTokShow] 💥 Forcing all active avatars to dance: " .. forceId)
                            local playableForceId = resolvePlayableAnimationId(forceId)
                            CROWD_DANCE_ANIMS = { playableForceId }
                            local spawnedFolder = workspace:FindFirstChild("SpawnedTikTokAvatars")
                            if spawnedFolder then
                                for _, char in ipairs(spawnedFolder:GetChildren()) do
                                    if char:IsA("Model") and char:FindFirstChildOfClass("Humanoid") then
                                        task.spawn(function()
                                            playAvatarAnimation(char, playableForceId)
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        task.wait(POLL_INTERVAL)
    end
end)
