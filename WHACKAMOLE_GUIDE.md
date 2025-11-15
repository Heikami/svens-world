# WhackAMole Modifier Guide

## Overview
WhackAMole is a chaotic room modifier that makes props randomly hide underground and reappear in different locations, creating a dynamic "whack-a-mole" gameplay experience.

## How It Works

### Core Mechanics

1. **Pop Cycle**: Props periodically hide underground and reappear
   - Each prop has independent pop schedules
   - Props can't pop while hidden or during cooldown
   - New location is randomly selected from available spawn zones

2. **Hide Animation**
   - Props gradually shrink (to 20% size) while fading out
   - Takes ~0.5 seconds
   - During hiding, props are invulnerable and invisible
   - Health bar is hidden

3. **Show Animation**
   - Props expand from 20% size back to full size while fading in
   - Takes ~0.3 seconds
   - Props reappear at random spawn zone location
   - Health bar reappears

4. **Cooldown System**
   - After appearing, props have 3-second cooldown before next pop
   - This prevents props from being impossible to hit
   - Gives players a window to damage each prop before it hides again

### Configuration

**File**: `WhackAMole.lua`

```lua
POP_CHECK_INTERVAL = 0.5   -- Check interval for pops
MIN_POP_DELAY = 4          -- Minimum seconds before pop
MAX_POP_DELAY = 6          -- Maximum seconds before pop
HIDE_DURATION = 2          -- Seconds prop stays hidden
POP_COOLDOWN = 3           -- Cooldown after appearing
```

**Behavioral Settings**:
- Non-trap props only (traps are excluded)
- Props can't take damage while hidden
- Damage-dealing modifiers don't stack with popping animation

## Installation

### Step 1: Create Module File
Place `WhackAMole.lua` in:
```
ReplicatedStorage/Modules/RoomManager/RoomModifiers/WhackAMole.lua
```

### Step 2: Add to Modifier Config
In `ModifierConfig.lua`, add to the Map:
```lua
COIN_RAIN = "CoinRain",
DARK_ROOM = "DarkRoom",
WHACK_A_MOLE = "WhackAMole",  -- Add this line
```

### Step 3: Update Modifier Map
In `RoomProgression.lua` or your modifier map, assign to room numbers:
```lua
local ROOM_MODIFIER_MAP = ModifierConfig.Map

-- Example: Room 5 uses WhackAMole
ROOM_MODIFIER_MAP[5] = "WhackAMole"
```

## API Reference

### Initialize(player, room)
Called when modifier starts. Sets up the whack-a-mole loop.

**Parameters**:
- `player` - Player who owns the room instance
- `room` - Room model to apply modifier to

**Returns**: effects table with:
- `connections` - Table of active connections
- `isActive` - Boolean indicating if modifier is running
- `player` - Reference to player
- `room` - Reference to room
- `popSchedules` - Table tracking pop timers per prop
- `propsPopped` - Counter of total pops

**Example**:
```lua
local effects = WhackAMole.Initialize(player, room)
```

### Cleanup(player, room, effects)
Called when modifier ends. Restores all hidden props and cleans up connections.

**Parameters**:
- `player` - Player who owns the room instance
- `room` - Room model
- `effects` - Effects table from Initialize

**Example**:
```lua
WhackAMole.Cleanup(player, room, effects)
```

## Modifier Board Display

The ModifierBoard in the room will display:
```
╔════════════════════╗
║  WHACK A MOLE      ║
╚════════════════════╝
```

## Game Balance Considerations

### Difficulty Scaling
- **Easy Room**: Longer pop intervals (6-8s) and longer hide duration (2.5s)
- **Medium Room**: Standard settings (4-6s pop, 2s hide)
- **Hard Room**: Shorter intervals (2-4s pop, 1.5s hide)

### Customization Tips

```lua
-- For EASIER gameplay
MIN_POP_DELAY = 6
MAX_POP_DELAY = 8
HIDE_DURATION = 2.5
POP_COOLDOWN = 4

-- For HARDER gameplay
MIN_POP_DELAY = 2
MAX_POP_DELAY = 3
HIDE_DURATION = 1.5
POP_COOLDOWN = 2
```

## Variant Modifiers

### WhackAMole_Speedy ⚡
**Configuration**: Everything 2x faster (chaos mode)
- `MIN_POP_DELAY = 1.5s`, `MAX_POP_DELAY = 2.5s`
- `HIDE_DURATION = 0.8s`, `POP_COOLDOWN = 1s`
- Props pop almost constantly
- Recommended for skilled players only

### WhackAMole_Synchronized 🎭
**Configuration**: All props pop together
- `SYNC_POP_INTERVAL = 3.5s`
- Every 3.5 seconds, ALL visible props hide and relocate
- Creates synchronized pattern - easier to predict but all props gone at once
- Good for endurance-style challenges

## Technical Details

### Prop Selection
- Only affects non-trap props
- Ignores props with `_IsTrap` attribute set to true
- Unregisters destroyed props automatically

### Spawn Zone Selection
- Randomly picks from available SpawnZones in room
- Calculates random X/Z within zone bounds
- Adjusts Y to be above floor
- Falls back to current location if no zones available

### Performance Optimization
- Uses single Heartbeat connection (not per-prop)
- Spawn animations are non-blocking (spawned tasks)
- Clears pop schedules for destroyed props
- Minimal memory footprint

### Compatibility
✅ Works with:
- Tier system (Gold, Diamond, etc.)
- Chain reactions
- Health bar system
- Bleed effects
- Combo counter

❌ Doesn't stack well with:
- Other movement-based modifiers (would look chaotic)
- Teleporting effects (conflicting animations)

## Troubleshooting

### Props Not Popping
**Solution**: Check that `isActive` is true and player is in correct room

### Props Permanently Hidden
**Solution**: Ensure Cleanup is called properly when modifier ends

### Animation Jank
**Solution**: Adjust animation frame counts (currently 10 frames hide, 8 frames show)

### Performance Issues
**Solution**: Reduce number of active props or increase pop intervals

## Future Enhancement Ideas

1. **Sound Effects**
   - Pop sound when hiding
   - Rise sound when appearing
   - Whoosh effect during movement

2. **Visual Effects**
   - Dust cloud when hiding
   - Ripple effect on floor
   - Glow indicator showing where prop will appear

3. **Advanced Mechanics**
   - Props can damage player if they pop on player location
   - Props move in pattern (line, circle, etc.)
   - Multi-stage pops (hide → reappear → hide again)

4. **Difficulty Modifiers**
   - Prop pop prediction UI (shows next location)
   - Slow-motion pop to catch them
   - Props follow player position

## Integration with Modifier System

The WhackAMole modifier integrates with the room modifier system:

```lua
-- In RoomProgression.lua
local RoomModifiers = require(game.ReplicatedStorage.Modules.RoomManager.RoomModifiers)

-- Apply modifier when room loads
RoomModifiers.ApplyModifier(player, room, "WhackAMole")

-- Modifier automatically Initialize() is called
-- ModifierBoard updates to show "WHACK A MOLE"
-- Props start popping on their schedules

-- When transitioning to next room
RoomModifiers.RemoveModifier(player, "WhackAMole")
-- Modifier Cleanup() is called
-- All hidden props reappear
-- Connections are disconnected
```

## Testing Checklist

When testing WhackAMole:

- [ ] ModifierBoard displays "WHACK A MOLE"
- [ ] Props start hiding and reappearing after initial delay
- [ ] Props can't take damage while hidden
- [ ] Props reappear at different spawn zone locations
- [ ] Health bars hide/show with props
- [ ] Cleanup restores all hidden props
- [ ] No prop is permanently stuck hidden
- [ ] Connection leaks don't occur
- [ ] Works with multiple players in same room
- [ ] Works with different room layouts
