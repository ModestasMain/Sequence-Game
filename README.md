# Remember the Sequence - Roblox Game

A competitive 1v1 sequence memory game where players battle to see who can remember the longest pattern!

## Game Features

- **Lobby System**: Multiple 1v1 platforms where players queue up
- **Sequence Memory Gameplay**: 3x3 grid where squares light up in sequence
- **Lives System**: Each player has 3 lives
- **Rewards**: Winners earn coins and win stats
- **Progressive Difficulty**: Sequences get longer each round

## Installation Instructions

1. Open Roblox Studio
2. Create a new Baseplate project
3. Import the scripts into their respective locations:

### Workspace Structure
```
Workspace/
  - Lobby (Folder)
    - Platform1 (Model - create this)
      - PlatformScript (Script)
      - Left (Part - Green, anchored)
      - Right (Part - Green, anchored)
      - Label (Part with SurfaceGui showing "1v1")
    - Platform2 (Model - duplicate Platform1)
    - Platform3 (Model - duplicate Platform1)
  - GameArena (Folder)
    - SpawnLocation (SpawnLocation part)
```

### ServerScriptService
```
ServerScriptService/
  - GameManager (Script)
  - LobbyManager (Script)
  - PlayerDataManager (Script)
```

### ReplicatedStorage
```
ReplicatedStorage/
  - GameConfig (ModuleScript)
  - RemoteEvents (Folder)
    - StartGame (RemoteEvent)
    - SequenceShow (RemoteEvent)
    - PlayerInput (RemoteEvent)
    - GameResult (RemoteEvent)
    - UpdateLives (RemoteEvent)
```

### StarterGui
```
StarterGui/
  - SequenceUI (ScreenGui)
    - SequenceClient (LocalScript)
```

## Setup Steps

1. Create the Workspace structure with platforms
2. Add all scripts to their locations
3. Create RemoteEvents in ReplicatedStorage
4. Test with 2 players in a local server (Test tab → Local Server → 2 Players)

## Game Flow

1. Two players stand on a lobby platform
2. Game starts after 3 second countdown
3. Sequence displays on 3x3 grid
4. Players must click squares in correct order
5. Wrong click = lose 1 life
6. Lose all 3 lives = game over
7. Winner gets 50 coins + 1 win stat

## Customization

Edit `GameConfig` module to adjust:
- Starting lives (default: 3)
- Coin rewards (default: 50)
- Sequence speed (default: 0.5s per square)
- Grid size (default: 3x3)
