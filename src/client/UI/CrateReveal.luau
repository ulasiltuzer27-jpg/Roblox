--!nonstrict
-- Sandık açılış kartı. Kısa ve okunur: nadirlik rengi + mutasyon adı,
-- ekran görüntüsü alınmaya değecek an burada.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Loot = require(ReplicatedStorage.Shared.Core.Loot)
local Net = require(script.Parent.Parent.Controllers.Net)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local CrateReveal = {}

function CrateReveal.mount(parent: Instance)
	local card = Widgets.frame({
		Name = "CrateReveal",
		Size = UDim2.fromOffset(340, 150),
		Position = UDim2.fromScale(0.5, 0.36),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.color.panel,
		Visible = false,
		Parent = parent,
		ZIndex = 18,
	}, { Widgets.corner(14) })

	local stroke = Widgets.stroke(Theme.color.accent, 2)
	stroke.Parent = card

	local title = Widgets.text({
		Text = "",
		Font = Theme.font.title,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 34),
		Position = UDim2.fromOffset(10, 22),
		Parent = card,
		ZIndex = 19,
	})

	local subtitle = Widgets.text({
		Text = "",
		TextColor3 = Theme.color.textDim,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 58),
		Parent = card,
		ZIndex = 19,
	})

	local extra = Widgets.text({
		Text = "",
		TextColor3 = Theme.color.textDim,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 86),
		Parent = card,
		ZIndex = 19,
	})

	local queue = {}
	local showing = false

	local function present(entry)
		local treasure = entry.treasure
		local rarity = Config.Rarities.get(treasure.rarity)
		local mutation = Config.Mutations.get(treasure.mutation)

		title.Text = Loot.displayName(treasure)
		title.TextColor3 = Color3.fromRGB(table.unpack(rarity.color))
		stroke.Color = Color3.fromRGB(table.unpack(mutation.color))
		subtitle.Text = `{Format.short(Economy.treasureIncome(treasure))}/sn gelir`
		extra.Text = if entry.placed then "Kasana yerleştirildi" else "Envanterine eklendi (kasan dolu)"

		card.Visible = true
		card.Size = UDim2.fromOffset(300, 130)
		TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Back), {
			Size = UDim2.fromOffset(340, 150),
		}):Play()
	end

	local function drain()
		if showing then
			return
		end
		showing = true
		task.spawn(function()
			while #queue > 0 do
				present(table.remove(queue, 1))
				task.wait(if #queue > 3 then 0.35 else 1.1)
			end
			card.Visible = false
			showing = false
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
