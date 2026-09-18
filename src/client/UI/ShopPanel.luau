--!nonstrict
-- Robux ürünleri. ID girilmemiş ürünler "yakında" olarak gösteriliyor ki
-- test sunucusunda kırık satın alma penceresi açılmasın.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(script.Parent.Parent.Controllers.Net)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local ShopPanel = {}

function ShopPanel.mount(parent: Instance)
	local panel = Widgets.panel(parent, "Mağaza", UDim2.fromOffset(600, 500))
	local player = Players.LocalPlayer
	local passRows = {}

	-- Tanıtım kodları: tanıtımcılara verilen kodlar buradan giriliyor.
	local codeRow = Widgets.frame({
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.color.panelAlt,
		LayoutOrder = 0,
		Parent = panel.content,
		ZIndex = 6,
	}, { Widgets.corner(8) })

	Widgets.text({
		Text = "KOD GİR",
		Font = Theme.font.title,
		TextSize = 14,
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(12, 6),
		Parent = codeRow,
		ZIndex = 7,
	})

	local codeBox = Widgets.create("TextBox", {
		Size = UDim2.new(1, -140, 0, 30),
		Position = UDim2.fromOffset(12, 26),
		BackgroundColor3 = Theme.color.panel,
		BorderSizePixel = 0,
		Font = Theme.font.body,
		TextSize = 15,
		TextColor3 = Theme.color.text,
		PlaceholderText = "örn. KASA",
		Text = "",
		ClearTextOnFocus = false,
		Parent = codeRow,
		ZIndex = 7,
	}, { Widgets.corner(6) })

	local codeStatus = Widgets.text({
		Text = "",
		TextSize = 12,
		TextColor3 = Theme.color.textDim,
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.fromOffset(12, 58),
		Parent = codeRow,
		ZIndex = 7,
	})

	local function submitCode()
		local response = Net.invoke("RedeemCode", { code = codeBox.Text })
		if response.ok then
			codeStatus.Text = `✓ {response.data.label}`
			codeStatus.TextColor3 = Theme.color.good
			codeBox.Text = ""
		else
			codeStatus.Text = response.error or "Kod kullanılamadı."
			codeStatus.TextColor3 = Theme.color.bad
		end
	end

	Widgets.button({
		Text = "KULLAN",
		Size = UDim2.fromOffset(112, 30),
		Position = UDim2.new(1, -124, 0, 26),
		Parent = codeRow,
		ZIndex = 7,
	}, submitCode)

	codeBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submitCode()
		end
	end)

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

	local productRows = {}
	for index, product in Config.Monetization.Products do
		local row = Widgets.row(panel.content, product.name, product.description, "Satın Al", function()
			if product.assetId == 0 then
				return
			end
			-- Tek seferlik ürün alınmışsa pencereyi hiç açma.
			if product.oneTime and State.profile and State.profile.purchases[product.id] then
				return
			end
			MarketplaceService:PromptProductPurchase(player, product.assetId)
		end)
		row.root.LayoutOrder = 100 + index
		table.insert(productRows, { product = product, row = row })
	end

	local function refresh()
		local profile = State.profile
		if not profile then
			return
		end
		for _, entry in productRows do
			local product = entry.product
			if product.oneTime and profile.purchases and profile.purchases[product.id] then
				entry.row.button.Text = "ALINDI"
				entry.row.button.BackgroundColor3 = Theme.color.good
			elseif product.assetId == 0 then
				entry.row.button.Text = "Yakında"
				entry.row.button.BackgroundColor3 = Theme.color.panel
			else
				entry.row.button.Text = "Satın Al"
				entry.row.button.BackgroundColor3 = Theme.color.accent
			end
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
