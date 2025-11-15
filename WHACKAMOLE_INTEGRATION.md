# WhackAMole Integration Guide

## Files Needed

1. ✅ `WhackAMole.lua` - Main modifier (created)
2. ✅ `WhackAMole_Variants.lua` - Speedy and Synchronized variants (created)
3. 📝 Update `ModifierConfig.lua` - Add to modifier map
4. 📝 Update room progression - Assign to specific rooms

## Step-by-Step Integration

### Step 1: Add WhackAMole to ModifierConfig.lua

Find the section where modifiers are defined and add:

```lua
-- ModifierConfig.lua

local ModifierConfig = {}

-- Modifier names
ModifierConfig.CoinRain = "CoinRain"
ModifierConfig.DarkRoom = "DarkRoom"
ModifierConfig.WhackAMole = "WhackAMole"      -- ADD THIS
ModifierConfig.WhackAMoleSpeedy = "WhackAMole_Speedy"  -- Optional variant
ModifierConfig.Synchronized = "WhackAMole_Synchronized"  -- Optional variant

-- Modifier progression map (room -> modifier)
ModifierConfig.Map = {
	[1] = ModifierConfig.CoinRain,
	[2] = ModifierConfig.DarkRoom,
	[3] = ModifierConfig.WhackAMole,        -- ADD THIS
	[4] = ModifierConfig.CoinRain,
	[5] = ModifierConfig.DarkRoom,
	[6] = ModifierConfig.WhackAMole,        -- ADD THIS
	[7] = ModifierConfig.CoinRain,
	-- ... continue pattern ...
}

return ModifierConfig
```

### Step 2: File Structure

Ensure your folder structure matches:

```
ReplicatedStorage/
├── Modules/
│   └── RoomManager/
│       ├── ModifierConfig.lua
│       ├── RoomProgression.lua
│       └── RoomModifiers/
│           ├── CoinRain.lua
│           ├── DarkRoom.lua
│           ├── WhackAMole.lua           ← PLACE HERE
│           ├── WhackAMole_Speedy.lua    ← OPTIONAL
│           └── WhackAMole_Synchronized.lua ← OPTIONAL
```

### Step 3: Verify RoomProgression.lua Integration

No changes needed if your RoomProgression already supports dynamic modifiers:

```lua
-- RoomProgression.lua (excerpt)

local ROOM_MODIFIER_MAP = ModifierConfig.Map

local function getModifierForRoom(roomIndex)
	local modifier = ROOM_MODIFIER_MAP[roomIndex]
	if not modifier then
		-- Cycle through all 20 modifiers after room 20
		local cycleIndex = ((roomIndex - 1) % 20) + 1
		modifier = ROOM_MODIFIER_MAP[cycleIndex]
	end
	return modifier
end

-- When loading next room:
function RoomProgression.loadNextRoom(player)
	-- ...
	local nextModifier = getModifierForRoom(nextIndex)
	if nextModifier and RoomModifiers then
		RoomModifiers.ApplyModifier(player, nextRoom, nextModifier)
	end
	-- ...
end
```

This automatically picks up WhackAMole from ModifierConfig.Map!

### Step 4: Test Setup

To test WhackAMole in specific rooms:

```lua
-- Quick test: Add to Room 3 only
ModifierConfig.Map[3] = ModifierConfig.WhackAMole

-- Or test multiple rooms
ModifierConfig.Map[3] = ModifierConfig.WhackAMole
ModifierConfig.Map[8] = ModifierConfig.WhackAMole_Speedy
ModifierConfig.Map[13] = ModifierConfig.WhackAMole_Synchronized
```

## Configuration by Room Difficulty

### Easy Rooms (Early Game)
```lua
-- Room 2-4: Basic WhackAMole
[2] = "WhackAMole",
[3] = "CoinRain",
[4] = "WhackAMole",
```

### Medium Rooms (Mid Game)
```lua
-- Room 10-15: Mix in faster variants
[10] = "WhackAMole",
[12] = "WhackAMole_Speedy",  -- Slightly faster
[14] = "WhackAMole",
```

### Hard Rooms (Late Game)
```lua
-- Room 18-20: Max chaos
[18] = "WhackAMole_Speedy",
[19] = "WhackAMole_Synchronized",
[20] = "WhackAMole_Speedy",
```

## Runtime Behavior

Once integrated, here's what happens when a player enters a room:

### Room 3 (WhackAMole)

```
1. RoomProgression.loadNextRoom(player) called
   ↓
2. getModifierForRoom(3) → "WhackAMole"
   ↓
3. RoomModifiers.ApplyModifier(player, room3, "WhackAMole")
   ↓
4. Loads: ReplicatedStorage.Modules.RoomManager.RoomModifiers.WhackAMole
   ↓
5. Calls: WhackAMole.Initialize(player, room3)
   - Sets up Heartbeat connection
   - Creates pop schedules
   - Updates ModifierBoard → "WHACK A MOLE"
   ↓
6. Props start their pop cycles!
   ↓
7. Player destroys props (while dodging pops)
   ↓
8. All props destroyed → Next room loads
   ↓
9. RoomModifiers.RemoveModifier(player, "WhackAMole")
   ↓
10. Calls: WhackAMole.Cleanup(player, room3, effects)
    - Restores any hidden props
    - Disconnects Heartbeat
    - Logs pop count
```

## Variant Setup

To use the variant modifiers:

### Option A: Separate Files
```lua
-- Create three files:
-- WhackAMole.lua (main)
-- WhackAMole_Speedy.lua (fast version)
-- WhackAMole_Synchronized.lua (sync version)

-- In ModifierConfig:
ModifierConfig.Map[5] = "WhackAMole"
ModifierConfig.Map[10] = "WhackAMole_Speedy"
ModifierConfig.Map[15] = "WhackAMole_Synchronized"
```

### Option B: Unified File
```lua
-- Put all variants in WhackAMole_Variants.lua
-- Then in RoomModifiers.lua, add variant loading:

function RoomModifiers.loadModifier(modifierName)
	if modifierName == "WhackAMole_Speedy" then
		local variants = require(modifiersFolder:FindFirstChild("WhackAMole_Variants"))
		return variants.Speedy
	elseif modifierName == "WhackAMole_Synchronized" then
		local variants = require(modifiersFolder:FindFirstChild("WhackAMole_Variants"))
		return variants.Synchronized
	end
	-- ... rest of loading
end
```

## Debugging

### Enable Logging

WhackAMole logs messages when:
- ✅ Module loads
- ✅ Modifier initializes
- ✅ Props start popping
- ✅ ModifierBoard updates
- ✅ Cleanup completes
- ℹ️ Props hide/show (optional - comment out for less spam)

Example output:
```
🔨 WhackAMole module loading...
✅ PlayerInstanceManager loaded
✅ Updated ModifierBoard for Room3: WHACK A MOLE
✅ WhackAMole started! Props will randomly pop underground
   ↓ PropModel1 hidden underground
   ↑ PropModel1 popped out!
```

### Check Active Effects

In Command Line / LocalScript:
```lua
local RoomModifiers = require(game.ReplicatedStorage.Modules.RoomManager.RoomModifiers)
local player = game.Players.LocalPlayer
local activeModifiers = RoomModifiers.GetActiveModifiers(player)
print("Active modifiers:", table.concat(activeModifiers, ", "))
-- Output: "WhackAMole"
```

## Common Issues

### Issue: WhackAMole doesn't load
**Solution**: Check that file path is exactly:
```
ReplicatedStorage/Modules/RoomManager/RoomModifiers/WhackAMole.lua
```

### Issue: Props never pop
**Possible causes**:
1. `effects.isActive` is false
2. Player has left room
3. Props folder doesn't exist
4. Props are marked as traps (`_IsTrap = true`)

**Solution**: Check console logs and verify conditions above

### Issue: Popped props disappear permanently
**Possible causes**:
1. Cleanup not being called
2. Room being destroyed
3. Props being removed before showing

**Solution**: Add error handling and verify cleanup is called

### Issue: Heavy CPU usage
**Possible causes**:
1. Too many props in room
2. Animation frame rates too high
3. Too many active pop cycles

**Solution**:
- Reduce props per room
- Increase animation frame wait times
- Increase `MIN_POP_DELAY` / `MAX_POP_DELAY`

## Next Steps

1. **Copy files to correct locations**:
   - WhackAMole.lua → RoomModifiers folder
   - WhackAMole_Variants.lua → RoomModifiers folder (optional)

2. **Update ModifierConfig.lua**:
   - Add WhackAMole to modifier names
   - Assign to specific room numbers

3. **Test in game**:
   - Load a room with WhackAMole modifier
   - Verify props pop correctly
   - Test variant modifiers if using them

4. **Tune difficulty**:
   - Adjust pop intervals and hide duration
   - Balance with room difficulty
   - Test with multiple players

## Additional Modifiers to Create

With the pattern established, consider creating:

- **GeyserGeyser** - Props launch upward then fall back down
- **PropTeleport** - Props instantly teleport instead of animating
- **Confusion** - Props appear as illusions, only one real
- **TimeWarp** - Props move in slow-motion
- **Reverse** - Destroy props to spawn more props (endless)
- **Mirror** - Props mirror player location, must hit reflection
