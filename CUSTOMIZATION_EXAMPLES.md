# Customization Examples

Cool ways to customize your game!

---

## 🎨 Visual Customizations

### Make Squares Rainbow
Edit `GameConfig.lua`:
```lua
GameConfig.SQUARE_DEFAULT_COLOR = Color3.fromRGB(100, 100, 100)
GameConfig.SQUARE_HIGHLIGHT_COLOR = Color3.fromRGB(255, 0, 255) -- Purple
GameConfig.SQUARE_ACTIVE_COLOR = Color3.fromRGB(0, 255, 255)    -- Cyan
GameConfig.SQUARE_WRONG_COLOR = Color3.fromRGB(255, 0, 0)       -- Red
```

### Neon Platforms
Edit `PlatformScript.lua`:
```lua
leftPart.Material = Enum.Material.ForceField  -- Instead of Neon
leftPart.BrickColor = BrickColor.new("Hot pink")

rightPart.Material = Enum.Material.ForceField
rightPart.BrickColor = BrickColor.new("Hot pink")
```

### Bigger Grid (4x4 instead of 3x3)
Edit `GameConfig.lua`:
```lua
GameConfig.GRID_SIZE = 4  -- Creates 4x4 grid (16 squares)
```

Edit `SequenceClient.lua` (adjust button size):
```lua
local buttonSize = 80  -- Smaller buttons for 4x4
local buttonGap = 8
```

---

## ⚡ Difficulty Customizations

### Easy Mode (More Lives, Slower)
Edit `GameConfig.lua`:
```lua
GameConfig.STARTING_LIVES = 5              -- 5 lives instead of 3
GameConfig.SEQUENCE_DISPLAY_TIME = 0.8     -- Slower animation
GameConfig.INPUT_TIMEOUT = 60              -- 60 seconds to input
```

### Hard Mode (Less Lives, Faster)
```lua
GameConfig.STARTING_LIVES = 1              -- One mistake and you're out!
GameConfig.SEQUENCE_DISPLAY_TIME = 0.2     -- Very fast
GameConfig.INPUT_TIMEOUT = 10              -- Only 10 seconds!
```

### Insane Mode (Blitz)
```lua
GameConfig.STARTING_LIVES = 1
GameConfig.SEQUENCE_DISPLAY_TIME = 0.1     -- Blink and you miss it
GameConfig.SEQUENCE_GAP_TIME = 0.05        -- Almost no gap
GameConfig.INPUT_TIMEOUT = 5               -- 5 seconds total
```

---

## 💰 Reward Customizations

### High Rewards
Edit `GameConfig.lua`:
```lua
GameConfig.WIN_COINS = 500              -- Big reward for winning
GameConfig.PARTICIPATION_COINS = 50     -- Even losers get good coins
```

### Progressive Rewards (Bonus for longer sequences)
Edit `GameManager.lua`, in `EndGame` function:
```lua
function GameSession:EndGame(loser)
    -- ... existing code ...

    -- Award bonus coins for sequence length
    local bonusCoins = self.SequenceLength * 10  -- 10 coins per round

    if winner then
        local totalWinCoins = GameConfig.WIN_COINS + bonusCoins
        PlayerDataManager:AddWin(winner, totalWinCoins)
        PlayerDataManager:UpdateHighestSequence(winner, self.SequenceLength)
    end

    -- ... rest of code ...
end
```

---

## 🎵 Sound Effects

### Add Click Sounds
Edit `SequenceClient.lua`, in `OnSquareClick` function:

```lua
function OnSquareClick(position)
    if not canInput or isShowingSequence then return end

    -- Add sound
    local clickSound = Instance.new("Sound")
    clickSound.SoundId = "rbxassetid://6895079853"  -- Click sound
    clickSound.Volume = 0.5
    clickSound.Parent = game.SoundService
    clickSound:Play()
    clickSound.Ended:Connect(function()
        clickSound:Destroy()
    end)

    -- Visual feedback
    if gridButtons[position] then
        gridButtons[position].BackgroundColor3 = GameConfig.SQUARE_ACTIVE_COLOR
        -- ... rest of code ...
    end
end
```

### Add Sequence Sounds
Edit `SequenceClient.lua`, in `ShowSequence` function:

```lua
-- Inside the sequence loop
for i, position in ipairs(sequence) do
    task.wait(GameConfig.SEQUENCE_GAP_TIME)

    -- Highlight square
    if gridButtons[position] then
        gridButtons[position].BackgroundColor3 = GameConfig.SQUARE_HIGHLIGHT_COLOR

        -- Add beep sound
        local beep = Instance.new("Sound")
        beep.SoundId = "rbxassetid://6895079853"
        beep.Volume = 0.3
        beep.Pitch = 1 + (i * 0.1)  -- Higher pitch for each square
        beep.Parent = game.SoundService
        beep:Play()
        game.Debris:AddItem(beep, 2)
    end

    -- ... rest of code ...
end
```

### Win/Lose Sounds
Edit `SequenceClient.lua`, in `ShowResult` function:

```lua
function ShowResult(won, sequenceLength)
    canInput = false

    if won then
        statusLabel.Text = "YOU WIN! 🎉 Sequence: " .. sequenceLength
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)

        -- Victory sound
        local winSound = Instance.new("Sound")
        winSound.SoundId = "rbxassetid://6895079853"  -- Replace with victory sound
        winSound.Volume = 0.7
        winSound.Parent = game.SoundService
        winSound:Play()
        game.Debris:AddItem(winSound, 5)
    else
        statusLabel.Text = "YOU LOSE! Sequence: " .. sequenceLength
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)

        -- Defeat sound
        local loseSound = Instance.new("Sound")
        loseSound.SoundId = "rbxassetid://6895079853"  -- Replace with defeat sound
        loseSound.Volume = 0.7
        loseSound.Parent = game.SoundService
        loseSound:Play()
        game.Debris:AddItem(loseSound, 5)
    end

    -- ... rest of code ...
end
```

**Sound IDs:** Find free sounds at https://www.roblox.com/develop?View=3

---

## 🏆 Leaderboard Customizations

### Add More Stats
Edit `PlayerDataManager.lua`, in `getDefaultData`:

```lua
local function getDefaultData()
    return {
        Wins = 0,
        Losses = 0,
        Coins = 0,
        GamesPlayed = 0,
        HighestSequence = 0,
        WinStreak = 0,           -- NEW
        TotalSequencesSolved = 0 -- NEW
    }
end
```

### Show Win Rate in Leaderstats
Edit `CreateLeaderstats` function:

```lua
function PlayerDataManager:CreateLeaderstats(player)
    local data = self.PlayerData[player.UserId]
    if not data then return end

    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local wins = Instance.new("IntValue")
    wins.Name = "Wins"
    wins.Value = data.Wins
    wins.Parent = leaderstats

    local coins = Instance.new("IntValue")
    coins.Name = "Coins"
    coins.Value = data.Coins
    coins.Parent = leaderstats

    -- NEW: Win Rate (percentage)
    local winRate = Instance.new("IntValue")
    winRate.Name = "Win %"
    if data.GamesPlayed > 0 then
        winRate.Value = math.floor((data.Wins / data.GamesPlayed) * 100)
    else
        winRate.Value = 0
    end
    winRate.Parent = leaderstats
end
```

---

## 🎮 Gameplay Customizations

### Speed Increases Per Round
Edit `GameManager.lua`, in `StartRound`:

```lua
function GameSession:StartRound()
    if not self.Active then return end

    print("Starting round " .. self.SequenceLength)

    -- Generate new sequence position
    self:GenerateSequence()

    -- Calculate speed multiplier (faster each round)
    local speedMultiplier = 1 - (self.SequenceLength * 0.05)  -- 5% faster each round
    speedMultiplier = math.max(speedMultiplier, 0.3)  -- Cap at 70% faster

    -- Show sequence with adjusted speed
    for _, player in ipairs(self.Players) do
        sequenceShowEvent:FireClient(player, self.Sequence, speedMultiplier)
    end

    -- ... rest of code ...
end
```

Then update `SequenceClient.lua` to accept speed parameter:

```lua
sequenceShowEvent.OnClientEvent:Connect(function(sequence, speedMultiplier)
    speedMultiplier = speedMultiplier or 1  -- Default to 1x
    currentSequence = sequence
    mainFrame.Visible = true
    ShowSequence(sequence, speedMultiplier)
end)

function ShowSequence(sequence, speedMultiplier)
    -- ... existing code ...

    for i, position in ipairs(sequence) do
        task.wait(GameConfig.SEQUENCE_GAP_TIME * speedMultiplier)

        -- Highlight square
        if gridButtons[position] then
            gridButtons[position].BackgroundColor3 = GameConfig.SQUARE_HIGHLIGHT_COLOR
        end

        task.wait(GameConfig.SEQUENCE_DISPLAY_TIME * speedMultiplier)

        -- ... rest of code ...
    end
end
```

### Lives Regeneration (Heal on Good Rounds)
Edit `GameManager.lua`, in `HandleInput`:

```lua
function GameSession:HandleInput(player, position)
    -- ... existing validation code ...

    if position == expectedPosition then
        print(player.Name .. " clicked correct position " .. position)

        -- Check if sequence is complete
        if self.CurrentInputIndex >= #self.Sequence then
            print(player.Name .. " completed the sequence!")

            -- BONUS: Restore 1 life every 5 rounds (up to max)
            if self.SequenceLength % 5 == 0 and self.Lives[player.UserId] < GameConfig.STARTING_LIVES then
                self.Lives[player.UserId] = self.Lives[player.UserId] + 1
                print(player.Name .. " earned a bonus life!")

                -- Update UI
                for _, p in ipairs(self.Players) do
                    updateLivesEvent:FireClient(p, self.Lives[self.Players[1].UserId], self.Lives[self.Players[2].UserId])
                end
            end

            self.CurrentInputIndex = 1
            task.wait(1)
            self:StartRound()
        else
            self.CurrentInputIndex = self.CurrentInputIndex + 1
        end
    end

    -- ... rest of code ...
end
```

---

## 🌈 UI Customizations

### Dark Mode UI
Edit `SequenceClient.lua`:

```lua
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)  -- Darker background

livesLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
```

### Animated UI Entrance
Edit `SequenceClient.lua`, in SequenceShow handler:

```lua
sequenceShowEvent.OnClientEvent:Connect(function(sequence)
    currentSequence = sequence

    -- Animate entrance
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.Visible = true

    mainFrame:TweenSize(
        UDim2.new(0, 400, 0, 500),
        Enum.EasingDirection.Out,
        Enum.EasingStyle.Back,
        0.5,
        true
    )

    mainFrame:TweenPosition(
        UDim2.new(0.5, -200, 0.5, -250),
        Enum.EasingDirection.Out,
        Enum.EasingStyle.Back,
        0.5,
        true
    )

    task.wait(0.5)
    ShowSequence(sequence)
end)
```

---

## 🎯 Advanced: Power-Ups

### Add Freeze Time Power-Up
Create new `PowerUpManager.lua` in ServerScriptService:

```lua
local PowerUpManager = {}
PowerUpManager.ActivePowerUps = {}

-- Give player a freeze power-up that slows sequence
function PowerUpManager:GiveFreezeTime(player)
    if not self.ActivePowerUps[player.UserId] then
        self.ActivePowerUps[player.UserId] = {}
    end

    table.insert(self.ActivePowerUps[player.UserId], "FreezeTime")
    print(player.Name .. " received Freeze Time power-up!")
end

function PowerUpManager:UsePowerUp(player, powerUpType)
    local playerPowerUps = self.ActivePowerUps[player.UserId]
    if not playerPowerUps then return false end

    for i, powerUp in ipairs(playerPowerUps) do
        if powerUp == powerUpType then
            table.remove(playerPowerUps, i)
            return true
        end
    end

    return false
end

return PowerUpManager
```

Give power-ups every 3 wins in `PlayerDataManager.lua`.

---

## Need More Ideas?

Check out these resources:
- 🎨 Roblox Color Library: https://www.roblox.com/develop
- 🎵 Free Sounds: Roblox Library (Search "UI sounds")
- 📚 Roblox Docs: https://create.roblox.com/docs

Have fun customizing! 🚀
