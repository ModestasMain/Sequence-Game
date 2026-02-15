# Rojo Setup Guide

This project uses **Rojo** to sync code between your file system and Roblox Studio.

## ✅ Setup Complete

Your project is already set up with:
- ✅ Git repository initialized
- ✅ Pushed to GitHub: https://github.com/ModestasMain/Sequence-Game
- ✅ Rojo project configured (`default.project.json`)
- ✅ All scripts exported to `src/` folder

## 📦 How to Sync with Rojo

### 1. Start Rojo Server
Open a terminal in the project folder and run:
```bash
./rojo.exe serve
```

### 2. Install Rojo Plugin in Roblox Studio
- Install from: https://create.roblox.com/marketplace/asset/13916111004/Rojo
- Or search "Rojo" in Roblox Studio plugins

### 3. Connect Roblox Studio to Rojo
- Open your Roblox place in Studio
- Click the **Rojo plugin** button
- Click **Connect** (default port: 34872)

### 4. Sync Your Changes
Rojo will automatically sync changes from your files to Roblox Studio!

## 🔄 Workflow

### From Files → Studio (Recommended)
1. Edit scripts in `src/` folder using your favorite code editor
2. Save the file
3. Rojo automatically syncs to Studio
4. **No manual work needed!**

### From Studio → Files
If you make changes in Studio and want to save them to files:
1. Make changes in Roblox Studio
2. The changes are only in Studio (not in files yet)
3. **Manually export** the script or use Rojo's build mode

## 📁 Project Structure

```
Remember the Sequence/
├── src/
│   ├── ReplicatedStorage/
│   │   └── GameConfig.lua
│   ├── ServerScriptService/
│   │   ├── GameManager.lua
│   │   ├── LobbyManager.lua
│   │   └── PlayerDataManager.lua
│   ├── StarterGui/
│   │   └── SequenceClient.lua
│   └── Workspace/
│       └── PlatformScript.lua
├── default.project.json    ← Rojo configuration
├── .gitignore
└── README.md
```

## ⚠️ Important Notes

- **Always edit files in the `src/` folder**, not in Studio
- Changes in `src/` → automatically sync to Studio
- Changes in Studio → need manual export to `src/`
- The `.rbxl` file is **not tracked** in Git (see `.gitignore`)

## 🔧 Troubleshooting

### "No files changed" when connecting
- Make sure Rojo server is running
- Check that you're in the correct project folder
- Verify `default.project.json` exists

### Changes not syncing
- Restart Rojo server
- Reconnect in Studio
- Check file paths in `default.project.json`

### Lost files after sync
- **Don't worry!** Your files in `src/` are safe
- Git tracks everything in `src/`
- Rojo only syncs what's in `default.project.json`

## 📚 Resources

- [Rojo Documentation](https://rojo.space/docs)
- [GitHub Repository](https://github.com/ModestasMain/Sequence-Game)
- [Rojo Installation Guide](https://rojo.space/docs/installation/)
