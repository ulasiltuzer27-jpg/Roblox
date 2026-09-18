--!nonstrict
-- Robux ürünleri. ID girilmemiş ürünler "yakında" olarak gösteriliyor ki
-- test sunucusunda kırık satın alma penceresi açılmasın.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local ShopPanel = {}

function ShopPanel.mount(parent: Instance)
	local panel = Widgets.panel(parent, "Mağaza", UDim2.fromOffset(600, 500))
	local player = Players.LocalPlayer
	local passRows = {}

	Widgets.text({
		Text = "GAMEPASS",
		Font = Theme.font.title,
		TextColor3 = Theme.color.textDim,
		TextSize = 15,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 1,
		Parent = panel.content,
		ZIndex = 6,
	})

	for index, pass in Config.Monetization.Gamepasses do
		local row = Widgets.row(panel.content, pass.name, pass.description, "Satın Al", function()
			if pass.assetId == 0 then
				return
			end
			MarketplaceService:PromptGamePassPurchase(player, pass.assetId)
		end)
		row.root.LayoutOrder = 1 + index
		table.insert(passRows, { pass = pass, row = row })
	end

	Widgets.text({
		Text = "ÜRÜNLER",
		Font = Theme.font.title,
		TextColor3 = Theme.color.textDim,
		TextSize = 15,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 100,
		Parent = panel.content,
		ZIndex = 6,
	})

	for index, product in Config.Monetization.Products do
		local row = Widgets.row(panel.content, product.name, product.description, "Satın Al", function()
			if product.assetId == 0 then
				return
			end
			MarketplaceService:PromptProductPurchase(player, product.assetId)
		end)
		row.root.LayoutOrder = 100 + index
		if product.assetId == 0 then
			row.button.Text = "Yakında"
			row.button.BackgroundColor3 = Theme.color.panel
		end
	end

	local function refresh()
		local profile = State.profile
		if not profile then
			return
		end
		for _, entry in passRows do
			local owned = profile.gamepasses and profile.gamepasses[entry.pass.id]
			if owned then
				entry.row.button.Text = "SAHİPSİN"
				entry.row.button.BackgroundColor3 = Theme.color.good
			elseif entry.pass.assetId == 0 then
				entry.row.button.Text = "Yakında"
				entry.row.button.BackgroundColor3 = Theme.color.panel
			else
				entry.row.button.Text = "Satın Al"
				entry.row.button.BackgroundColor3 = Theme.color.accent
			end
		end
	end

	State.Changed:connect(refresh)
	refresh()
	return panel
end

return ShopPanel
