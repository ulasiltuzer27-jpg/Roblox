--!nonstrict
-- Hub'ı ve kasa parsellerini kod ile kurar. Haritayı Studio'da elle yapmak
-- yerine üretmek, yeni bölge eklemeyi tek satırlık iş haline getiriyor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Loot = require(ReplicatedStorage.Shared.Core.Loot)
local DataService = require(ServerScriptService.Server.Services.DataService)
local VaultService = require(ServerScriptService.Server.Services.VaultService)

local WorldService = {}

local PLOT_COUNT = 12
local PLOT_RADIUS = 96
local PEDESTALS_PER_ROW = 9

local plots: { [number]: any } = {} -- plotIndex -> { model, userId }
local byUser: { [number]: number } = {} -- userId -> plotIndex

local function newPart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function label(parent: BasePart, text: string, size: Vector2, offset: number): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(size.X, size.Y)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 220
	billboard.Parent = parent

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
	textLabel.TextStrokeTransparency = 0.4
	textLabel.Text = text
	textLabel.Parent = billboard
	return textLabel
end

local function buildKiosk(parent: Instance, name: string, promptText: string, position: Vector3, color: Color3)
	local kiosk = newPart(name, Vector3.new(6, 8, 2), color, parent)
	kiosk.Material = Enum.Material.Neon
	kiosk.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(180), 0)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = promptText
	prompt.ObjectText = name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = kiosk

	label(kiosk, name, Vector2.new(6, 1.4), 6)
	return kiosk
end

local function buildHub(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Hub"

	local floor = newPart("Zemin", Vector3.new(260, 2, 260), Color3.fromRGB(24, 26, 34), folder)
	floor.CFrame = CFrame.new(0, -1, 0)
	floor.Material = Enum.Material.Concrete

	local center = newPart("Merkez", Vector3.new(60, 0.4, 60), Color3.fromRGB(38, 42, 56), folder)
	center.CFrame = CFrame.new(0, 0.2, 0)
	center.Material = Enum.Material.Neon
	center.Transparency = 0.6

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.5, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.BrickColor = BrickColor.new("Institutional white")
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.4
	spawn.Parent = folder

	-- Kiosklar istemcideki panelleri açar (ProximityPrompt istemcide dinleniyor).
	buildKiosk(folder, "Sandık Dükkanı", "Aç", Vector3.new(-22, 4, -26), Color3.fromRGB(255, 200, 64))
	buildKiosk(folder, "Yükseltmeler", "Aç", Vector3.new(0, 4, -30), Color3.fromRGB(64, 255, 236))
	buildKiosk(folder, "Savunmalar", "Aç", Vector3.new(22, 4, -26), Color3.fromRGB(122, 60, 255))
	buildKiosk(folder, "Soygun Panosu", "Aç", Vector3.new(-22, 4, 26), Color3.fromRGB(255, 64, 88))
	buildKiosk(folder, "Günlük Ödül", "Al", Vector3.new(22, 4, 26), Color3.fromRGB(92, 200, 122))

	folder.Parent = Workspace
	return folder
end

local function buildPlot(index: number, parent: Instance)
	local angle = (index - 1) / PLOT_COUNT * math.pi * 2
	local position = Vector3.new(math.cos(angle) * PLOT_RADIUS, 0, math.sin(angle) * PLOT_RADIUS)

	local model = Instance.new("Model")
	model.Name = `Kasa{index}`

	local platform = newPart("Platform", Vector3.new(26, 1, 20), Color3.fromRGB(32, 34, 44), model)
	platform.CFrame = CFrame.new(position) * CFrame.Angles(0, -angle + math.pi / 2, 0)

	local backWall = newPart("ArkaDuvar", Vector3.new(26, 14, 1), Color3.fromRGB(20, 21, 28), model)
	backWall.CFrame = platform.CFrame * CFrame.new(0, 7, -9.5)

	local sign = newPart("Tabela", Vector3.new(14, 3, 0.5), Color3.fromRGB(16, 17, 22), model)
	sign.CFrame = backWall.CFrame * CFrame.new(0, 4, 0.8)
	local nameLabel = label(sign, "Boş Kasa", Vector2.new(12, 2.4), 2)
	nameLabel.Name = "Sahip"
	local statLabel = label(sign, "", Vector2.new(12, 1.8), -0.6)
	statLabel.Name = "Durum"

	local pedestals = Instance.new("Folder")
	pedestals.Name = "Kaideler"
	pedestals.Parent = model

	model.Parent = parent
	return {
		model = model,
		platform = platform,
		nameLabel = nameLabel,
		statLabel = statLabel,
		pedestals = pedestals,
		userId = nil,
	}
end

local function renderLabels(plot)
	if not plot.userId then
		plot.nameLabel.Text = "Boş Kasa"
		plot.statLabel.Text = "Bir oyuncu bekleniyor"
		return
	end

	local player = Players:GetPlayerByUserId(plot.userId)
	local profile = if player then DataService.get(player) else nil
	if not player or not profile then
		return
	end

	plot.nameLabel.Text = `{player.DisplayName} Kasası`
	plot.statLabel.Text = `{#profile.placed} hazine · {Format.short(profile.stash)} birikim`
end

-- Kaideler yalnızca kasa içeriği değiştiğinde yeniden kuruluyor: her 5
-- saniyede yüzlerce parçayı silip yeniden yaratmak hem pahalı hem titrek.
local function renderPedestals(plot)
	plot.pedestals:ClearAllChildren()
	if not plot.userId then
		return
	end

	local player = Players:GetPlayerByUserId(plot.userId)
	local profile = if player then DataService.get(player) else nil
	if not profile then
		return
	end

	for index, uid in profile.placed do
		local treasure = profile.treasures[uid]
		if not treasure then
			continue
		end
		local rarity = Config.Rarities.get(treasure.rarity)
		local mutation = Config.Mutations.get(treasure.mutation)

		local row = math.floor((index - 1) / PEDESTALS_PER_ROW)
		local column = (index - 1) % PEDESTALS_PER_ROW
		local offsetX = (column - (PEDESTALS_PER_ROW - 1) / 2) * 2.6
		local offsetZ = 2 - row * 4.5

		local stand = newPart("Kaide", Vector3.new(1.8, 2, 1.8), Color3.fromRGB(44, 46, 58), plot.pedestals)
		stand.CFrame = plot.platform.CFrame * CFrame.new(offsetX, 1.5, offsetZ)

		local gem = newPart("Hazine", Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(table.unpack(mutation.color)), plot.pedestals)
		gem.Material = Enum.Material.Neon
		gem.CFrame = stand.CFrame * CFrame.new(0, 1.8, 0) * CFrame.Angles(math.rad(35), math.rad(35), 0)
		gem.CanCollide = false

		local gemLabel = label(gem, Loot.displayName(treasure), Vector2.new(4.5, 1.1), 1.6)
		gemLabel.TextColor3 = Color3.fromRGB(table.unpack(rarity.color))
	end
end

local function renderPlot(plot)
	renderLabels(plot)
	renderPedestals(plot)
end

local function assignPlot(player: Player)
	for index, plot in plots do
		if not plot.userId then
			plot.userId = player.UserId
			byUser[player.UserId] = index
			renderPlot(plot)

			-- Oyuncuyu kendi kasasının önüne ışınla ki ilk gördüğü şey kasası olsun.
			task.defer(function()
				local character = player.Character or player.CharacterAdded:Wait()
				task.wait(0.2)
				if character and character.PrimaryPart then
					character:PivotTo(plot.platform.CFrame * CFrame.new(0, 4, 6))
				end
			end)
			return
		end
	end
end

local function releasePlot(userId: number)
	local index = byUser[userId]
	if not index then
		return
	end
	byUser[userId] = nil
	local plot = plots[index]
	if plot then
		plot.userId = nil
		renderPlot(plot)
	end
end

function WorldService.plotOf(userId: number)
	local index = byUser[userId]
	return if index then plots[index] else nil
end

function WorldService.init()
	buildHub()

	local plotFolder = Instance.new("Folder")
	plotFolder.Name = "Kasalar"
	plotFolder.Parent = Workspace

	for index = 1, PLOT_COUNT do
		plots[index] = buildPlot(index, plotFolder)
		renderPlot(plots[index])
	end

	DataService.Loaded:connect(assignPlot)
	Players.PlayerRemoving:Connect(function(player)
		releasePlot(player.UserId)
	end)

	VaultService.Changed:connect(function(userId)
		local plot = WorldService.plotOf(userId)
		if plot then
			renderPlot(plot)
		end
	end)

	-- Birikim etiketleri canlı kalsın (kaideler dokunulmadan).
	task.spawn(function()
		while true do
			task.wait(5)
			for _, plot in plots do
				if plot.userId then
					renderLabels(plot)
				end
			end
		end
	end)
end

return WorldService
