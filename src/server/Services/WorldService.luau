--!nonstrict
-- Dünyayı kurar: beş bölge, kasa parselleri, kiosklar ve bölgeler arası
-- kapılar. Geometri Core/MapLayout'tan geliyor (saf ve test edilmiş);
-- buranın işi o tarifleri Instance'a çevirmek ve oyuncuları yönetmek.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Loot = require(ReplicatedStorage.Shared.Core.Loot)
local MapLayout = require(ReplicatedStorage.Shared.Core.MapLayout)
local DataService = require(ServerScriptService.Server.Services.DataService)
local NotificationService = require(ServerScriptService.Server.Services.NotificationService)
local VaultService = require(ServerScriptService.Server.Services.VaultService)

local WorldService = {}

local PEDESTALS_PER_ROW = 6

-- zoneId -> { folder, layout, plots = { {model, userId, ...} }, spawn }
local zones: { [string]: any } = {}
-- userId -> { zoneId, index }
local assignments: { [number]: any } = {}

--═══ Yardımcılar ═══════════════════════════════════════════════════════

local function color3(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function vector3(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

local function cframeOf(position: { number }, rotation: { number }): CFrame
	return CFrame.new(vector3(position))
		* CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
end

local function buildPart(spec, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Size = vector3(spec.size)
	part.CFrame = cframeOf(spec.position, spec.rotation)
	part.Color = color3(spec.color)
	part.Material = (Enum.Material :: any)[spec.material]
	part.Anchored = true
	part.CanCollide = if spec.collide == nil then true else spec.collide
	-- Dekoratif parçalar imleç ve raycast'i yakalamasın.
	part.CanQuery = part.CanCollide
	part.CanTouch = false
	part.Transparency = spec.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	if spec.shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif spec.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end

	if spec.light then
		local light = Instance.new("PointLight")
		light.Color = color3(spec.light.color)
		light.Brightness = spec.light.brightness
		light.Range = spec.light.range
		light.Shadows = false
		light.Parent = part
	end

	part.Parent = parent
	return part
end

local function billboard(parent: BasePart, text: string, width: number, height: number, offset: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(width, height)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	gui.MaxDistance = 260
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(240, 240, 250)
	label.TextStrokeTransparency = 0.35
	label.Text = text
	label.Parent = gui
	return label
end

--═══ Kurulum ═══════════════════════════════════════════════════════════

local function buildKiosk(spec, parent: Instance)
	local kiosk = Instance.new("Part")
	kiosk.Name = spec.name
	kiosk.Size = vector3(Config.Map.Dimensions.kioskSize)
	kiosk.CFrame = cframeOf(spec.position, spec.rotation)
	kiosk.Color = color3(spec.color)
	kiosk.Material = Enum.Material.Neon
	kiosk.Anchored = true
	kiosk.CanCollide = true
	kiosk.CanTouch = false
	kiosk.Parent = parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = spec.prompt
	prompt.ObjectText = spec.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = kiosk

	billboard(kiosk, spec.name, 7, 1.5, Config.Map.Dimensions.kioskSize[2] / 2 + 1.6)
	return kiosk
end

local function buildGate(spec, parent: Instance)
	local gate = Instance.new("Part")
	gate.Name = `Kapi_{spec.targetZone}`
	gate.Size = Vector3.new(Config.Map.Dimensions.gateSize[1], 1, Config.Map.Dimensions.gateSize[3])
	gate.CFrame = cframeOf(spec.position, spec.rotation) * CFrame.new(0, 0.5, 0)
	gate.Transparency = 1
	gate.Anchored = true
	gate.CanCollide = false
	gate.CanTouch = false
	gate.Parent = parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = "Git"
	prompt.ObjectText = spec.label
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = gate

	local label = billboard(gate, spec.label, 12, 2, Config.Map.Dimensions.gateArchHeight + 2.6)
	if spec.requiredRebirths > 0 then
		label.Text = `{spec.label}\n🔒 {spec.requiredRebirths} rebirth`
	end

	-- Bölge kimliği istemci tarafında da lazım.
	local value = Instance.new("StringValue")
	value.Name = "TargetZone"
	value.Value = spec.targetZone
	value.Parent = gate

	return gate, label
end

local function buildPlot(spec, parent: Instance)
	local model = Instance.new("Model")
	model.Name = `Kasa{spec.index}`

	local dimensions = Config.Map.Dimensions
	local anchor = Instance.new("Part")
	anchor.Name = "Zemin"
	anchor.Size = Vector3.new(dimensions.plotWidth - 1, 0.2, dimensions.plotDepth - 1)
	anchor.CFrame = cframeOf(spec.position, spec.rotation) * CFrame.new(0, 1.1, 0)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.Parent = model

	local sign = Instance.new("Part")
	sign.Name = "Tabela"
	sign.Size = Vector3.new(dimensions.plotWidth - 6, 3, 0.4)
	sign.CFrame = cframeOf(spec.position, spec.rotation)
		* CFrame.new(0, dimensions.plotWallHeight - 2, -(dimensions.plotDepth / 2 - 2))
	sign.Color = Color3.fromRGB(14, 15, 20)
	sign.Material = Enum.Material.SmoothPlastic
	sign.Anchored = true
	sign.CanCollide = false
	sign.CanTouch = false
	sign.Parent = model

	local owner = billboard(sign, "Boş Kasa", 14, 2.2, 1.8)
	owner.Name = "Sahip"
	local status = billboard(sign, "", 14, 1.6, -0.3)
	status.Name = "Durum"
	status.TextColor3 = Color3.fromRGB(160, 166, 184)

	local pedestals = Instance.new("Folder")
	pedestals.Name = "Kaideler"
	pedestals.Parent = model

	model.Parent = parent
	return {
		index = spec.index,
		model = model,
		anchor = anchor,
		owner = owner,
		status = status,
		pedestals = pedestals,
		userId = nil,
	}
end

local function buildZone(zoneId: string, parent: Instance)
	local layout = MapLayout.build(zoneId)
	local theme = Config.Map.theme(zoneId)

	local folder = Instance.new("Folder")
	folder.Name = zoneId
	folder.Parent = parent

	local structure = Instance.new("Folder")
	structure.Name = "Yapi"
	structure.Parent = folder
	for _, spec in layout.parts do
		buildPart(spec, structure)
	end

	local kioskFolder = Instance.new("Folder")
	kioskFolder.Name = "Kiosklar"
	kioskFolder.Parent = folder
	for _, spec in layout.kiosks do
		buildKiosk(spec, kioskFolder)
	end

	local gateFolder = Instance.new("Folder")
	gateFolder.Name = "Kapilar"
	gateFolder.Parent = folder
	for _, spec in layout.gates do
		buildGate(spec, gateFolder)
	end

	local plotFolder = Instance.new("Folder")
	plotFolder.Name = "Kasalar"
	plotFolder.Parent = folder

	local plots = {}
	for _, spec in layout.plots do
		table.insert(plots, buildPlot(spec, plotFolder))
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(Config.Map.Dimensions.spawnSize, 1, Config.Map.Dimensions.spawnSize)
	spawn.CFrame = cframeOf(layout.spawn.position, layout.spawn.rotation)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = color3(theme.accent)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.5
	spawn.CanCollide = true
	-- Yalnızca bölgesindeki oyuncular burada doğsun diye kendiliğinden
	-- seçilmesini kapatıyoruz; atamayı RespawnLocation ile yapıyoruz.
	spawn.Enabled = zoneId == "hub"
	spawn.Parent = folder

	zones[zoneId] = { folder = folder, layout = layout, plots = plots, spawn = spawn }
end

--═══ Parseller ═════════════════════════════════════════════════════════

local function renderLabels(plot)
	if not plot.userId then
		plot.owner.Text = "Boş Kasa"
		plot.status.Text = "Bir oyuncu bekleniyor"
		return
	end

	local player = Players:GetPlayerByUserId(plot.userId)
	local profile = if player then DataService.get(player) else nil
	if not player or not profile then
		return
	end

	plot.owner.Text = player.DisplayName
	plot.status.Text = `{#profile.placed} hazine · {Format.short(profile.stash)} birikim`
end

-- Kaideler yalnızca kasa içeriği değiştiğinde kuruluyor: her saniye
-- yüzlerce parçayı silip yaratmak hem pahalı hem titrek.
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

	local base = plot.anchor.CFrame
	for index, uid in profile.placed do
		local treasure = profile.treasures[uid]
		if not treasure then
			continue
		end
		local rarity = Config.Rarities.get(treasure.rarity)
		local mutation = Config.Mutations.get(treasure.mutation)

		local row = math.floor((index - 1) / PEDESTALS_PER_ROW)
		local column = (index - 1) % PEDESTALS_PER_ROW
		local offsetX = (column - (PEDESTALS_PER_ROW - 1) / 2) * 3.2
		local offsetZ = 4 - row * 4.2

		local stand = Instance.new("Part")
		stand.Name = "Kaide"
		stand.Size = Vector3.new(2, 2.4, 2)
		stand.CFrame = base * CFrame.new(offsetX, 1.2, offsetZ)
		stand.Color = Color3.fromRGB(44, 46, 58)
		stand.Material = Enum.Material.Metal
		stand.Anchored = true
		stand.CanCollide = false
		stand.CanTouch = false
		stand.Parent = plot.pedestals

		local gem = Instance.new("Part")
		gem.Name = "Hazine"
		gem.Size = Vector3.new(1.4, 1.4, 1.4)
		gem.CFrame = stand.CFrame * CFrame.new(0, 2, 0) * CFrame.Angles(math.rad(35), math.rad(35), 0)
		gem.Color = color3(mutation.color)
		gem.Material = Enum.Material.Neon
		gem.Anchored = true
		gem.CanCollide = false
		gem.CanTouch = false
		gem.Parent = plot.pedestals

		local label = billboard(gem, Loot.displayName(treasure), 5, 1.2, 1.7)
		label.TextColor3 = color3(rarity.color)
	end
end

local function releasePlot(userId: number)
	local assignment = assignments[userId]
	if not assignment then
		return
	end
	assignments[userId] = nil

	local zone = zones[assignment.zoneId]
	local plot = zone and zone.plots[assignment.index]
	if plot then
		plot.userId = nil
		renderLabels(plot)
		renderPedestals(plot)
	end
end

local function assignPlot(player: Player, zoneId: string): boolean
	releasePlot(player.UserId)

	local zone = zones[zoneId]
	if not zone then
		return false
	end

	for index, plot in zone.plots do
		if not plot.userId then
			plot.userId = player.UserId
			assignments[player.UserId] = { zoneId = zoneId, index = index }
			renderLabels(plot)
			renderPedestals(plot)
			return true
		end
	end

	warn(`[WorldService] {zoneId} bölgesinde boş parsel yok; {player.Name} kasasız`)
	return false
end

function WorldService.plotOf(userId: number)
	local assignment = assignments[userId]
	if not assignment then
		return nil
	end
	local zone = zones[assignment.zoneId]
	return zone and zone.plots[assignment.index]
end

--═══ Bölge değişimi ════════════════════════════════════════════════════

function WorldService.spawnCFrame(zoneId: string): CFrame?
	local zone = zones[zoneId]
	if not zone then
		return nil
	end
	return zone.spawn.CFrame * CFrame.new(0, 4, 0)
end

-- Oyuncuyu bölgesine yerleştirir: parsel ataması, doğma noktası ve
-- karakterin ışınlanması. Travel bunu çağırmadığı için bölgeler oyunda
-- fiilen erişilemiyordu.
function WorldService.placeInZone(player: Player, zoneId: string, teleport: boolean): boolean
	local zone = zones[zoneId]
	if not zone then
		return false
	end

	local gotPlot = assignPlot(player, zoneId)
	-- RespawnLocation ipucu olarak duruyor ama ona güvenmiyoruz: devre dışı
	-- bir SpawnLocation'ın kabul edilip edilmediği belirsiz. Doğma sonrası
	-- yerleştirmeyi CharacterAdded'da kendimiz yapıyoruz.
	player.RespawnLocation = zone.spawn

	if teleport then
		local character = player.Character
		if character and character.PrimaryPart then
			character:PivotTo(WorldService.spawnCFrame(zoneId))
		end
	end

	if not gotPlot then
		NotificationService.toast(
			player,
			`{Config.Zones.get(zoneId).name} bölgesinde boş kasa yeri kalmamış; kasan görünmeyecek.`,
			"warn"
		)
	end
	return gotPlot
end

-- Oyuncunun o an hangi bölgede olduğunu profilden okur.
local function zoneOf(player: Player): string
	local profile = DataService.get(player)
	local zoneId = profile and profile.zone or "hub"
	return if zones[zoneId] then zoneId else "hub"
end

function WorldService.init()
	local world = Workspace:FindFirstChild("Dunya")
	if world then
		world:Destroy()
	end
	world = Instance.new("Folder")
	world.Name = "Dunya"
	world.Parent = Workspace

	local total = 0
	for _, mapZone in Config.Map.Zones do
		buildZone(mapZone.id, world)
		total += #zones[mapZone.id].layout.parts
	end
	print(`[WorldService] {#Config.Map.Zones} bölge kuruldu, {total} parça`)

	DataService.Loaded:connect(function(player, profile)
		-- Kilidi açık olmayan bir bölgede kayıtlıysa hub'a çek.
		if not Config.Zones.isUnlocked(profile.zone, profile.rebirths) then
			profile.zone = "hub"
		end
		WorldService.placeInZone(player, profile.zone, true)
	end)

	-- Her doğuşta oyuncuyu kendi bölgesine koy. Roblox'un doğma noktası
	-- seçimi birden fazla SpawnLocation varken güvenilmez; soygundan
	-- ölerek çıkan oyuncu da böylece doğru yere dönüyor.
	local function onCharacter(player: Player, character: Model)
		task.defer(function()
			if not player.Parent or not character.Parent then
				return
			end
			local target = WorldService.spawnCFrame(zoneOf(player))
			if target and character.PrimaryPart then
				character:PivotTo(target)
			end
		end)
	end

	for _, player in Players:GetPlayers() do
		if player.Character then
			onCharacter(player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		releasePlot(player.UserId)
	end)

	VaultService.Changed:connect(function(userId)
		local plot = WorldService.plotOf(userId)
		if plot then
			renderLabels(plot)
			renderPedestals(plot)
		end
	end)

	-- Birikim etiketleri canlı kalsın (kaideler dokunulmadan).
	task.spawn(function()
		while true do
			task.wait(5)
			for _, zone in zones do
				for _, plot in zone.plots do
					if plot.userId then
						renderLabels(plot)
					end
				end
			end
		end
	end)
end

return WorldService
