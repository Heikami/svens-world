--[[
	WhackAMole Modifier Variants
	Alternative gameplay mechanics for the WhackAMole modifier

	Includes:
	1. Speedy - Props pop more frequently
	2. Teleport - Props teleport instead of animated pop
	3. Swarm - Multiple props pop simultaneously
	4. Synchronized - All props pop/hide at same time
]]

-- ============================================================================
-- VARIANT 1: SPEEDY (Props pop much more frequently)
-- ============================================================================

--[[
	WhackAMole_Speedy Modifier
	Everything happens 2x faster - chaos mode!
	Location: ReplicatedStorage.Modules.RoomManager.RoomModifiers.WhackAMole_Speedy
]]

local WhackAMoleSpeedy = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("⚡ WhackAMole_Speedy module loading...")

local PlayerInstanceManager = nil

local function loadDependencies()
	if PlayerInstanceManager then return true end

	local success, pim = pcall(function()
		return require(ReplicatedStorage.Modules.PlayerInstanceManager)
	end)

	if success and pim then
		PlayerInstanceManager = pim
		print("✅ PlayerInstanceManager loaded")
	else
		warn("❌ Failed to load PlayerInstanceManager")
		return false
	end

	return true
end

-- SPEEDY CONFIGURATION (2x faster)
local POP_CHECK_INTERVAL = 0.25
local MIN_POP_DELAY = 1.5
local MAX_POP_DELAY = 2.5
local HIDE_DURATION = 0.8
local POP_COOLDOWN = 1

local function getRandomSpawnZone(room)
	local spawnZonesFolder = room:FindFirstChild("SpawnZones")
	if not spawnZonesFolder then return nil end
	local spawnZones = spawnZonesFolder:GetChildren()
	if #spawnZones == 0 then return nil end
	return spawnZones[math.random(1, #spawnZones)]
end

local function getRandomPositionInZone(spawnZone)
	if not spawnZone then return nil end
	local halfX = spawnZone.Size.X / 2
	local halfZ = spawnZone.Size.Z / 2
	local randomX = math.random(-halfX * 100, halfX * 100) / 100
	local randomZ = math.random(-halfZ * 100, halfZ * 100) / 100
	return spawnZone.Position + spawnZone.CFrame.RightVector * randomX + spawnZone.CFrame.LookVector * randomZ
end

local function hideProp(prop)
	if not prop or not prop.Parent then return end
	prop:SetAttribute("_IsHiddenByWhackAMole", true)
	prop:SetAttribute("CanTakeDamage", false)

	local parts = {}
	for _, child in ipairs(prop:GetDescendants()) do
		if child:IsA("BasePart") then table.insert(parts, child) end
	end

	for _, part in ipairs(parts) do
		if part.Name ~= "HealthBarAnchor" then
			local originalTransparency = part.Transparency
			local originalSize = part.Size
			for i = 0, 5 do
				task.wait(0.04)
				if not prop or not prop.Parent then break end
				local progress = i / 5
				part.Transparency = originalTransparency + (1 - originalTransparency) * progress
				part.Size = originalSize * (1 - progress * 0.8)
			end
			part.Transparency = 1
			part.CanCollide = false
		end
	end

	local healthBarAnchor = prop:FindFirstChild("HealthBarAnchor")
	if healthBarAnchor then
		local billboard = healthBarAnchor:FindFirstChild("HealthBarTemplate")
		if billboard then billboard.Enabled = false end
	end
end

local function showProp(prop, newPosition)
	if not prop or not prop.Parent then return end
	if newPosition then
		prop:PivotTo(CFrame.new(newPosition) * prop:GetPivot():inverse())
	end
	prop:SetAttribute("_IsHiddenByWhackAMole", false)
	prop:SetAttribute("CanTakeDamage", true)
	prop:SetAttribute("_LastPopTime", tick())

	local parts = {}
	for _, child in ipairs(prop:GetDescendants()) do
		if child:IsA("BasePart") then table.insert(parts, child) end
	end

	for _, part in ipairs(parts) do
		if part.Name ~= "HealthBarAnchor" then
			local originalTransparency = part.Transparency or 0
			local originalSize = part.Size
			part.Transparency = 1
			part.CanCollide = true
			part.Size = originalSize * 0.2
			for i = 0, 4 do
				task.wait(0.04)
				if not prop or not prop.Parent then break end
				local progress = i / 4
				part.Transparency = 1 - progress
				part.Size = originalSize * (0.2 + progress * 0.8)
			end
			part.Transparency = originalTransparency
			part.Size = originalSize
		end
	end

	local healthBarAnchor = prop:FindFirstChild("HealthBarAnchor")
	if healthBarAnchor then
		local billboard = healthBarAnchor:FindFirstChild("HealthBarTemplate")
		if billboard then billboard.Enabled = true end
	end
end

local function getPropsInRoom(room)
	local props = {}
	local propsFolder = room:FindFirstChild("Props")
	if propsFolder then
		for _, child in ipairs(propsFolder:GetChildren()) do
			if child:IsA("Model") then
				local isTrap = child:GetAttribute("_IsTrap")
				if not isTrap then table.insert(props, child) end
			end
		end
	end
	return props
end

function WhackAMoleSpeedy.Initialize(player, room)
	print("⚡ WhackAMole_Speedy initialized - CHAOS MODE!")

	if not loadDependencies() then
		warn("❌ WhackAMole_Speedy: Failed to load dependencies")
		return nil
	end

	if not player or not room then
		warn("❌ WhackAMole_Speedy: Invalid player or room")
		return nil
	end

	local decor = room:FindFirstChild("Decor")
	if decor then
		local modifierBoard = decor:FindFirstChild("ModifierBoard")
		if modifierBoard then
			local surfaceGui = modifierBoard:FindFirstChild("SurfaceGui")
			if surfaceGui then
				local header = surfaceGui:FindFirstChild("Header")
				if header then
					local label = header:FindFirstChild("Label")
					if label then
						label.Text = "⚡ SPEEDY MOLES ⚡"
						print("✅ Updated ModifierBoard: ⚡ SPEEDY MOLES ⚡")
					end
				end
			end
		end
	end

	local effects = {
		connections = {},
		isActive = true,
		player = player,
		room = room,
		popSchedules = {},
		propsPopped = 0,
	}

	local popLoopConnection
	popLoopConnection = game:GetService("RunService").Heartbeat:Connect(function()
		if not effects.isActive then
			if popLoopConnection and popLoopConnection.Connected then popLoopConnection:Disconnect() end
			return
		end

		if not effects.player.Parent or not effects.player.Character then
			effects.isActive = false
			if popLoopConnection and popLoopConnection.Connected then popLoopConnection:Disconnect() end
			return
		end

		local currentRoom = nil
		if PlayerInstanceManager then
			local instance = PlayerInstanceManager.getPlayerInstance(effects.player)
			if instance and instance.currentRoomIndex then
				currentRoom = instance.roomsInOrder[instance.currentRoomIndex]
			end
		end

		if not currentRoom or not currentRoom.Parent then return end

		local props = getPropsInRoom(currentRoom)

		for _, prop in ipairs(props) do
			if not prop or not prop.Parent then
				effects.popSchedules[prop] = nil
			else
				local isHidden = prop:GetAttribute("_IsHiddenByWhackAMole")
				local lastPopTime = prop:GetAttribute("_LastPopTime") or 0
				local currentTime = tick()

				if not isHidden and (currentTime - lastPopTime) >= POP_COOLDOWN then
					local nextPopTime = effects.popSchedules[prop]

					if not nextPopTime then
						local popDelay = math.random(MIN_POP_DELAY * 100, MAX_POP_DELAY * 100) / 100
						effects.popSchedules[prop] = currentTime + popDelay
					elseif currentTime >= nextPopTime then
						effects.popSchedules[prop] = nil

						task.spawn(function()
							hideProp(prop)
							task.wait(HIDE_DURATION)

							if prop and prop.Parent then
								local spawnZone = getRandomSpawnZone(currentRoom)
								if spawnZone then
									local newPosition = getRandomPositionInZone(spawnZone)
									if newPosition then
										local decor = currentRoom:FindFirstChild("Decor")
										if decor then
											local floor = decor:FindFirstChild("Floor")
											if floor then
												local floorY = floor.Position.Y + floor.Size.Y / 2
												newPosition = Vector3.new(newPosition.X, floorY + 5, newPosition.Z)
											end
										end
										showProp(prop, newPosition)
										effects.propsPopped = effects.propsPopped + 1
									end
								else
									showProp(prop, nil)
								end
							end
						end)
					end
				end
			end
		end
	end)

	table.insert(effects.connections, popLoopConnection)
	print("✅ WhackAMole_Speedy started! MOLES ARE MOVING FAST!")

	return effects
end

function WhackAMoleSpeedy.Cleanup(player, room, effects)
	print("⚡ WhackAMole_Speedy ending")

	if effects then
		effects.isActive = false
		print(string.format("   Total pops: %d", effects.propsPopped or 0))

		if room then
			local props = getPropsInRoom(room)
			for _, prop in ipairs(props) do
				if prop and prop.Parent then
					local isHidden = prop:GetAttribute("_IsHiddenByWhackAMole")
					if isHidden then showProp(prop, nil) end
				end
			end
		end
	end

	if effects and effects.connections then
		for _, connection in ipairs(effects.connections) do
			if connection and connection.Connected then connection:Disconnect() end
		end
	end

	print("✅ WhackAMole_Speedy cleanup complete")
end

print("✅ WhackAMole_Speedy module loaded\n")

-- ============================================================================
-- VARIANT 2: SYNCHRONIZED (All props pop at the same time)
-- ============================================================================

--[[
	WhackAMole_Synchronized Modifier
	All props pop/hide simultaneously - coordinated chaos!
	Location: ReplicatedStorage.Modules.RoomManager.RoomModifiers.WhackAMole_Synchronized
]]

local WhackAMoleSynchronized = {}

print("🎭 WhackAMole_Synchronized module loading...")

local PlayerInstanceManager2 = nil

local function loadDependencies2()
	if PlayerInstanceManager2 then return true end
	local success, pim = pcall(function()
		return require(ReplicatedStorage.Modules.PlayerInstanceManager)
	end)
	if success and pim then
		PlayerInstanceManager2 = pim
		print("✅ PlayerInstanceManager loaded")
	else
		warn("❌ Failed to load PlayerInstanceManager")
		return false
	end
	return true
end

-- SYNCHRONIZED CONFIGURATION
local SYNC_POP_INTERVAL = 3.5

local function getPropsInRoom2(room)
	local props = {}
	local propsFolder = room:FindFirstChild("Props")
	if propsFolder then
		for _, child in ipairs(propsFolder:GetChildren()) do
			if child:IsA("Model") then
				local isTrap = child:GetAttribute("_IsTrap")
				if not isTrap then table.insert(props, child) end
			end
		end
	end
	return props
end

local function getRandomSpawnZone2(room)
	local spawnZonesFolder = room:FindFirstChild("SpawnZones")
	if not spawnZonesFolder then return nil end
	local spawnZones = spawnZonesFolder:GetChildren()
	if #spawnZones == 0 then return nil end
	return spawnZones[math.random(1, #spawnZones)]
end

local function getRandomPositionInZone2(spawnZone)
	if not spawnZone then return nil end
	local halfX = spawnZone.Size.X / 2
	local halfZ = spawnZone.Size.Z / 2
	local randomX = math.random(-halfX * 100, halfX * 100) / 100
	local randomZ = math.random(-halfZ * 100, halfZ * 100) / 100
	return spawnZone.Position + spawnZone.CFrame.RightVector * randomX + spawnZone.CFrame.LookVector * randomZ
end

local function hidePropSync(prop)
	if not prop or not prop.Parent then return end
	prop:SetAttribute("_IsHiddenByWhackAMole", true)
	prop:SetAttribute("CanTakeDamage", false)

	local parts = {}
	for _, child in ipairs(prop:GetDescendants()) do
		if child:IsA("BasePart") then table.insert(parts, child) end
	end

	task.spawn(function()
		for _, part in ipairs(parts) do
			if part.Name ~= "HealthBarAnchor" then
				local originalTransparency = part.Transparency
				local originalSize = part.Size
				for i = 0, 10 do
					task.wait(0.05)
					if not prop or not prop.Parent then break end
					local progress = i / 10
					part.Transparency = originalTransparency + (1 - originalTransparency) * progress
					part.Size = originalSize * (1 - progress * 0.8)
				end
				part.Transparency = 1
				part.CanCollide = false
			end
		end

		local healthBarAnchor = prop:FindFirstChild("HealthBarAnchor")
		if healthBarAnchor then
			local billboard = healthBarAnchor:FindFirstChild("HealthBarTemplate")
			if billboard then billboard.Enabled = false end
		end
	end)
end

local function showPropSync(prop, newPosition)
	if not prop or not prop.Parent then return end
	if newPosition then
		prop:PivotTo(CFrame.new(newPosition) * prop:GetPivot():inverse())
	end
	prop:SetAttribute("_IsHiddenByWhackAMole", false)
	prop:SetAttribute("CanTakeDamage", true)

	local parts = {}
	for _, child in ipairs(prop:GetDescendants()) do
		if child:IsA("BasePart") then table.insert(parts, child) end
	end

	task.spawn(function()
		for _, part in ipairs(parts) do
			if part.Name ~= "HealthBarAnchor" then
				local originalTransparency = part.Transparency or 0
				local originalSize = part.Size
				part.Transparency = 1
				part.CanCollide = true
				part.Size = originalSize * 0.2
				for i = 0, 8 do
					task.wait(0.04)
					if not prop or not prop.Parent then break end
					local progress = i / 8
					part.Transparency = 1 - progress
					part.Size = originalSize * (0.2 + progress * 0.8)
				end
				part.Transparency = originalTransparency
				part.Size = originalSize
			end
		end

		local healthBarAnchor = prop:FindFirstChild("HealthBarAnchor")
		if healthBarAnchor then
			local billboard = healthBarAnchor:FindFirstChild("HealthBarTemplate")
			if billboard then billboard.Enabled = true end
		end
	end)
end

function WhackAMoleSynchronized.Initialize(player, room)
	print("🎭 WhackAMole_Synchronized initialized - ALL TOGETHER NOW!")

	if not loadDependencies2() then
		warn("❌ WhackAMole_Synchronized: Failed to load dependencies")
		return nil
	end

	if not player or not room then
		warn("❌ WhackAMole_Synchronized: Invalid player or room")
		return nil
	end

	local decor = room:FindFirstChild("Decor")
	if decor then
		local modifierBoard = decor:FindFirstChild("ModifierBoard")
		if modifierBoard then
			local surfaceGui = modifierBoard:FindFirstChild("SurfaceGui")
			if surfaceGui then
				local header = surfaceGui:FindFirstChild("Header")
				if header then
					local label = header:FindFirstChild("Label")
					if label then
						label.Text = "🎭 SYNCHRONIZED MOLES 🎭"
						print("✅ Updated ModifierBoard: 🎭 SYNCHRONIZED MOLES 🎭")
					end
				end
			end
		end
	end

	local effects = {
		connections = {},
		isActive = true,
		player = player,
		room = room,
		nextSyncTime = tick() + SYNC_POP_INTERVAL,
		totalPops = 0,
	}

	local syncLoopConnection
	syncLoopConnection = game:GetService("RunService").Heartbeat:Connect(function()
		if not effects.isActive then
			if syncLoopConnection and syncLoopConnection.Connected then syncLoopConnection:Disconnect() end
			return
		end

		if not effects.player.Parent or not effects.player.Character then
			effects.isActive = false
			if syncLoopConnection and syncLoopConnection.Connected then syncLoopConnection:Disconnect() end
			return
		end

		local currentRoom = nil
		if PlayerInstanceManager2 then
			local instance = PlayerInstanceManager2.getPlayerInstance(effects.player)
			if instance and instance.currentRoomIndex then
				currentRoom = instance.roomsInOrder[instance.currentRoomIndex]
			end
		end

		if not currentRoom or not currentRoom.Parent then return end

		-- Check if it's time for synchronized pop
		if tick() >= effects.nextSyncTime then
			effects.nextSyncTime = tick() + SYNC_POP_INTERVAL

			local props = getPropsInRoom2(currentRoom)

			-- Hide ALL visible props simultaneously
			for _, prop in ipairs(props) do
				if prop and prop.Parent then
					local isHidden = prop:GetAttribute("_IsHiddenByWhackAMole")
					if not isHidden then
						hidePropSync(prop)
					end
				end
			end

			-- Wait then show all at new positions
			task.wait(2)

			for _, prop in ipairs(props) do
				if prop and prop.Parent then
					local isHidden = prop:GetAttribute("_IsHiddenByWhackAMole")
					if isHidden then
						local spawnZone = getRandomSpawnZone2(currentRoom)
						if spawnZone then
							local newPosition = getRandomPositionInZone2(spawnZone)
							if newPosition then
								local decor = currentRoom:FindFirstChild("Decor")
								if decor then
									local floor = decor:FindFirstChild("Floor")
									if floor then
										local floorY = floor.Position.Y + floor.Size.Y / 2
										newPosition = Vector3.new(newPosition.X, floorY + 5, newPosition.Z)
									end
								end
								showPropSync(prop, newPosition)
							end
						else
							showPropSync(prop, nil)
						end
						effects.totalPops = effects.totalPops + 1
					end
				end
			end
		end
	end)

	table.insert(effects.connections, syncLoopConnection)
	print("✅ WhackAMole_Synchronized started! All moles pop together!")

	return effects
end

function WhackAMoleSynchronized.Cleanup(player, room, effects)
	print("🎭 WhackAMole_Synchronized ending")

	if effects then
		effects.isActive = false
		print(string.format("   Total synchronized pops: %d", effects.totalPops or 0))

		if room then
			local props = getPropsInRoom2(room)
			for _, prop in ipairs(props) do
				if prop and prop.Parent then
					local isHidden = prop:GetAttribute("_IsHiddenByWhackAMole")
					if isHidden then showPropSync(prop, nil) end
				end
			end
		end
	end

	if effects and effects.connections then
		for _, connection in ipairs(effects.connections) do
			if connection and connection.Connected then connection:Disconnect() end
		end
	end

	print("✅ WhackAMole_Synchronized cleanup complete")
end

print("✅ WhackAMole_Synchronized module loaded\n")

return {
	Speedy = WhackAMoleSpeedy,
	Synchronized = WhackAMoleSynchronized,
}
