# Project Structure

## File Organization

```
Remember the Sequence/
│
├── README.md                          # Overview and quick setup
├── SETUP_GUIDE.md                     # Detailed step-by-step instructions
├── PROJECT_STRUCTURE.md               # This file
├── TROUBLESHOOTING.md                 # Common issues and solutions
│
└── src/                               # All Lua scripts organized by Roblox service
    │
    ├── ReplicatedStorage/             # Shared between client and server
    │   └── GameConfig.lua             # Configuration module (lives, coins, colors, etc.)
    │
    ├── ServerScriptService/           # Server-side scripts only
    │   ├── GameManager.lua            # Main game logic, sequence generation, win/loss
    │   ├── LobbyManager.lua           # Platform detection and matchmaking
    │   └── PlayerDataManager.lua      # DataStore, stats, coins, leaderboard
    │
    ├── StarterGui/                    # Client UI scripts
    │   └── SequenceClient.lua         # LocalScript for 3x3 grid UI and player input
    │
    └── Workspace/                     # Physical game objects
        └── PlatformScript.lua         # Auto-setup for lobby platforms (visual)
```

## Roblox Studio Hierarchy

This is what your game structure should look like in Roblox Studio's Explorer:

```
Workspace/
│
├── Lobby/                             [Folder]
│   ├── SpawnLocation                  [SpawnLocation] - Where players spawn
│   ├── Platform1/                     [Model]
│   │   ├── PlatformScript             [Script] - Auto-configures the platform
│   │   ├── Left                       [Part] - Green platform (left side)
│   │   ├── Right                      [Part] - Green platform (right side)
│   │   └── Label                      [Part] - Created by script, shows "1v1"
│   ├── Platform2/                     [Model] - Duplicate of Platform1
│   └── Platform3/                     [Model] - Duplicate of Platform1
│
└── GameArena/                         [Folder]
    └── SpawnLocation                  [SpawnLocation] - Where players fight

ReplicatedStorage/
│
├── GameConfig                         [ModuleScript]
└── RemoteEvents/                      [Folder]
    ├── SequenceShow                   [RemoteEvent] - Server → Client: Show sequence
    ├── PlayerInput                    [RemoteEvent] - Client → Server: Player clicked square
    ├── GameResult                     [RemoteEvent] - Server → Client: Game over, winner
    └── UpdateLives                    [RemoteEvent] - Server → Client: Lives changed

ServerScriptService/
│
├── GameManager                        [Script]
├── LobbyManager                       [Script]
└── PlayerDataManager                  [Script]

StarterGui/
│
└── SequenceUI/                        [ScreenGui]
    └── SequenceClient                 [LocalScript]
```

## Script Dependencies

### GameManager Dependencies
- Requires: `GameConfig`, `PlayerDataManager`
- Uses RemoteEvents: `SequenceShow`, `PlayerInput`, `GameResult`, `UpdateLives`
- Called by: `LobbyManager` when 2 players are ready

### LobbyManager Dependencies
- Requires: `GameConfig`, `GameManager`
- Detects: Platform models in `Workspace/Lobby`
- Monitors: Player touch events on platform parts

### PlayerDataManager Dependencies
- Uses: DataStoreService
- DataStore Name: `"PlayerStats_v1"`
- Creates: leaderstats folder (Wins, Coins)

### SequenceClient Dependencies
- Requires: `GameConfig`
- Uses RemoteEvents: `SequenceShow`, `PlayerInput`, `GameResult`, `UpdateLives`
- Creates: All UI elements dynamically

## Remote Event Flow

### Game Start Flow
```
Player stands on platform
    ↓
LobbyManager detects 2 players
    ↓
LobbyManager calls GameManager:StartGame()
    ↓
GameManager teleports players to arena
    ↓
[UpdateLives] Server → Both Clients (initial lives)
    ↓
GameManager generates sequence
    ↓
[SequenceShow] Server → Both Clients (sequence array)
    ↓
SequenceClient displays sequence animation
```

### Input Flow
```
Player clicks square on UI
    ↓
SequenceClient detects click
    ↓
[PlayerInput] Client → Server (square position)
    ↓
GameManager validates input
    ↓
If correct: Continue or next round
If wrong: Deduct life
    ↓
[UpdateLives] Server → Both Clients (updated lives)
    ↓
If lives = 0: EndGame()
```

### Game End Flow
```
GameManager:EndGame(loser)
    ↓
Determine winner
    ↓
PlayerDataManager:AddWin(winner, coins)
PlayerDataManager:AddLoss(loser, coins)
    ↓
[GameResult] Server → Both Clients (won: boolean, sequence length)
    ↓
SequenceClient shows result message
    ↓
Wait 5 seconds
    ↓
Teleport players back to lobby
    ↓
Platform:Reset()
```

## Key Variables

### GameConfig
- `STARTING_LIVES = 3` - How many mistakes each player gets
- `GRID_SIZE = 3` - 3x3 grid (9 squares total)
- `SEQUENCE_DISPLAY_TIME = 0.5` - Seconds each square lights up
- `WIN_COINS = 50` - Coins awarded to winner
- `PLATFORM_WAIT_TIME = 3` - Countdown before game starts

### GameSession
- `Players` - Array of 2 player objects
- `Lives` - Table: `{[userId] = livesRemaining}`
- `Sequence` - Array of square positions (1-9)
- `SequenceLength` - Current round number
- `CurrentInputIndex` - Which square in sequence player should click next

### Platform
- `LeftPart` - Left side green platform
- `RightPart` - Right side green platform
- `Players` - Array of players standing on platform
- `InUse` - Boolean: true if game is active

## Testing Requirements

### Minimum Test Setup
- **2 players required** (use Local Server in Roblox Studio)
- Both players must stand on same platform
- Wait for 3 second countdown
- Game should start automatically

### What to Test
1. ✅ Player spawning in lobby
2. ✅ Platform detection (green parts)
3. ✅ 2-player requirement
4. ✅ Countdown system
5. ✅ Teleport to arena
6. ✅ UI appears
7. ✅ Sequence displays correctly
8. ✅ Input validation
9. ✅ Lives system
10. ✅ Win/loss detection
11. ✅ Coin rewards
12. ✅ Return to lobby

## Customization Points

### Easy Customizations
- **Difficulty**: Edit `SEQUENCE_DISPLAY_TIME` (lower = harder)
- **Lives**: Edit `STARTING_LIVES`
- **Rewards**: Edit `WIN_COINS`, `PARTICIPATION_COINS`
- **Colors**: Edit all `SQUARE_*_COLOR` values
- **Grid Size**: Edit `GRID_SIZE` (4 = 4x4 grid)

### Medium Customizations
- **Platform visuals**: Edit `PlatformScript.lua`
- **UI layout**: Edit `SequenceClient.lua` (mainFrame size/position)
- **Sound effects**: Add `Sound` objects and play in SequenceClient

### Advanced Customizations
- **Power-ups**: Add items that give extra lives
- **Leaderboards**: Query top players from DataStore
- **Tournaments**: Bracket system with multiple rounds
- **Teams**: 2v2 mode with team coordination
