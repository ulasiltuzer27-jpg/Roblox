--!nonstrict
-- Sandık dükkanı: satın al, aç, çıkma ihtimallerini gör.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Loot = require(ReplicatedStorage.Shared.Core.Loot)
local Net = require(script.Parent.Parent.Controllers.Net)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local CratePanel = {}

local function oddsText(crateId: string, luck: number): string
	local parts = {}
	for index = #Config.Rarities.List, 1, -1 do
		local rarity = Config.Rarities.List[index]
		local chance = Loot.rarityChance(crateId, rarity.id, luck)
		if chance > 0 and #parts < 3 then
			local color = string.format("rgb(%d,%d,%d)", table.unpack(rarity.color))
			table.insert(parts, `<font color="{color}">{rarity.name} {Format.odds(chance)}</font>`)
		end
	end
	return table.concat(parts, "  ·  ")
end

function CratePanel.mount(parent: Instance)
	local panel = Widgets.panel(parent, "Sandık Dükkanı", UDim2.fromOffset(560, 470))
	local rows = {}

	for _, crate in Config.Crates.List do
		local card = Widgets.frame({
			Size = UDim2.new(1, 0, 0, 92),
			BackgroundColor3 = Theme.color.panelAlt,
			Parent = panel.content,
			ZIndex = 6,
		}, { Widgets.corner(10) })

		local title = Widgets.text({
			Text = crate.name,
			Font = Theme.font.title,
			TextSize = 16,
			Size = UDim2.new(1, -220, 0, 22),
			Position = UDim2.fromOffset(12, 8),
			Parent = card,
			ZIndex = 7,
		})

		local price = Widgets.text({
			Text = "",
			TextColor3 = Theme.color.coin,
			TextSize = 14,
			Size = UDim2.new(1, -220, 0, 18),
			Position = UDim2.fromOffset(12, 30),
			Parent = card,
			ZIndex = 7,
		})

		local odds = Widgets.text({
			Text = "",
			TextColor3 = Theme.color.textDim,
			TextSize = 12,
			Size = UDim2.new(1, -24, 0, 18),
			Position = UDim2.fromOffset(12, 52),
			Parent = card,
			ZIndex = 7,
		})

		local owned = Widgets.text({
			Text = "",
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromOffset(180, 18),
			Position = UDim2.new(1, -192, 0, 8),
			Parent = card,
			ZIndex = 7,
		})

		Widgets.button({
			Text = "Satın Al",
			Size = UDim2.fromOffset(84, 30),
			Position = UDim2.new(1, -192, 0, 30),
			BackgroundColor3 = Theme.color.panel,
			Parent = card,
			ZIndex = 7,
		}, function()
			Net.invoke("BuyCrates", { crateId = crate.id, amount = 1 })
		end)

		Widgets.button({
			Text = "10 Al",
			Size = UDim2.fromOffset(84, 30),
			Position = UDim2.new(1, -100, 0, 30),
			BackgroundColor3 = Theme.color.panel,
			Parent = card,
			ZIndex = 7,
		}, function()
			Net.invoke("BuyCrates", { crateId = crate.id, amount = 10 })
		end)

		Widgets.button({
			Text = "AÇ",
			Size = UDim2.fromOffset(84, 30),
			Position = UDim2.new(1, -192, 0, 56),
			BackgroundColor3 = Theme.color.accent,
			Parent = card,
			ZIndex = 7,
		}, function()
			Net.invoke("OpenCrates", { crateId = crate.id, amount = 1 })
		end)

		Widgets.button({
			Text = "10 AÇ",
			Size = UDim2.fromOffset(84, 30),
			Position = UDim2.new(1, -100, 0, 56),
			BackgroundColor3 = Theme.color.accent,
			Parent = card,
			ZIndex = 7,
		}, function()
			Net.invoke("OpenCrates", { crateId = crate.id, amount = 10 })
		end)

		table.insert(rows, {
			crate = crate,
			card = card,
			title = title,
			price = price,
			odds = odds,
			owned = owned,
		})
	end

	local function refresh()
		local profile = State.profile
		if not profile then
			return
		end
		local effects = State.event and State.event.effects
		local discount = if effects then effects.crateDiscount or 0 else 0
		for _, row in rows do
			local crate = row.crate
			local unlocked = Config.Zones.isUnlocked(crate.zone, profile.rebirths)
			row.card.BackgroundTransparency = if unlocked then 0 else 0.5
			row.title.Text = if unlocked
				then crate.name
				else `{crate.name} 🔒 ({Config.Zones.get(crate.zone).requiredRebirths} rebirth)`

			if crate.currency == "tokens" then
				row.price.Text = `{crate.cost} jeton`
			else
				row.price.Text = `{Format.short(Economy.crateCost(crate.id, discount))} coin`
			end

			row.odds.Text = oddsText(crate.id, profile.luck or 1)
			local count = profile.crates[crate.id] or 0
			row.owned.Text = if count > 0 then `Envanterinde {count} adet` else ""
		end
	end

	State.Changed:connect(refresh)
	-- Event başlayınca indirimli fiyat anında görünsün.
	State.EventChanged:connect(refresh)
	refresh()
	return panel
end

return CratePanel
