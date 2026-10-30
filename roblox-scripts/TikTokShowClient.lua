--[[
    ============================================================================
    TIKTOK LIVE -> ROBLOX AVATAR SHOW (CLIENT CAMERA POV & HUD SCRIPT)
    ============================================================================
    HOW TO USE IN ROBLOX STUDIO:
    1. In Explorer, open `StarterPlayer` -> `StarterPlayerScripts`.
    2. Create a new `LocalScript` named `TikTokShowClient`.
    3. Paste this entire file into `TikTokShowClient`.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

-- ============================================================================
-- Camera Configuration (Continuous Avatar Follow + Drone Surveillance View)
-- ============================================================================
local STAGE_POSITION = Vector3.new(49.665, 58.798, -68.576)
local MAIN_CAMERA_POS = STAGE_POSITION + Vector3.new(0, 10, 22)
local MAIN_CAMERA_LOOKAT = STAGE_POSITION + Vector3.new(0, 3.0, 0)
local MAIN_CAMERA_CFRAME = CFrame.lookAt(MAIN_CAMERA_POS, MAIN_CAMERA_LOOKAT)

-- ============================================================================
-- 3-Scene Cinematic Director Settings
-- ============================================================================
-- Scene 1: Drone View (sweeping arena surveillance)
-- Scene 2: Paparazzi Cam (telephoto handheld spotter on 1 random avatar)
-- Scene 3: Pull-In Shot (smooth cinematic glide from (50, 63.403, -10.701) to (50, 63.403, -69.701))

-- Scene 1: Drone View Area Settings (Center on the action area)
local DRONE_CENTER = Vector3.new(50.239, 66.903, -106)
local DRONE_RADIUS_X = 52.0
local DRONE_RADIUS_Z = 55.0
local DRONE_SPEED = 0.16

-- Scene 3: Pull-In Coordinates requested by user
local PULLIN_START = Vector3.new(50, 63.403, -10.701)
local PULLIN_END = Vector3.new(50, 63.403, -69.701)

-- Scene Durations (Total cycle: 27 seconds)
local SCENE_1_DURATION = 10.0   -- 10s Drone View
local SCENE_2_DURATION = 9.0    -- 9s Paparazzi Handheld
local SCENE_3_DURATION = 8.0    -- 8s Cinematic Pull-In
local TOTAL_CYCLE_DURATION = SCENE_1_DURATION + SCENE_2_DURATION + SCENE_3_DURATION

-- Paparazzi state variables
local paparazziTargetAvatar = nil
local paparazziAngle = 0
local paparazziDist = 30.0
local currentSceneIndex = 1
local previousSceneIndex = -1
local manualCameraScene = "auto" -- "auto", "drone", "paparazzi", "pullin"

local currentTrackedAvatar = nil
local isRoseVIPMode = false
local roseVIPStartTime = 0
local povToken = 0
local cameraInitialized = false

-- State for Stage Posing vs Ambient 3-Scene Rotation:
-- When an avatar spawns, isAvatarPosingOnStage = true (camera follows avatar closely).
-- When posing finishes, stagePoseFinishTime = os.clock() and isAvatarPosingOnStage = false.
-- If 4 seconds pass after posing finishes and no new avatar has spawned on stage, switch to 3-Scene Rotation!
local isAvatarPosingOnStage = false
local stagePoseFinishTime = 0

local function pickRandomAvatarForPaparazzi()
    local folder = workspace:FindFirstChild("SpawnedTikTokAvatars")
    if folder then
        local children = folder:GetChildren()
        if #children > 0 then
            return children[math.random(1, #children)]
        end
    end
    return nil
end

local function findFallbackAvatar()
    local folder = workspace:FindFirstChild("SpawnedTikTokAvatars")
    if folder then
        local children = folder:GetChildren()
        if #children > 0 then
            return children[#children]
        end
    end
    return nil
end

-- Automatically lock onto any newly spawned TikTok avatar immediately
task.spawn(function()
    local folder = workspace:WaitForChild("SpawnedTikTokAvatars", 30)
    if folder then
        folder.ChildAdded:Connect(function(child)
            task.wait(0.05)
            currentTrackedAvatar = child
            isAvatarPosingOnStage = true
        end)
    end
end)

-- Use BindToRenderStep at RenderPriority.Camera + 10 so Roblox's default character camera NEVER overrides it!
RunService:BindToRenderStep("TikTokShowCamera", Enum.RenderPriority.Camera.Value + 10, function(dt)
    local camera = workspace.CurrentCamera
    if not camera then return end

    camera.CameraType = Enum.CameraType.Scriptable

    if not cameraInitialized then
        cameraInitialized = true
        camera.CFrame = MAIN_CAMERA_CFRAME
    end

    -- Ensure we have a valid spawned TikTok avatar to follow
    if not currentTrackedAvatar or not currentTrackedAvatar.Parent then
        currentTrackedAvatar = findFallbackAvatar()
    end

    -- If a Rose VIP Gift or Panda Giant Gift is active, focus closely on that avatar
    if isRoseVIPMode and currentTrackedAvatar and currentTrackedAvatar.Parent then
        local hrp = currentTrackedAvatar:FindFirstChild("HumanoidRootPart") or currentTrackedAvatar.PrimaryPart
        if hrp then
            local currentScale = 1.0
            pcall(function()
                currentScale = currentTrackedAvatar:GetScale()
            end)
            local scaleMultiplier = math.clamp(currentScale, 1.0, 3.5)
            local heightOffset = 1.8 * (1 + (scaleMultiplier - 1) * 0.6)
            local distOffset = 10.5 * (1 + (scaleMultiplier - 1) * 0.7)
            local targetLookAt = hrp.Position + Vector3.new(0, heightOffset, 0)
            local elapsed = os.clock() - roseVIPStartTime
            local orbitAngle = math.sin(elapsed * 1.5) * 0.55
            local frontVec = (hrp.CFrame * CFrame.Angles(0, orbitAngle, 0)).LookVector
            local camPos = targetLookAt + (frontVec * distOffset) + Vector3.new(0, 2.4 * (1 + (scaleMultiplier - 1) * 0.5), 0)
            local desiredCFrame = CFrame.lookAt(camPos, targetLookAt)
            local alpha = math.clamp(dt * 8.0, 0, 1)
            camera.CFrame = camera.CFrame:Lerp(desiredCFrame, alpha)
            camera.FieldOfView = camera.FieldOfView + (60 - camera.FieldOfView) * alpha
            return
        end
    end

    -- If an avatar is currently on stage posing/dancing, follow them!
    if isAvatarPosingOnStage and currentTrackedAvatar and currentTrackedAvatar.Parent then
        local hrp = currentTrackedAvatar:FindFirstChild("HumanoidRootPart") or currentTrackedAvatar.PrimaryPart
        local hum = currentTrackedAvatar:FindFirstChildOfClass("Humanoid")
        if hum then camera.CameraSubject = hum end

        if hrp then
            local targetLookAt = hrp.Position + Vector3.new(0, 1.8, 0)
            local frontVec = hrp.CFrame.LookVector
            local camPos = targetLookAt + (frontVec * 15.0) + Vector3.new(0, 3.8, 0)
            local desiredCFrame = CFrame.lookAt(camPos, targetLookAt)
            local alpha = math.clamp(dt * 8.0, 0, 1)
            camera.CFrame = camera.CFrame:Lerp(desiredCFrame, alpha)
            camera.FieldOfView = camera.FieldOfView + (68 - camera.FieldOfView) * alpha
            return
        end
    end

    -- If avatar finished posing, check if 5 seconds have passed with no new avatar posing:
    local timeSincePosingFinished = (stagePoseFinishTime > 0) and (os.clock() - stagePoseFinishTime) or 999

    if timeSincePosingFinished < 5.0 and currentTrackedAvatar and currentTrackedAvatar.Parent then
        -- During the 0 - 5 second window after posing: still smoothly follow the avatar as they walk to the crowd
        local hrp = currentTrackedAvatar:FindFirstChild("HumanoidRootPart") or currentTrackedAvatar.PrimaryPart
        if hrp then
            local targetLookAt = hrp.Position + Vector3.new(0, 1.8, 0)
            local frontVec = hrp.CFrame.LookVector
            local camPos = targetLookAt + (frontVec * 15.0) + Vector3.new(0, 3.8, 0)
            local desiredCFrame = CFrame.lookAt(camPos, targetLookAt)
            local alpha = math.clamp(dt * 7.0, 0, 1)
            camera.CFrame = camera.CFrame:Lerp(desiredCFrame, alpha)
            camera.FieldOfView = camera.FieldOfView + (68 - camera.FieldOfView) * alpha
            return
        end
    end

    -- ========================================================================
    -- 3-SCENE CINEMATIC DIRECTOR (Active when no new avatar is on stage)
    -- Scene 1: Drone View (10s)
    -- Scene 2: Paparazzi Cam (9s)
    -- Scene 3: Pull-In Shot (8s)
    -- ========================================================================
    local cycleTime = os.clock() % TOTAL_CYCLE_DURATION
    local targetCFrame = nil
    local targetFOV = 70
    local lerpSpeed = 3.5

    -- Determine which scene is active (auto-cycle or manual override)
    local activeScene = 1
    local pullinElapsed = 0

    if manualCameraScene == "drone" then
        activeScene = 1
    elseif manualCameraScene == "paparazzi" then
        activeScene = 2
    elseif manualCameraScene == "pullin" then
        activeScene = 3
        pullinElapsed = (os.clock() % SCENE_3_DURATION)
    else
        if cycleTime < SCENE_1_DURATION then
            activeScene = 1
        elseif cycleTime < (SCENE_1_DURATION + SCENE_2_DURATION) then
            activeScene = 2
        else
            activeScene = 3
            pullinElapsed = cycleTime - (SCENE_1_DURATION + SCENE_2_DURATION)
        end
    end

    if activeScene == 1 then
        -- --------------------------------------------------------------------
        -- SCENE 1: DRONE VIEW (Sweeping Arena Surveillance)
        -- --------------------------------------------------------------------
        currentSceneIndex = 1
        local t = os.clock() * DRONE_SPEED
        local droneX = DRONE_CENTER.X + math.cos(t) * DRONE_RADIUS_X
        local droneZ = DRONE_CENTER.Z + math.sin(t) * DRONE_RADIUS_Z
        local droneY = DRONE_CENTER.Y + 12.0 + (math.sin(t * 1.8) * 3.5)

        local lookTarget = DRONE_CENTER + Vector3.new(
            math.cos(t + 0.4) * 8,
            -2.0,
            math.sin(t + 0.4) * 8
        )

        targetCFrame = CFrame.lookAt(Vector3.new(droneX, droneY, droneZ), lookTarget)
        targetFOV = 72
        lerpSpeed = 3.8

    elseif activeScene == 2 then
        -- --------------------------------------------------------------------
        -- SCENE 2: PAPARAZZI CAM (Randomly spot 1 avatar, telephoto handheld from afar)
        -- --------------------------------------------------------------------
        currentSceneIndex = 2

        -- When entering Scene 2 (or if current paparazzi avatar died), pick a new random avatar
        if previousSceneIndex ~= 2 or not paparazziTargetAvatar or not paparazziTargetAvatar.Parent then
            paparazziTargetAvatar = pickRandomAvatarForPaparazzi()
            paparazziAngle = math.random() * math.pi * 2
            paparazziDist = math.random(26, 36)
        end

        local hrp = nil
        if paparazziTargetAvatar and paparazziTargetAvatar.Parent then
            hrp = paparazziTargetAvatar:FindFirstChild("HumanoidRootPart") or paparazziTargetAvatar.PrimaryPart
        end

        local targetPos = STAGE_POSITION + Vector3.new(0, 3.5, 0)
        if hrp then
            targetPos = hrp.Position + Vector3.new(0, 1.8, 0)
        end

        -- Base camera position at telephoto distance
        local baseCamPos = targetPos + Vector3.new(
            math.cos(paparazziAngle) * paparazziDist,
            4.0,
            math.sin(paparazziAngle) * paparazziDist
        )

        -- Realistic Handheld Mechanics (Operator breathing, micro-tremor, and framing hunting):
        local now = os.clock()
        -- High-frequency micro-tremor (hands holding heavy telephoto lens)
        local tremorX = math.noise(now * 7.5, 12.3, 0) * 0.12
        local tremorY = math.noise(now * 6.8, 23.4, 0) * 0.12
        -- Low-frequency breathing & postural sway
        local swayX = (math.sin(now * 1.3) * 0.28) + (math.noise(now * 1.6, 45.6, 0) * 0.35)
        local swayY = (math.cos(now * 0.95) * 0.20) + (math.noise(now * 1.9, 67.8, 0) * 0.25)
        local swayRoll = math.noise(now * 1.1, 89.1, 0) * math.rad(1.2)

        -- Cameraman framing lag (subtle natural hunting to center subject)
        local operatorFramingLag = Vector3.new(swayX * 0.7, swayY * 0.6, 0)
        local handCamPos = baseCamPos + Vector3.new(swayX * 0.35, swayY * 0.3, 0)
        local actualLook = targetPos + operatorFramingLag

        local baseLook = CFrame.lookAt(handCamPos, actualLook)
        targetCFrame = baseLook * CFrame.Angles(tremorY * 0.015, tremorX * 0.015, swayRoll)

        -- Telephoto lens compression (tighter FOV around 44)
        targetFOV = 44
        lerpSpeed = (previousSceneIndex ~= 2) and 3.0 or 8.0

    else
        -- --------------------------------------------------------------------
        -- SCENE 3: CINEMATIC PULL-IN
        -- Pull in from (50, 63.403, -10.701) to (50, 63.403, -69.701)
        -- --------------------------------------------------------------------
        currentSceneIndex = 3
        local progress = math.clamp(pullinElapsed / SCENE_3_DURATION, 0, 1)

        -- Smoothstep cubic easing for cinematic dolly acceleration & deceleration
        local smoothT = progress * progress * (3 - 2 * progress)
        local currentCamPos = PULLIN_START:Lerp(PULLIN_END, smoothT)

        -- Look target: straight forward down the arena centerline toward the stage & audience
        local lookTarget = Vector3.new(50, 60.0, -85.0)

        -- Subtle cinematic dolly drift
        local dollySwayY = math.sin(pullinElapsed * 1.5) * 0.12
        local dollySwayX = math.cos(pullinElapsed * 1.2) * 0.18
        local adjustedPos = currentCamPos + Vector3.new(dollySwayX, dollySwayY, 0)

        targetCFrame = CFrame.lookAt(adjustedPos, lookTarget)

        -- Cinematic Dolly Zoom (starts slightly wide at 72, narrows to 62 as it reaches stage)
        targetFOV = 72 - (smoothT * 10.0)
        lerpSpeed = (previousSceneIndex ~= 3) and 3.2 or 7.0
    end

    previousSceneIndex = currentSceneIndex

    if targetCFrame then
        local alpha = math.clamp(dt * lerpSpeed, 0, 1)
        camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
        camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * alpha
    end
end)

-- ============================================================================
-- Auto-Build Stream Overlay HUD (Live Notification Banner)
-- ============================================================================
local playerGui = localPlayer:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TikTokShowHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Middle Alert Banner (Spawns, Not-Following Warnings, Rose VIP Alerts, 9:16 Optimized)
local alertBanner = Instance.new("Frame")
alertBanner.Name = "AlertBanner"
alertBanner.AnchorPoint = Vector2.new(0.5, 0.5)
alertBanner.Size = UDim2.new(0.85, 0, 0, 66)
alertBanner.Position = UDim2.new(0.5, 0, 0.42, 0) -- Centered in middle
alertBanner.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
alertBanner.BackgroundTransparency = 1
alertBanner.Visible = false
alertBanner.Parent = screenGui

local alertSizeConstraint = Instance.new("UISizeConstraint")
alertSizeConstraint.MaxSize = Vector2.new(380, 80)
alertSizeConstraint.MinSize = Vector2.new(240, 52)
alertSizeConstraint.Parent = alertBanner

local alertScale = Instance.new("UIScale")
alertScale.Scale = 0
alertScale.Parent = alertBanner

local alertCorner = Instance.new("UICorner")
alertCorner.CornerRadius = UDim.new(0, 14)
alertCorner.Parent = alertBanner

local alertStroke = Instance.new("UIStroke")
alertStroke.Thickness = 2.5
alertStroke.Color = Color3.fromRGB(254, 44, 85)
alertStroke.Transparency = 1
alertStroke.Parent = alertBanner

local alertText = Instance.new("TextLabel")
alertText.Size = UDim2.new(1, -24, 1, -12)
alertText.Position = UDim2.new(0, 12, 0, 6)
alertText.BackgroundTransparency = 1
alertText.Font = Enum.Font.GothamBold
alertText.TextColor3 = Color3.fromRGB(255, 255, 255)
alertText.TextSize = 18
alertText.TextWrapped = true
alertText.TextScaled = true
alertText.Text = ""
alertText.TextTransparency = 1
alertText.Parent = alertBanner

local bannerToken = 0
local function showBanner(message, borderColor, duration)
    bannerToken += 1
    local myToken = bannerToken

    alertText.Text = message
    alertStroke.Color = borderColor or Color3.fromRGB(37, 244, 238)

    -- Pop in oversized in the middle, then shrink into 9:16 placement!
    alertBanner.Visible = true
    alertScale.Scale = 1.35
    alertBanner.BackgroundTransparency = 0.5
    alertStroke.Transparency = 0.5
    alertText.TextTransparency = 0.2

    TweenService:Create(
        alertScale,
        TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1.0 }
    ):Play()

    TweenService:Create(
        alertBanner,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0.12 }
    ):Play()

    TweenService:Create(
        alertStroke,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Transparency = 0 }
    ):Play()

    TweenService:Create(
        alertText,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { TextTransparency = 0 }
    ):Play()

    task.delay(duration or 3.5, function()
        if bannerToken == myToken then
            local fadeOut = TweenService:Create(
                alertScale,
                TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In),
                { Scale = 0 }
            )
            TweenService:Create(
                alertBanner,
                TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { BackgroundTransparency = 1 }
            ):Play()
            TweenService:Create(
                alertStroke,
                TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Transparency = 1 }
            ):Play()
            TweenService:Create(
                alertText,
                TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { TextTransparency = 1 }
            ):Play()

            fadeOut:Play()
            fadeOut.Completed:Connect(function()
                if bannerToken == myToken then
                    alertBanner.Visible = false
                end
            end)
        end
    end)
end

-- ============================================================================
-- Camera Tracking Helpers (Spawn Follow + Rose VIP Close-Up POV)
-- ============================================================================
local function followAvatar(targetModel)
    if targetModel and targetModel.Parent then
        currentTrackedAvatar = targetModel
        isAvatarPosingOnStage = true
    end
end

local function focusCameraOnAvatar(targetModel, duration)
    if targetModel and targetModel.Parent then
        currentTrackedAvatar = targetModel
    end

    povToken += 1
    local myPovToken = povToken
    isRoseVIPMode = true
    roseVIPStartTime = os.clock()

    task.delay(duration or 4.5, function()
        if povToken == myPovToken then
            isRoseVIPMode = false
        end
    end)
end

-- ============================================================================
-- Listen for Server Events
-- ============================================================================
local remoteEvent = ReplicatedStorage:WaitForChild("TikTokShowEvents")

remoteEvent.OnClientEvent:Connect(function(action, data)
    if action == "AvatarStagePoseFinished" and data then
        isAvatarPosingOnStage = false
        stagePoseFinishTime = os.clock()

    elseif action == "SetCameraScene" and data then
        manualCameraScene = tostring(data.scene or "auto")
        if manualCameraScene == "paparazzi" then
            paparazziTargetAvatar = pickRandomAvatarForPaparazzi()
            paparazziAngle = math.random() * math.pi * 2
            paparazziDist = math.random(26, 36)
        end

    elseif action == "FocusAvatarPOV" and data then
        local isPanda = (data.giftName == "Panda") or (data.alertType == "panda_gift")
        if isPanda then
            showBanner(
                string.format("🐼 @%s sent Panda! 💥 GIANT TITAN AVATAR (30s)!", data.tiktokUniqueId),
                Color3.fromRGB(16, 185, 129),
                6.0
            )
        else
            showBanner(
                string.format("🌹 @%s sent a %s! VIP Spotlight on %s!", data.tiktokUniqueId, data.giftName or "Rose", data.robloxUsername),
                Color3.fromRGB(254, 44, 85),
                data.duration or 4.5
            )
        end
        focusCameraOnAvatar(data.targetModel, data.duration or (isPanda and 10.0 or 4.5))

    elseif action == "ShowBannerAlert" and data then
        if data.alertType == "spawn" then
            if data.targetModel then
                followAvatar(data.targetModel)
            end
            local prefix = data.justFollowed and "🎉 Thanks for following! " or "Thankyou"
            showBanner(
                string.format("%s@%s spawned Roblox avatar: %s", prefix, data.tiktokUniqueId, data.robloxUsername),
                Color3.fromRGB(37, 244, 238),
                3.5
            )
        elseif data.alertType == "panda_gift" then
            showBanner(
                string.format("🐼 @%s sent Panda! 💥 GIANT TITAN AVATAR (30s)!", data.tiktokUniqueId),
                Color3.fromRGB(16, 185, 129),
                6.0
            )
        elseif data.alertType == "not_following" then
            showBanner(
                string.format("⚠️ @%s — Follow the TikTok account first to spawn %s!", data.tiktokUniqueId, data.robloxUsername),
                Color3.fromRGB(245, 158, 11),
                4.0
            )
        elseif data.alertType == "new_follower" then
            showBanner(
                string.format("➕ @%s just followed! Type your Roblox username in chat!", data.tiktokUniqueId),
                Color3.fromRGB(16, 185, 129),
                3.0
            )
        elseif data.alertType == "rose" then
            showBanner(
                string.format("🌹 @%s sent a %s!", data.tiktokUniqueId, data.giftName or "Rose"),
                Color3.fromRGB(254, 44, 85),
                4.0
            )
        elseif data.alertType == "member_join" then
            showBanner(
                string.format("👋 @%s joined the stream! 🎆", data.tiktokUniqueId),
                Color3.fromRGB(255, 120, 200),
                3.0
            )
        elseif data.alertType == "witch_hat_dragon" then
            showBanner(
                string.format("🧙‍♂️ @%s sent Topi Penyihir! 🐉 3 Dragons Summoned!", data.tiktokUniqueId),
                Color3.fromRGB(180, 70, 255),
                5.0
            )
        elseif data.alertType == "finger_heart_dolphin" then
            showBanner(
                string.format("🐬 @%s sent Finger Heart! 🌊 5 Dolphins Leaping!", data.tiktokUniqueId),
                Color3.fromRGB(6, 182, 212),
                5.0
            )
        end
    end
end)

