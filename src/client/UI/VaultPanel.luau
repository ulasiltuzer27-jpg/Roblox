--!nonstrict
-- Kasa: hazineleri yerleştir, çıkar, sat. Yuva sayısı ve gelir burada görünür.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Loot = require(ReplicatedStorage.Shared.Core.Loot)
local Net = require(script.Parent.Parent.Controllers.Net)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local VaultPanel = {}

function VaultPanel.mount(parent: Instance)
	local panel = Widgets.panel(parent, "Kasam", UDim2.fromOffset(600, 500))

	local header = Widgets.frame({
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = Theme.color.panelAlt,
		LayoutOrder = 1,
		Parent = panel.content,
		ZIndex = 6,
	}, { Widgets.corner(10) })

	local summary = Widgets.text({
		Text = "",
		Font = Theme.font.title,
		TextSize = 15,
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 8),
		Parent = header,
		ZIndex = 7,
	})

	local detail = Widgets.text({
		Text = "",
		TextColor3 = Theme.color.textDim,
		TextSize = 13,
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(12, 30),
		Parent = header,
		ZIndex = 7,
	})

	Widgets.button({
		Text = "Yerleştirilmemişleri Sat",
		Size = UDim2.fromOffset(190, 26),
		Position = UDim2.new(1, -202, 0, 38),
		BackgroundColor3 = Theme.color.bad,
		Parent = header,
		ZIndex = 7,
	}, function()
		local profile = State.profile
		if not profile then
			return
		end
		local uids = {}
		for uid in profile.treasures do
			if not table.find(profile.placed, uid) then
				table.insert(uids, uid)
			end
		end
		if #uids > 0 then
			Net.invoke("SellTreasures", { uids = uids })
		end
	end)

	local listHolder = Widgets.frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = panel.content,
		ZIndex = 6,
	})
	Widgets.list(Enum.FillDirection.Vertical, 6).Parent = listHolder

	local function treasureRow(uid: string, treasure, placed: boolean)
		local rarity = Config.Rarities.get(treasure.rarity)
		local mutation = Config.Mutations.get(treasure.mutation)
		local income = Economy.treasureIncome(treasure)

		local row = Widgets.frame({
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundColor3 = Theme.color.panelAlt,
			Parent = listHolder,
			ZIndex = 6,
		}, { Widgets.corner(8) })

		Widgets.frame({
			Size = UDim2.fromOffset(6, 32),
			Position = UDim2.fromOffset(10, 8),
			BackgroundColor3 = Color3.fromRGB(table.unpack(mutation.color)),
			Parent = row,
			ZIndex = 7,
		}, { Widgets.corner(3) })

		Widgets.text({
			Text = Loot.displayName(treasure),
			Font = Theme.font.title,
			TextSize = 15,
			TextColor3 = Color3.fromRGB(table.unpack(rarity.color)),
			Size = UDim2.new(1, -200, 0, 20),
			Position = UDim2.fromOffset(24, 5),
			Parent = row,
			ZIndex = 7,
		})

		Widgets.text({
			Text = `{Format.short(income)}/sn · satış {Format.short(Economy.treasureValue(treasure))}`,
			TextColor3 = Theme.color.textDim,
			TextSize = 12,
			Size = UDim2.new(1, -200, 0, 16),
			Position = UDim2.fromOffset(24, 25),
			Parent = row,
			ZIndex = 7,
		})

		Widgets.button({
			Text = if placed then "Çıkar" else "Yerleştir",
			Size = UDim2.fromOffset(88, 28),
			Position = UDim2.new(1, -184, 0.5, -14),
			BackgroundColor3 = if placed then Theme.color.panel else Theme.color.good,
			Parent = row,
			ZIndex = 7,
		}, function()
			Net.invoke(if placed then "UnplaceTreasure" else "PlaceTreasure", { uid = uid })
		end)

		Widgets.button({
			Text = "Sat",
			Size = UDim2.fromOffset(80, 28),
			Position = UDim2.new(1, -92, 0.5, -14),
			BackgroundColor3 = Theme.color.bad,
			Parent = row,
			ZIndex = 7,
		}, function()
			Net.invoke("SellTreasures", { uids = { uid } })
		end)
	end

	local function refresh()
		local profile = State.profile
		if not profile then
			return
		end

		summary.Text = `{#profile.placed}/{profile.slots} yuva dolu · {Format.short(profile.incomePerSecond)}/sn`
		detail.Text = `Şans çarpanı x{string.format("%.2f", profile.luck or 1)} · Servet {Format.short(profile.netWorth)}`

		listHolder:ClearAllChildren()
		Widgets.list(Enum.FillDirection.Vertical, 6).Parent = listHolder

		-- Önce kasadakiler, sonra envanterdekiler; her grup değerine göre sıralı.
		local placedSet = {}
		for _, uid in profile.placed do
			placedSet[uid] = true
			local treasure = profile.treasures[uid]
			if treasure then
				treasureRow(uid, treasure, true)
			end
		end

		local loose = {}
		for uid, treasure in profile.treasures do
			if not placedSet[uid] then
				table.insert(loose, { uid = uid, treasure = treasure })
			end
		end
		table.sort(loose, function(a, b)
			return Economy.treasureIncome(a.treasure) > Economy.treasureIncome(b.treasure)
		end)
		for _, entry in loose do
			treasureRow(entry.uid, entry.treasure, false)
		end
	end

	State.Changed:connect(refresh)
	refresh()
	return panel
end

return VaultPanel
