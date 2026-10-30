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

-- Drone View Area Settings (Closer to the stage & dragon orbit area)
local DRONE_CENTER = Vector3.new(50.239, 66.903, -106)    -- Center on the action area
local DRONE_RADIUS_X = 52.0                               -- Closer orbit radius (~52 studs)
local DRONE_RADIUS_Z = 55.0                               -- Closer orbit radius (~55 studs)
local DRONE_SPEED = 0.16                                  -- Dynamic sweeping speed

local currentTrackedAvatar = nil
local isRoseVIPMode = false
local roseVIPStartTime = 0
local povToken = 0
local cameraInitialized = false

-- State for Stage Posing vs Drone View:
-- When an avatar spawns, isAvatarPosingOnStage = true (camera follows avatar closely).
-- When posing finishes, stagePoseFinishTime = os.clock() and isAvatarPosingOnStage = false.
-- If 5 seconds pass after posing finishes and no new avatar has spawned on stage, switch to Drone View!
local isAvatarPosingOnStage = false
local stagePoseFinishTime = 0

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

    -- If a Rose VIP Gift is active, focus closely on that avatar
    if isRoseVIPMode and currentTrackedAvatar and currentTrackedAvatar.Parent then
        local hrp = currentTrackedAvatar:FindFirstChild("HumanoidRootPart") or currentTrackedAvatar.PrimaryPart
        if hrp then
            local targetLookAt = hrp.Position + Vector3.new(0, 1.8, 0)
            local elapsed = os.clock() - roseVIPStartTime
            local orbitAngle = math.sin(elapsed * 1.8) * 0.55
            local frontVec = (hrp.CFrame * CFrame.Angles(0, orbitAngle, 0)).LookVector
            local camPos = targetLookAt + (frontVec * 10.5) + Vector3.new(0, 2.4, 0)
            local desiredCFrame = CFrame.lookAt(camPos, targetLookAt)
            local alpha = math.clamp(dt * 8.0, 0, 1)
            camera.CFrame = camera.CFrame:Lerp(desiredCFrame, alpha)
            camera.FieldOfView = camera.FieldOfView + (62 - camera.FieldOfView) * alpha
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

    -- 5 SECONDS HAVE PASSED SINCE POSING FINISHED (or initial state with no avatar):
    -- Switch to Drone View viewing the surrounding area closely!
    local t = os.clock() * DRONE_SPEED
    local droneX = DRONE_CENTER.X + math.cos(t) * DRONE_RADIUS_X
    local droneZ = DRONE_CENTER.Z + math.sin(t) * DRONE_RADIUS_Z
    local droneY = DRONE_CENTER.Y + 12.0 + (math.sin(t * 1.8) * 3.5)

    -- Look slightly ahead towards the center of the orbit
    local lookTarget = DRONE_CENTER + Vector3.new(
        math.cos(t + 0.4) * 8,
        -2.0,
        math.sin(t + 0.4) * 8
    )

    local droneCFrame = CFrame.lookAt(Vector3.new(droneX, droneY, droneZ), lookTarget)
    local alpha = math.clamp(dt * 3.8, 0, 1)
    camera.CFrame = camera.CFrame:Lerp(droneCFrame, alpha)
    camera.FieldOfView = camera.FieldOfView + (72 - camera.FieldOfView) * alpha
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

-- Bottom Alert Banner (Spawns, Not-Following Warnings, Rose VIP Alerts)
local alertBanner = Instance.new("Frame")
alertBanner.Name = "AlertBanner"
alertBanner.Size = UDim2.new(0, 600, 0, 64)
alertBanner.Position = UDim2.new(0.5, -300, 1, 90) -- Starts hidden below screen
alertBanner.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
alertBanner.BackgroundTransparency = 0.1
alertBanner.Parent = screenGui

local alertCorner = Instance.new("UICorner")
alertCorner.CornerRadius = UDim.new(0, 14)
alertCorner.Parent = alertBanner

local alertStroke = Instance.new("UIStroke")
alertStroke.Thickness = 2.5
alertStroke.Color = Color3.fromRGB(254, 44, 85)
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
alertText.Parent = alertBanner

local bannerToken = 0
local function showBanner(message, borderColor, duration)
    bannerToken += 1
    local myToken = bannerToken

    alertText.Text = message
    alertStroke.Color = borderColor or Color3.fromRGB(37, 244, 238)

    TweenService:Create(
        alertBanner,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, -300, 1, -86) }
    ):Play()

    task.delay(duration or 3.5, function()
        if bannerToken == myToken then
            TweenService:Create(
                alertBanner,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Position = UDim2.new(0.5, -300, 1, 90) }
            ):Play()
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

    elseif action == "FocusAvatarPOV" and data then
        showBanner(
            string.format("🌹 @%s sent a %s! VIP Spotlight on %s!", data.tiktokUniqueId, data.giftName or "Rose", data.robloxUsername),
            Color3.fromRGB(254, 44, 85),
            data.duration or 4.5
        )
        focusCameraOnAvatar(data.targetModel, data.duration or 4.5)

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

