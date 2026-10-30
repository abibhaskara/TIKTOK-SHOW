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
-- 3 Dragons Flight Event (Hat and Mustache / Topi dan Kumis Gift)
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
    print("🐉 [DRAGON EVENT] Spawning 3 Dragons for Hat and Mustache gift from @" .. tostring(giftData and giftData.tiktokUniqueId or "viewer"))

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
-- Giant Tsunami Wave Event (Potato Gift)
-- Searches for model "TsunamiWave", animates for 15s:
--   0s -> 2s: Transparency 1 -> 0
--   0s -> 15s: Position (59.32, 34.43, -689.134) -> (59.32, 74.414, 77.776)
--   12s -> 15s: Transparency 0 -> 1
-- ============================================================================
local TSUNAMI_START_POS = Vector3.new(59.32, 34.43, -689.134)
local TSUNAMI_END_POS = Vector3.new(59.32, 74.414, 77.776)
local TSUNAMI_DURATION = 15.0
local isTsunamiActive = false
local cachedTsunamiModel = nil
local cachedTsunamiRotation = nil

local function setTsunamiTransparency(model, trans)
    if not model then return end
    if model:IsA("BasePart") then
        model.Transparency = trans
    end
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
            desc.Transparency = trans
        end
    end
end

local function moveTsunamiModel(model, pos)
    if not model then return end
    if model:IsA("Model") then
        local rot = cachedTsunamiRotation or model:GetPivot().Rotation
        model:PivotTo(CFrame.new(pos) * rot)
    elseif model:IsA("BasePart") then
        local rot = cachedTsunamiRotation or model.CFrame.Rotation
        model.CFrame = CFrame.new(pos) * rot
    end
end

local function findAndPrepareTsunamiModel()
    if cachedTsunamiModel and cachedTsunamiModel.Parent then
        return cachedTsunamiModel
    end

    local found = workspace:FindFirstChild("TsunamiWave", true) or ReplicatedStorage:FindFirstChild("TsunamiWave", true)
    if not found then
        return nil
    end

    cachedTsunamiModel = found
    if found:IsA("Model") then
        cachedTsunamiRotation = found:GetPivot().Rotation
    elseif found:IsA("BasePart") then
        cachedTsunamiRotation = found.CFrame.Rotation
    end

    -- Clean up any legacy free-model scripts (Move, Damage, Destroy) and anchor parts safely
    for _, desc in ipairs(found:GetDescendants()) do
        if desc:IsA("BaseScript") then
            desc.Disabled = true
            desc:Destroy()
        elseif desc:IsA("BasePart") then
            desc.Anchored = true
            desc.CanCollide = false
            desc.CanTouch = false
        elseif desc:IsA("Sound") then
            desc.Playing = false
        end
    end

    -- Start hidden at TSUNAMI_START_POS with Transparency = 1
    setTsunamiTransparency(found, 1)
    moveTsunamiModel(found, TSUNAMI_START_POS)
    if found.Parent ~= workspace then
        found.Parent = workspace
    end

    return found
end

-- Prepare TsunamiWave immediately on server startup so it stays hidden until triggered
task.defer(findAndPrepareTsunamiModel)

local function triggerPotatoTsunami(giftData)
    if isTsunamiActive then
        print("⚠️ Tsunami Wave event is already running!")
        return
    end

    local tsunami = findAndPrepareTsunamiModel()
    if not tsunami then
        warn("❌ Model 'TsunamiWave' not found in Workspace or ReplicatedStorage!")
        return
    end

    isTsunamiActive = true
    print("🌊 [TSUNAMI EVENT] Unleashing 15s TsunamiWave for Potato gift from @" .. tostring(giftData and giftData.tiktokUniqueId or "viewer"))

    local waveSound = tsunami:FindFirstChildWhichIsA("Sound", true)
    if waveSound then
        waveSound.Looped = true
        waveSound.Volume = 0
        waveSound:Play()
    end

    setTsunamiTransparency(tsunami, 1)
    moveTsunamiModel(tsunami, TSUNAMI_START_POS)

    task.spawn(function()
        local startTime = os.clock()
        local conn
        conn = RunService.Heartbeat:Connect(function()
            local elapsed = os.clock() - startTime
            if elapsed >= TSUNAMI_DURATION then
                conn:Disconnect()
                return
            end

            -- 1. Position interpolation: 0s -> 15s from (59.32, 34.43, -689.134) to (59.32, 74.414, 77.776)
            local posAlpha = math.clamp(elapsed / TSUNAMI_DURATION, 0, 1)
            local currentPos = TSUNAMI_START_POS:Lerp(TSUNAMI_END_POS, posAlpha)
            moveTsunamiModel(tsunami, currentPos)

            -- 2. Transparency interpolation:
            --    0s -> 2s: Transparency 1 -> 0
            --    2s -> 12s: Transparency 0
            --    12s -> 15s: Transparency 0 -> 1
            local trans = 0
            if elapsed < 2.0 then
                trans = 1.0 - math.clamp(elapsed / 2.0, 0, 1)
            elseif elapsed >= 12.0 then
                trans = math.clamp((elapsed - 12.0) / 3.0, 0, 1)
            else
                trans = 0.0
            end
            setTsunamiTransparency(tsunami, trans)

            if waveSound then
                waveSound.Volume = (1.0 - trans) * 4.5
            end
        end)

        task.wait(TSUNAMI_DURATION + 0.1)
        if conn and conn.Connected then
            conn:Disconnect()
        end

        -- Ensure final state is Transparency = 1 at end of 15s
        moveTsunamiModel(tsunami, TSUNAMI_END_POS)
        setTsunamiTransparency(tsunami, 1)
        if waveSound then
            waveSound:Stop()
        end

        isTsunamiActive = false
        print("🌊 [TSUNAMI EVENT] 15s TsunamiWave finished & hidden!")
    end)
end

-- ============================================================================
-- Configuration (Auto-Detects Studio Localhost vs Published Roblox Player Tunnel)
-- ============================================================================
local LOCAL_BRIDGE_URL = "http://localhost:3000/api/events"
local PUBLIC_BRIDGE_URL = workspace:GetAttribute("PublicBridgeUrl") or "https://1ecfb6b8b42bab.lhr.life/api/events"
local BRIDGE_URL = RunService:IsStudio() and LOCAL_BRIDGE_URL or PUBLIC_BRIDGE_URL
local POLL_INTERVAL = 0.15           -- Fast 150ms polling for instant live reactions!
local STAGE_DANCE_DURATION = 4.5     -- Seconds an avatar dances on the Main Stage before walking to crowd
local ROSE_POV_DURATION = 4.5        -- Seconds the Camera POV focuses on an avatar when they send a Rose
local MAX_CROWD_AVATARS = 30         -- Delete oldest character if total avatars exceed 30

-- Panda Gift: 30s Giant Titan Scale & 10s POV
local PANDA_GIANT_SCALE = 3.0        -- Giant Titan scale (3.0x size)
local PANDA_GIANT_DURATION = 30.0    -- Giant size lasts for 30s
local PANDA_POV_DURATION = 10.0      -- Camera POV stays on giant avatar for 10s
local avatarGiantToken = {}

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

    -- Delete oldest character(s) if count exceeds MAX_CROWD_AVATARS (30)
    while #crowdQueue > MAX_CROWD_AVATARS do
        local oldest = table.remove(crowdQueue, 1)
        if oldest and oldest.Parent then
            oldest:Destroy()
        end
    end
end

-- Custom Walking & Roaming Waypoints
local TRANSITION_WAYPOINT = Vector3.new(50, 59.248, -105.44)
local ROAM_AREA = {
    minX = 39.5,
    maxX = 60.5,
    minY = 59.198,
    maxY = 59.248,
    minZ = -122.5,
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
    character:SetAttribute("TikTokUniqueId", tostring(tiktokUniqueId))
    character:SetAttribute("RobloxUsername", tostring(robloxUsername))
    local isPandaVIP = (isRoseVIP == "panda")
    local isRose = (isRoseVIP == true or isRoseVIP == "rose")

    -- Using Studs (Scale) sizing so the nametag maintains realistic 3D world dimensions
    -- and stops growing on screen as the camera pulls further away:
    billboard.Size = UDim2.new(5.5, 0, 1.5, 0)
    billboard.StudsOffset = Vector3.new(0, isPandaVIP and 4.6 or 3.8, 0)
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
    stroke.Color = isPandaVIP and Color3.fromRGB(16, 185, 129) or (isRose and Color3.fromRGB(254, 44, 85) or Color3.fromRGB(37, 244, 238))
    stroke.Parent = container

    -- Line 1: TikTok Username
    local tiktokLabel = Instance.new("TextLabel")
    tiktokLabel.Name = "TikTokLabel"
    tiktokLabel.Size = UDim2.new(1, -12, 0.5, 0)
    tiktokLabel.Position = UDim2.new(0, 6, 0, 2)
    tiktokLabel.BackgroundTransparency = 1
    tiktokLabel.Font = Enum.Font.GothamBold
    tiktokLabel.TextSize = 16
    tiktokLabel.TextColor3 = isPandaVIP and Color3.fromRGB(52, 211, 153) or Color3.fromRGB(37, 244, 238)
    tiktokLabel.TextStrokeTransparency = 0.3
    local prefix = "🎵 @"
    if isPandaVIP then
        prefix = "🐼 [TITAN] @"
    elseif isRose then
        prefix = "🌹 @"
    end
    tiktokLabel.Text = prefix .. tostring(tiktokUniqueId)
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
    robloxLabel.TextColor3 = (isPandaVIP or isRose) and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(240, 244, 255)
    robloxLabel.TextStrokeTransparency = 0.4
    robloxLabel.Text = "🎮 Roblox: " .. tostring(robloxUsername)
    robloxLabel.TextScaled = true
    robloxLabel.Parent = container
end

-- ============================================================================
-- Helper: Resolve Animation ID (Supports both direct Animation IDs and Catalog Emotes)
-- ============================================================================
local InsertService = game:GetService("InsertService")
local resolvedAnimationCache = {
    ["507771019"] = "rbxassetid://507771019",
    ["507776043"] = "rbxassetid://507776043",
    ["507777268"] = "rbxassetid://507777268",
    ["3333499508"] = "rbxassetid://3333499508",
    ["507770677"] = "rbxassetid://507770677",
    ["128280894782553"] = "rbxassetid://136857756041583",
    ["125465899146465"] = "rbxassetid://91348383154280",
}

local function resolvePlayableAnimationId(rawId)
    if not rawId then return nil end
    local numId = string.match(tostring(rawId), "%d+")
    if not numId then return nil end

    if resolvedAnimationCache[numId] then
        return resolvedAnimationCache[numId]
    end

    -- Direct built-in / legacy animation IDs (< 12 digits) are already playable Animation assets (Zero latency)
    if #numId < 12 then
        local directId = "rbxassetid://" .. numId
        resolvedAnimationCache[numId] = directId
        return directId
    end

    -- Only UGC/Catalog Emotes (12+ digits) need LoadAsset to unpack
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
-- Helper: Avatar Walk / Locomotion Animation Helpers
-- ============================================================================
local DEFAULT_WALK_ANIM = "http://www.roblox.com/asset/?id=10921269718"

local function getAvatarWalkAnimId(character)
    local animScript = character:FindFirstChild("Animate")
    if animScript then
        local walkVal = animScript:FindFirstChild("walk") or animScript:FindFirstChild("run")
        local found = walkVal and walkVal:FindFirstChildWhichIsA("Animation")
        if found and found.AnimationId and found.AnimationId ~= "" then
            return found.AnimationId
        end
    end
    return DEFAULT_WALK_ANIM
end

local function playWalkAnimation(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    -- Stop playing dance tracks
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        track:Stop(0.15)
    end

    local walkId = getAvatarWalkAnimId(character)
    local anim = Instance.new("Animation")
    anim.AnimationId = walkId

    local ok, track = pcall(function()
        return animator:LoadAnimation(anim)
    end)

    if ok and track then
        track.Priority = Enum.AnimationPriority.Action4
        track.Looped = true
        track:Play(0.1)
        return track
    end
    return nil
end

local function stopWalkAnimation(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            if track.Priority == Enum.AnimationPriority.Action4 then
                track:Stop(0.15)
            end
        end
    end
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
-- Panda Gift: Emerald & Gold Titan Glowing Aura + Particles (30s)
-- ============================================================================
local function applyPandaGiftEffects(character, duration)
    local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
    if not hrp then return end

    -- Clean up any existing panda effects
    local oldH = character:FindFirstChild("PandaHighlight")
    if oldH then oldH:Destroy() end
    local oldP = hrp:FindFirstChild("PandaParticles")
    if oldP then oldP:Destroy() end
    local oldL = hrp:FindFirstChild("PandaLight")
    if oldL then oldL:Destroy() end

    -- Emerald + Gold Titan Highlight
    local highlight = Instance.new("Highlight")
    highlight.Name = "PandaHighlight"
    highlight.FillColor = Color3.fromRGB(16, 185, 129)
    highlight.FillTransparency = 0.55
    highlight.OutlineColor = Color3.fromRGB(255, 215, 0)
    highlight.OutlineTransparency = 0
    highlight.Parent = character
    Debris:AddItem(highlight, duration)

    -- Bright Emerald Glow Light
    local light = Instance.new("PointLight")
    light.Name = "PandaLight"
    light.Color = Color3.fromRGB(52, 211, 153)
    light.Brightness = 5.0
    light.Range = 32
    light.Parent = hrp
    Debris:AddItem(light, duration)

    -- Emerald / Gold Sparkle Particle Emitter
    local pandaParticles = Instance.new("ParticleEmitter")
    pandaParticles.Name = "PandaParticles"
    pandaParticles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pandaParticles.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 185, 129)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(52, 211, 153)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0)),
    })
    pandaParticles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(0.5, 2.0),
        NumberSequenceKeypoint.new(1, 0),
    })
    pandaParticles.Rate = 55
    pandaParticles.Lifetime = NumberRange.new(1.5, 2.8)
    pandaParticles.Speed = NumberRange.new(5, 12)
    pandaParticles.SpreadAngle = Vector2.new(180, 180)
    pandaParticles.Parent = hrp
    Debris:AddItem(pandaParticles, duration)
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
        humanoid.Running:Connect(function(speed)
            if not character or not character.Parent then return end
            if speed > 1.0 then
                local isAlreadyWalking = false
                local anim = humanoid:FindFirstChildOfClass("Animator")
                if anim then
                    for _, tr in ipairs(anim:GetPlayingAnimationTracks()) do
                        if tr.Priority == Enum.AnimationPriority.Action4 then
                            isAlreadyWalking = true
                            break
                        end
                    end
                end
                if not isAlreadyWalking then
                    playWalkAnimation(character)
                end
            elseif speed <= 0.5 then
                stopWalkAnimation(character)
            end
        end)
    end

    -- Scale avatar larger by default for prominent visibility!
    pcall(function()
        character:ScaleTo(currentAvatarScale)
    end)

    -- Wait briefly if another avatar is mid-spotlight on the center pedestal
    local waitCount = 0
    while isStageBusy and waitCount < 5 do
        task.wait(0.2)
        waitCount += 1
    end
    isStageBusy = true
    task.delay(STAGE_DANCE_DURATION + 0.5, function()
        isStageBusy = false
    end)

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
        playWalkAnimation(character)
        humanoid:MoveTo(TRANSITION_WAYPOINT)
        humanoid.MoveToFinished:Wait()
    end

    if not character or not character.Parent then return end

    -- 2. Once reached, pick a spot inside the custom boundary area:
    --    X: [37, 62], Y: [59.198, 59.248], Z: [-124.44, -105.44]
    local targetRoamSpot = getRandomRoamPosition()
    character:SetAttribute("CrowdSpot", targetRoamSpot)

    if humanoid then
        playWalkAnimation(character)
        humanoid:MoveTo(targetRoamSpot)
        humanoid.MoveToFinished:Wait()
        stopWalkAnimation(character)
    end

    -- Face forward and dance
    if character and character.Parent then
        local currentPos = character:GetPivot().Position
        character:PivotTo(CFrame.lookAt(currentPos, currentPos + Vector3.new(0, 0, 20)))
        playAvatarAnimation(character, CROWD_DANCE_ANIMS)

        -- Periodically roam between spots within the boundary area
        task.spawn(function()
            while character and character.Parent and humanoid and humanoid.Parent do
                task.wait(math.random(7, 13))
                if not character or not character.Parent then break end

                -- Do not walk away if currently featured in a VIP Spotlight (Rose / Panda)
                local vipUntil = character:GetAttribute("VIPSpotlightUntil") or 0
                if os.clock() >= vipUntil then
                    local newSpot = getRandomRoamPosition()
                    playWalkAnimation(character)
                    humanoid:MoveTo(newSpot)
                    humanoid.MoveToFinished:Wait()
                    stopWalkAnimation(character)

                    if character and character.Parent and os.clock() >= (character:GetAttribute("VIPSpotlightUntil") or 0) then
                        local posNow = character:GetPivot().Position
                        character:PivotTo(CFrame.lookAt(posNow, posNow + Vector3.new(0, 0, 20)))
                        playAvatarAnimation(character, CROWD_DANCE_ANIMS)
                    end
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

    local targetCharacter = event.targetCharacter or activeAvatarsByTikTok[key]

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

    -- Pause roaming while in VIP Spotlight so the avatar stands still for the camera
    targetCharacter:SetAttribute("VIPSpotlightUntil", os.clock() + ROSE_POV_DURATION + 1.5)
    stopWalkAnimation(targetCharacter)
    local hum = targetCharacter:FindFirstChildOfClass("Humanoid")
    local hrp = targetCharacter:FindFirstChild("HumanoidRootPart") or targetCharacter.PrimaryPart
    if hum and hrp then
        hum:MoveTo(hrp.Position)
    end

    -- Upgrade overhead tag to Rose VIP style
    attachNametag(targetCharacter, tiktokUniqueId, targetCharacter.Name, true)

    -- Apply Rose Particle Emitters + Glow Highlight
    applyRoseGiftEffects(targetCharacter, ROSE_POV_DURATION + 1.0)

    -- Play energetic VIP Rose Dance
    playAvatarAnimation(targetCharacter, VIP_ROSE_DANCE_ANIMS)

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
-- Handle Panda Gift: Summon or Enlarge Current Avatar for 30s + 10s POV!
-- ============================================================================
local function triggerPandaGiftEffect(event)
    local tiktokUniqueId = event.tiktokUniqueId or "gifter"
    local robloxUserId = tonumber(event.robloxUserId)
    local robloxUsername = event.robloxUsername or tiktokUniqueId
    local giftName = event.giftName or "Panda"
    local key = string.lower(tiktokUniqueId)

    local targetCharacter = event.targetCharacter or activeAvatarsByTikTok[key]

    -- If their avatar isn't currently spawned, summon it right now!
    if (not targetCharacter or not targetCharacter.Parent) then
        if not robloxUserId then
            pcall(function()
                robloxUserId = Players:GetUserIdFromNameAsync(robloxUsername)
            end)
        end
        if not robloxUserId then
            robloxUserId = 1
        end

        local ok, newChar = pcall(function()
            return Players:CreateHumanoidModelFromUserId(robloxUserId)
        end)

        if ok and newChar then
            newChar.Name = robloxUsername
            local hum = newChar:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                hum.Running:Connect(function(speed)
                    if not newChar or not newChar.Parent then return end
                    if speed > 1.0 then
                        local isAlreadyWalking = false
                        local anim = hum:FindFirstChildOfClass("Animator")
                        if anim then
                            for _, tr in ipairs(anim:GetPlayingAnimationTracks()) do
                                if tr.Priority == Enum.AnimationPriority.Action4 then
                                    isAlreadyWalking = true
                                    break
                                end
                            end
                        end
                        if not isAlreadyWalking then
                            playWalkAnimation(newChar)
                        end
                    elseif speed <= 0.5 then
                        stopWalkAnimation(newChar)
                    end
                end)
            end

            local stagePos = STAGE_POSITION + Vector3.new(0, 4.0, 0)
            newChar:PivotTo(CFrame.lookAt(stagePos, stagePos + Vector3.new(0, 0, 20)))
            newChar.Parent = avatarsFolder
            activeAvatarsByTikTok[key] = newChar
            table.insert(crowdQueue, newChar)
            enforceMaxAvatars()
            targetCharacter = newChar
        end
    end

    -- Fallback: If still no avatar, pick latest crowd avatar
    if (not targetCharacter or not targetCharacter.Parent) and #crowdQueue > 0 then
        targetCharacter = crowdQueue[#crowdQueue]
    end

    if not targetCharacter or not targetCharacter.Parent then
        remoteEvent:FireAllClients("ShowBannerAlert", {
            alertType = "panda_gift",
            tiktokUniqueId = tiktokUniqueId,
            robloxUsername = robloxUsername,
            giftName = giftName
        })
        return
    end

    -- Pause roaming while in 10s Panda POV Spotlight
    targetCharacter:SetAttribute("VIPSpotlightUntil", os.clock() + PANDA_POV_DURATION + 1.5)
    stopWalkAnimation(targetCharacter)
    local hum = targetCharacter:FindFirstChildOfClass("Humanoid")
    local hrp = targetCharacter:FindFirstChild("HumanoidRootPart") or targetCharacter.PrimaryPart
    if hum and hrp then
        hum:MoveTo(hrp.Position)
    end

    -- Enlarge current avatar to Giant Titan size (3.0x scale) for 30 seconds!
    pcall(function()
        targetCharacter:ScaleTo(PANDA_GIANT_SCALE)
    end)

    -- Upgrade overhead nametag to Giant Panda VIP style
    attachNametag(targetCharacter, tiktokUniqueId, targetCharacter.Name, "panda")

    -- Apply glowing emerald/gold titan aura & particles for 30 seconds
    applyPandaGiftEffects(targetCharacter, PANDA_GIANT_DURATION)

    -- Play energetic celebration dance
    playAvatarAnimation(targetCharacter, VIP_ROSE_DANCE_ANIMS)

    -- Safe revert after 30 seconds
    avatarGiantToken[targetCharacter] = (avatarGiantToken[targetCharacter] or 0) + 1
    local currentToken = avatarGiantToken[targetCharacter]

    task.delay(PANDA_GIANT_DURATION, function()
        if avatarGiantToken[targetCharacter] == currentToken and targetCharacter and targetCharacter.Parent then
            print("[TikTokShow] 🐼 30s Giant duration finished for " .. targetCharacter.Name .. ", restoring scale to " .. currentAvatarScale .. "x")
            avatarGiantToken[targetCharacter] = nil
            pcall(function()
                targetCharacter:ScaleTo(currentAvatarScale)
            end)
            attachNametag(targetCharacter, tiktokUniqueId, targetCharacter.Name, false)
        end
    end)

    -- Direct camera POV to this giant avatar for 10.0 seconds!
    currentServerTrackedAvatar = targetCharacter
    isServerRoseVIP = true
    serverRoseStartTime = os.clock()
    task.delay(PANDA_POV_DURATION, function()
        isServerRoseVIP = false
    end)

    remoteEvent:FireAllClients("FocusAvatarPOV", {
        targetModel = targetCharacter,
        tiktokUniqueId = tiktokUniqueId,
        robloxUsername = targetCharacter.Name,
        giftName = "Panda",
        duration = PANDA_POV_DURATION
    })
end

-- ============================================================================
-- Auto Random Gift Effect Loop (Every 7 Seconds)
-- Only chooses randomly from:
--   1. 🌹 Send Rose (Effect + Dance + POV)
--   2. 🐼 Send Panda (Giant 30s + 10s POV) -- 15% chance
--   3. 🧙‍♂️ / 🎩 Send Topi Penyihir / Hat and Mustache (3 Dragons 20s Event)
--   4. 🐬 Send Finger Heart (5 Leaping Dolphins 15s Event)
-- ============================================================================
local autoRandomGiftInterval = 7.0
local autoRandomGiftEnabled = true

local function getActiveSpawnedAvatars()
    local list = {}
    if avatarsFolder then
        for _, child in ipairs(avatarsFolder:GetChildren()) do
            if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") and (child:FindFirstChild("HumanoidRootPart") or child.PrimaryPart) then
                table.insert(list, child)
            end
        end
    end
    return list
end

task.spawn(function()
    while true do
        local elapsedWait = 0
        while elapsedWait < autoRandomGiftInterval do
            task.wait(0.2)
            if autoRandomGiftEnabled then
                elapsedWait += 0.2
            end
        end
        if autoRandomGiftEnabled then
            local activeAvatars = getActiveSpawnedAvatars()
            local chosenAva = nil
            if #activeAvatars > 0 then
                chosenAva = activeAvatars[math.random(1, #activeAvatars)]
            end

            local tiktokId = (chosenAva and chosenAva:GetAttribute("TikTokUniqueId")) or (chosenAva and chosenAva.Name) or "cool_viewer99"
            local robloxName = (chosenAva and chosenAva:GetAttribute("RobloxUsername")) or (chosenAva and chosenAva.Name) or "builderman"

            -- Weighted random selection among the 4 requested gift effects:
            --   - "panda_gift" (🐼 Gigantic 30s + 10s POV): 15% chance
            --   - Remaining 85% split equally among:
            --     * "rose_gift" (🌹 Rose Effect + Dance + POV)
            --     * "witch_hat_dragon" (🧙‍♂️ / 🎩 3 Dragons 20s Event)
            --     * "finger_heart_dolphin" (🐬 5 Leaping Dolphins 15s Event)
            local PANDA_GIGANTIC_CHANCE = 0.15
            local roll = math.random()
            local chosenGift
            if roll < PANDA_GIGANTIC_CHANCE then
                chosenGift = "panda_gift"
            else
                local otherPool = { "rose_gift" }
                if not isDragonEventActive then
                    table.insert(otherPool, "witch_hat_dragon")
                end
                if not isDolphinEventActive then
                    table.insert(otherPool, "finger_heart_dolphin")
                end
                chosenGift = otherPool[math.random(1, #otherPool)]
            end
            print(string.format("🎲 [AUTO 7s GIFT] (roll=%.2f) Applying '%s' to avatar '%s' (@%s)", roll, chosenGift, tostring(robloxName), tostring(tiktokId)))

            if chosenGift == "rose_gift" then
                task.spawn(function()
                    triggerRoseGiftEffect({
                        targetCharacter = chosenAva,
                        tiktokUniqueId = tiktokId,
                        robloxUsername = robloxName,
                        robloxUserId = (not chosenAva) and 1 or nil,
                        giftName = "Rose"
                    })
                end)
            elseif chosenGift == "panda_gift" then
                task.spawn(function()
                    triggerPandaGiftEffect({
                        targetCharacter = chosenAva,
                        tiktokUniqueId = tiktokId,
                        robloxUsername = robloxName,
                        robloxUserId = (not chosenAva) and 1 or nil,
                        giftName = "Panda"
                    })
                end)
            elseif chosenGift == "witch_hat_dragon" then
                if chosenAva then
                    applyRoseGiftEffects(chosenAva, 5.0)
                    playAvatarAnimation(chosenAva, VIP_ROSE_DANCE_ANIMS)
                end
                task.spawn(function()
                    triggerWitchHatDragons({
                        tiktokUniqueId = tiktokId,
                        robloxUsername = robloxName,
                        giftName = "Hat and Mustache"
                    })
                end)
                remoteEvent:FireAllClients("ShowBannerAlert", {
                    alertType = "witch_hat_dragon",
                    tiktokUniqueId = tiktokId,
                    giftName = "Hat and Mustache"
                })
            elseif chosenGift == "finger_heart_dolphin" then
                if chosenAva then
                    applyRoseGiftEffects(chosenAva, 5.0)
                    playAvatarAnimation(chosenAva, VIP_ROSE_DANCE_ANIMS)
                end
                task.spawn(function()
                    triggerFingerHeartDolphins({
                        tiktokUniqueId = tiktokId,
                        robloxUsername = robloxName,
                        giftName = "Finger Heart"
                    })
                end)
                remoteEvent:FireAllClients("ShowBannerAlert", {
                    alertType = "finger_heart_dolphin",
                    tiktokUniqueId = tiktokId,
                    giftName = "Finger Heart"
                })
            end
        end
    end
end)

-- ============================================================================
-- Poll Node.js Bridge Server (Auto-Supports Studio Localhost & Roblox Player Cloud Tunnel)
-- ============================================================================
print("================================================================")
print("🎬 TikTok Show Server Started! Polling " .. BRIDGE_URL)
print("================================================================")

local lastEventSeq = -1
local lastSyncedCameraScene = "auto"
local lastSyncedForceDanceSeq = 0
local lastSyncedStageDancesKey = ""
local lastSyncedCrowdDancesKey = ""
local lastSyncedVipDancesKey = ""

local function appendSinceQuery(baseUrl, seq)
    local sep = string.find(baseUrl, "?", 1, true) and "&" or "?"
    return baseUrl .. sep .. "since=" .. tostring(seq)
end

local function fetchBridgeEvents(url)
    local fullUrl = appendSinceQuery(url, lastEventSeq)
    local ok, res = pcall(function()
        return HttpService:RequestAsync({
            Url = fullUrl,
            Method = "GET",
            Headers = {
                ["Bypass-Tunnel-Reminder"] = "true",
                ["ngrok-skip-browser-warning"] = "true",
                ["Accept"] = "application/json"
            }
        })
    end)
    if ok and res and res.Success and res.Body then
        return true, res.Body
    end
    return false, nil
end

local function syncLiveStateFromController(state)
    if type(state) ~= "table" then return end

    -- 1. Sync Auto Random Gift (ON/OFF + 1s-30s Slider)
    if state.autoRandomGiftEnabled ~= nil then
        local newEnabled = (state.autoRandomGiftEnabled ~= false)
        if newEnabled ~= autoRandomGiftEnabled then
            autoRandomGiftEnabled = newEnabled
            print("[TikTokShow] 🎲 Synced Auto Random Gift Enabled -> " .. tostring(autoRandomGiftEnabled))
        end
    end
    if state.autoRandomGiftInterval and tonumber(state.autoRandomGiftInterval) then
        local newInterval = math.clamp(tonumber(state.autoRandomGiftInterval), 1, 30)
        if newInterval ~= autoRandomGiftInterval then
            autoRandomGiftInterval = newInterval
            print("[TikTokShow] ⏱️ Synced Auto Random Gift Interval -> " .. tostring(autoRandomGiftInterval) .. "s")
        end
    end

    -- 2. Sync Camera Scene
    if state.cameraScene and tostring(state.cameraScene) ~= lastSyncedCameraScene then
        lastSyncedCameraScene = tostring(state.cameraScene)
        print("[TikTokShow] 🎥 Synced Camera Scene -> " .. lastSyncedCameraScene)
        remoteEvent:FireAllClients("SetCameraScene", { scene = lastSyncedCameraScene })
    end

    -- 3. Sync Avatar Scale
    if state.avatarScale and tonumber(state.avatarScale) then
        local newScale = tonumber(state.avatarScale)
        if math.abs(newScale - currentAvatarScale) > 0.01 then
            currentAvatarScale = newScale
            print("[TikTokShow] 📏 Synced Avatar Scale -> " .. currentAvatarScale .. "x")
            local spawnedFolder = workspace:FindFirstChild("SpawnedTikTokAvatars")
            if spawnedFolder then
                for _, char in ipairs(spawnedFolder:GetChildren()) do
                    if char:IsA("Model") and not avatarGiantToken[char] then
                        pcall(function()
                            char:ScaleTo(currentAvatarScale)
                        end)
                    end
                end
            end
        end
    end

    -- 3b. Sync Dance Playlists (Stage, Crowd, VIP) so custom settings apply immediately on startup
    if type(state.stageDances) == "table" and #state.stageDances > 0 then
        local key = table.concat(state.stageDances, ",")
        if key ~= lastSyncedStageDancesKey then
            lastSyncedStageDancesKey = key
            task.spawn(function()
                local resolved = {}
                for _, id in ipairs(state.stageDances) do
                    table.insert(resolved, resolvePlayableAnimationId(id))
                end
                STAGE_DANCE_ANIMS = resolved
                print("[TikTokShow] 🎤 Synced STAGE_DANCE_ANIMS: " .. key)
            end)
        end
    end

    if type(state.crowdDances) == "table" and #state.crowdDances > 0 then
        local key = table.concat(state.crowdDances, ",")
        if key ~= lastSyncedCrowdDancesKey then
            lastSyncedCrowdDancesKey = key
            task.spawn(function()
                local resolved = {}
                for _, id in ipairs(state.crowdDances) do
                    table.insert(resolved, resolvePlayableAnimationId(id))
                end
                CROWD_DANCE_ANIMS = resolved
                print("[TikTokShow] 👥 Synced CROWD_DANCE_ANIMS: " .. key)
                local spawnedFolder = workspace:FindFirstChild("SpawnedTikTokAvatars")
                if spawnedFolder then
                    for _, char in ipairs(spawnedFolder:GetChildren()) do
                        if char:IsA("Model") and char:FindFirstChildOfClass("Humanoid") then
                            task.spawn(function()
                                playAvatarAnimation(char, CROWD_DANCE_ANIMS)
                            end)
                        end
                    end
                end
            end)
        end
    end

    if type(state.vipDances) == "table" and #state.vipDances > 0 then
        local key = table.concat(state.vipDances, ",")
        if key ~= lastSyncedVipDancesKey then
            lastSyncedVipDancesKey = key
            task.spawn(function()
                local resolved = {}
                for _, id in ipairs(state.vipDances) do
                    table.insert(resolved, resolvePlayableAnimationId(id))
                end
                VIP_ROSE_DANCE_ANIMS = resolved
                print("[TikTokShow] 🌹 Synced VIP_ROSE_DANCE_ANIMS: " .. key)
            end)
        end
    end

    -- 4. Sync Instant Forced Dance if a new forceDanceSeq arrived
    if state.forceDanceSeq and tonumber(state.forceDanceSeq) and tonumber(state.forceDanceSeq) > lastSyncedForceDanceSeq then
        lastSyncedForceDanceSeq = tonumber(state.forceDanceSeq)
        if state.forceDanceId and tostring(state.forceDanceId) ~= "" then
            local forceId = tostring(state.forceDanceId)
            task.spawn(function()
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
            end)
        end
    end
end

task.spawn(function()
    local PERMANENT_TUNNEL_URL = "https://tiktokshow796910abib.loca.lt/api/events"
    local DISCOVERY_URL = "https://ntfy.sh/tiktok_show_abibhaskara_796910_cfg/raw?poll=1&since=24h"
    local discoveredTunnelUrl = nil
    local lastDiscoveryCheck = 0

    local function refreshDiscoveredTunnelUrl()
        if os.clock() - lastDiscoveryCheck < 3.0 then return end
        lastDiscoveryCheck = os.clock()
        local ok, res = pcall(function()
            return HttpService:GetAsync(DISCOVERY_URL)
        end)
        if ok and res and res ~= "" then
            local lastLine = nil
            for line in string.gmatch(res, "[^\r\n]+") do
                if string.find(line, "tunnelUrl", 1, true) then
                    lastLine = line
                end
            end
            if lastLine then
                local decOk, data = pcall(function()
                    return HttpService:JSONDecode(lastLine)
                end)
                if decOk and data and data.tunnelUrl and tostring(data.tunnelUrl) ~= "" then
                    discoveredTunnelUrl = tostring(data.tunnelUrl)
                end
            end
        end
    end

    -- Immediately fetch the active cloud tunnel URL on startup so we never wait on stale URLs!
    if not RunService:IsStudio() then
        refreshDiscoveredTunnelUrl()
    end

    while true do
        local candidateUrls = {}
        local seen = {}
        local function addCandidate(u)
            if u and u ~= "" and not seen[u] then
                seen[u] = true
                table.insert(candidateUrls, u)
            end
        end

        local customPublicUrl = workspace:GetAttribute("PublicBridgeUrl")
        if RunService:IsStudio() then
            addCandidate(LOCAL_BRIDGE_URL)
        end
        addCandidate(discoveredTunnelUrl)
        addCandidate(PERMANENT_TUNNEL_URL)
        addCandidate(PUBLIC_BRIDGE_URL)
        addCandidate(customPublicUrl)

        local ok, responseBody = false, nil
        for _, url in ipairs(candidateUrls) do
            ok, responseBody = fetchBridgeEvents(url)
            if ok and responseBody then
                break
            end
        end

        if not ok then
            refreshDiscoveredTunnelUrl()
            if discoveredTunnelUrl then
                ok, responseBody = fetchBridgeEvents(discoveredTunnelUrl)
            end
        end

        if ok and responseBody then
            local decodeOk, payload = pcall(function()
                return HttpService:JSONDecode(responseBody)
            end)

            if decodeOk and payload and payload.ok then
                if payload.nextSeq and tonumber(payload.nextSeq) then
                    lastEventSeq = tonumber(payload.nextSeq)
                end

                -- Always keep live state in sync with localhost:3000 controller!
                if payload.state then
                    syncLiveStateFromController(payload.state)
                end

                if type(payload.events) == "table" then
                    for _, event in ipairs(payload.events) do
                    if event.type == "spawn_avatar" then
                        task.spawn(function()
                            spawnVerifiedFollowerAvatar(event)
                        end)
                    elseif event.type == "rose_gift" then
                        task.spawn(function()
                            triggerRoseGiftEffect(event)
                        end)
                    elseif event.type == "panda_gift" then
                        task.spawn(function()
                            triggerPandaGiftEffect(event)
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
                    elseif event.type == "witch_hat_dragon" or event.type == "hat_mustache_dragon" then
                        task.spawn(function()
                            triggerWitchHatDragons(event)
                        end)
                        remoteEvent:FireAllClients("ShowBannerAlert", {
                            alertType = "witch_hat_dragon",
                            tiktokUniqueId = event.tiktokUniqueId,
                            giftName = event.giftName or "Hat and Mustache"
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
                    elseif event.type == "potato_tsunami" then
                        task.spawn(function()
                            triggerPotatoTsunami(event)
                        end)
                        remoteEvent:FireAllClients("ShowBannerAlert", {
                            alertType = "potato_tsunami",
                            tiktokUniqueId = event.tiktokUniqueId,
                            giftName = event.giftName or "Potato"
                        })
                    elseif event.type == "set_camera_scene" then
                        print("[TikTokShow] 🎥 Camera Scene switched to: " .. tostring(event.scene))
                        remoteEvent:FireAllClients("SetCameraScene", { scene = event.scene })
                    elseif event.type == "set_auto_random_gift" then
                        if event.enabled ~= nil then
                            autoRandomGiftEnabled = (event.enabled ~= false)
                        end
                        if event.intervalSeconds and tonumber(event.intervalSeconds) then
                            autoRandomGiftInterval = math.clamp(tonumber(event.intervalSeconds), 1, 30)
                        end
                        print(string.format("[TikTokShow] 🎲 Auto Random Gift: %s (Interval: %ds)", tostring(autoRandomGiftEnabled), autoRandomGiftInterval))
                    elseif event.type == "update_bridge_url" and event.publicBridgeUrl then
                        workspace:SetAttribute("PublicBridgeUrl", tostring(event.publicBridgeUrl))
                        PUBLIC_BRIDGE_URL = tostring(event.publicBridgeUrl)
                        print("[TikTokShow] 🌐 Updated Public Bridge URL to: " .. PUBLIC_BRIDGE_URL)
                    elseif event.type == "update_dance_config" then
                        task.spawn(function()
                            print("[TikTokShow] 💃 Received update_dance_config from web controller!")
                            if event.avatarScale and tonumber(event.avatarScale) then
                                currentAvatarScale = tonumber(event.avatarScale)
                                print("[TikTokShow] 📏 Updated avatar scale to: " .. currentAvatarScale .. "x")
                                local spawnedFolder = workspace:FindFirstChild("SpawnedTikTokAvatars")
                                if spawnedFolder then
                                    for _, char in ipairs(spawnedFolder:GetChildren()) do
                                        if char:IsA("Model") and not avatarGiantToken[char] then
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
                        end)
                    end
                    end
                end
            end
        end

        task.wait(POLL_INTERVAL)
    end
end)
