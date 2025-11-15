--[[
	WhackAMole Modifier - WHACK A MOLE EVENT
	Props randomly pop underground and reappear in different locations
	Creates chaotic gameplay where props constantly move around
	Location: ReplicatedStorage.Modules.RoomManager.RoomModifiers.WhackAMole
]]

local WhackAMole = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("🔨 WhackAMole module loading...")

-- Load dependencies
local PlayerInstanceManager = nil

local function loadDependencies()
	if PlayerInstanceManager then
		return true
	end

	-- Load PlayerInstanceManager
	if not PlayerInstanceManager then
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
	end

	return true
end

-- Configuration
local POP_CHECK_INTERVAL = 0.5  -- Check every 0.5s if prop should pop
local MIN_POP_DELAY = 4  -- Minimum 4 seconds between pops
local MAX_POP_DELAY = 6  -- Maximum 6 seconds between pops
local HIDE_DURATION = 2  -- Props stay hidden for 2 seconds
local POP_COOLDOWN = 3  -- Cooldown after appearing before next pop
local POP_CHANCE_PER_PROP = 0.3  -- 30% chance for each prop per interval

-- Helper: Get random spawn zone in room
local function getRandomSpawnZone(room)
	local spawnZonesFolder = room:FindFirstChild("SpawnZones")
	if not spawnZonesFolder then
		return nil
	end

	local spawnZones = spawnZonesFolder:GetChildren()
	if #spawnZones == 0 then
		return nil
	end

	return spawnZones[math.random(1, #spawnZones)]
end

-- Helper: Get random position within spawn zone
local function getRandomPositionInZone(spawnZone)
	if not spawnZone then
		return nil
	end

	local halfX = spawnZone.Size.X / 2
	local halfZ = spawnZone.Size.Z / 2

	local randomX = math.random(-halfX * 100, halfX * 100) / 100
	local randomZ = math.random(-halfZ * 100, halfZ * 100) / 100

	local position = spawnZone.Position
		+ spawnZone.CFrame.RightVector * randomX
		+ spawnZone.CFrame.LookVector * randomZ

	return position
end

-- Helper: Hide prop with animation (move underground)
local function hideProp(prop)
	if not prop or not prop.Parent then
		return
	end

	-- Mark as hidden
	prop:SetAttribute("_IsHiddenByWhackAMole", true)
	prop:SetAttribute("CanTakeDamage", false)

	-- Get current position and move down underground
	local currentCFrame = prop:GetPivot()
	local undergroundCFrame = currentCFrame * CFrame.new(0, -30, 0)  -- Move 30 studs down

	-- Animate moving underground
	for i = 0, 10 do
		task.wait(0.05)
		if not prop or not prop.Parent then break end

		local progress = i / 10
		local interpolatedCFrame = currentCFrame:Lerp(undergroundCFrame, progress)
		prop:PivotTo(interpolatedCFrame)
	end

	-- Ensure fully underground
	prop:PivotTo(undergroundCFrame)

	-- Hide health bar
	local healthBarAnchor = prop:FindFirstChild("HealthBarAnchor")
	if healthBarAnchor then
		local billboard = healthBarAnchor:FindFirstChild("HealthBarTemplate")
		if billboard then
			billboard.Enabled = false
		end
	end

	print("   ↓ " .. prop.Name .. " hidden underground")
end

-- Helper: Show prop with pop animation (move up from underground)
local function showProp(prop, newPosition)
	if not prop or not prop.Parent then
		return
	end

	-- First, move to new horizontal position while still underground
	local undergroundPos = prop:GetPivot()
	if newPosition then
		-- Move horizontally to new position, keeping Y underground
		local newUndergroundCFrame = CFrame.new(newPosition) * prop:GetPivot():inverse()
		newUndergroundCFrame = newUndergroundCFrame * CFrame.new(0, -30, 0)  -- Keep underground
		prop:PivotTo(newUndergroundCFrame)
		undergroundPos = prop:GetPivot()
	end

	-- Now move up from underground to surface
	local surfaceCFrame = undergroundPos * CFrame.new(0, 30, 0)  -- Move 30 studs up

	-- Animate moving up
	for i = 0, 8 do
		task.wait(0.04)
		if not prop or not prop.Parent then break end

		local progress = i / 8
		local interpolatedCFrame = undergroundPos:Lerp(surfaceCFrame, progress)
		prop:PivotTo(interpolatedCFrame)
	end

	-- Ensure at surface position
	prop:PivotTo(surfaceCFrame)

	-- Mark as no longer hidden
	prop:SetAttribute("_IsHiddenByWhackAMole", false)
	prop:SetAttribute("CanTakeDamage", true)
	prop:SetAttribute("_LastPopTime", tick())

	-- Show health bar
	local healthBarAnchor = prop:FindFirstChild("HealthBarAnchor")
	if healthBarAnchor then
		local billboard = healthBarAnchor:FindFirstChild("HealthBarTemplate")
		if billboard then
			billboard.Enabled = true
		end
	end

	print("   ↑ " .. prop.Name .. " popped out!")
end

-- Helper: Get all active props in room
local function getPropsInRoom(room)
	local props = {}
	local propsFolder = room:FindFirstChild("Props")

	if propsFolder then
		for _, child in ipairs(propsFolder:GetChildren()) do
			if child:IsA("Model") then
				local isTrap = child:GetAttribute("_IsTrap")
				if not isTrap then
					table.insert(props, child)
				end
			end
		end
	end

	return props
end

--[[
	Initialize(player, room)
	Sets up whack-a-mole events for the room
]]
function WhackAMole.Initialize(player, room)
	print("🔨 WhackAMole initialized for room")

	if not loadDependencies() then
		warn("❌ WhackAMole: Failed to load dependencies")
		return nil
	end

	if not player or not room then
		warn("❌ WhackAMole: Invalid player or room")
		return nil
	end

	-- Update ModifierBoard for THIS room only
	local function updateModifierBoard()
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
							label.Text = "WHACK A MOLE"
							print("✅ Updated ModifierBoard for " .. room.Name .. ": WHACK A MOLE")
						end
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
		popSchedules = {},  -- Track pop timers per prop
		propsPopped = 0,
	}

	-- Update board immediately
	updateModifierBoard()

	-- Main pop/hide loop
	local popLoopConnection
	popLoopConnection = game:GetService("RunService").Heartbeat:Connect(function()
		if not effects.isActive then
			if popLoopConnection and popLoopConnection.Connected then
				popLoopConnection:Disconnect()
			end
			return
		end

		-- Check player still exists
		if not effects.player.Parent or not effects.player.Character then
			effects.isActive = false
			if popLoopConnection and popLoopConnection.Connected then
				popLoopConnection:Disconnect()
			end
			return
		end

		-- Get current room from instance manager
		local currentRoom = nil
		if PlayerInstanceManager then
			local instance = PlayerInstanceManager.getPlayerInstance(effects.player)
			if instance and instance.currentRoomIndex then
				currentRoom = instance.roomsInOrder[instance.currentRoomIndex]
			end
		end

		-- If room invalid, stop
		if not currentRoom or not currentRoom.Parent then
			return
		end

		-- Get all active props
		local props = getPropsInRoom(currentRoom)

		for _, prop in ipairs(props) do
			if not prop or not prop.Parent then
				effects.popSchedules[prop] = nil
			else
				local isHidden = prop:GetAttribute("_IsHiddenByWhackAMole")
				local lastPopTime = prop:GetAttribute("_LastPopTime") or 0
				local currentTime = tick()

				-- If prop is visible and past cooldown, schedule next pop
				if not isHidden and (currentTime - lastPopTime) >= POP_COOLDOWN then
					local nextPopTime = effects.popSchedules[prop]

					if not nextPopTime then
						-- Schedule first pop
						local popDelay = math.random(MIN_POP_DELAY * 100, MAX_POP_DELAY * 100) / 100
						effects.popSchedules[prop] = currentTime + popDelay
					elseif currentTime >= nextPopTime then
						-- Time to pop!
						effects.popSchedules[prop] = nil

						-- Spawn hiding animation
						task.spawn(function()
							hideProp(prop)

							-- Stay hidden for duration
							task.wait(HIDE_DURATION)

							if prop and prop.Parent then
								-- Pick random spawn zone and position
								local spawnZone = getRandomSpawnZone(currentRoom)
								if spawnZone then
									local newPosition = getRandomPositionInZone(spawnZone)
									if newPosition then
										-- Adjust Y to floor height
										local decor = currentRoom:FindFirstChild("Decor")
										if decor then
											local floor = decor:FindFirstChild("Floor")
											if floor then
												local floorY = floor.Position.Y + floor.Size.Y / 2
												newPosition = Vector3.new(newPosition.X, floorY + 5, newPosition.Z)
											end
										end

										-- Show with new position
										showProp(prop, newPosition)
										effects.propsPopped = effects.propsPopped + 1
									end
								else
									-- No spawn zone, just show at current location
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
	print("✅ WhackAMole started! Props will randomly pop underground")

	return effects
end

--[[
	Cleanup(player, room, effects)
	Stops the whack-a-mole effects and restores all props
]]
function WhackAMole.Cleanup(player, room, effects)
	print("🔨 WhackAMole ending")

	if effects then
		effects.isActive = false
		print(string.format("   Total pops: %d", effects.propsPopped or 0))

		-- Restore all hidden props
		if room then
			local props = getPropsInRoom(room)
			for _, prop in ipairs(props) do
				if prop and prop.Parent then
					local isHidden = prop:GetAttribute("_IsHiddenByWhackAMole")
					if isHidden then
						showProp(prop, nil)
					end
				end
			end
		end
	end

	if effects and effects.connections then
		for _, connection in ipairs(effects.connections) do
			if connection and connection.Connected then
				connection:Disconnect()
			end
		end
	end

	print("✅ WhackAMole cleanup complete")
end

print("✅ WhackAMole module loaded\n")
return WhackAMole
