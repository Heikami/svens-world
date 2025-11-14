-- CoinSpawner.lua - OPTIMIZED WITH FLOOR BOUNDS (Production Version)
-- Centralized coin spawning module - coins spawn within floor boundaries

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CoinSpawner = {}

local coinPrefab = nil
local TIER_COIN_COUNTS = {
	Rainbow = 16,
	Radioactive = 12,
	Burning = 10,
	Diamond = 8,
	Gold = 4,
	Silver = 2,
	Standard = 1,
}

local SPAWN_RADIUS = 1
local ARC_HEIGHT = 10
local pi2 = math.pi * 2

--------------------------------------------------------------------------------
-- HELPER: Get Floor Bounds from position
--------------------------------------------------------------------------------

local function getFloorBoundsFromPosition(barrelPos)
	-- Search for a room with a Bounds part near the barrel position
	local bestBounds = nil
	local bestDistance = math.huge

	for _, room in ipairs(workspace:GetChildren()) do
		if room:IsA("Folder") or room:IsA("Model") then
			local bounds = room:FindFirstChild("Bounds")
			if bounds and bounds:IsA("BasePart") then
				-- Check if barrel is near this bounds (within reasonable distance)
				local dist = (barrelPos - bounds.Position).Magnitude
				if dist < bestDistance then
					bestDistance = dist
					bestBounds = bounds
				end
			end
		end
	end

	if not bestBounds or bestDistance > 500 then
		return nil
	end

	local boundsSize = bestBounds.Size
	local boundsPos = bestBounds.Position

	return {
		minX = boundsPos.X - (boundsSize.X / 2),
		maxX = boundsPos.X + (boundsSize.X / 2),
		minZ = boundsPos.Z - (boundsSize.Z / 2),
		maxZ = boundsPos.Z + (boundsSize.Z / 2),
	}
end

--------------------------------------------------------------------------------
-- HELPER: Clamp Position to Floor Bounds
--------------------------------------------------------------------------------

local function clampToFloorBounds(position, floorBounds)
	if not floorBounds then
		return position
	end

	local margin = 0.5
	local clampedX = math.max(floorBounds.minX + margin, math.min(position.X, floorBounds.maxX - margin))
	local clampedZ = math.max(floorBounds.minZ + margin, math.min(position.Z, floorBounds.maxZ - margin))

	return Vector3.new(clampedX, position.Y, clampedZ)
end

--------------------------------------------------------------------------------
-- HELPER: Quadratic Bezier
--------------------------------------------------------------------------------

local function quadraticBezier(p0, p1, p2, t)
	local mt = 1 - t
	local mt2 = mt * mt
	local t2 = t * t
	return p0 * mt2 + p1 * (2 * mt * t) + p2 * t2
end

--------------------------------------------------------------------------------
-- HELPER: Find Closest Orientation
--------------------------------------------------------------------------------

local function findClosestOrientation(currentCFrame)
	local x, y, z = currentCFrame:ToEulerAnglesXYZ()
	local currentAngles = Vector3.new(math.deg(x), math.deg(y), math.deg(z))

	local function normalizeAngle(angle)
		angle = angle % 360
		if angle < 0 then angle = angle + 360 end
		return angle
	end

	currentAngles = Vector3.new(
		normalizeAngle(currentAngles.X),
		normalizeAngle(currentAngles.Y),
		normalizeAngle(currentAngles.Z)
	)

	local targetOrientations = {
		Vector3.new(90, 0, 0),
		Vector3.new(90, 0, 180),
		Vector3.new(90, 180, 0),
		Vector3.new(90, 180, 180),
	}

	local closestTarget = targetOrientations[1]
	local closestDistance = math.huge

	for _, target in ipairs(targetOrientations) do
		local dx = math.min(math.abs(currentAngles.X - target.X), 360 - math.abs(currentAngles.X - target.X))
		local dy = math.min(math.abs(currentAngles.Y - target.Y), 360 - math.abs(currentAngles.Y - target.Y))
		local dz = math.min(math.abs(currentAngles.Z - target.Z), 360 - math.abs(currentAngles.Z - target.Z))

		local distance = dx + dy + dz

		if distance < closestDistance then
			closestDistance = distance
			closestTarget = target
		end
	end

	return closestTarget
end

--------------------------------------------------------------------------------
-- HELPER: Check if coin can sink
--------------------------------------------------------------------------------

local function checkCanSink(coin, position)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {coin}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local rayResult = workspace:Raycast(position, Vector3.new(0, -0.5, 0), raycastParams)

	if not rayResult then
		return true
	end

	local hitPart = rayResult.Instance
	if hitPart and (hitPart.Name == "Floor" or hitPart.Parent.Name == "Decor") then
		return true
	end

	return false
end

--------------------------------------------------------------------------------
-- MAIN: Spawn Single Coin
--------------------------------------------------------------------------------

function CoinSpawner.spawnCoin(barrelPos, floorY, attackSourcePos)
	task.spawn(function()
		local coinPrefabLive = workspace:FindFirstChild("Prefabs") and workspace.Prefabs:FindFirstChild("Coin")

		if not coinPrefabLive then
			warn("❌ Coin prefab not found")
			return
		end

		local coin = coinPrefabLive:Clone()

		if not coin then
			warn("❌ Failed to clone coin")
			return
		end

		local cashModels = workspace:FindFirstChild("_CashModels")
		if not cashModels then
			cashModels = Instance.new("Folder")
			cashModels.Name = "_CashModels"
			cashModels.Parent = workspace
		end
		coin.Parent = cashModels

		local basePart = coin:FindFirstChild("Base")

		if not basePart then
			warn("❌ Base part not found in coin")
			coin:Destroy()
			return
		end

		local neonPart = basePart:FindFirstChild("Neon")
		local toucher = basePart:FindFirstChild("Toucher")

		if not neonPart or not toucher then
			warn("❌ Neon or Toucher part missing")
			coin:Destroy()
			return
		end

		for _, coinPart in ipairs(coin:GetDescendants()) do
			if coinPart:IsA("BasePart") then
				coinPart.Anchored = true
				coinPart.CanCollide = false
			end
		end

		-- ⭐ GET FLOOR BOUNDS using barrel position
		local floorBounds = getFloorBoundsFromPosition(barrelPos)

		local angle = math.random() * pi2
		local cosAngle = math.cos(angle)
		local sinAngle = math.sin(angle)
		local spawnDir = Vector3.new(cosAngle, 0, sinAngle)

		local randomArcHeight = ARC_HEIGHT + math.random(-5, 8)
		local randomSpawnRadius = SPAWN_RADIUS + math.random(-1, 2) / 2
		local randomLandRadius = SPAWN_RADIUS + 10 + math.random(-5, 5)

		local spawnPos = barrelPos + spawnDir * randomSpawnRadius + Vector3.new(0, 1, 0)
		local peakPos = barrelPos + spawnDir * (SPAWN_RADIUS + 4.5) + Vector3.new(0, randomArcHeight, 0)

		-- ⭐ ORIGINAL HEIGHT CALCULATION, THEN CLAMP X AND Z TO FLOOR BOUNDS
		local landPos = Vector3.new(
			barrelPos.X + spawnDir.X * randomLandRadius,
			floorY,
			barrelPos.Z + spawnDir.Z * randomLandRadius
		)
		landPos = clampToFloorBounds(landPos, floorBounds)

		basePart.Position = spawnPos

		local function getExcludedRandom(negLow, negHigh, posLow, posHigh)
			if math.random(1, 2) == 1 then
				return math.random(negLow, negHigh)
			else
				return math.random(posLow, posHigh)
			end
		end
		local spinSpeed = getExcludedRandom(-30, -15, 15, 30)

		basePart.CFrame = basePart.CFrame * CFrame.Angles(
			math.rad(spinSpeed * 0.5),
			math.rad(spinSpeed * 0.75),
			math.rad(spinSpeed * 0.4)
		)

		neonPart.Position = basePart.Position
		neonPart.CFrame = basePart.CFrame

		local touched = false
		local canBeCollected = false
		local canMagnetize = false
		local magnetActive = false
		local phase = "arc"

		local arcElapsed = 0
		local fallElapsed = 0
		local fallStartPos = nil
		local spinStartTime = tick()
		local magnetElapsed = 0
		local magnetStartPos = nil
		local spinCompletedAt = nil
		local finalOrientationElapsed = 0
		local targetFinalOrientation = nil
		local sinkStartPos = nil
		local sinkElapsed = 0
		local finalRestPosition = nil

		local head = nil
		local updateConnection = nil
		local magnetConnection = nil
		local touchConnection = nil

		local arcMidpoint = (spawnPos + peakPos) / 2
		local arcControlPoint = arcMidpoint + Vector3.new(0, 8, 0)
		local yAxis05 = Vector3.new(0, 0.5, 0)
		local y025 = Vector3.new(0, 0.25, 0)
		local landPosOffset = landPos + yAxis05

		updateConnection = RunService.Heartbeat:Connect(function()
			if not coin or not coin.Parent or touched then
				if updateConnection then
					updateConnection:Disconnect()
					updateConnection = nil
				end
				return
			end

			local elapsedTime = tick() - spinStartTime
			local spinProgress = math.min(elapsedTime * 0.25, 1)
			local currentSpinSpeed = spinSpeed * (1 - spinProgress)

			if spinProgress < 1 and currentSpinSpeed > 0.1 then
				basePart.CFrame = basePart.CFrame * CFrame.Angles(
					math.rad(currentSpinSpeed),
					math.rad(currentSpinSpeed * 1.5),
					math.rad(currentSpinSpeed * 0.8)
				)
			elseif spinProgress >= 1 and not spinCompletedAt then
				spinCompletedAt = tick()
				local closestAngle = findClosestOrientation(basePart.CFrame)
				targetFinalOrientation = CFrame.new(basePart.Position) * CFrame.Angles(
					math.rad(closestAngle.X),
					math.rad(closestAngle.Y),
					math.rad(closestAngle.Z)
				)
			end

			if spinCompletedAt then
				finalOrientationElapsed = tick() - spinCompletedAt
				local orientationProgress = math.min(finalOrientationElapsed * 2, 1)

				basePart.CFrame = basePart.CFrame:lerp(targetFinalOrientation, orientationProgress)

				if orientationProgress >= 1 then
					basePart.CFrame = targetFinalOrientation
				end
			end

			if phase == "arc" then
				arcElapsed = arcElapsed + (1/60)
				local t = math.min(arcElapsed * 1.667, 1)
				basePart.Position = quadraticBezier(spawnPos, arcControlPoint, peakPos, t)

				if t >= 1 then
					phase = "fall"
					fallStartPos = basePart.Position
					fallElapsed = 0
					task.wait(0.05)
				end

			elseif phase == "fall" then
				fallElapsed = fallElapsed + (1/60)
				local t = math.min(fallElapsed * 2, 1)

				local fallMidpoint = (fallStartPos + landPosOffset) / 2
				local fallControlPoint = fallMidpoint + Vector3.new(0, 3, 0)

				basePart.Position = quadraticBezier(fallStartPos, fallControlPoint, landPosOffset, t)

				if t >= 1 then
					phase = "landed"
					basePart.Position = landPosOffset
					basePart.CFrame = CFrame.new(basePart.Position) * CFrame.Angles(math.rad(90), 0, 0)
				end

			elseif phase == "landed" then
				if not sinkStartPos then
					sinkStartPos = basePart.Position

					if checkCanSink(coin, basePart.Position) then
						phase = "sink"
						sinkElapsed = 0
					else
						finalRestPosition = basePart.Position
						phase = "idle"
					end
				end

			elseif phase == "sink" then
				if not checkCanSink(coin, basePart.Position) then
					finalRestPosition = basePart.Position
					phase = "idle"
				else
					sinkElapsed = sinkElapsed + (1/60)
					local t = math.min(sinkElapsed * 3.33, 1)
					local sinkEndPos = sinkStartPos - y025
					basePart.Position = sinkStartPos:Lerp(sinkEndPos, t * t)

					if t >= 1 then
						basePart.Position = sinkEndPos
						finalRestPosition = sinkEndPos
						phase = "idle"
					end
				end

			elseif phase == "idle" then
				if finalRestPosition then
					basePart.Position = finalRestPosition
				end

			elseif phase == "magnet" and magnetActive and head and head.Parent then
				magnetElapsed = magnetElapsed + (1/60)
				local t = math.min(magnetElapsed * 2, 1)
				local magnetEndPos = head.Position

				local magnetMidpoint = (magnetStartPos + magnetEndPos) / 2
				local magnetControlPoint = magnetMidpoint + Vector3.new(0, 2, 0)

				basePart.Position = quadraticBezier(magnetStartPos, magnetControlPoint, magnetEndPos, t)
				neonPart.Position = basePart.Position

				if t >= 1 then
					basePart.Position = magnetEndPos
					if canBeCollected then
						touched = true
						coin:Destroy()
					end
					if updateConnection then
						updateConnection:Disconnect()
						updateConnection = nil
					end
				end
			end

			toucher.Position = basePart.Position

			if spinProgress < 1 or phase == "arc" or phase == "fall" or phase == "magnet" or phase == "idle" or (spinCompletedAt and finalOrientationElapsed < 0.5) or (phase == "sink" and sinkElapsed < 0.3) then
				neonPart.CFrame = basePart.CFrame
				if phase == "idle" and finalRestPosition then
					neonPart.Position = finalRestPosition
				end
			end
		end)

		task.delay(1, function()
			canBeCollected = true
		end)

		task.delay(1.5, function()
			canMagnetize = true
		end)

		if toucher then
			magnetConnection = toucher.Touched:Connect(function(hit)
				if touched or magnetActive or not canMagnetize then
					return
				end

				local plyr = Players:GetPlayerFromCharacter(hit.Parent)
				if not plyr then return end

				local character = plyr.Character
				if not character then return end

				head = character:FindFirstChild("Head")
				if not head then return end

				magnetActive = true
				phase = "magnet"
				magnetStartPos = basePart.Position
				magnetElapsed = 0

				if magnetConnection then
					magnetConnection:Disconnect()
					magnetConnection = nil
				end
			end)
		end

		touchConnection = basePart.Touched:Connect(function(hit)
			if touched or not canBeCollected then return end

			local plyr = Players:GetPlayerFromCharacter(hit.Parent)
			if not plyr then return end

			touched = true
			basePart.CanTouch = false

			if touchConnection then
				touchConnection:Disconnect()
				touchConnection = nil
			end
			if magnetConnection then
				magnetConnection:Disconnect()
				magnetConnection = nil
			end
			if updateConnection then
				updateConnection:Disconnect()
				updateConnection = nil
			end

			local headLocal = hit.Parent:FindFirstChild("Head")
			if not headLocal then
				coin:Destroy()
				return
			end

			local pullStartPos = basePart.Position
			local pullControlPos = pullStartPos + (headLocal.Position - pullStartPos) * 0.5
			local pullElapsed = 0

			local pullConnection
			pullConnection = RunService.Heartbeat:Connect(function()
				if not coin or not coin.Parent then
					if pullConnection then pullConnection:Disconnect() end
					return
				end

				pullElapsed = pullElapsed + (1/60)
				local t = math.min(pullElapsed * 3.33, 1)
				local newPos = pullStartPos * (1-t)^2 + pullControlPos * 2*(1-t)*t + headLocal.Position * t^2
				coin:PivotTo(CFrame.new(newPos) * coin:GetPivot().Rotation)

				if t >= 1 then
					coin:Destroy()
					if pullConnection then pullConnection:Disconnect() end
				end
			end)
		end)

		task.delay(60, function()
			if coin and coin.Parent then
				coin:Destroy()
			end
			if updateConnection then
				updateConnection:Disconnect()
			end
			if magnetConnection then
				magnetConnection:Disconnect()
			end
			if touchConnection then
				touchConnection:Disconnect()
			end
		end)
	end)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function CoinSpawner.spawnCoinsInBurst(barrelPos, floorY, count, attackSourcePos)
	for i = 1, count do
		CoinSpawner.spawnCoin(barrelPos, floorY, attackSourcePos)
		task.wait(0.1)
	end
end

function CoinSpawner.spawnCoinsByTier(barrelPos, floorY, tierName, attackSourcePos)
	local count = TIER_COIN_COUNTS[tierName] or TIER_COIN_COUNTS.Standard
	CoinSpawner.spawnCoinsInBurst(barrelPos, floorY, count, attackSourcePos)
end

function CoinSpawner.Initialize()
	local prefabsFolder = workspace:FindFirstChild("Prefabs")

	if not prefabsFolder then
		warn("⚠️ Prefabs folder not found in workspace")
		return
	end

	coinPrefab = prefabsFolder:FindFirstChild("Coin")

	if not coinPrefab then
		warn("⚠️ Coin prefab not found at Workspace.Prefabs.Coin")
		return
	end
end

return CoinSpawner
