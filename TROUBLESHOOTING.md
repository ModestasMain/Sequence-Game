# Troubleshooting Guide

## Common Issues and Solutions

### 🔴 Issue: "Infinite yield possible on 'ReplicatedStorage:WaitForChild(...)'"

**Cause:** RemoteEvents or GameConfig module not created

**Solution:**
1. Open ReplicatedStorage in Explorer
2. Verify `GameConfig` ModuleScript exists
3. Verify `RemoteEvents` folder exists
4. Inside RemoteEvents, verify these RemoteEvents exist:
   - SequenceShow
   - PlayerInput
   - GameResult
   - UpdateLives
5. Names must match exactly (case-sensitive)

---

### 🔴 Issue: Players don't teleport to arena

**Cause:** GameArena or SpawnLocation missing

**Solution:**
1. In Workspace, create folder named "GameArena"
2. Insert a SpawnLocation inside GameArena
3. Make sure SpawnLocation is positioned away from lobby
4. Check Output window for errors

---

### 🔴 Issue: Platform doesn't detect players

**Symptoms:**
- Players stand on green platforms
- Nothing happens after 3 seconds
- No "stepped on platform" messages in Output

**Solution:**
1. Check that platform parts are named exactly "Left" and "Right"
2. Verify PlatformScript is a regular Script (not LocalScript)
3. Verify PlatformScript is inside the Platform Model
4. Check that Left and Right parts have:
   - `CanCollide = true`
   - `Anchored = true`
5. Open Output window and look for initialization message: "Initialized platform: Platform1"

**Debug Steps:**
```lua
-- Add this to PlatformScript to test
print("Script running in:", script.Parent.Name)
print("Left part exists:", script.Parent:FindFirstChild("Left") ~= nil)
print("Right part exists:", script.Parent:FindFirstChild("Right") ~= nil)
```

---

### 🔴 Issue: UI doesn't appear during game

**Symptoms:**
- Players teleport to arena
- No 3x3 grid appears
- Can't click any squares

**Solution:**
1. Verify SequenceClient is a **LocalScript** (NOT regular Script)
2. Check it's in StarterGui/SequenceUI
3. Open Output window and look for: "SequenceClient loaded for [PlayerName]"
4. If you see errors about "SequenceShow", check RemoteEvents exist

**Debug Steps:**
1. In Test mode, press F9 to open Developer Console
2. Switch to "Client" tab (not "Server")
3. Look for error messages
4. You should see: "SequenceClient loaded for Player1"

---

### 🔴 Issue: "Script timeout" or "infinite loop"

**Cause:** LobbyManager and GameManager both try to require each other

**Solution:**
This is by design and normal. The circular require is handled safely:
- LobbyManager requires GameManager when needed (in StartGame)
- Don't require at the top level, require inside functions

---

### 🔴 Issue: Game starts with only 1 player

**Cause:** Configuration error or platform detection issue

**Solution:**
1. Open `GameConfig.lua`
2. Verify: `GameConfig.PLAYERS_PER_GAME = 2`
3. Check LobbyManager prints in Output showing player count
4. Make sure both players are on THE SAME platform (not different platforms)

---

### 🔴 Issue: Sequence doesn't display / squares don't light up

**Symptoms:**
- Game starts
- UI appears
- Grid is visible
- But squares don't light up in sequence

**Solution:**
1. Check client Output/Console (F9 → Client tab)
2. Verify SequenceShow RemoteEvent exists and is spelled correctly
3. Add debug print in SequenceClient:
```lua
sequenceShowEvent.OnClientEvent:Connect(function(sequence)
    print("Received sequence:", table.concat(sequence, ", "))
    -- rest of code...
end)
```

---

### 🔴 Issue: Clicks don't register

**Symptoms:**
- Sequence displays correctly
- Click squares but nothing happens
- No response from clicks

**Solution:**
1. Verify PlayerInput RemoteEvent exists
2. Check that `canInput = true` after sequence finishes
3. Add debug print:
```lua
function OnSquareClick(position)
    print("Clicked square:", position, "canInput:", canInput)
    -- rest of code...
end
```

---

### 🔴 Issue: Lives don't update

**Solution:**
1. Verify UpdateLives RemoteEvent exists
2. Check GameManager is calling `updateLivesEvent:FireClient()`
3. Verify SequenceClient has handler:
```lua
updateLivesEvent.OnClientEvent:Connect(function(lives1, lives2)
    print("Lives updated:", lives1, "vs", lives2)
    UpdateLives(lives1, lives2)
end)
```

---

### 🔴 Issue: Players don't return to lobby after game

**Cause:** Lobby SpawnLocation not found

**Solution:**
1. Make sure Workspace/Lobby has a SpawnLocation
2. Or add a SpawnLocation directly in Workspace as fallback
3. Check GameSession:Cleanup() for errors in Output

---

### 🔴 Issue: DataStore errors / Stats not saving

**Symptoms:**
- "DataStore request was rejected"
- "502: API Services rejected request"
- Stats reset every time

**Cause:** DataStores only work in published games or with API access enabled

**Solution:**

**For Testing:**
1. Game Settings → Security → Enable Studio Access to API Services
2. Or just ignore - stats will work when published

**For Published Game:**
1. Stats should work automatically
2. If not, check game is not private/friends-only (DataStore restrictions)

**Disable DataStore for Testing:**
Edit PlayerDataManager.lua, comment out save/load:
```lua
function PlayerDataManager:LoadData(player)
    -- Skip DataStore during testing
    self.PlayerData[player.UserId] = getDefaultData()
    self:CreateLeaderstats(player)
end

function PlayerDataManager:SaveData(player)
    -- Skip saving during testing
end
```

---

### 🔴 Issue: Multiple games starting at once on same platform

**Cause:** Platform not properly marked as InUse

**Solution:**
1. Check LobbyManager Platform:StartGame() sets `self.InUse = true`
2. Verify Platform:Reset() is called after game ends
3. Add debug print:
```lua
function Platform:StartGame()
    print("Platform InUse status:", self.InUse)
    if self.InUse then return end
    -- rest of code...
end
```

---

### 🔴 Issue: "ServerScriptService.LobbyManager:XX: attempt to call a nil value"

**Cause:** GameManager not found or circular dependency issue

**Solution:**
Move the require inside the function:
```lua
function Platform:StartGame()
    if self.InUse then return end
    self.InUse = true

    -- Require here, not at top of file
    local GameManager = require(script.Parent:WaitForChild("GameManager"))
    GameManager:StartGame(player1, player2, self)
end
```

---

## Testing Checklist

Use this checklist when testing:

### Pre-Game
- [ ] Join game as Player 1
- [ ] Join game as Player 2 (Local Server with 2 players)
- [ ] Both players spawn in lobby
- [ ] Lobby has visible green platforms
- [ ] Platforms show "1v1" label

### Platform Testing
- [ ] Player 1 stands on left platform
- [ ] Player 2 stands on right platform of SAME platform
- [ ] Console shows "[PlayerName] stepped on [Left/Right] platform"
- [ ] Console shows "Starting countdown for platform..."
- [ ] Wait 3 seconds
- [ ] Console shows "Starting game between Player1 and Player2"

### Game Start
- [ ] Both players teleport to GameArena
- [ ] UI appears on both screens
- [ ] Lives display shows "Lives: 3 vs 3"
- [ ] Status shows "Watch the sequence..."

### Sequence Display
- [ ] First square lights up (yellow)
- [ ] Square turns back to dark gray
- [ ] Status changes to "Your turn! Click the sequence..."

### Input Testing
- [ ] Click the correct square
- [ ] Square flashes green briefly
- [ ] New round starts
- [ ] Sequence now has 2 squares
- [ ] Both squares light up in order

### Lives System
- [ ] Click wrong square
- [ ] Lives decrease (e.g., "3 vs 2")
- [ ] Sequence resets to beginning
- [ ] Click wrong 2 more times
- [ ] Player loses (0 lives)

### Game End
- [ ] Winner sees "YOU WIN! 🎉"
- [ ] Loser sees "YOU LOSE!"
- [ ] Both messages show sequence length
- [ ] Coins added to leaderstats
- [ ] Wins added for winner
- [ ] After 5 seconds, both players return to lobby
- [ ] Platform resets and is ready for new players

---

## Debug Output Guide

### Expected Console Messages

**When game loads:**
```
Platform Platform1 initialized
Platform Platform2 initialized
Initialized platform: Platform1
Initialized platform: Platform2
SequenceClient loaded for Player1
SequenceClient loaded for Player2
```

**When players join platform:**
```
Player1 stepped on Left platform
Player2 stepped on Right platform
Starting countdown for platform...
```

**When game starts:**
```
Starting game between Player1 and Player2
Game session starting...
Starting round 1
Generated sequence of length 1: 5
```

**During gameplay:**
```
Player1 clicked correct position 5
Player1 completed the sequence!
Starting round 2
Generated sequence of length 2: 5, 3
```

**When error occurs:**
```
Player2 clicked wrong position 7 (expected 5)
Player2 lost a life! Lives remaining: 2
```

**When game ends:**
```
Game Over! Winner: Player1, Loser: Player2
Platform reset and ready for new players
```

---

## Getting Help

If issues persist:

1. **Check Output Window**
   - View → Output (or press F9)
   - Look for red error messages
   - Share the full error message

2. **Check Script Locations**
   - Compare your Explorer hierarchy to PROJECT_STRUCTURE.md
   - Verify script names match exactly

3. **Test in Local Server**
   - Single player mode won't work (needs 2 players)
   - Test → Local Server → 2 players

4. **Verify RemoteEvents**
   - All 4 RemoteEvents must exist
   - Names are case-sensitive
   - Must be in ReplicatedStorage/RemoteEvents

5. **Check Parts**
   - Platform parts must be named "Left" and "Right"
   - Must have CanCollide = true
   - Must be inside a Model (the Platform)

---

## Performance Issues

### Game lags during sequence display

**Solution:** Reduce animation detail in GameConfig:
```lua
GameConfig.SEQUENCE_DISPLAY_TIME = 0.3  -- Faster
GameConfig.SEQUENCE_GAP_TIME = 0.1      -- Less gap
```

### Too many players cause lag

**Solution:** Limit concurrent games:
- Only create 3-4 platforms max
- Each platform = 1 concurrent game (2 players)
- 4 platforms = max 8 players in games at once
