# Game Flow Diagram

Visual representation of how the game works from start to finish.

---

## Complete Game Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      GAME STARTS                             │
│                  Players Join Server                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    SPAWN IN LOBBY                            │
│  - PlayerDataManager loads player stats from DataStore      │
│  - Creates leaderstats (Wins, Coins)                        │
│  - Player spawns at Lobby/SpawnLocation                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                 WAITING FOR MATCH                            │
│  Players explore lobby and find green platforms             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
               ┌─────────────────────┐
               │  Player 1 stands    │
               │  on Left platform   │
               └──────────┬──────────┘
                          │
                          ▼
               ┌─────────────────────┐
               │  Player 2 stands    │
               │  on Right platform  │
               └──────────┬──────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              PLATFORM DETECTS 2 PLAYERS                      │
│  - LobbyManager's Platform:OnTouch() triggered              │
│  - Adds players to platform.Players table                   │
│  - Starts 3-second countdown                                │
└────────────────────────┬────────────────────────────────────┘
                         │
                    (3 seconds)
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   GAME STARTS!                               │
│  - Platform:StartGame() called                              │
│  - Platform marked as InUse = true                          │
│  - GameManager:StartGame(player1, player2, platform)        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                TELEPORT TO ARENA                             │
│  - GameSession created                                      │
│  - Both players teleported to GameArena/SpawnLocation       │
│  - Lives initialized: Player1: 3, Player2: 3                │
│  - [UpdateLives] event sent to both clients                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                    (2 seconds)
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                     ROUND 1                                  │
│  SERVER:                                                     │
│  - GameSession:GenerateSequence()                           │
│  - Randomly pick 1 square (1-9)                             │
│  - Sequence = [5]  (example)                                │
│  - [SequenceShow] event → Both clients with sequence        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  SHOW SEQUENCE                               │
│  CLIENT (SequenceClient.lua):                               │
│  - UI appears (3x3 grid)                                    │
│  - Status: "Watch the sequence..."                          │
│  - Square 5 lights up yellow (0.5s)                         │
│  - Square 5 returns to gray                                 │
│  - Status: "Your turn! Click the sequence..."               │
│  - canInput = true                                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
                 ┌───────────────┐
                 │ Player clicks │
                 │   square 5    │
                 └───────┬───────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   PLAYER INPUT                               │
│  CLIENT:                                                     │
│  - Square flashes green                                     │
│  - [PlayerInput] event → Server with position 5             │
│                                                              │
│  SERVER:                                                     │
│  - GameSession:HandleInput(player, 5)                       │
│  - Check if 5 == Sequence[1]  ✓ CORRECT!                   │
│  - CurrentInputIndex = 1, Sequence length = 1               │
│  - Sequence complete!                                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                    (1 second)
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                     ROUND 2                                  │
│  SERVER:                                                     │
│  - Add new square to sequence                               │
│  - Sequence = [5, 3]  (example)                             │
│  - [SequenceShow] event → Both clients                      │
│                                                              │
│  CLIENT:                                                     │
│  - Square 5 lights up (0.5s)                                │
│  - Square 3 lights up (0.5s)                                │
│  - Wait for player input                                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
                 ┌───────────────┐
                 │ Player clicks │
                 │   square 5    │◄──── Input 1
                 └───────┬───────┘
                         │
                         ▼
                 ┌───────────────┐
                 │ Player clicks │
                 │   square 3    │◄──── Input 2
                 └───────┬───────┘
                         │
                         ▼
             ┌─────────────────────┐
             │   Both correct!     │
             │  Continue to Round 3│
             └──────────┬──────────┘
                        │
                       ...
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                     ROUND 7                                  │
│  Sequence = [5, 3, 1, 9, 2, 7, 4]                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
                 ┌───────────────┐
                 │ Player clicks │
                 │   square 5    │◄──── Correct
                 └───────┬───────┘
                         │
                         ▼
                 ┌───────────────┐
                 │ Player clicks │
                 │   square 3    │◄──── Correct
                 └───────┬───────┘
                         │
                         ▼
                 ┌───────────────┐
                 │ Player clicks │
                 │   square 8    │◄──── WRONG! (Expected 1)
                 └───────┬───────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   WRONG INPUT!                               │
│  SERVER:                                                     │
│  - GameSession:HandleWrongInput(player)                     │
│  - Player loses 1 life: 3 → 2                               │
│  - [UpdateLives] event → Both clients                       │
│                                                              │
│  CLIENT:                                                     │
│  - Lives display updates: "Lives: 3 vs 2"                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                    (2 seconds)
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                RESTART CURRENT ROUND                         │
│  Sequence stays [5, 3, 1, 9, 2, 7, 4]                       │
│  Player gets another chance                                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                        ...
                         │
                 (Player makes 2 more mistakes)
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  OUT OF LIVES!                               │
│  - Player has 0 lives remaining                             │
│  - GameSession:EndGame(loser)                               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    GAME OVER                                 │
│  SERVER:                                                     │
│  - Determine winner (the other player)                      │
│  - PlayerDataManager:AddWin(winner, 50 coins)               │
│  - PlayerDataManager:AddLoss(loser, 10 coins)               │
│  - Update highest sequence records                          │
│  - [GameResult] event → Both clients (won: boolean)         │
│                                                              │
│  CLIENT:                                                     │
│  Winner sees: "YOU WIN! 🎉 Sequence: 7"                     │
│  Loser sees:  "YOU LOSE! Sequence: 7"                       │
│                                                              │
│  Both players see updated coins in leaderstats              │
└────────────────────────┬────────────────────────────────────┘
                         │
                    (5 seconds)
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                 RETURN TO LOBBY                              │
│  - Both players teleported back to Lobby/SpawnLocation      │
│  - UI hidden                                                │
│  - Platform:Reset() called                                  │
│  - Platform.InUse = false                                   │
│  - Platform ready for next match                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                READY FOR NEXT GAME                           │
│  Players can join platforms again                           │
│  Cycle repeats                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Parallel Player Experience

### What Player 1 Sees:
```
1. Spawn in lobby
2. Walk to green platform, stand on left side
3. Wait for Player 2
4. See "Starting game..." (maybe add this to UI?)
5. Teleport to arena
6. UI appears with 3x3 grid
7. "Lives: 3 vs 3"
8. "Watch the sequence..."
9. Squares light up: [5]
10. "Your turn! Click the sequence..."
11. Click square 5 → Flashes green
12. Next round: [5, 3]
13. Click 5, click 3
14. Continue until mistake or opponent loses
15. "YOU WIN! 🎉" or "YOU LOSE!"
16. See coins added to leaderstats
17. Teleport back to lobby
```

### What Player 2 Sees:
```
Same experience as Player 1!
- Both players see the same sequence
- Both players input simultaneously
- First player to make 3 mistakes loses
```

---

## Code Execution Flow

### Server Scripts Initialization Order:

```
1. PlayerDataManager loads
   └─> Sets up DataStore connection
   └─> Connects to PlayerAdded event

2. LobbyManager loads
   └─> Waits 1 second for Workspace to load
   └─> LobbyManager:Initialize()
   └─> Finds all Platform models in Lobby
   └─> Creates Platform objects
   └─> Sets up Touch events for each platform

3. GameManager loads
   └─> Requires GameConfig
   └─> Requires PlayerDataManager
   └─> Connects to PlayerInput RemoteEvent
   └─> Waits for LobbyManager to call StartGame()
```

### Client Script Initialization:

```
1. SequenceClient loads (when player joins)
   └─> Requires GameConfig
   └─> Creates entire UI (ScreenGui, mainFrame, grid buttons)
   └─> UI hidden by default
   └─> Connects to all RemoteEvents:
       - SequenceShow
       - GameResult
       - UpdateLives
   └─> Waits for server to send events
```

---

## Event Timeline (Example Game)

| Time | Event | Who Triggers | What Happens |
|------|-------|--------------|--------------|
| 0:00 | Players spawn | Server | PlayerDataManager loads data |
| 0:10 | Player1 touches platform | Player1 | Platform adds to Players table |
| 0:15 | Player2 touches platform | Player2 | Platform starts countdown |
| 0:18 | Countdown finishes | Platform | Platform:StartGame() |
| 0:18 | Game starts | GameManager | Create GameSession, teleport |
| 0:20 | Round 1 starts | GameSession | Generate sequence, send to clients |
| 0:21 | Show sequence | SequenceClient | Animate square 5 |
| 0:22 | Player input phase | SequenceClient | Enable clicking |
| 0:23 | Player clicks | Player1 | Send to server |
| 0:23 | Validate input | GameSession | Check if correct |
| 0:24 | Round 2 starts | GameSession | Add to sequence [5,3] |
| ... | Continue... | ... | ... |
| 1:45 | Player makes mistake | Player2 | Lose 1 life |
| 2:10 | Player out of lives | Player2 | GameSession:EndGame() |
| 2:10 | Show results | GameSession | Send GameResult to both |
| 2:15 | Return to lobby | GameSession | Teleport, cleanup |

---

## Data Flow Diagram

```
┌──────────────┐
│   Client 1   │
└──────┬───────┘
       │
       │ PlayerInput
       ▼
┌─────────────────────────┐         ┌──────────────────┐
│   GameManager (Server)  │◄────────┤  LobbyManager    │
└──────┬──────────────────┘         └──────────────────┘
       │
       │ SequenceShow
       │ UpdateLives
       │ GameResult
       │
       ▼
┌──────────────┐
│   Client 2   │
└──────────────┘

       │
       │ Reads/Writes
       ▼
┌──────────────────────┐
│ PlayerDataManager    │
└──────┬───────────────┘
       │
       │ DataStore API
       ▼
┌──────────────────────┐
│  Roblox DataStore    │
│  (Cloud Storage)     │
└──────────────────────┘
```

---

## RemoteEvent Communication

### Server → Client Events:

| RemoteEvent | Parameters | Purpose |
|-------------|------------|---------|
| SequenceShow | `sequence: {number}` | Tell client to display sequence |
| UpdateLives | `lives1: number, lives2: number` | Update lives display |
| GameResult | `won: boolean, sequenceLength: number` | Show win/loss screen |

### Client → Server Events:

| RemoteEvent | Parameters | Purpose |
|-------------|------------|---------|
| PlayerInput | `position: number` | Player clicked square (1-9) |

---

This diagram should help you understand the complete flow of the game from start to finish!
