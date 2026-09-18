--!nonstrict
-- Sandık açılış animasyonu.
--
-- Akış: kart açılır -> nadirlikler hızla dönerek yavaşlar -> sonuçta durur
-- -> nadirse ışık patlaması ve ekran titremesi. Klasik "case opening" hissi;
-- oyunun klip üreten anı burası.
--
-- Toplu açmada (10 AÇ) dönme atlanır, kartlar hızlı akar: 10 kez 2 saniye
-- beklemek eğlenceli değil.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Loot = require(ReplicatedStorage.Shared.Core.Loot)
local Net = require(script.Parent.Parent.Controllers.Net)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local CrateReveal = {}

local ROLL_SECONDS = 0.85 -- tek açmada dönme süresi
local HOLD_SECONDS = 1.15 -- sonucun ekranda kalma süresi
local BULK_HOLD_SECONDS = 0.3 -- toplu açmada
local BURST_COUNT = 10

-- Bu eşiklerin üstü "olay": patlama, titreme ve daha uzun bekleme.
local function isSpecial(treasure): boolean
	return Loot.shouldAnnounce(treasure)
end

function CrateReveal.mount(parent: Instance)
	local card = Widgets.frame({
		Name = "CrateReveal",
		Size = UDim2.fromOffset(340, 160),
		Position = UDim2.fromScale(0.5, 0.36),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.color.panel,
		Visible = false,
		Parent = parent,
		ZIndex = 18,
	}, { Widgets.corner(14) })

	local stroke = Widgets.stroke(Theme.color.accent, 2)
	stroke.Parent = card

	-- Işık patlaması için ışınlar; kartın arkasında durur.
	local burst = Widgets.frame({
		Name = "Burst",
		Size = UDim2.fromOffset(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = card,
		ZIndex = 17,
	})

	local rays = {}
	for index = 1, BURST_COUNT do
		local ray = Widgets.frame({
			Size = UDim2.fromOffset(4, 42),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.color.accent,
			BackgroundTransparency = 1,
			Rotation = (index - 1) / BURST_COUNT * 360,
			Parent = burst,
			ZIndex = 17,
		}, { Widgets.corner(2) })
		table.insert(rays, ray)
	end

	local title = Widgets.text({
		Text = "",
		Font = Theme.font.title,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 34),
		Position = UDim2.fromOffset(10, 26),
		Parent = card,
		ZIndex = 19,
	})

	local subtitle = Widgets.text({
		Text = "",
		TextColor3 = Theme.color.textDim,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 64),
		Parent = card,
		ZIndex = 19,
	})

	local extra = Widgets.text({
		Text = "",
		TextColor3 = Theme.color.textDim,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 92),
		Parent = card,
		ZIndex = 19,
	})

	-- Kalan sandık sayacı: toplu açmada ne kadar kaldığını gösterir.
	local counter = Widgets.text({
		Text = "",
		TextColor3 = Theme.color.textDim,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 120),
		Parent = card,
		ZIndex = 19,
	})

	-- Ekran flaşı (nadir sonuçlarda)
	local flash = Widgets.frame({
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
		ZIndex = 17,
	})

	local queue = {}
	local running = false

	local function colorOf(treasure)
		return Color3.fromRGB(table.unpack(Config.Mutations.get(treasure.mutation).color))
	end

	local function playBurst(color: Color3)
		burst.Size = UDim2.fromOffset(1, 1)
		for _, ray in rays do
			ray.BackgroundColor3 = color
			ray.BackgroundTransparency = 0.15
			ray.Size = UDim2.fromOffset(4, 30)
			TweenService:Create(ray, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(2, 130),
			}):Play()
		end
	end

	local function playFlash(color: Color3)
		flash.BackgroundColor3 = color
		flash.BackgroundTransparency = 0.55
		flash.Visible = true
		local tween = TweenService:Create(flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 1,
		})
		tween.Completed:Connect(function()
			flash.Visible = false
		end)
		tween:Play()
	end

	-- Titreme Humanoid.CameraOffset üzerinden: kameranın CFrame'ini doğrudan
	-- yazmak varsayılan kamera scriptiyle çakışır (her kare geri ezer) ve
	-- sapma birikir. CameraOffset'i kamera scripti zaten hesaba katıyor.
	local shaking = false

	local function shakeCamera(strength: number)
		if shaking then
			return
		end
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		shaking = true
		task.spawn(function()
			local elapsed = 0
			while elapsed < 0.35 and humanoid.Parent do
				elapsed += RunService.RenderStepped:Wait()
				local falloff = math.max(0, 1 - elapsed / 0.35)
				humanoid.CameraOffset = Vector3.new(
					(math.random() - 0.5) * strength * falloff,
					(math.random() - 0.5) * strength * falloff,
					0
				)
			end
			if humanoid.Parent then
				humanoid.CameraOffset = Vector3.zero
			end
			shaking = false
		end)
	end

	-- Sonuç açıklanmadan önce nadirlikler arasında hızla dönen yazı.
	local function rollThen(treasure, onDone)
		local names = {}
		for _, rarity in Config.Rarities.List do
			table.insert(names, rarity)
		end

		task.spawn(function()
			local elapsed = 0
			local index = 1
			local step = 0.04
			while elapsed < ROLL_SECONDS do
				local rarity = names[index]
				title.Text = rarity.name
				title.TextColor3 = Color3.fromRGB(table.unpack(rarity.color))
				subtitle.Text = "..."
				index = index % #names + 1

				task.wait(step)
				elapsed += step
				-- Yavaşlayarak dur: gerilim buradan geliyor.
				step = math.min(0.16, step * 1.14)
			end
			onDone()
		end)
	end

	local function present(entry, remaining: number, instant: boolean)
		local treasure = entry.treasure
		local rarity = Config.Rarities.get(treasure.rarity)
		local mutationColor = colorOf(treasure)

		local function reveal()
			title.Text = Loot.displayName(treasure)
			title.TextColor3 = Color3.fromRGB(table.unpack(rarity.color))
			stroke.Color = mutationColor
			subtitle.Text = `{Format.short(Economy.treasureIncome(treasure))}/sn gelir`
			extra.Text = if entry.placed then "Kasana yerleştirildi" else "Envanterine eklendi (kasan dolu)"
			counter.Text = if remaining > 0 then `+{remaining} sandık daha` else ""

			-- Ortaya çıkış vuruşu
			card.Size = UDim2.fromOffset(310, 142)
			TweenService:Create(card, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(340, 160),
			}):Play()

			if isSpecial(treasure) then
				playBurst(mutationColor)
				playFlash(mutationColor)
				shakeCamera(0.55)
			end
		end

		card.Visible = true
		if instant then
			reveal()
		else
			stroke.Color = Theme.color.stroke
			extra.Text = ""
			counter.Text = if remaining > 0 then `+{remaining} sandık daha` else ""
			rollThen(treasure, reveal)
		end
	end

	local function drain()
		if running then
			return
		end
		running = true
		task.spawn(function()
			while #queue > 0 do
				local entry = table.remove(queue, 1)
				local remaining = #queue
				-- Tek açmada dönme animasyonu, toplu açmada hızlı akış.
				local instant = remaining > 0
				present(entry, remaining, instant)

				local hold = if instant then BULK_HOLD_SECONDS else HOLD_SECONDS
				if not instant then
					hold += ROLL_SECONDS
				end
				if isSpecial(entry.treasure) then
					hold += 0.6 -- nadir sonuç ekranda biraz daha kalsın
				end
				task.wait(hold)
			end

			TweenService:Create(card, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
			task.wait(0.2)
			card.Visible = false
			card.BackgroundTransparency = 0
			running = false
		end)
	end

	Net.on("CrateResult", function(payload)
		for _, entry in payload.results do
			table.insert(queue, entry)
		end
		drain()
	end)

	return card
end

return CrateReveal
