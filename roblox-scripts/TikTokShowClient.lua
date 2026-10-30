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
-- Camera Configuration (Continuous Avatar Follow + 3-Scene Broadcast Director)
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
local DRONE_RADIUS_X = 48.0
local DRONE_RADIUS_Z = 48.0
local DRONE_SPEED = 0.18

-- Scene 3: Pull-In Coordinates requested by user
local PULLIN_START = Vector3.new(50, 63.403, -10.701)
local PULLIN_END = Vector3.new(50, 63.403, -69.701)

-- Scene Durations (Total cycle: 27 seconds)
local SCENE_1_DURATION = 10.0   -- 10s Drone View
local SCENE_2_DURATION = 9.0    -- 9s Paparazzi Handheld
local SCENE_3_DURATION = 8.0    -- 8s Cinematic Pull-In
local TOTAL_CYCLE_DURATION = SCENE_1_DURATION + SCENE_2_DURATION + SCENE_3_DURATION

-- Camera State Variables
local paparazziTargetAvatar = nil
local paparazziAngle = 0
local paparazziDist = 25.0
local smoothedPaparazziPos = nil

local manualCameraScene = "auto" -- "auto", "drone", "paparazzi", "pullin"
local lastCameraMode = nil
local lastPullinElapsed = 0

local currentTrackedAvatar = nil
local smoothedTrackedPos = nil
local isRoseVIPMode = false
local roseVIPStartTime = 0
local povToken = 0
local cameraInitialized = false

-- Stage Posing state (with automatic safety timeout so it can never get stuck)
local isAvatarPosingOnStage = false
local stagePoseStartTime = 0
local stagePoseFinishTime = 0
local MAX_STAGE_POSE_DURATION = 5.5
local POST_STAGE_FOLLOW_DURATION = 3.2

-- Frame-rate independent exponential smoothing factor
local function expAlpha(speed, dt)
    return 1 - math.exp(-speed * math.clamp(dt, 0.001, 0.1))
end

-- Smoothly filter an avatar's world position (dampens vertical jumps/steps to prevent camera shake)
local function getSmoothedAvatarPosition(prevPos, rawPos, dt)
    if not prevPos or (rawPos - prevPos).Magnitude > 35 then
        return rawPos
    end
    local alphaXZ = expAlpha(10.0, dt)
    local alphaY = expAlpha(5.0, dt)
    return Vector3.new(
        prevPos.X + (rawPos.X - prevPos.X) * alphaXZ,
        prevPos.Y + (rawPos.Y - prevPos.Y) * alphaY,
        prevPos.Z + (rawPos.Z - prevPos.Z) * alphaXZ
    )
end

local function pickRandomAvatarForPaparazzi()
    local folder = workspace:FindFirstChild("SpawnedTikTokAvatars")
    if folder then
        local valid = {}
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("Model") and (child:FindFirstChild("HumanoidRootPart") or child.PrimaryPart) then
                table.insert(valid, child)
            end
        end
        if #valid > 0 then
            return valid[math.random(1, #valid)]
        end
    end
    return nil
end

local function findFallbackAvatar()
    local folder = workspace:FindFirstChild("SpawnedTikTokAvatars")
    if folder then
        local children = folder:GetChildren()
        for i = #children, 1, -1 do
            local child = children[i]
            if child:IsA("Model") and (child:FindFirstChild("HumanoidRootPart") or child.PrimaryPart) then
                return child
            end
        end
    end
    return nil
end

-- Keep close-up / stage / paparazzi cameras inside the clear central arena corridor
-- (Pillars are at X=34.6 and X=65.4, so X in [38.8, 61.2] is 100% open & unobstructed with zero raycast jumps!)
local function getClearCameraPosition(_lookAtPos, desiredCamPos)
    local clampedX = math.clamp(desiredCamPos.X, 38.8, 61.2)
    return Vector3.new(clampedX, desiredCamPos.Y, desiredCamPos.Z)
end

-- Use BindToRenderStep at RenderPriority.Camera + 10 so Roblox's default character camera NEVER overrides it!
RunService:BindToRenderStep("TikTokShowCamera", Enum.RenderPriority.Camera.Value + 10, function(dt)
    local camera = workspace.CurrentCamera
    if not camera then return end

    if camera.CameraType ~= Enum.CameraType.Scriptable then
        camera.CameraType = Enum.CameraType.Scriptable
    end

    if not cameraInitialized then
        cameraInitialized = true
        camera.CFrame = MAIN_CAMERA_CFRAME
        camera.FieldOfView = 68
    end

    -- Auto-expire stage posing if it ever exceeds MAX_STAGE_POSE_DURATION
    if isAvatarPosingOnStage and (os.clock() - stagePoseStartTime) > MAX_STAGE_POSE_DURATION then
        isAvatarPosingOnStage = false
        stagePoseFinishTime = os.clock()
    end

    -- Ensure we have a valid spawned TikTok avatar to follow
    if not currentTrackedAvatar or not currentTrackedAvatar.Parent then
        currentTrackedAvatar = findFallbackAvatar()
    end

    -- ========================================================================
    -- PRIORITY 1: ROSE VIP / PANDA GIANT TITAN SPOTLIGHT POV
    -- Uses stable world-space front orbit (+Z) so character turning/dancing never whips camera!
    -- ========================================================================
    if isRoseVIPMode and currentTrackedAvatar and currentTrackedAvatar.Parent then
        local hrp = currentTrackedAvatar:FindFirstChild("HumanoidRootPart") or currentTrackedAvatar.PrimaryPart
        if hrp then
            local currentScale = 1.0
            pcall(function()
                currentScale = currentTrackedAvatar:GetScale()
            end)
            local scaleMultiplier = math.clamp(currentScale, 1.0, 3.5)
            local heightOffset = 1.8 * (1 + (scaleMultiplier - 1) * 0.6)
            local distOffset = 11.5 * (1 + (scaleMultiplier - 1) * 0.72)

            smoothedTrackedPos = getSmoothedAvatarPosition(smoothedTrackedPos, hrp.Position, dt)
            local targetLookAt = smoothedTrackedPos + Vector3.new(0, heightOffset, 0)

            local elapsed = os.clock() - roseVIPStartTime
            local orbitAngle = math.sin(elapsed * 1.25) * 0.48
            -- World-space front direction (+Z side looking toward -Z), immune to HRP spinning!
            local orbitVec = Vector3.new(math.sin(orbitAngle), 0, math.cos(orbitAngle))
            local rawCamPos = targetLookAt + (orbitVec * distOffset) + Vector3.new(0, 2.5 * (1 + (scaleMultiplier - 1) * 0.5), 0)
            local safeCamPos = getClearCameraPosition(targetLookAt, rawCamPos)
            local desiredCFrame = CFrame.lookAt(safeCamPos, targetLookAt)

            if lastCameraMode ~= "vip" then
                lastCameraMode = "vip"
                camera.CFrame = desiredCFrame
                camera.FieldOfView = 60
            else
                local alpha = expAlpha(8.0, dt)
                camera.CFrame = camera.CFrame:Lerp(desiredCFrame, alpha)
                camera.FieldOfView = camera.FieldOfView + (60 - camera.FieldOfView) * alpha
            end
            return
        end
    end

    -- ========================================================================
    -- PRIORITY 2: STAGE POSING & WALK-TO-CROWD FOLLOW
    -- Uses stable world-space front angle (+Z) so walking to crowd (-Z) never whips 180 degrees!
    -- ========================================================================
    local timeSincePosingFinished = (stagePoseFinishTime > 0) and (os.clock() - stagePoseFinishTime) or 999
    local shouldFollowStageAvatar = isAvatarPosingOnStage or (timeSincePosingFinished < POST_STAGE_FOLLOW_DURATION)

    if shouldFollowStageAvatar and currentTrackedAvatar and currentTrackedAvatar.Parent then
        local hrp = currentTrackedAvatar:FindFirstChild("HumanoidRootPart") or currentTrackedAvatar.PrimaryPart
        if hrp then
            smoothedTrackedPos = getSmoothedAvatarPosition(smoothedTrackedPos, hrp.Position, dt)
            local targetLookAt = smoothedTrackedPos + Vector3.new(0, 2.0, 0)

            local swayX = math.sin(os.clock() * 0.8) * 2.2
            local rawCamPos = targetLookAt + Vector3.new(swayX, 4.2, 15.5)
            local safeCamPos = getClearCameraPosition(targetLookAt, rawCamPos)
            local desiredCFrame = CFrame.lookAt(safeCamPos, targetLookAt)

            if lastCameraMode ~= "stage" then
                lastCameraMode = "stage"
                camera.CFrame = desiredCFrame
                camera.FieldOfView = 66
            else
                local alpha = expAlpha(7.5, dt)
                camera.CFrame = camera.CFrame:Lerp(desiredCFrame, alpha)
                camera.FieldOfView = camera.FieldOfView + (66 - camera.FieldOfView) * alpha
            end
            return
        end
    end

    -- ========================================================================
    -- PRIORITY 3: 3-SCENE CINEMATIC BROADCAST DIRECTOR
    -- Scene 1: Drone View (10s)
    -- Scene 2: Paparazzi Cam (9s)
    -- Scene 3: Pull-In Shot (8s)
    -- Performs clean broadcast cuts between scenes so camera never flies through walls!
    -- ========================================================================
    local cycleTime = os.clock() % TOTAL_CYCLE_DURATION
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

    local sceneModeName = "scene_" .. tostring(activeScene)
    local isNewSceneCut = (lastCameraMode ~= sceneModeName)

    if activeScene == 1 then
        -- --------------------------------------------------------------------
        -- SCENE 1: DRONE VIEW (Sweeping Arena Surveillance)
        -- --------------------------------------------------------------------
        local t = os.clock() * DRONE_SPEED
        local droneX = DRONE_CENTER.X + math.cos(t) * DRONE_RADIUS_X
        local droneZ = DRONE_CENTER.Z + math.sin(t) * DRONE_RADIUS_Z
        local droneY = DRONE_CENTER.Y + 14.0 + (math.sin(t * 1.6) * 3.0)

        local lookTarget = DRONE_CENTER + Vector3.new(
            math.cos(t + 0.4) * 6,
            -3.0,
            math.sin(t + 0.4) * 6
        )

        local targetCFrame = CFrame.lookAt(Vector3.new(droneX, droneY, droneZ), lookTarget)
        local targetFOV = 70

        if isNewSceneCut then
            camera.CFrame = targetCFrame
            camera.FieldOfView = targetFOV
        else
            local alpha = expAlpha(5.0, dt)
            camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
            camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * alpha
        end

    elseif activeScene == 2 then
        -- --------------------------------------------------------------------
        -- SCENE 2: PAPARAZZI CAM (Telephoto handheld spotter from clear front cone)
        -- --------------------------------------------------------------------
        if isNewSceneCut or not paparazziTargetAvatar or not paparazziTargetAvatar.Parent then
            paparazziTargetAvatar = pickRandomAvatarForPaparazzi()
            -- Keep angle in the clear front viewing cone (-38 deg to +38 deg around +Z)
            -- so Bounce House walls/pillars never block the shot!
            paparazziAngle = (math.random() - 0.5) * 1.35
            paparazziDist = math.random(22, 28)
            smoothedPaparazziPos = nil
        end

        local hrp = nil
        if paparazziTargetAvatar and paparazziTargetAvatar.Parent then
            hrp = paparazziTargetAvatar:FindFirstChild("HumanoidRootPart") or paparazziTargetAvatar.PrimaryPart
        end

        local rawTargetPos = STAGE_POSITION + Vector3.new(0, 3.2, 0)
        if hrp then
            rawTargetPos = hrp.Position + Vector3.new(0, 2.0, 0)
        end

        smoothedPaparazziPos = getSmoothedAvatarPosition(smoothedPaparazziPos, rawTargetPos, dt)

        -- Position camera in the clear front cone (+Z side looking toward avatar)
        local desiredCamPos = smoothedPaparazziPos + Vector3.new(
            math.sin(paparazziAngle) * paparazziDist,
            4.2,
            math.cos(paparazziAngle) * paparazziDist
        )
        local safeCamPos = getClearCameraPosition(smoothedPaparazziPos, desiredCamPos)

        -- Organic handheld operator breathing & subtle telephoto sway
        local now = os.clock()
        local swayX = (math.sin(now * 1.25) * 0.22) + (math.noise(now * 1.4, 15.2, 0) * 0.25)
        local swayY = (math.cos(now * 0.95) * 0.16) + (math.noise(now * 1.6, 37.8, 0) * 0.18)
        local swayRoll = math.noise(now * 0.9, 61.4, 0) * math.rad(0.9)

        local handCamPos = safeCamPos + Vector3.new(swayX * 0.3, swayY * 0.25, 0)
        local handLookPos = smoothedPaparazziPos + Vector3.new(swayX * 0.55, swayY * 0.45, 0)

        local targetCFrame = CFrame.lookAt(handCamPos, handLookPos) * CFrame.Angles(0, 0, swayRoll)
        local targetFOV = 45

        if isNewSceneCut then
            camera.CFrame = targetCFrame
            camera.FieldOfView = targetFOV
        else
            local alpha = expAlpha(10.0, dt)
            camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
            camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * alpha
        end

    else
        -- --------------------------------------------------------------------
        -- SCENE 3: CINEMATIC PULL-IN
        -- Pull in from (50, 63.403, -10.701) to (50, 63.403, -69.701)
        -- --------------------------------------------------------------------
        local isLoopRestart = (pullinElapsed < lastPullinElapsed - 1.0)
        lastPullinElapsed = pullinElapsed

        local progress = math.clamp(pullinElapsed / SCENE_3_DURATION, 0, 1)
        -- Smoothstep cubic easing for cinematic dolly acceleration & deceleration
        local smoothT = progress * progress * (3 - 2 * progress)
        local currentCamPos = PULLIN_START:Lerp(PULLIN_END, smoothT)

        -- Look straight forward down the arena centerline toward the stage & crowd
        local lookTarget = Vector3.new(50, 60.5, -95.0)
        local targetCFrame = CFrame.lookAt(currentCamPos, lookTarget)
        local targetFOV = 70 - (smoothT * 8.0)

        if isNewSceneCut or isLoopRestart then
            camera.CFrame = targetCFrame
            camera.FieldOfView = targetFOV
        else
            local alpha = expAlpha(12.0, dt)
            camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
            camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * alpha
        end
    end

    lastCameraMode = sceneModeName
end)

-- ============================================================================
-- Auto-Build Stream Overlay HUD (Live Notification Banner)
-- ============================================================================
local playerGui = localPlayer:WaitForChild("PlayerGui")

local existingHud = playerGui:FindFirstChild("TikTokShowHUD")
if existingHud then
    existingHud:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TikTokShowHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Middle Alert Banner (Spawns, Not-Following Warnings, Rose VIP & Panda Titan Alerts, 9:16 Optimized)
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
-- Camera Tracking Helpers (Spawn Follow + Rose/Panda VIP Close-Up POV)
-- ============================================================================
local function followAvatar(targetModel)
    if targetModel and targetModel.Parent then
        currentTrackedAvatar = targetModel
        smoothedTrackedPos = nil
        isAvatarPosingOnStage = true
        stagePoseStartTime = os.clock()
    end
end

local function focusCameraOnAvatar(targetModel, duration)
    if targetModel and targetModel.Parent then
        currentTrackedAvatar = targetModel
        smoothedTrackedPos = nil
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
        lastCameraMode = nil -- Trigger clean cut to newly selected scene
        if manualCameraScene == "paparazzi" then
            paparazziTargetAvatar = pickRandomAvatarForPaparazzi()
            paparazziAngle = (math.random() - 0.5) * 1.35
            paparazziDist = math.random(22, 28)
            smoothedPaparazziPos = nil
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
            local prefix = data.justFollowed and "🎉 Thanks for following! " or "Thankyou "
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
