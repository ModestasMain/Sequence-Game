# Quick Start Guide

## 5-Minute Setup

### Prerequisites
- Roblox Studio installed
- Basic understanding of Roblox Studio interface

---

## Step 1: Create New Place (30 seconds)

1. Open Roblox Studio
2. **File → New → Baseplate**
3. **File → Save** as "RememberTheSequence"

---

## Step 2: Create Game Structure (2 minutes)

### In Workspace:

**Create Lobby:**
1. Right-click Workspace → Insert Object → **Folder**
2. Name: `Lobby`

**Create Platform:**
1. Right-click Lobby → Insert Object → **Model**
2. Name: `Platform1`
3. Right-click Platform1 → Insert Object → **Part**
   - Name: `Left`
4. Right-click Platform1 → Insert Object → **Part**
   - Name: `Right`

**Create Arena:**
1. Right-click Workspace → Insert Object → **Folder**
2. Name: `GameArena`
3. Right-click GameArena → Insert Object → **SpawnLocation**

---

## Step 3: Add Scripts (1 minute)

### In ReplicatedStorage:

1. Right-click ReplicatedStorage → Insert Object → **ModuleScript**
   - Name: `GameConfig`
   - Copy code from: `src/ReplicatedStorage/GameConfig.lua`

2. Right-click ReplicatedStorage → Insert Object → **Folder**
   - Name: `RemoteEvents`

3. Inside RemoteEvents, insert 4 **RemoteEvents**:
   - `SequenceShow`
   - `PlayerInput`
   - `GameResult`
   - `UpdateLives`

### In ServerScriptService:

Insert 3 **Scripts** (copy code from `src/ServerScriptService/`):
1. `GameManager`
2. `LobbyManager`
3. `PlayerDataManager`

### In Platform1 Model:

1. Right-click Platform1 → Insert Object → **Script**
   - Name: `PlatformScript`
   - Copy code from: `src/Workspace/PlatformScript.lua`

### In StarterGui:

1. Right-click StarterGui → Insert Object → **ScreenGui**
   - Name: `SequenceUI`
2. Right-click SequenceUI → Insert Object → **LocalScript**
   - Name: `SequenceClient`
   - Copy code from: `src/StarterGui/SequenceClient.lua`

---

## Step 4: Test (1 minute)

1. Go to **Test** tab
2. Click dropdown next to **Play**
3. Select **Local Server**
4. Set players: **2**
5. Click **Start**

### Testing:
1. Both players stand on same platform (green parts)
2. Wait 3 seconds
3. Game should start!
4. Watch sequence, then click squares

---

## That's It! 🎉

Your game is ready to play!

### Next Steps:

- **Add more platforms:** Duplicate Platform1 in Lobby folder
- **Customize:** Edit values in GameConfig module
- **Publish:** File → Publish to Roblox

---

## Visual Guide

### Workspace Structure:
```
Workspace/
├── Lobby/
│   └── Platform1/
│       ├── PlatformScript [Script]
│       ├── Left [Part]
│       └── Right [Part]
└── GameArena/
    └── SpawnLocation
```

### ReplicatedStorage Structure:
```
ReplicatedStorage/
├── GameConfig [ModuleScript]
└── RemoteEvents/
    ├── SequenceShow [RemoteEvent]
    ├── PlayerInput [RemoteEvent]
    ├── GameResult [RemoteEvent]
    └── UpdateLives [RemoteEvent]
```

### ServerScriptService Structure:
```
ServerScriptService/
├── GameManager [Script]
├── LobbyManager [Script]
└── PlayerDataManager [Script]
```

### StarterGui Structure:
```
StarterGui/
└── SequenceUI [ScreenGui]
    └── SequenceClient [LocalScript]
```

---

## Common First-Time Issues

### ❌ UI doesn't show
→ Make sure SequenceClient is a **LocalScript** (not Script)

### ❌ Platform doesn't work
→ Parts must be named exactly "Left" and "Right"

### ❌ Scripts error
→ Check all 4 RemoteEvents are created in RemoteEvents folder

### ❌ Players don't teleport
→ Make sure GameArena folder exists with SpawnLocation

---

## Need More Help?

📖 **Detailed Setup:** See `SETUP_GUIDE.md`
🐛 **Having Issues?** See `TROUBLESHOOTING.md`
📁 **File Organization:** See `PROJECT_STRUCTURE.md`
