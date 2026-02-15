# Detailed Setup Guide

## Step-by-Step Roblox Studio Setup

### 1. Create New Project
1. Open Roblox Studio
2. File → New → Baseplate
3. Save the place as "RememberTheSequence.rbxl"

### 2. Create Workspace Structure

#### Create Lobby
1. In Explorer, right-click **Workspace**
2. Insert Object → Folder
3. Name it "Lobby"

#### Create Platforms
1. Right-click **Lobby** folder
2. Insert Object → Model
3. Name it "Platform1"
4. Inside Platform1, insert two Parts:
   - Right-click Platform1 → Insert Object → Part
   - Name first part "Left"
   - Insert another Part, name it "Right"
5. Select the **PlatformScript.lua** from `src/Workspace/`
6. Copy its contents
7. In Roblox Studio, right-click Platform1 → Insert Object → Script
8. Name it "PlatformScript"
9. Paste the code
10. The script will auto-setup the platform visually

11. **Duplicate platforms:**
    - Right-click Platform1 → Duplicate
    - Name it "Platform2"
    - Move it to a different position (select Platform2, use Move tool)
    - Repeat for Platform3, Platform4, etc.

#### Create Game Arena
1. Right-click **Workspace**
2. Insert Object → Folder
3. Name it "GameArena"
4. Right-click GameArena → Insert Object → SpawnLocation
5. Position the SpawnLocation where players should spawn during matches

### 3. Create ReplicatedStorage Structure

#### Add GameConfig Module
1. In Explorer, find **ReplicatedStorage**
2. Right-click → Insert Object → ModuleScript
3. Name it "GameConfig"
4. Copy contents from `src/ReplicatedStorage/GameConfig.lua`
5. Paste into the ModuleScript

#### Create RemoteEvents Folder
1. Right-click **ReplicatedStorage**
2. Insert Object → Folder
3. Name it "RemoteEvents"
4. Inside RemoteEvents, create these RemoteEvents:
   - Right-click RemoteEvents → Insert Object → RemoteEvent → Name: "SequenceShow"
   - Repeat for: "PlayerInput", "GameResult", "UpdateLives"

### 4. Setup ServerScriptService

1. Find **ServerScriptService** in Explorer
2. Create three scripts:

   **Script 1: GameManager**
   - Right-click ServerScriptService → Insert Object → Script
   - Name: "GameManager"
   - Copy from `src/ServerScriptService/GameManager.lua`

   **Script 2: LobbyManager**
   - Right-click ServerScriptService → Insert Object → Script
   - Name: "LobbyManager"
   - Copy from `src/ServerScriptService/LobbyManager.lua`

   **Script 3: PlayerDataManager**
   - Right-click ServerScriptService → Insert Object → Script
   - Name: "PlayerDataManager"
   - Copy from `src/ServerScriptService/PlayerDataManager.lua`

### 5. Setup StarterGui

1. Find **StarterGui** in Explorer
2. Right-click StarterGui → Insert Object → ScreenGui
3. Name it "SequenceUI"
4. Right-click SequenceUI → Insert Object → LocalScript
5. Name it "SequenceClient"
6. Copy from `src/StarterGui/SequenceClient.lua`

### 6. Configure Spawning

1. In Workspace, find the default **SpawnLocation**
2. Move it to inside the **Lobby** folder
3. Position it where players should spawn when joining

### 7. Test the Game

#### Local Server Testing (Required - needs 2 players)
1. Go to **Test** tab in Roblox Studio
2. Click the dropdown next to "Play"
3. Select "Local Server"
4. Set players to **2**
5. Click "Start"

#### Testing Checklist
- [ ] Both players spawn in lobby
- [ ] Both players can stand on platform (green parts)
- [ ] Game starts after 3 seconds with 2 players
- [ ] Players teleport to GameArena
- [ ] 3x3 grid appears on screen
- [ ] Sequence plays (squares light up)
- [ ] Players can click squares
- [ ] Correct clicks advance the sequence
- [ ] Wrong clicks remove lives
- [ ] Game ends when player reaches 0 lives
- [ ] Winner sees "YOU WIN" message
- [ ] Players return to lobby

### 8. Common Issues & Fixes

**Issue: Scripts not running**
- Make sure scripts are in the correct locations
- Check Output window (View → Output) for errors

**Issue: RemoteEvent errors**
- Verify all RemoteEvents are created in ReplicatedStorage/RemoteEvents
- Names must match exactly: SequenceShow, PlayerInput, GameResult, UpdateLives

**Issue: Players don't teleport**
- Check that GameArena folder exists in Workspace
- Verify SpawnLocation exists in GameArena

**Issue: Platform doesn't detect players**
- Make sure Left and Right parts are named correctly
- Ensure PlatformScript is inside the Platform model
- Check that parts have CanCollide = true

**Issue: UI doesn't show**
- Verify SequenceClient is a LocalScript (not regular Script)
- Check that it's in StarterGui

### 9. Customization Tips

#### Adjust Difficulty
Edit `GameConfig` module:
```lua
GameConfig.SEQUENCE_DISPLAY_TIME = 0.3 -- Faster = harder
GameConfig.STARTING_LIVES = 5 -- More lives = easier
```

#### Change Rewards
```lua
GameConfig.WIN_COINS = 100 -- More coins for winning
```

#### Change Colors
```lua
GameConfig.SQUARE_HIGHLIGHT_COLOR = Color3.fromRGB(255, 0, 0) -- Red squares
```

#### Add More Platforms
Simply duplicate any existing platform in the Lobby folder. LobbyManager automatically detects all platforms!

### 10. Publishing

1. File → Publish to Roblox
2. Fill in game details
3. Set to Public or Private
4. Click "Create"

Your game is now live!

## Support

If you encounter issues:
1. Check the Output window for errors
2. Verify all scripts are in correct locations
3. Make sure all RemoteEvents are created
4. Test with Local Server (2 players minimum)
